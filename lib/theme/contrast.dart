import 'package:flutter/material.dart';

/// WCAG 2.x contrast ratio between two colors. Translucent [foreground]
/// colors are composited over [background] first.
double contrastRatio(Color foreground, Color background) {
  final fg = Color.alphaBlend(foreground, background).computeLuminance();
  final bg = background.computeLuminance();
  final hi = fg > bg ? fg : bg;
  final lo = fg > bg ? bg : fg;
  return (hi + 0.05) / (lo + 0.05);
}

/// Darkens (or lightens, for dark [against] colors) [color] in small HSL
/// steps until it reaches [minRatio] against [against]. Returns [color]
/// unchanged when it already passes.
Color ensureContrast(Color color, Color against, double minRatio) {
  final lighten = against.computeLuminance() < 0.18;
  var hsl = HSLColor.fromColor(color);
  var out = color;
  while (contrastRatio(out, against) < minRatio) {
    final next = (hsl.lightness + (lighten ? 0.01 : -0.01)).clamp(0.0, 1.0);
    if (next == hsl.lightness) break;
    hsl = hsl.withLightness(next);
    out = hsl.toColor();
  }
  return out;
}
