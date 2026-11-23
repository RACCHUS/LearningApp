import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/models/learning_support/companion_plan.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';

/// Bundled companion plans (master plan v2.6 §9.2 level 4), validated
/// against the Bridge and companion libraries. An invalid plan is left out.
class CompanionPlanLibrary {
  CompanionPlanLibrary(this.plans);

  static final empty = CompanionPlanLibrary(const []);

  static const assetPaths = [
    'content/companion_plans/openstax_prealgebra_percent.plan.json',
    'content/companion_plans/openstax_college_algebra_ch1.plan.json',
    'content/companion_plans/openstax_python_basics.plan.json',
  ];

  final List<CompanionPlan> plans;

  /// The first plan that includes [bridgeId], if any.
  CompanionPlan? forBridge(String bridgeId) {
    for (final p in plans) {
      if (p.indexOfBridge(bridgeId) >= 0) return p;
    }
    return null;
  }

  static List<String> issuesFor(
    Object? json,
    BridgeLibrary bridges,
    ExternalCompanionLibrary companions,
  ) {
    final r = CompanionPlan.decode(json);
    if (r.plan == null) return [for (final i in r.issues) '$i'];
    return [
      for (final i in r.plan!.validateAgainst(
        hasBridge: (id) => bridges[id] != null,
        hasCompanion: (id) => companions.forBridge(id) != null,
      ))
        '$i',
    ];
  }

  static Future<CompanionPlanLibrary> load(
    AssetBundle bundle,
    BridgeLibrary bridges,
    ExternalCompanionLibrary companions,
  ) async {
    final out = <CompanionPlan>[];
    for (final path in assetPaths) {
      try {
        final json = jsonDecode(await bundle.loadString(path));
        final problems = issuesFor(json, bridges, companions);
        if (problems.isNotEmpty) {
          debugPrint('Companion plan $path skipped: ${problems.join('; ')}');
          continue;
        }
        out.add(CompanionPlan.decode(json).plan!);
      } catch (e) {
        debugPrint('Companion plan $path unreadable: ${e.runtimeType}');
      }
    }
    return CompanionPlanLibrary(out);
  }
}
