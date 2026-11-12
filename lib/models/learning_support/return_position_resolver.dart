import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/return_anchor.dart';

/// How exactly a return could be restored, best first (master plan v2.6
/// §10.5 "Position resolution priority").
enum ReturnPrecision {
  /// Same version and block, plus a valid cursor inside it.
  exactPosition,

  /// Same version and block; the cursor was absent or no longer valid.
  blockStart,

  /// The block's counterpart in an approved replacement version.
  mappedReplacement,

  /// The original route/section, without a block position.
  section,

  /// The original route with a best-effort scroll hint. Never "exact".
  approximateScroll,

  /// The learner's goal or catalog entry, with a clear message.
  goalFallback,
}

/// Read-only view of what the app can currently open, supplied by the
/// caller. Implementations must not depend on the feature-control network
/// so that "Back" keeps working when a feature is switched off.
abstract interface class ReturnTargetView {
  /// Whether the current account may still open the anchor's context.
  bool canOpen(ReturnAnchor anchor);

  /// Whether [blockOrItemId] still exists in [assetVersionId].
  bool hasBlock(String assetVersionId, String blockOrItemId);

  /// Whether [token] is still a valid cursor inside that block.
  bool isValidIntraBlockAnchor(
    String assetVersionId,
    String blockOrItemId,
    String token,
  );

  /// The mapped block in an approved replacement version, if any.
  MappedBlock? mappedReplacement(String assetVersionId, String blockOrItemId);

  /// Whether [route] can still be opened.
  bool routeAvailable(String route);

  /// Safe goal/catalog route for this anchor when nothing else works.
  String goalFallbackRoute(ReturnAnchor anchor);
}

class MappedBlock {
  const MappedBlock({
    required this.assetVersionId,
    required this.blockId,
    required this.route,
  });

  final String assetVersionId;
  final String blockId;
  final String route;
}

class ResolvedReturn {
  const ResolvedReturn({
    required this.precision,
    required this.route,
    required this.strategy,
    this.assetVersionId,
    this.blockId,
    this.intraBlockAnchor,
    this.scrollHint,
  });

  final ReturnPrecision precision;
  final String route;

  /// Unchanged from the anchor: returning never switches Standard/Fast.
  final PersistedLearningStrategy strategy;
  final String? assetVersionId;
  final String? blockId;
  final String? intraBlockAnchor;
  final String? scrollHint;

  /// The learner must be told the place changed or could not be found.
  bool get needsExplanation =>
      precision != ReturnPrecision.exactPosition &&
      precision != ReturnPrecision.blockStart;
}

/// Pure, synchronous and ungated: resolves where "Back" should go. It
/// never marks anything complete, clears a stack or calls a scheduler.
class ReturnPositionResolver {
  const ReturnPositionResolver._();

  static ResolvedReturn resolve(ReturnAnchor anchor, ReturnTargetView view) {
    final strategy = anchor.activeLearningStrategy;
    if (!view.canOpen(anchor)) {
      return ResolvedReturn(
        precision: ReturnPrecision.goalFallback,
        route: view.goalFallbackRoute(anchor),
        strategy: strategy,
      );
    }

    final version = anchor.assetVersionId;
    final block = anchor.blockId ?? anchor.assessmentItemId;
    if (version != null && block != null) {
      if (view.hasBlock(version, block)) {
        final token = anchor.intraBlockAnchor;
        final exact =
            token != null &&
            view.isValidIntraBlockAnchor(version, block, token);
        return ResolvedReturn(
          precision: exact
              ? ReturnPrecision.exactPosition
              : ReturnPrecision.blockStart,
          route: anchor.originRoute,
          strategy: strategy,
          assetVersionId: version,
          blockId: block,
          intraBlockAnchor: exact ? token : null,
        );
      }
      final mapped = view.mappedReplacement(version, block);
      if (mapped != null && view.routeAvailable(mapped.route)) {
        return ResolvedReturn(
          precision: ReturnPrecision.mappedReplacement,
          route: mapped.route,
          strategy: strategy,
          assetVersionId: mapped.assetVersionId,
          blockId: mapped.blockId,
        );
      }
    }

    if (view.routeAvailable(anchor.originRoute)) {
      final hint = anchor.pageOrScrollAnchor;
      return ResolvedReturn(
        precision: hint == null
            ? ReturnPrecision.section
            : ReturnPrecision.approximateScroll,
        route: anchor.originRoute,
        strategy: strategy,
        scrollHint: hint,
      );
    }

    return ResolvedReturn(
      precision: ReturnPrecision.goalFallback,
      route: view.goalFallbackRoute(anchor),
      strategy: strategy,
    );
  }
}
