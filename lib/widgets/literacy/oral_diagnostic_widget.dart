import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Formative oral placement diagnostic for non-readers.
///
/// Adheres to Section 5.7 of the Literacy Accessibility Plan:
/// - Audio-guided 3-step diagnostic flow:
///   1. Letter sound recognition (/m/ sound)
///   2. Survival sign recognition (STOP sign)
///   3. Decodable word recognition (CAT)
/// - Recommends an optimal starting point without gating learner choice:
///   - Level 1: Alphabet sounds & handwriting tracing
///   - Level 2: Environmental survival words
///   - Level 3: CVC sound blending
///   - Level 4: Life Milestones & Connected Stories
class OralDiagnosticWidget extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;

  const OralDiagnosticWidget({super.key, this.onComplete});

  @override
  ConsumerState<OralDiagnosticWidget> createState() =>
      _OralDiagnosticWidgetState();
}

class _OralDiagnosticWidgetState extends ConsumerState<OralDiagnosticWidget> {
  int _currentStep = 0; // 0 = Sound, 1 = Sign, 2 = Word, 3 = Results
  int _score = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentQuestion();
    });
  }

  void _speakCurrentQuestion() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_currentStep) {
      case 0:
        audio.speak(
            'Question 1. Listen closely: Which picture starts with the /m/ sound? Like money.');
        break;
      case 1:
        audio.speak(
            'Question 2. Which red sign tells cars and buses to STOP?');
        break;
      case 2:
        audio.speak('Question 3. Tap the word: C-A-T. Cat.');
        break;
      case 3:
        audio.speak(
            'Great job! We found the best starting place for you. Tap the button below to start learning.');
        break;
    }
  }

  void _answerQuestion(bool isCorrect) {
    if (isCorrect) {
      _score++;
    }
    setState(() {
      _currentStep++;
    });
    _speakCurrentQuestion();
  }

  void _resetDiagnostic() {
    setState(() {
      _currentStep = 0;
      _score = 0;
    });
    _speakCurrentQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step Progress Bar
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i < _currentStep
                          ? Colors.green
                          : (i == _currentStep
                              ? Colors.amber
                              : colorScheme.surfaceContainerHighest),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: DesignTokens.space4),

          if (_currentStep < 3) ...[
            _buildQuestionCard(theme, colorScheme),
          ] else ...[
            _buildResultsCard(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          children: [
            // Speaker Replay Header
            IconButton.filled(
              key: const Key('diagnostic-speaker-button'),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.all(DesignTokens.space3),
              ),
              icon: const Icon(Icons.volume_up, size: 32),
              tooltip: 'Hear question again',
              onPressed: _speakCurrentQuestion,
            ),
            const SizedBox(height: DesignTokens.space3),

            Text(
              _getQuestionTitle(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Tap the speaker to hear instructions again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.space5),

            // 3 Visual Choice Options
            _buildChoices(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  String _getQuestionTitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1 of 3: Letter Sound /m/';
      case 1:
        return 'Step 2 of 3: Safety Sign STOP';
      case 2:
        return 'Step 3 of 3: Decodable Word CAT';
      default:
        return '';
    }
  }

  Widget _buildChoices(ThemeData theme, ColorScheme colorScheme) {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            _buildChoiceTile('💵 Money (Sound /m/)', '💵', true,
                key: 'diagnostic-choice-step-0'),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('🌳 Tree', '🌳', false),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('⏰ Clock', '⏰', false),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildChoiceTile('🛑 STOP (Red Octagon)', '🛑', true,
                key: 'diagnostic-choice-step-1'),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('🚪 EXIT', '🚪', false),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('🚻 RESTROOM', '🚻', false),
          ],
        );
      case 2:
        return Column(
          children: [
            _buildChoiceTile('CAT', '🐱', true,
                key: 'diagnostic-choice-step-2'),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('BUS', '🚌', false),
            const SizedBox(height: DesignTokens.space3),
            _buildChoiceTile('SUN', '☀️', false),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChoiceTile(
    String label,
    String emoji,
    bool isCorrect, {
    String? key,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: key != null ? Key(key) : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
        ),
        onPressed: () => _answerQuestion(isCorrect),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: DesignTokens.space3),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(ThemeData theme, ColorScheme colorScheme) {
    final recommendation = _getRecommendation();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 48)),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Diagnostic Placement Complete',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              'Score: $_score out of 3 questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            // Recommendation Box
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                border: Border.all(color: colorScheme.primary),
              ),
              child: Column(
                children: [
                  Text(
                    'Recommended Starting Point:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space1),
                  Text(
                    recommendation.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    recommendation.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space5),

            // Start Learning Button
            FilledButton.icon(
              key: const Key('diagnostic-start-learning-button'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space5,
                  vertical: DesignTokens.space3,
                ),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                'Start Recommended Lessons',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                widget.onComplete?.call();
                try {
                  context.push(recommendation.route);
                } catch (_) {}
              },
            ),
            const SizedBox(height: DesignTokens.space2),

            // Re-take diagnostic button
            TextButton(
              onPressed: _resetDiagnostic,
              child: const Text('Try Diagnostic Again'),
            ),
          ],
        ),
      ),
    );
  }

  _DiagnosticRecommendation _getRecommendation() {
    if (_score <= 1) {
      return const _DiagnosticRecommendation(
        title: 'Alphabet & Finger Tracing',
        description:
            'Start with pure letter sounds and tactile touch-screen tracing to build confidence.',
        route: '/literacy',
      );
    } else if (_score == 2) {
      return const _DiagnosticRecommendation(
        title: 'Environmental Words & Sound Blending',
        description:
            'Practice real-world survival signs and blending CVC short vowel words.',
        route: '/literacy',
      );
    } else {
      return const _DiagnosticRecommendation(
        title: 'High-Stakes Life Milestones',
        description:
            'You are ready for US Citizenship prep, DMV driver rules, and connected early stories!',
        route: '/milestones',
      );
    }
  }
}

class _DiagnosticRecommendation {
  final String title;
  final String description;
  final String route;

  const _DiagnosticRecommendation({
    required this.title,
    required this.description,
    required this.route,
  });
}
