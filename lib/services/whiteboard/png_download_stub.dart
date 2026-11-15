import 'dart:typed_data';

/// Non-web builds have no browser download.
Future<bool> downloadPng(Uint8List bytes, String fileName) async => false;
