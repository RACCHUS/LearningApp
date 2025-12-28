import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';

/// Onboarding widget for setting up hands-free mode
class HandsFreeOnboarding extends ConsumerStatefulWidget {
  final VoidCallback? onCompleted;
  final bool showSkipOption;

  const HandsFreeOnboarding({
    super.key,
    this.onCompleted,
    this.showSkipOption = true,
  });

  @override
  ConsumerState<HandsFreeOnboarding> createState() => _HandsFreeOnboardingState();
}

class _HandsFreeOnboardingState extends ConsumerState<HandsFreeOnboarding> {
  int _currentStep = 0;
  bool _permissionsGranted = false;
  bool _isTestingVoice = false;
  bool _voiceTestPassed = false;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Welcome to Hands-Free Mode',
      content: 'Control the app with your voice! Navigate lessons, answer questions, and access features without touching the screen.',
      icon: Icons.voice_over_off,
    ),
    OnboardingStep(
      title: 'Microphone Permission',
      content: 'We need access to your microphone to listen for voice commands. This permission is required for hands-free functionality.',
      icon: Icons.mic,
    ),
    OnboardingStep(
      title: 'Test Your Voice',
      content: 'Let\'s test if your microphone is working. Try saying "next" when prompted.',
      icon: Icons.record_voice_over,
    ),
    OnboardingStep(
      title: 'Choose Your Settings',
      content: 'Customize how hands-free mode works for you.',
      icon: Icons.settings,
    ),
    OnboardingStep(
      title: 'You\'re All Set!',
      content: 'Hands-free mode is ready to use. You can always change these settings later.',
      icon: Icons.check_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hands-Free Setup'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final step = _steps[_currentStep];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          step.icon,
          size: 80,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        Text(
          step.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          step.content,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        
        // Step-specific content
        _buildStepSpecificContent(),
      ],
    );
  }

  Widget _buildStepSpecificContent() {
    switch (_currentStep) {
      case 1: // Microphone permission
        return _buildPermissionStep();
      case 2: // Voice test
        return _buildVoiceTestStep();
      case 3: // Settings
        return _buildSettingsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPermissionStep() {
    return Column(
      children: [
        if (_permissionsGranted)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Microphone permission granted!'),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.mic),
            label: const Text('Grant Microphone Permission'),
          ),
      ],
    );
  }

  Widget _buildVoiceTestStep() {
    return Column(
      children: [
        if (_voiceTestPassed)
          const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 8),
              Text('Voice test passed! Your microphone is working correctly.'),
            ],
          )
        else if (_isTestingVoice)
          const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Listening... say "next" now'),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: _testVoice,
            icon: const Icon(Icons.mic),
            label: const Text('Test Voice Commands'),
          ),
      ],
    );
  }

  Widget _buildSettingsStep() {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(handsFreeSettingsProvider);
        final settingsNotifier = ref.read(handsFreeSettingsProvider.notifier);

        return Column(
          children: [
            SwitchListTile(
              title: const Text('Enable by default'),
              subtitle: const Text('Start with hands-free mode enabled'),
              value: settings.defaultHandsFreeMode,
              onChanged: (value) => settingsNotifier.toggleDefaultHandsFreeMode(),
            ),
            SwitchListTile(
              title: const Text('Global voice commands'),
              subtitle: const Text('Listen for commands throughout the app'),
              value: settings.globalVoiceCommands,
              onChanged: (value) => settingsNotifier.toggleGlobalVoiceCommands(),
            ),
            SwitchListTile(
              title: const Text('Auto hands-free for lessons'),
              subtitle: const Text('Automatically enable for lessons'),
              value: settings.autoLessonHandsFree,
              onChanged: (value) => settingsNotifier.toggleAutoLessonHandsFree(),
            ),
            SwitchListTile(
              title: const Text('Show voice indicator'),
              subtitle: const Text('Display voice status in the app'),
              value: settings.showVoiceIndicator,
              onChanged: (value) => settingsNotifier.toggleShowVoiceIndicator(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Skip button (first step only)
          if (_currentStep == 0 && widget.showSkipOption)
            TextButton(
              onPressed: () => widget.onCompleted?.call(),
              child: const Text('Skip Setup'),
            )
          else if (_currentStep > 0)
            TextButton(
              onPressed: _goToPreviousStep,
              child: const Text('Back'),
            ),
          
          const Spacer(),
          
          // Next/Finish button
          ElevatedButton(
            onPressed: _canProceed() ? _goToNextStep : null,
            child: Text(_currentStep == _steps.length - 1 ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 1: // Microphone permission
        return _permissionsGranted;
      case 2: // Voice test
        return _voiceTestPassed;
      default:
        return true;
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToNextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _requestPermissions() async {
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    final granted = await audioNotifier.requestMicrophonePermissions();
    
    setState(() {
      _permissionsGranted = granted;
    });

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission granted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testVoice() async {
    setState(() {
      _isTestingVoice = true;
    });

    try {
      final audioNotifier = ref.read(audioPlaybackProvider.notifier);
      final command = await audioNotifier.listenForCommand(
        timeout: const Duration(seconds: 5),
      );

      setState(() {
        _voiceTestPassed = command != null && command.phrase.toLowerCase().contains('next');
        _isTestingVoice = false;
      });

      if (_voiceTestPassed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice test successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No command detected. Try speaking louder and clearer.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isTestingVoice = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    // Enable hands-free mode if user chose to
    final settings = ref.read(handsFreeSettingsProvider);
    if (settings.defaultHandsFreeMode) {
      final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);
      await globalVoiceNotifier.enable();
    }

    widget.onCompleted?.call();
  }
}

class OnboardingStep {
  final String title;
  final String content;
  final IconData icon;

  const OnboardingStep({
    required this.title,
    required this.content,
    required this.icon,
  });
}

/// Show hands-free onboarding dialog
Future<void> showHandsFreeOnboarding(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog.fullscreen(
      child: HandsFreeOnboarding(
        onCompleted: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
