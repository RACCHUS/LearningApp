// PR-A2: execution/publication state machines and reuse decisions
// (master plan v2.6 §5.2, Appendix D.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/asset_publication_status.dart';
import 'package:learning_pwa/models/content_generation/content_resolution_decision.dart';
import 'package:learning_pwa/models/content_generation/generation_error.dart';
import 'package:learning_pwa/models/content_generation/generation_job_status.dart';

typedef S = GenerationJobStatus;
typedef E = GenerationJobEvent;
typedef P = AssetPublicationStatus;
typedef PE = AssetPublicationEvent;

/// The §5.2 table, written out independently of the implementation.
const _allowed = <S, Map<E, S>>{
  S.ready: {
    E.showManualPrompt: S.awaitingManualResponse,
    E.startAuthorizedRoute: S.running,
    E.cancel: S.cancelled,
  },
  S.awaitingManualResponse: {
    E.pasteResponse: S.validating,
    E.pause: S.paused,
    E.cancel: S.cancelled,
  },
  S.running: {
    E.receiveResponse: S.validating,
    E.providerRateLimit: S.rateLimited,
    E.pause: S.paused,
    E.fail: S.failedSafe,
    E.cancel: S.cancelled,
  },
  S.validating: {
    E.allRequiredSlotsValid: S.completedPrivate,
    E.someValid: S.partialReady,
    E.requiresRepair: S.repairNeeded,
    E.fail: S.failedSafe,
  },
  S.partialReady: {
    E.prepareNext: S.ready,
    E.repair: S.repairNeeded,
    E.finishPartialIfAllowed: S.completedPrivate,
    E.pause: S.paused,
    E.cancel: S.cancelled,
  },
  S.repairNeeded: {
    E.prepareRepairPrompt: S.ready,
    E.userEdit: S.validating,
    E.pause: S.paused,
    E.cancel: S.cancelled,
  },
  S.paused: {
    E.resumeManual: S.awaitingManualResponse,
    E.prepare: S.ready,
    E.reauthorizeExecutor: S.running,
    E.cancel: S.cancelled,
  },
  S.rateLimited: {
    E.userRetryOrSwitch: S.ready,
    E.pause: S.paused,
    E.cancel: S.cancelled,
  },
};

void main() {
  group('GenerationJobMachine: every status × event', () {
    for (final status in S.values) {
      for (final event in E.values) {
        final expected = _allowed[status]?[event];
        test('${status.wire} + ${event.name}', () {
          final r = GenerationJobMachine.apply(
            GenerationJobState(status, revision: 3),
            event,
          );
          if (expected == null) {
            expect(r.isOk, isFalse);
            expect(
              r.error!.errorCode,
              GenerationErrorCode.invalidStateTransition,
            );
            expect(r.state, isNull, reason: 'never resets to ready');
          } else {
            expect(r.state!.status, expected);
            expect(r.state!.revision, 4);
          }
        });
      }
    }
  });

  test('terminal states are exactly completed/failed/cancelled', () {
    expect(S.values.where((s) => s.isTerminal), {
      S.completedPrivate,
      S.failedSafe,
      S.cancelled,
    });
    for (final t in S.values.where((s) => s.isTerminal)) {
      expect(GenerationJobMachine.table[t], isEmpty);
    }
  });

  test('stale revision is a checkpoint conflict', () {
    final r = GenerationJobMachine.apply(
      const GenerationJobState(S.ready, revision: 5),
      E.showManualPrompt,
      expectedRevision: 4,
    );
    expect(r.error!.errorCode, GenerationErrorCode.checkpointConflict);
  });

  test('no publication/reuse words leak into execution statuses', () {
    const forbidden = {
      'identified',
      'resource_checked',
      'reused_existing',
      'pending_public_review',
      'published',
      'manual_pending',
      'draft_ready',
      'public_approved',
    };
    expect(
      S.values.map((s) => s.wire).toSet().intersection(forbidden),
      isEmpty,
    );
    expect(S.fromWire('published'), isNull);
  });

  group('AssetPublicationMachine', () {
    const owner = PublicationActor(isOwner: true);
    const moderator = PublicationActor(isOwner: false, canModerate: true);
    const publisher = PublicationActor(isOwner: false, canPublish: true);

    test('happy path needs the right actor at each step', () {
      var s = AssetPublicationMachine.apply(
        P.privateDraft,
        PE.submit,
        actor: owner,
      ).status!;
      expect(s, P.submitted);
      s = AssetPublicationMachine.apply(
        s,
        PE.checksPassed,
        actor: moderator,
      ).status!;
      expect(s, P.readyForPublication);
      s = AssetPublicationMachine.apply(
        s,
        PE.publish,
        actor: publisher,
        rightsCleared: true,
      ).status!;
      expect(s, P.published);
      expect(
        AssetPublicationMachine.apply(s, PE.withdraw, actor: moderator).status,
        P.withdrawn,
      );
    });

    test('owner cannot approve or publish their own draft', () {
      expect(
        AssetPublicationMachine.apply(
          P.submitted,
          PE.checksPassed,
          actor: owner,
        ).error!.errorCode,
        GenerationErrorCode.publicationDenied,
      );
      expect(
        AssetPublicationMachine.apply(
          P.readyForPublication,
          PE.publish,
          actor: owner,
          rightsCleared: true,
        ).error!.errorCode,
        GenerationErrorCode.publicationDenied,
      );
    });

    test('publishing without cleared rights is blocked', () {
      expect(
        AssetPublicationMachine.apply(
          P.readyForPublication,
          PE.publish,
          actor: publisher,
        ).error!.errorCode,
        GenerationErrorCode.sourceRightsBlocked,
      );
    });

    test('a draft cannot jump straight to published', () {
      expect(
        AssetPublicationMachine.apply(
          P.privateDraft,
          PE.publish,
          actor: publisher,
          rightsCleared: true,
        ).error!.errorCode,
        GenerationErrorCode.invalidStateTransition,
      );
    });

    test(
      'checks_failed returns to submitted only by resubmit after repair',
      () {
        expect(
          AssetPublicationMachine.apply(
            P.checksFailed,
            PE.resubmitAfterRepair,
            actor: owner,
          ).status,
          P.submitted,
        );
        expect(
          AssetPublicationMachine.apply(
            P.checksFailed,
            PE.submit,
            actor: owner,
          ).isOk,
          isFalse,
        );
      },
    );

    test('rejected, withdrawn and superseded are final', () {
      for (final s in [P.rejected, P.withdrawn, P.superseded]) {
        for (final e in PE.values) {
          expect(
            AssetPublicationMachine.apply(
              s,
              e,
              actor: const PublicationActor(
                isOwner: true,
                canModerate: true,
                canPublish: true,
              ),
              rightsCleared: true,
            ).isOk,
            isFalse,
          );
        }
      }
    });

    test('job and publication statuses share no values', () {
      expect(
        S.values
            .map((s) => s.wire)
            .toSet()
            .intersection(P.values.map((p) => p.wire).toSet()),
        isEmpty,
      );
    });
  });

  group('ContentResolutionDecision', () {
    test('only generate creates a job', () {
      for (final kind in ContentResolutionKind.values) {
        final d = ContentResolutionDecision(
          kind: kind,
          reason: 'r',
          eligibleAssetRef: 'asset-1',
        );
        expect(
          d.createsGenerationJob,
          kind == ContentResolutionKind.generate,
          reason: kind.wire,
        );
      }
    });
  });

  test('every error code has a stable code and learner-facing text', () {
    final codes = GenerationErrorCode.values.map((c) => c.code).toSet();
    expect(codes, hasLength(17));
    for (final c in GenerationErrorCode.values) {
      expect(c.userMessage, isNotEmpty);
      expect(c.recovery, isNotEmpty);
    }
  });
}
