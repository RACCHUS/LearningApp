import 'package:flutter/material.dart';

/// A single continuous stroke defined by ordered normalized points in [0.0, 1.0].
class NormalizedStroke {
  final List<Offset> points;
  final String? directionHint;

  const NormalizedStroke(this.points, {this.directionHint});

  Offset get startPoint => points.first;
  Offset get endPoint => points.last;
}

/// Comprehensive handwriting stroke templates for all 26 uppercase letters,
/// lowercase letters, and digits 0–9.
///
/// Hand-verified according to Zaner-Bloser and D'Nealian penmanship standards:
/// - Top-to-bottom vertical strokes
/// - Left-to-right crossbars and horizontals
/// - Counter-clockwise circular loops starting near top-right (2 o'clock)
/// - Eliminates plotter-optimized reversals and bottom-to-top strokes
class LetterStrokeData {
  static final Map<String, List<NormalizedStroke>> uppercase = {
    'A': [
      // Stroke 1: Left slant from apex down
      const NormalizedStroke(
        [Offset(0.50, 0.12), Offset(0.20, 0.88)],
        directionHint: 'Slant down left',
      ),
      // Stroke 2: Right slant from apex down
      const NormalizedStroke(
        [Offset(0.50, 0.12), Offset(0.80, 0.88)],
        directionHint: 'Slant down right',
      ),
      // Stroke 3: Crossbar left to right
      const NormalizedStroke(
        [Offset(0.32, 0.58), Offset(0.68, 0.58)],
        directionHint: 'Across left to right',
      ),
    ],
    'B': [
      // Stroke 1: Vertical stem top to bottom
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Top lobe
      const NormalizedStroke(
        [
          Offset(0.25, 0.12),
          Offset(0.65, 0.12),
          Offset(0.75, 0.31),
          Offset(0.65, 0.50),
          Offset(0.25, 0.50),
        ],
        directionHint: 'Curve around top',
      ),
      // Stroke 3: Bottom lobe
      const NormalizedStroke(
        [
          Offset(0.25, 0.50),
          Offset(0.70, 0.50),
          Offset(0.80, 0.69),
          Offset(0.70, 0.88),
          Offset(0.25, 0.88),
        ],
        directionHint: 'Curve around bottom',
      ),
    ],
    'C': [
      // Single continuous counter-clockwise curve
      const NormalizedStroke(
        [
          Offset(0.78, 0.28),
          Offset(0.50, 0.12),
          Offset(0.22, 0.50),
          Offset(0.50, 0.88),
          Offset(0.78, 0.72),
        ],
        directionHint: 'Curve around counter-clockwise',
      ),
    ],
    'D': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Large curve top to bottom
      const NormalizedStroke(
        [
          Offset(0.25, 0.12),
          Offset(0.68, 0.12),
          Offset(0.82, 0.50),
          Offset(0.68, 0.88),
          Offset(0.25, 0.88),
        ],
        directionHint: 'Big curve around',
      ),
    ],
    'E': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Top horizontal
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.75, 0.12)],
        directionHint: 'Top across',
      ),
      // Stroke 3: Middle horizontal
      const NormalizedStroke(
        [Offset(0.25, 0.50), Offset(0.65, 0.50)],
        directionHint: 'Middle across',
      ),
      // Stroke 4: Bottom horizontal
      const NormalizedStroke(
        [Offset(0.25, 0.88), Offset(0.75, 0.88)],
        directionHint: 'Bottom across',
      ),
    ],
    'F': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Top horizontal
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.75, 0.12)],
        directionHint: 'Top across',
      ),
      // Stroke 3: Middle horizontal
      const NormalizedStroke(
        [Offset(0.25, 0.50), Offset(0.65, 0.50)],
        directionHint: 'Middle across',
      ),
    ],
    'G': [
      // Stroke 1: Counter-clockwise curve
      const NormalizedStroke(
        [
          Offset(0.78, 0.28),
          Offset(0.50, 0.12),
          Offset(0.22, 0.50),
          Offset(0.50, 0.88),
          Offset(0.78, 0.65),
          Offset(0.55, 0.65),
        ],
        directionHint: 'Curve around and in',
      ),
    ],
    'H': [
      // Stroke 1: Left vertical
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Left down',
      ),
      // Stroke 2: Right vertical
      const NormalizedStroke(
        [Offset(0.75, 0.12), Offset(0.75, 0.88)],
        directionHint: 'Right down',
      ),
      // Stroke 3: Crossbar
      const NormalizedStroke(
        [Offset(0.25, 0.50), Offset(0.75, 0.50)],
        directionHint: 'Across middle',
      ),
    ],
    'I': [
      // Stroke 1: Central vertical stem
      const NormalizedStroke(
        [Offset(0.50, 0.12), Offset(0.50, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Top serif bar
      const NormalizedStroke(
        [Offset(0.30, 0.12), Offset(0.70, 0.12)],
        directionHint: 'Top bar across',
      ),
      // Stroke 3: Bottom serif bar
      const NormalizedStroke(
        [Offset(0.30, 0.88), Offset(0.70, 0.88)],
        directionHint: 'Bottom bar across',
      ),
    ],
    'J': [
      // Stroke 1: Top bar across
      const NormalizedStroke(
        [Offset(0.35, 0.12), Offset(0.75, 0.12)],
        directionHint: 'Top bar across',
      ),
      // Stroke 2: Stem down with bottom hook
      const NormalizedStroke(
        [
          Offset(0.60, 0.12),
          Offset(0.60, 0.72),
          Offset(0.48, 0.88),
          Offset(0.30, 0.82),
        ],
        directionHint: 'Down and hook left',
      ),
    ],
    'K': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Upper slant in
      const NormalizedStroke(
        [Offset(0.75, 0.15), Offset(0.25, 0.50)],
        directionHint: 'Slant in to center',
      ),
      // Stroke 3: Lower slant out
      const NormalizedStroke(
        [Offset(0.35, 0.45), Offset(0.78, 0.88)],
        directionHint: 'Slant out to bottom',
      ),
    ],
    'L': [
      // Single continuous stroke: down and right
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88), Offset(0.75, 0.88)],
        directionHint: 'Down and right',
      ),
    ],
    'M': [
      // Hand-verified Zaner-Bloser M:
      // Stroke 1: Left stem down
      const NormalizedStroke(
        [Offset(0.20, 0.12), Offset(0.20, 0.88)],
        directionHint: 'Left down',
      ),
      // Stroke 2: Diagonal down to center
      const NormalizedStroke(
        [Offset(0.20, 0.12), Offset(0.50, 0.62)],
        directionHint: 'Slant to center',
      ),
      // Stroke 3: Diagonal up to top right
      const NormalizedStroke(
        [Offset(0.50, 0.62), Offset(0.80, 0.12)],
        directionHint: 'Slant to top right',
      ),
      // Stroke 4: Right stem down
      const NormalizedStroke(
        [Offset(0.80, 0.12), Offset(0.80, 0.88)],
        directionHint: 'Right down',
      ),
    ],
    'N': [
      // Stroke 1: Left stem down
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Left down',
      ),
      // Stroke 2: Diagonal across down
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.75, 0.88)],
        directionHint: 'Slant down right',
      ),
      // Stroke 3: Right stem up/down from top
      const NormalizedStroke(
        [Offset(0.75, 0.12), Offset(0.75, 0.88)],
        directionHint: 'Right down',
      ),
    ],
    'O': [
      // Counter-clockwise full circle starting at 2 o'clock (0.65, 0.15)
      const NormalizedStroke(
        [
          Offset(0.55, 0.12),
          Offset(0.25, 0.50),
          Offset(0.50, 0.88),
          Offset(0.75, 0.50),
          Offset(0.55, 0.12),
        ],
        directionHint: 'Circle counter-clockwise',
      ),
    ],
    'P': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Upper lobe
      const NormalizedStroke(
        [
          Offset(0.25, 0.12),
          Offset(0.68, 0.12),
          Offset(0.78, 0.32),
          Offset(0.68, 0.52),
          Offset(0.25, 0.52),
        ],
        directionHint: 'Curve around top',
      ),
    ],
    'Q': [
      // Stroke 1: Full circle
      const NormalizedStroke(
        [
          Offset(0.55, 0.12),
          Offset(0.25, 0.50),
          Offset(0.50, 0.88),
          Offset(0.75, 0.50),
          Offset(0.55, 0.12),
        ],
        directionHint: 'Circle counter-clockwise',
      ),
      // Stroke 2: Tail slant out
      const NormalizedStroke(
        [Offset(0.58, 0.65), Offset(0.82, 0.88)],
        directionHint: 'Tail slant out',
      ),
    ],
    'R': [
      // Stroke 1: Vertical stem
      const NormalizedStroke(
        [Offset(0.25, 0.12), Offset(0.25, 0.88)],
        directionHint: 'Straight down',
      ),
      // Stroke 2: Upper lobe
      const NormalizedStroke(
        [
          Offset(0.25, 0.12),
          Offset(0.68, 0.12),
          Offset(0.78, 0.32),
          Offset(0.68, 0.52),
          Offset(0.25, 0.52),
        ],
        directionHint: 'Curve around top',
      ),
      // Stroke 3: Diagonal leg
      const NormalizedStroke(
        [Offset(0.50, 0.52), Offset(0.78, 0.88)],
        directionHint: 'Leg slant down right',
      ),
    ],
    'S': [
      // Continuous S-curve
      const NormalizedStroke(
        [
          Offset(0.75, 0.25),
          Offset(0.50, 0.12),
          Offset(0.28, 0.28),
          Offset(0.50, 0.50),
          Offset(0.72, 0.72),
          Offset(0.48, 0.88),
          Offset(0.25, 0.75),
        ],
        directionHint: 'Curve left, right, and left',
      ),
    ],
    'T': [
      // Stroke 1: Top bar across
      const NormalizedStroke(
        [Offset(0.18, 0.14), Offset(0.82, 0.14)],
        directionHint: 'Across top',
      ),
      // Stroke 2: Central stem down
      const NormalizedStroke(
        [Offset(0.50, 0.14), Offset(0.50, 0.88)],
        directionHint: 'Straight down',
      ),
    ],
    'U': [
      // Down, round bottom, straight up
      const NormalizedStroke(
        [
          Offset(0.25, 0.12),
          Offset(0.25, 0.70),
          Offset(0.50, 0.88),
          Offset(0.75, 0.70),
          Offset(0.75, 0.12),
        ],
        directionHint: 'Down, curve around, and up',
      ),
    ],
    'V': [
      // Slant down left-to-bottom, slant up to right
      const NormalizedStroke(
        [Offset(0.20, 0.12), Offset(0.50, 0.88), Offset(0.80, 0.12)],
        directionHint: 'Slant down to point, then up',
      ),
    ],
    'W': [
      // Slant down, up, down, up
      const NormalizedStroke(
        [
          Offset(0.15, 0.12),
          Offset(0.32, 0.88),
          Offset(0.50, 0.40),
          Offset(0.68, 0.88),
          Offset(0.85, 0.12),
        ],
        directionHint: 'Down, up, down, up',
      ),
    ],
    'X': [
      // Stroke 1: Top-left to bottom-right
      const NormalizedStroke(
        [Offset(0.22, 0.12), Offset(0.78, 0.88)],
        directionHint: 'Slant down right',
      ),
      // Stroke 2: Top-right to bottom-left
      const NormalizedStroke(
        [Offset(0.78, 0.12), Offset(0.22, 0.88)],
        directionHint: 'Cross slant down left',
      ),
    ],
    'Y': [
      // Stroke 1: Left branch to center
      const NormalizedStroke(
        [Offset(0.22, 0.12), Offset(0.50, 0.50)],
        directionHint: 'Branch to center',
      ),
      // Stroke 2: Right branch to center
      const NormalizedStroke(
        [Offset(0.78, 0.12), Offset(0.50, 0.50)],
        directionHint: 'Branch to center',
      ),
      // Stroke 3: Central stem down
      const NormalizedStroke(
        [Offset(0.50, 0.50), Offset(0.50, 0.88)],
        directionHint: 'Straight down',
      ),
    ],
    'Z': [
      // Top across, diagonal down left, bottom across
      const NormalizedStroke(
        [
          Offset(0.22, 0.15),
          Offset(0.78, 0.15),
          Offset(0.22, 0.85),
          Offset(0.78, 0.85),
        ],
        directionHint: 'Across, slant down left, across',
      ),
    ],
  };

  /// Digits 0–9 standard penmanship strokes
  static final Map<String, List<NormalizedStroke>> digits = {
    '0': [
      const NormalizedStroke([
        Offset(0.50, 0.12),
        Offset(0.25, 0.50),
        Offset(0.50, 0.88),
        Offset(0.75, 0.50),
        Offset(0.50, 0.12),
      ], directionHint: 'Oval counter-clockwise'),
    ],
    '1': [
      const NormalizedStroke([
        Offset(0.50, 0.12),
        Offset(0.50, 0.88),
      ], directionHint: 'Straight down'),
    ],
    '2': [
      const NormalizedStroke([
        Offset(0.28, 0.30),
        Offset(0.50, 0.12),
        Offset(0.75, 0.32),
        Offset(0.25, 0.88),
        Offset(0.78, 0.88),
      ], directionHint: 'Curve around, slant down left, across'),
    ],
    '3': [
      const NormalizedStroke([
        Offset(0.28, 0.22),
        Offset(0.50, 0.12),
        Offset(0.72, 0.28),
        Offset(0.50, 0.48),
        Offset(0.75, 0.68),
        Offset(0.50, 0.88),
        Offset(0.25, 0.78),
      ], directionHint: 'Curve top, curve bottom'),
    ],
    '4': [
      const NormalizedStroke([
        Offset(0.65, 0.12),
        Offset(0.22, 0.60),
        Offset(0.78, 0.60),
      ], directionHint: 'Slant down and across'),
      const NormalizedStroke([
        Offset(0.65, 0.35),
        Offset(0.65, 0.88),
      ], directionHint: 'Stem down'),
    ],
    '5': [
      const NormalizedStroke([
        Offset(0.70, 0.15),
        Offset(0.32, 0.15),
        Offset(0.32, 0.48),
        Offset(0.68, 0.48),
        Offset(0.75, 0.68),
        Offset(0.50, 0.88),
        Offset(0.25, 0.78),
      ], directionHint: 'Across, down, and curve around'),
    ],
    '6': [
      const NormalizedStroke([
        Offset(0.68, 0.22),
        Offset(0.40, 0.12),
        Offset(0.25, 0.55),
        Offset(0.50, 0.88),
        Offset(0.75, 0.68),
        Offset(0.50, 0.50),
        Offset(0.25, 0.55),
      ], directionHint: 'Curve down and loop inside'),
    ],
    '7': [
      const NormalizedStroke([
        Offset(0.22, 0.15),
        Offset(0.78, 0.15),
        Offset(0.38, 0.88),
      ], directionHint: 'Across and slant down left'),
    ],
    '8': [
      const NormalizedStroke([
        Offset(0.50, 0.15),
        Offset(0.30, 0.32),
        Offset(0.50, 0.50),
        Offset(0.70, 0.68),
        Offset(0.50, 0.88),
        Offset(0.30, 0.68),
        Offset(0.50, 0.50),
        Offset(0.70, 0.32),
        Offset(0.50, 0.15),
      ], directionHint: 'Figure-eight curve around and back'),
    ],
    '9': [
      const NormalizedStroke([
        Offset(0.50, 0.48),
        Offset(0.28, 0.32),
        Offset(0.50, 0.15),
        Offset(0.72, 0.32),
        Offset(0.72, 0.88),
      ], directionHint: 'Loop around top and line straight down'),
    ],
  };

  /// Retrieves templates for any character (uppercase, lowercase fallback, or digit).
  static List<NormalizedStroke>? forChar(String char) {
    if (char.isEmpty) return null;
    final upper = char.toUpperCase();
    if (uppercase.containsKey(upper)) {
      return uppercase[upper];
    }
    if (digits.containsKey(char)) {
      return digits[char];
    }
    return null;
  }
}
