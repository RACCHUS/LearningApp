import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/models/audio_state.dart';

class AudioControlWidget extends ConsumerWidget {
  final String? text;
  final IconData? icon;
  final String? tooltip;
  final bool autoPlay;
  final String contentType; // 'question', 'answer', 'content'
  final VoidCallback? onPlaybackComplete;

  const AudioControlWidget({
    super.key,
    this.text,
    this.icon,
    this.tooltip,
    this.autoPlay = false,
    this.contentType = 'content',
    this.onPlaybackComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSpeak = ref.watch(canSpeakProvider);
    final audioState = ref.watch(audioStateProvider);
    final audioNotifier = ref.read(audioStateProvider.notifier);
    final settings = ref.watch(audioSettingsProvider);

    // Debug: Always show audio control for testing
    // Remove this after debugging
    if (text == null || text!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // Show debug info if audio is not available
    if (!canSpeak) {
      return Tooltip(
        message: 'Audio not available: enabled=${settings.isEnabled}, available=${audioState.isAvailable}',
        child: IconButton(
          onPressed: null,
          icon: const Icon(Icons.volume_off, color: Colors.grey),
        ),
      );
    }

    // Auto-play functionality based on settings and content type
    // Only autoplay if explicitly requested AND enabled in settings
    final shouldAutoPlay = autoPlay && 
                          settings.isEnabled &&
                          settings.autoPlay &&
                          (contentType == 'question' ? settings.autoReadQuestions : 
                           contentType == 'answer' ? settings.autoReadAnswers : true);
                          
    if (shouldAutoPlay && 
        audioState.playbackState == AudioPlaybackState.idle && 
        text != null &&
        !_isInModeSelection(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioNotifier.speak(text!);
      });
    }

    // Listen for playback completion
    if (audioState.playbackState == AudioPlaybackState.idle && 
        audioState.currentText == text && 
        onPlaybackComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPlaybackComplete!();
      });
    }

    return IconButton(
      onPressed: _getOnPressed(audioState, audioNotifier),
      icon: Icon(_getIcon(audioState)),
      tooltip: tooltip ?? _getTooltip(audioState),
      iconSize: 24,
    );
  }

  bool _isInModeSelection(BuildContext context) {
    // Check if we're currently in a mode selection dialog or screen
    final route = ModalRoute.of(context);
    if (route == null) return false;
    
    final routeName = route.settings.name;
    if (routeName != null && routeName.contains('lesson') && 
        !routeName.contains('mode') && !routeName.contains('study')) {
      return true;
    }
    
    // Check if there's an active dialog (like LessonModeDialog)
    return route is DialogRoute;
  }

  VoidCallback? _getOnPressed(AudioState state, audioNotifier) {
    if (text == null || text!.trim().isEmpty) return null;

    switch (state.playbackState) {
      case AudioPlaybackState.idle:
      case AudioPlaybackState.stopped:
        return () => audioNotifier.speak(text!);
      case AudioPlaybackState.playing:
        return () => audioNotifier.pause();
      case AudioPlaybackState.paused:
        return () => audioNotifier.resume();
      case AudioPlaybackState.loading:
        return () => audioNotifier.stop();
      case AudioPlaybackState.error:
        return () => audioNotifier.speak(text!);
    }
  }

  IconData _getIcon(AudioState state) {
    if (icon != null) return icon!;

    switch (state.playbackState) {
      case AudioPlaybackState.idle:
      case AudioPlaybackState.stopped:
        return Icons.volume_up;
      case AudioPlaybackState.playing:
        return Icons.pause;
      case AudioPlaybackState.paused:
        return Icons.play_arrow;
      case AudioPlaybackState.loading:
        return Icons.stop;
      case AudioPlaybackState.error:
        return Icons.refresh;
    }
  }

  String _getTooltip(AudioState state) {
    switch (state.playbackState) {
      case AudioPlaybackState.idle:
      case AudioPlaybackState.stopped:
        return 'Listen';
      case AudioPlaybackState.playing:
        return 'Pause';
      case AudioPlaybackState.paused:
        return 'Resume';
      case AudioPlaybackState.loading:
        return 'Loading...';
      case AudioPlaybackState.error:
        return 'Retry';
    }
  }
}

class AudioPlaybackIndicator extends ConsumerWidget {
  const AudioPlaybackIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioStateProvider);
    final theme = Theme.of(context);

    if (!audioState.isPlaying && !audioState.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            audioState.isLoading ? 'Loading...' : 'Playing...',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceInputButton extends ConsumerStatefulWidget {
  final ValueChanged<String>? onResult;
  final VoidCallback? onError;
  final String? tooltip;
  final Duration? timeout;

  const VoiceInputButton({
    super.key,
    this.onResult,
    this.onError,
    this.tooltip,
    this.timeout,
  });

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  @override
  Widget build(BuildContext context) {
    final canListen = ref.watch(canListenProvider);
    final audioState = ref.watch(audioStateProvider);
    final audioNotifier = ref.read(audioStateProvider.notifier);

    // Debug: Show disabled state instead of hiding
    if (!canListen) {
      return Tooltip(
        message: 'Voice input not available',
        child: IconButton(
          onPressed: null,
          icon: const Icon(Icons.mic_off, color: Colors.grey),
        ),
      );
    }

    return IconButton(
      onPressed: _getOnPressed(audioState, audioNotifier),
      icon: Icon(_getIcon(audioState)),
      tooltip: widget.tooltip ?? _getTooltip(audioState),
      iconSize: 24,
    );
  }

  VoidCallback? _getOnPressed(AudioState state, audioNotifier) {
    switch (state.voiceInputState) {
      case VoiceInputState.idle:
        return () => _startListening(audioNotifier);
      case VoiceInputState.listening:
      case VoiceInputState.processing:
        return () => audioNotifier.stopListening();
      case VoiceInputState.completed:
        return () => _handleResult(audioNotifier);
      case VoiceInputState.error:
        return () => _startListening(audioNotifier);
    }
  }

  IconData _getIcon(AudioState state) {
    switch (state.voiceInputState) {
      case VoiceInputState.idle:
        return Icons.mic;
      case VoiceInputState.listening:
        return Icons.mic;
      case VoiceInputState.processing:
        return Icons.mic;
      case VoiceInputState.completed:
        return Icons.check;
      case VoiceInputState.error:
        return Icons.mic_off;
    }
  }

  String _getTooltip(AudioState state) {
    switch (state.voiceInputState) {
      case VoiceInputState.idle:
        return 'Voice input';
      case VoiceInputState.listening:
        return 'Listening...';
      case VoiceInputState.processing:
        return 'Processing...';
      case VoiceInputState.completed:
        return 'Voice input complete';
      case VoiceInputState.error:
        return 'Try again';
    }
  }

  Future<void> _startListening(audioNotifier) async {
    final success = await audioNotifier.startListening(
      timeout: widget.timeout ?? const Duration(seconds: 5),
    );
    
    if (!success && widget.onError != null) {
      widget.onError!();
    }
  }

  void _handleResult(audioNotifier) {
    final result = audioNotifier.parseLastCommand();
    if (result != null && widget.onResult != null) {
      widget.onResult!(result.phrase);
    }
    
    // Reset state
    audioNotifier.cancelListening();
  }
}

class AudioSpeedControl extends ConsumerWidget {
  const AudioSpeedControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(audioSettingsProvider);
    final settingsNotifier = ref.read(audioSettingsProvider.notifier);
    final canSpeak = ref.watch(canSpeakProvider);

    if (!canSpeak) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<double>(
      icon: const Icon(Icons.speed),
      tooltip: 'Speech speed',
      onSelected: (speed) {
        settingsNotifier.setSpeechRate(speed);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 0.5, child: Text('0.5x ${settings.speechRate == 0.5 ? '✓' : ''}')),
        PopupMenuItem(value: 0.75, child: Text('0.75x ${settings.speechRate == 0.75 ? '✓' : ''}')),
        PopupMenuItem(value: 1.0, child: Text('1.0x ${settings.speechRate == 1.0 ? '✓' : ''}')),
        PopupMenuItem(value: 1.25, child: Text('1.25x ${settings.speechRate == 1.25 ? '✓' : ''}')),
        PopupMenuItem(value: 1.5, child: Text('1.5x ${settings.speechRate == 1.5 ? '✓' : ''}')),
        PopupMenuItem(value: 2.0, child: Text('2.0x ${settings.speechRate == 2.0 ? '✓' : ''}')),
      ],
    );
  }
}
