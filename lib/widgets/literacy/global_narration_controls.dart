import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';

/// One shared set of controls for *all* spoken guidance, including Home,
/// onboarding dialogs, literacy lessons and learning activities.
/// Lives above the router so it survives navigation between screens.
class GlobalNarrationControls extends StatefulWidget {
  final Widget child;
  final AudioService? audioService;
  const GlobalNarrationControls({
    super.key,
    required this.child,
    this.audioService,
  });

  @override
  State<GlobalNarrationControls> createState() =>
      _GlobalNarrationControlsState();
}

class _GlobalNarrationControlsState extends State<GlobalNarrationControls> {
  late final AudioService _audio;
  StreamSubscription<AudioState>? _audioEvents;
  AudioState _state = const AudioState();
  bool _hasNarration = false;

  @override
  void initState() {
    super.initState();
    _audio = widget.audioService ?? AudioService();
    _state = _audio.currentState;
    _hasNarration = _state.isPlaying || _state.isPaused || _state.isLoading;
    _audioEvents = _audio.stateStream.listen((next) {
      if (!mounted) return;
      setState(() {
        _state = next;
        if (next.isPlaying || next.isPaused || next.isLoading) {
          _hasNarration = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _audioEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        if (_hasNarration)
          Positioned(
            // Stay clear of the three-destination bottom navigation.
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 92,
            child: SafeArea(
              child: Material(
                elevation: 8,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.primary, width: 2),
                ),
                child: Semantics(
                  container: true,
                  label: 'Spoken guidance playback controls',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over_rounded,
                            color: colors.primary, size: 25),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('narration-pause'),
                          icon: const Icon(Icons.pause_circle_filled, size: 31),
                          tooltip: 'Pause spoken guidance',
                          onPressed: _state.isPlaying ? _audio.pause : null,
                        ),
                        IconButton(
                          key: const Key('narration-resume'),
                          icon: const Icon(Icons.play_circle_fill, size: 31),
                          tooltip: 'Resume spoken guidance',
                          onPressed: _state.isPaused ? _audio.resume : null,
                        ),
                        IconButton(
                          key: const Key('narration-restart'),
                          icon: const Icon(Icons.replay_circle_filled, size: 31),
                          tooltip: 'Restart spoken guidance from the beginning',
                          onPressed: _audio.restart,
                        ),
                        IconButton(
                          key: const Key('narration-stop'),
                          icon: const Icon(Icons.stop_circle, size: 31),
                          tooltip: 'Stop spoken guidance',
                          onPressed: _audio.stop,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
