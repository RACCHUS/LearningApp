import 'package:flutter/widgets.dart';

/// Non-web builds (VM tests): there is no browser frame. The address is
/// shown as text so tests can see what would be loaded.
Widget buildEmbedFrame(Uri src, {required String title}) =>
    Center(key: const Key('embed_frame_stub'), child: Text(src.toString()));
