import 'package:learning_pwa/models/content_generation/generation_error.dart';

/// Lifecycle of a content asset version, independent of any generation job
/// (master plan v2.6 §5.2, Appendix D.1). A job finishing never publishes
/// anything, and publication never implies correctness: trust evidence is
/// recorded separately.
enum AssetPublicationStatus {
  privateDraft('private_draft'),
  submitted('submitted'),
  checksFailed('checks_failed'),
  readyForPublication('ready_for_publication'),
  published('published'),
  rejected('rejected'),
  withdrawn('withdrawn'),
  superseded('superseded');

  const AssetPublicationStatus(this.wire);

  final String wire;

  static AssetPublicationStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

enum AssetPublicationEvent {
  submit,
  checksFailed,
  checksPassed,
  reject,
  resubmitAfterRepair,
  publish,
  withdraw,
  supersede,
}

/// Who is asking for a publication change. Supplied by an authenticated
/// server layer in production; never trusted from client-only claims.
class PublicationActor {
  const PublicationActor({
    required this.isOwner,
    this.canModerate = false,
    this.canPublish = false,
  });

  /// Owns the draft (may submit or resubmit it).
  final bool isOwner;

  /// May record check results, reject, withdraw or supersede.
  final bool canModerate;

  /// May publish a version that is ready for publication.
  final bool canPublish;
}

class AssetPublicationResult {
  const AssetPublicationResult._(this.status, this.error);

  final AssetPublicationStatus? status;
  final GenerationError? error;

  bool get isOk => error == null;
}

class AssetPublicationMachine {
  const AssetPublicationMachine._();

  static const Map<
    AssetPublicationStatus,
    Map<AssetPublicationEvent, AssetPublicationStatus>
  >
  table = {
    AssetPublicationStatus.privateDraft: {
      AssetPublicationEvent.submit: AssetPublicationStatus.submitted,
    },
    AssetPublicationStatus.submitted: {
      AssetPublicationEvent.checksFailed: AssetPublicationStatus.checksFailed,
      AssetPublicationEvent.checksPassed:
          AssetPublicationStatus.readyForPublication,
      AssetPublicationEvent.reject: AssetPublicationStatus.rejected,
    },
    AssetPublicationStatus.checksFailed: {
      AssetPublicationEvent.resubmitAfterRepair:
          AssetPublicationStatus.submitted,
    },
    AssetPublicationStatus.readyForPublication: {
      AssetPublicationEvent.publish: AssetPublicationStatus.published,
    },
    AssetPublicationStatus.published: {
      AssetPublicationEvent.withdraw: AssetPublicationStatus.withdrawn,
      AssetPublicationEvent.supersede: AssetPublicationStatus.superseded,
    },
    AssetPublicationStatus.rejected: {},
    AssetPublicationStatus.withdrawn: {},
    AssetPublicationStatus.superseded: {},
  };

  /// Applies [event] for [actor]. Publishing additionally requires
  /// [rightsCleared]; every refusal is a structured, audit-safe error.
  static AssetPublicationResult apply(
    AssetPublicationStatus current,
    AssetPublicationEvent event, {
    required PublicationActor actor,
    bool rightsCleared = false,
  }) {
    final next = table[current]?[event];
    if (next == null) {
      return AssetPublicationResult._(
        null,
        GenerationError(
          GenerationErrorCode.invalidStateTransition,
          detail: '${event.name} is not allowed from ${current.wire}',
        ),
      );
    }
    final allowed = switch (event) {
      AssetPublicationEvent.submit ||
      AssetPublicationEvent.resubmitAfterRepair => actor.isOwner,
      AssetPublicationEvent.checksFailed ||
      AssetPublicationEvent.checksPassed ||
      AssetPublicationEvent.reject ||
      AssetPublicationEvent.withdraw ||
      AssetPublicationEvent.supersede => actor.canModerate,
      AssetPublicationEvent.publish => actor.canPublish,
    };
    if (!allowed) {
      return AssetPublicationResult._(
        null,
        GenerationError(
          GenerationErrorCode.publicationDenied,
          detail: '${event.name} requires a different permission',
        ),
      );
    }
    if (event == AssetPublicationEvent.publish && !rightsCleared) {
      return const AssetPublicationResult._(
        null,
        GenerationError(GenerationErrorCode.sourceRightsBlocked),
      );
    }
    return AssetPublicationResult._(next, null);
  }
}
