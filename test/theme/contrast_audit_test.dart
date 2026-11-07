import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/theme/contrast.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

// WCAG 2.2 AA: 4.5:1 for normal text, 3:1 for UI component boundaries.
const text = 4.5;
const ui = 3.0;

class Pair {
  const Pair(this.name, this.fg, this.bg, this.min);
  final String name;
  final Color fg;
  final Color bg;
  final double min;
  double get ratio => contrastRatio(fg, bg);
  bool get passes => ratio + 1e-9 >= min;
}

List<Pair> tokenPairs(ThemeData t) {
  final c = t.colorScheme;
  final s = t.extension<SemanticColors>()!;
  final bg = t.scaffoldBackgroundColor;
  final card = t.cardTheme.color ?? c.surfaceContainerLow;
  final chipBg = t.chipTheme.backgroundColor!;
  final chipSel = t.chipTheme.selectedColor!;
  final input = t.inputDecorationTheme;
  return [
    Pair('body text on background', c.onSurface, bg, text),
    Pair('body text on card', c.onSurface, card, text),
    Pair('secondary text on background', c.onSurfaceVariant, bg, text),
    Pair('secondary text on card', c.onSurfaceVariant, card, text),
    Pair('chip label on chip', t.chipTheme.labelStyle!.color!, chipBg, text),
    Pair(
      'selected chip label',
      t.chipTheme.secondaryLabelStyle!.color!,
      chipSel,
      text,
    ),
    Pair(
      'primary as text (links, text/outlined buttons) on background',
      c.primary,
      bg,
      text,
    ),
    Pair('primary as text on card', c.primary, card, text),
    Pair('on primary (filled button label)', c.onPrimary, c.primary, text),
    Pair(
      'on primary container',
      c.onPrimaryContainer,
      c.primaryContainer,
      text,
    ),
    Pair(
      'on secondary container',
      c.onSecondaryContainer,
      c.secondaryContainer,
      text,
    ),
    Pair('error text on background', c.error, bg, text),
    Pair('on error', c.onError, c.error, text),
    Pair('success text on background', s.success, bg, text),
    Pair('warning text on background', s.warning, bg, text),
    Pair('danger text on background', s.danger, bg, text),
    Pair('info text on background', s.info, bg, text),
    Pair('on success', s.onSuccess, s.success, text),
    Pair('on warning', s.onWarning, s.warning, text),
    Pair('on danger', s.onDanger, s.danger, text),
    Pair('on info', s.onInfo, s.info, text),
    Pair('outline (control boundary) on background', c.outline, bg, ui),
    Pair('outline on card', c.outline, card, ui),
    Pair(
      'text-field border on background',
      input.enabledBorder!.borderSide.color,
      bg,
      ui,
    ),
    Pair(
      'focused text-field border on background',
      input.focusedBorder!.borderSide.color,
      bg,
      ui,
    ),
  ];
}

/// Legacy hard-coded colors still used as status text in widgets. Reported,
/// not enforced: they are migrated to tokens file by file.
List<Pair> legacyPairs(ThemeData t) {
  final bg = t.scaffoldBackgroundColor;
  return [
    for (final e in <String, Color>{
      'Colors.green': Colors.green,
      'Colors.red': Colors.red,
      'Colors.orange': Colors.orange,
      'Colors.amber': Colors.amber,
      'Colors.blue': Colors.blue,
      'Colors.grey': Colors.grey,
      'Colors.white70': Colors.white70,
      'Colors.black54': Colors.black54,
    }.entries)
      Pair('${e.key} text on background', e.value, bg, text),
  ];
}

/// Viénot/Brettel/Mollon (1999) dichromat simulation in linear RGB.
Color simulate(Color c, List<double> m) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double enc(double v) {
    v = v.clamp(0.0, 1.0);
    return v <= 0.0031308
        ? v * 12.92
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
  }

  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  return Color.from(
    alpha: 1,
    red: enc(m[0] * r + m[1] * g + m[2] * b),
    green: enc(m[3] * r + m[4] * g + m[5] * b),
    blue: enc(m[6] * r + m[7] * g + m[8] * b),
  );
}

const protan = <double>[
  0.11238,
  0.88762,
  0,
  0.11238,
  0.88762,
  0,
  0.00401,
  -0.00401,
  1.0,
];
const deutan = <double>[
  0.29275,
  0.70725,
  0,
  0.29275,
  0.70725,
  0,
  -0.02234,
  0.02234,
  1.0,
];
const gray = <double>[
  0.2126,
  0.7152,
  0.0722,
  0.2126,
  0.7152,
  0.0722,
  0.2126,
  0.7152,
  0.0722,
];

String table(String title, List<Pair> pairs) {
  final b = StringBuffer(
    '\n### $title\n\n| Pair | Ratio | Needs | Result |\n'
    '|---|---|---|---|\n',
  );
  for (final p in pairs) {
    b.writeln(
      '| ${p.name} | ${p.ratio.toStringAsFixed(2)}:1 | '
      '${p.min.toStringAsFixed(1)}:1 | ${p.passes ? 'pass' : '**FAIL**'} |',
    );
  }
  return b.toString();
}

String stateSeparation(String theme, ThemeData t) {
  final s = t.extension<SemanticColors>()!;
  final b = StringBuffer(
    '\n### $theme theme: success vs danger under '
    'simulation\n\n| View | Contrast between success and danger |\n|---|---|\n',
  );
  for (final e in {
    'Full color': null,
    'Protanopia': protan,
    'Deuteranopia': deutan,
    'Grayscale': gray,
  }.entries) {
    final a = e.value == null ? s.success : simulate(s.success, e.value!);
    final d = e.value == null ? s.danger : simulate(s.danger, e.value!);
    b.writeln('| ${e.key} | ${contrastRatio(a, d).toStringAsFixed(2)}:1 |');
  }
  return b.toString();
}

void main() {
  setUp(BrandConfig.reset);
  tearDown(BrandConfig.reset);

  testWidgets('theme tokens meet WCAG 2.2 AA in light and dark', (
    tester,
  ) async {
    final report = StringBuffer();
    final failures = <String>[];
    for (final e in {
      'Light': AppTheme.lightTheme(),
      'Dark': AppTheme.darkTheme(),
    }.entries) {
      final pairs = tokenPairs(e.value);
      failures.addAll(
        pairs
            .where((p) => !p.passes)
            .map((p) => '${e.key}: ${p.name} ${p.ratio.toStringAsFixed(2)}'),
      );
      report
        ..write(table('${e.key} theme tokens', pairs))
        ..write(
          table(
            '${e.key} theme: legacy hard-coded colors',
            legacyPairs(e.value),
          ),
        )
        ..write(stateSeparation(e.key, e.value));
    }
    // Run with --plain-name 'theme tokens' to regenerate the tables in
    // docs/design/CONTRAST_AUDIT.md.
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty);
  });

  testWidgets('a low-contrast brand primary is darkened for light theme', (
    tester,
  ) async {
    BrandConfig.set(
      const BrandConfigCore(
        appName: 'Pale',
        primaryColorHex: '#4FC3F7',
        secondaryColorHex: '#00897B',
        darkPrimaryColorHex: '#4FC3F7',
        darkSecondaryColorHex: '#80CBC4',
      ),
    );
    final scheme = AppTheme.lightTheme().colorScheme;
    expect(
      contrastRatio(scheme.onPrimary, scheme.primary),
      greaterThanOrEqualTo(text),
    );
    expect(
      contrastRatio(scheme.primary, Colors.white),
      greaterThanOrEqualTo(text),
    );
  });

  test('ensureContrast leaves passing colors unchanged', () {
    const passing = Color(0xFF01579B);
    expect(ensureContrast(passing, Colors.white, text), passing);
  });
}
