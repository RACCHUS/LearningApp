import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';

/// Bundled external companions, keyed by the Bridge they support. Loaded
/// offline and validated against the Bridge Library; anything invalid is
/// left out rather than shown half-checked.
class ExternalCompanionLibrary {
  ExternalCompanionLibrary(List<ExternalCompanion> companions)
    : _byBridge = {for (final c in companions) c.bridgeId: c};

  static final empty = ExternalCompanionLibrary(const []);

  static const assetPaths = [
    'content/companions/fraction_decimal.companion.json',
    'content/companions/percent_change.companion.json',
    'content/companions/spreadsheet_percent_format.companion.json',
  ];

  final Map<String, ExternalCompanion> _byBridge;

  ExternalCompanion? forBridge(String bridgeId) => _byBridge[bridgeId];

  int get length => _byBridge.length;

  static Future<ExternalCompanionLibrary> load(
    AssetBundle bundle,
    BridgeLibrary bridges,
  ) async {
    final out = <ExternalCompanion>[];
    for (final path in assetPaths) {
      try {
        final r = ExternalCompanion.decode(
          jsonDecode(await bundle.loadString(path)),
        );
        final c = r.companion;
        if (c == null) {
          debugPrint('Companion $path skipped: ${r.issues.join('; ')}');
          continue;
        }
        final bridge = bridges[c.bridgeId];
        final cross = bridge == null ? null : c.validateAgainst(bridge);
        if (bridge == null || cross!.isNotEmpty) {
          debugPrint('Companion $path skipped: ${cross ?? 'unknown bridge'}');
          continue;
        }
        if (out.any((o) => o.bridgeId == c.bridgeId)) {
          debugPrint('Companion $path skipped: duplicate for ${c.bridgeId}');
          continue;
        }
        out.add(c);
      } catch (e) {
        debugPrint('Companion $path unreadable: ${e.runtimeType}');
      }
    }
    return ExternalCompanionLibrary(out);
  }
}
