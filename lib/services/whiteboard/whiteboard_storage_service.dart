import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/whiteboard/whiteboard_stroke.dart';

/// Storage service for saving and reloading whiteboard vector strokes and PNG images (P8-2).
class WhiteboardStorageService extends ChangeNotifier {
  static const String _strokesStorageKey = 'whiteboard_strokes_cache_v1';
  static const String _pngStorageKey = 'whiteboard_png_base64_v1';

  final SharedPreferences? _prefs;

  WhiteboardStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  /// Saves current strokes and optional PNG raster snapshot.
  Future<void> saveStrokes(
    List<WhiteboardStroke> strokes, {
    Uint8List? pngBytes,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonList = strokes.map((s) => s.toJson()).toList();
    await prefs.setString(_strokesStorageKey, jsonEncode(jsonList));

    if (pngBytes != null) {
      await prefs.setString(_pngStorageKey, base64Encode(pngBytes));
    }

    notifyListeners();
  }

  /// Loads persisted strokes from device storage.
  Future<List<WhiteboardStroke>> loadStrokes() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_strokesStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((item) => WhiteboardStroke.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading whiteboard strokes: $e');
      return [];
    }
  }

  /// Loads saved PNG image bytes.
  Future<Uint8List?> loadSavedPng() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final base64Str = prefs.getString(_pngStorageKey);
    if (base64Str == null || base64Str.isEmpty) return null;

    try {
      return base64Decode(base64Str);
    } catch (e) {
      debugPrint('Error decoding saved whiteboard PNG: $e');
      return null;
    }
  }

  /// Clears stored strokes and PNG data.
  Future<void> clearWhiteboard() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_strokesStorageKey);
    await prefs.remove(_pngStorageKey);
    notifyListeners();
  }
}

