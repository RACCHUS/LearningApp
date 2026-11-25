import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The provider's player in a plain browser frame. Nothing is drawn over it
/// and nothing listens to it: LearningApp does not see what is played. The
/// Referer is left at the browser's strict-origin default, as the provider
/// asks of sites that embed its player.
Widget buildEmbedFrame(
  Uri src, {
  required String title,
}) => HtmlElementView.fromTagName(
  key: ValueKey('embed_${src.toString()}'),
  tagName: 'iframe',
  onElementCreated: (Object element) {
    final frame = element as web.HTMLIFrameElement;
    frame
      ..src = src.toString()
      ..title = title
      ..allow =
          'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true
      ..referrerPolicy = 'strict-origin-when-cross-origin';
    frame.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%';
  },
);
