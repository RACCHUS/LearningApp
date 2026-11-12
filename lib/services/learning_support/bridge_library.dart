import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';

/// The bundled, offline Bridge Library (master plan v2.6 §10.0). It works
/// without network, AI or a server: content ships with the app and is
/// validated on load. Anything that fails validation is left out rather
/// than shown half-checked.
class BridgeLibrary {
  BridgeLibrary(List<BridgeLesson> bridges)
    : bridges = List.unmodifiable(bridges),
      _byId = {for (final b in bridges) b.bridgeId: b};

  static final empty = BridgeLibrary(const []);

  /// Asset paths bundled through `pubspec.yaml`.
  static const assetPaths = [
    'content/bridges/fraction_decimal.bridge.json',
    'content/bridges/percent_change.bridge.json',
    'content/bridges/spreadsheet_percent_format.bridge.json',
  ];

  final List<BridgeLesson> bridges;
  final Map<String, BridgeLesson> _byId;

  BridgeLesson? operator [](String bridgeId) => _byId[bridgeId];

  bool get isEmpty => bridges.isEmpty;

  /// The most specific Bridge (the one building on the most others) comes
  /// first, because it is closest to the pilot activity; foundations
  /// follow and stay reachable through "Need a step back?".
  List<BridgeLesson> get offerOrder {
    final out = [...bridges];
    out.sort((a, b) {
      final d = b.buildsOn.length.compareTo(a.buildsOn.length);
      return d != 0 ? d : a.title.compareTo(b.title);
    });
    return out;
  }

  /// Loads and validates every bundled Bridge. Invalid files are skipped;
  /// a set-level problem (unknown dependency, cycle) drops the whole set,
  /// because nested help could otherwise point at a missing Bridge.
  static Future<BridgeLibrary> load(AssetBundle bundle) async {
    final loaded = <BridgeLesson>[];
    for (final path in assetPaths) {
      try {
        final result = BridgeLesson.decode(
          jsonDecode(await bundle.loadString(path)),
        );
        if (result.isOk) {
          loaded.add(result.bridge!);
        } else {
          debugPrint('Bridge $path skipped: ${result.issues.join('; ')}');
        }
      } catch (e) {
        debugPrint('Bridge $path unreadable: ${e.runtimeType}');
      }
    }
    final setIssues = BridgeLibraryValidator.validate(loaded);
    if (setIssues.isNotEmpty) {
      debugPrint('Bridge library disabled: ${setIssues.join('; ')}');
      return empty;
    }
    return BridgeLibrary(loaded);
  }
}
