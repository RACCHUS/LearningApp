import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

const String _onboardingCompleteKey = 'hasCompletedOnboarding';
const String _dailyGoalKey = 'dailyGoalMinutes';

/// Check if onboarding has been completed
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompleteKey) ?? false;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _customGoalController = TextEditingController();
  int _currentPage = 0;
  int _selectedGoal = 15;
  bool _setGoalLater = false;
  bool _isLoading = false;

  static const _goalOptions = [5, 15, 30, 60];

  @override
  void dispose() {
    _pageController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save daily goal unless user opted to set it later in Settings.
      if (_setGoalLater) {
        await prefs.remove(_dailyGoalKey);
      } else {
        await prefs.setInt(_dailyGoalKey, _selectedGoal);
      }

      // Import sample lesson
      try {
        final jsonString =
            await rootBundle.loadString('assets/sample_lesson.json');
        final importService = LessonImportService();
        await importService.importLessonFromJson(jsonString, 'local');
      } catch (e) {
        debugPrint('Sample lesson import failed (non-critical): $e');
      }

      // Mark onboarding complete
      await prefs.setBool(_onboardingCompleteKey, true);

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onGoalChanged(int goal) {
    setState(() {
      _selectedGoal = goal;
      _setGoalLater = false;
    });
  }

  void _setLater() {
    setState(() {
      _setGoalLater = true;
    });
  }

  void _applyCustomGoal() {
    final parsed = int.tryParse(_customGoalController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 720) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid goal between 1 and 720 minutes.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedGoal = parsed;
      _setGoalLater = false;
    });
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _WelcomePage(textTheme: textTheme, colorScheme: colorScheme),
                  _GoalPage(
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                    selectedGoal: _selectedGoal,
                    setGoalLater: _setGoalLater,
                    customGoalController: _customGoalController,
                    goalOptions: _goalOptions,
                    onGoalChanged: _onGoalChanged,
                    onSetLater: _setLater,
                    onApplyCustomGoal: _applyCustomGoal,
                  ),
                  _GetStartedPage(
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DesignTokens.space4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space6,
                0,
                DesignTokens.space6,
                DesignTokens.space6,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: _currentPage < 2
                    ? FilledButton(
                        onPressed: _nextPage,
                        child: const Text('Next'),
                      )
                    : FilledButton(
                        onPressed: _isLoading ? null : _completeOnboarding,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Get Started'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _WelcomePage({required this.textTheme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_rounded,
            size: 96,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to\nLearning App',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Create lessons, study with flashcards & quizzes, and track your progress — all in one place.',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final int selectedGoal;
  final bool setGoalLater;
  final TextEditingController customGoalController;
  final List<int> goalOptions;
  final ValueChanged<int> onGoalChanged;
  final VoidCallback onSetLater;
  final VoidCallback onApplyCustomGoal;

  const _GoalPage({
    required this.textTheme,
    required this.colorScheme,
    required this.selectedGoal,
    required this.setGoalLater,
    required this.customGoalController,
    required this.goalOptions,
    required this.onGoalChanged,
    required this.onSetLater,
    required this.onApplyCustomGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_rounded,
            size: 72,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Set Your Daily Goal',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'How much time do you want to study each day?',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...goalOptions.map((minutes) {
            final isSelected = !setGoalLater && minutes == selectedGoal;
            final label = minutes < 60
                ? '$minutes minutes'
                : '${minutes ~/ 60} hour';
            final subtitle = switch (minutes) {
              5 => 'Light — a quick review',
              15 => 'Regular — builds a habit',
              30 => 'Committed — strong progress',
              60 => 'Intensive — fast results',
              _ => '',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onGoalChanged(minutes),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Minutes',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customGoalController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Enter minutes (1-720)',
                                isDense: true,
                              ),
                              onSubmitted: (_) => onApplyCustomGoal(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: onApplyCustomGoal,
                            child: const Text('Use'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onSetLater,
            icon: Icon(
              setGoalLater ? Icons.check_circle : Icons.schedule,
              color: setGoalLater ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            label: Text(
              setGoalLater
                  ? 'Goal will be set later in Settings'
                  : 'Set this later in Settings',
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedPage extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _GetStartedPage({required this.textTheme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch_rounded,
            size: 72,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            "You're All Set!",
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "We've loaded a sample lesson to get you started. You can create your own lessons anytime.",
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FeatureRow(
            icon: Icons.auto_awesome,
            title: 'AI-Powered Lessons',
            subtitle: 'Generate lessons from any topic',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _FeatureRow(
            icon: Icons.style,
            title: 'Flashcards & Quizzes',
            subtitle: 'Multiple study modes to reinforce learning',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _FeatureRow(
            icon: Icons.insights,
            title: 'Track Progress',
            subtitle: 'Streaks, XP, and daily goals',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
