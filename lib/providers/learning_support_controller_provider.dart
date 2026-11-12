import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/models/learning_support/return_anchor_stack.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:url_launcher/url_launcher.dart';

/// `learning.quick_rescue` (master plan v2.6 §15.0). Default OFF: before
/// the registry runtime is bootstrapped it stays off, and afterwards an
/// unreachable or absent flag is treated as off. It gates only *new* help;
/// returning to the original lesson never reads it.
final quickRescueEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningQuickRescue,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// `learning.auto_gap_suggestions` (master plan v2.6 §15.0, PR-D). Default
/// OFF and fails closed. Independent of `learning.quick_rescue`: turning
/// it off removes only proactive suggestions, never explicit help or Back.
final autoGapSuggestionsEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningAutoGapSuggestions,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// `content.external_companion` (master plan v2.6 §15.0, PR-E). Default
/// OFF and fails closed. Only hides companion pointers and their checks;
/// a Bridge's own source links stay visible.
final externalCompanionEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentExternalCompanion,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Bundled companions, validated against the Bridge Library.
final externalCompanionLibraryProvider =
    FutureProvider<ExternalCompanionLibrary>((ref) async {
      final bridges = await ref.watch(bridgeLibraryProvider.future);
      return ExternalCompanionLibrary.load(rootBundle, bridges);
    });

/// Opens an outside https link in the system browser or a new tab. Never
/// in an embedded view, so no external session is captured (§9.3).
final externalLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The bundled Bridge Library, loaded once from app assets (offline).
final bridgeLibraryProvider = FutureProvider<BridgeLibrary>((ref) {
  return BridgeLibrary.load(rootBundle);
});

final supportSessionStoreProvider = Provider<SupportSessionStore>(
  (ref) => SupportSessionStore(),
);

/// The pilot is limited to one context: spreadsheet/Excel lessons
/// (master plan v2.6 §17 PR-B "one existing Excel lesson/reader").
bool isQuickRescuePilotLesson(Iterable<String> tags) => tags.any((t) {
  final tag = t.toLowerCase();
  return tag == 'excel' || tag == 'spreadsheet';
});

/// Owner scope for local storage: the signed-in user ID, or `guest` when
/// the ID is not a safe opaque identifier.
String supportOwnerScope(String learnerId) =>
    SupportIdentifiers.isId(learnerId) ? learnerId : 'guest';

/// One controller per (owner, learning context) (master plan v2.6 §13.5).
class SupportContextKey {
  const SupportContextKey({
    required this.ownerScope,
    required this.learningContextId,
  });

  final String ownerScope;
  final String learningContextId;

  @override
  bool operator ==(Object other) =>
      other is SupportContextKey &&
      other.ownerScope == ownerScope &&
      other.learningContextId == learningContextId;

  @override
  int get hashCode => Object.hash(ownerScope, learningContextId);
}

enum BridgeOpenOutcome {
  opened,

  /// `learning.quick_rescue` is off: no new help starts.
  gateOff,

  /// Too many nested help steps.
  depthLimit,

  /// This topic is already open further back.
  cycle,

  /// The anchor does not belong to this context, or repeats a session.
  rejected,
}

class LearningSupportState {
  const LearningSupportState({
    required this.stack,
    this.persisted = true,
    this.restored = false,
  });

  final ReturnAnchorStack stack;

  /// Whether the last change was saved and read back. When false, Back
  /// still works in this tab, but a refresh may lose the help trail.
  final bool persisted;

  /// Whether the saved stack has been loaded yet.
  final bool restored;

  LearningSupportState copyWith({
    ReturnAnchorStack? stack,
    bool? persisted,
    bool? restored,
  }) => LearningSupportState(
    stack: stack ?? this.stack,
    persisted: persisted ?? this.persisted,
    restored: restored ?? this.restored,
  );
}

/// The only orchestrator for learning help on a route: it opens Bridges,
/// keeps the bounded return stack and saves it before help is shown. It
/// never records progress, mastery or completion, and never changes the
/// learner's Standard/Fast strategy.
class LearningSupportController extends StateNotifier<LearningSupportState> {
  LearningSupportController({
    required this.key,
    required SupportSessionStore store,
    required bool Function() isGateOn,
  }) : _store = store,
       _isGateOn = isGateOn,
       super(
         LearningSupportState(
           stack: ReturnAnchorStack.empty(ownerScope: key.ownerScope),
         ),
       );

  final SupportContextKey key;
  final SupportSessionStore _store;
  final bool Function() _isGateOn;
  Future<void>? _restoring;

  /// Loads a saved stack for this owner and context. A stack for another
  /// context is left untouched for that context.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    final saved = await _store.load(key.ownerScope);
    if (!mounted) return;
    final root = saved?.root;
    if (saved != null && root?.learningContextId == key.learningContextId) {
      state = state.copyWith(stack: saved, restored: true);
    } else {
      state = state.copyWith(restored: true);
    }
  }

  /// After a refresh the help screens are gone and the learner is back on
  /// [currentRoute]. If that is where the trail started, the trail is done.
  Future<void> settleAt(String currentRoute) async {
    await restore();
    final root = state.stack.root;
    if (root != null && root.originRoute == currentRoute) {
      await _commit(state.stack.unwindToRoot().pop());
    }
  }

  /// Saves [anchor] and pushes [bridge] onto the trail. The anchor is
  /// persisted *before* this returns, so callers show help only after.
  Future<BridgeOpenOutcome> openBridge(
    BridgeLesson bridge,
    ReturnAnchor anchor,
  ) async {
    if (!_isGateOn()) return BridgeOpenOutcome.gateOff;
    await restore();
    if (anchor.learningContextId != key.learningContextId) {
      return BridgeOpenOutcome.rejected;
    }
    final pushed = state.stack.push(anchor, conceptId: bridge.conceptId);
    if (!pushed.isOk) {
      return switch (pushed.rejection!) {
        AnchorPushRejection.depthLimit => BridgeOpenOutcome.depthLimit,
        AnchorPushRejection.cycle => BridgeOpenOutcome.cycle,
        _ => BridgeOpenOutcome.rejected,
      };
    }
    await _commit(pushed.stack!);
    return BridgeOpenOutcome.opened;
  }

  /// Whether opening [bridge] now would be allowed (for disabling buttons).
  bool canOpen(BridgeLesson bridge) =>
      _isGateOn() &&
      state.stack.depth < state.stack.maxDepth &&
      !state.stack.entries.any((e) => e.conceptId == bridge.conceptId);

  /// Leaves the current Bridge. Never gated. Returns where to go back to.
  Future<ReturnAnchor?> returnFromTop() async {
    final top = state.stack.top;
    await _commit(state.stack.pop());
    return top;
  }

  /// Leaves all help and goes back to the original activity. Never gated.
  Future<ReturnAnchor?> returnToRoot() async {
    final root = state.stack.root;
    await _commit(state.stack.unwindToRoot().pop());
    return root;
  }

  Future<void> _commit(ReturnAnchorStack next) async {
    state = state.copyWith(stack: next);
    final ok = await _store.save(next);
    if (mounted) state = state.copyWith(persisted: ok);
  }
}

final learningSupportControllerProvider = StateNotifierProvider.autoDispose
    .family<LearningSupportController, LearningSupportState, SupportContextKey>(
      (ref, key) {
        return LearningSupportController(
          key: key,
          store: ref.watch(supportSessionStoreProvider),
          isGateOn: () => ref.read(quickRescueEnabledProvider),
        );
      },
    );
