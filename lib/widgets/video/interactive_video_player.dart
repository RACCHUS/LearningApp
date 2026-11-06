import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';
import '../../services/video/video_learning_service.dart';

/// Interactive video player widget with ER-10 prequestioning, retrieval pauses,
/// chapter navigation, and measured learning gain tracking (OPP-2, ER-10).
class InteractiveVideoPlayer extends StatefulWidget {
  final VideoInteractiveModule module;
  final VideoLearningService? learningService;
  final void Function(VideoCheckpoint checkpoint, bool isCorrect)? onCheckpointCompleted;
  final void Function(int timestampSeconds)? onSeek;

  const InteractiveVideoPlayer({
    super.key,
    required this.module,
    this.learningService,
    this.onCheckpointCompleted,
    this.onSeek,
  });

  @override
  State<InteractiveVideoPlayer> createState() => _InteractiveVideoPlayerState();
}

class _InteractiveVideoPlayerState extends State<InteractiveVideoPlayer> {
  late final VideoLearningService _service;
  late final VideoPlatformInfo _platformInfo;

  bool _isPlaying = false;
  int _currentSeconds = 0;
  VideoCheckpoint? _activeCheckpoint;
  int? _selectedOptionIndex;
  bool _hasSubmittedCurrent = false;
  final Set<String> _dismissedCheckpointIds = {};

  @override
  void initState() {
    super.initState();
    _service = widget.learningService ?? VideoLearningService();
    _platformInfo = VideoEmbedResolver.resolve(widget.module.rawVideoUrl);

    // If there is an initial prequestion at t = 0, trigger it upfront (ER-10)
    final initialPre = widget.module.checkpoints
        .where((cp) => cp.timestampSeconds == 0 && cp.type == VideoCheckpointType.prequestion)
        .firstOrNull;
    if (initialPre != null && !_service.isCheckpointCompleted(initialPre.id)) {
      _activeCheckpoint = initialPre;
    }
  }

  void _seekTo(int seconds) {
    final clamped = seconds.clamp(0, widget.module.durationSeconds);
    setState(() {
      _currentSeconds = clamped;
    });
    widget.onSeek?.call(clamped);
    _checkForCheckpoint(clamped);
  }

  void _checkForCheckpoint(int seconds) {
    if (_activeCheckpoint != null) return;

    final cp = widget.module.checkpointAt(seconds, toleranceSeconds: 1);
    if (cp != null &&
        !_dismissedCheckpointIds.contains(cp.id) &&
        !_service.isCheckpointCompleted(cp.id)) {
      setState(() {
        _isPlaying = false;
        _activeCheckpoint = cp;
        _selectedOptionIndex = null;
        _hasSubmittedCurrent = false;
      });
    }
  }

  void _submitCheckpoint() {
    if (_selectedOptionIndex == null || _activeCheckpoint == null) return;

    final cp = _activeCheckpoint!;
    final event = _service.recordCheckpointAttempt(
      module: widget.module,
      checkpoint: cp,
      selectedOptionIndex: _selectedOptionIndex!,
      latencyMs: 1500,
    );

    setState(() {
      _hasSubmittedCurrent = true;
    });

    final isCorrect = (event.score ?? 0.0) > 0.5;
    widget.onCheckpointCompleted?.call(cp, isCorrect);
  }

  void _resumePlayback() {
    if (_activeCheckpoint != null) {
      _dismissedCheckpointIds.add(_activeCheckpoint!.id);
    }
    setState(() {
      _activeCheckpoint = null;
      _selectedOptionIndex = null;
      _hasSubmittedCurrent = false;
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeChapter = widget.module.chapterForTimestamp(_currentSeconds);

    return Card(
      key: Key('video_player_${widget.module.id}'),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Title & Chapters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.module.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (activeChapter != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_border, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                activeChapter.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.module.measuredLearningGain != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 14, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          'Gain: ${(widget.module.measuredLearningGain! * 100).toInt()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Video Viewport / Embed Area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(
              minHeight: _activeCheckpoint != null ? 360 : 240,
            ),
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Embed placeholder / simulated player
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _platformInfo.sourceType == VideoSourceType.youtube
                            ? Icons.smart_display
                            : Icons.ondemand_video,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _platformInfo.embedUrl,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlaying ? 'Playing...' : 'Paused',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Interactive Checkpoint Overlay
                if (_activeCheckpoint != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.92),
                      padding: const EdgeInsets.all(16.0),
                      child: _buildCheckpointOverlay(context),
                    ),
                  ),
              ],
            ),
          ),

          // Controls & Timeline
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Timeline Slider with Checkpoint Markers
                Row(
                  children: [
                    Text(
                      VideoEmbedResolver.formatTimestamp(_currentSeconds),
                      style: theme.textTheme.labelSmall,
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              key: const Key('timeline_slider'),
                              min: 0,
                              max: widget.module.durationSeconds.toDouble(),
                              value: _currentSeconds.toDouble().clamp(
                                  0.0, widget.module.durationSeconds.toDouble()),
                              onChanged: (val) => _seekTo(val.toInt()),
                            ),
                          ),
                          // Visual pin markers for checkpoints
                          ...widget.module.checkpoints.map((cp) {
                            final fraction = widget.module.durationSeconds > 0
                                ? cp.timestampSeconds / widget.module.durationSeconds
                                : 0.0;
                            return Positioned(
                              left: (MediaQuery.of(context).size.width - 120) * fraction,
                              child: Tooltip(
                                message: '${cp.type.toDbString()} @ ${VideoEmbedResolver.formatTimestamp(cp.timestampSeconds)}',
                                child: InkWell(
                                  key: Key('checkpoint_pin_${cp.id}'),
                                  onTap: () => _seekTo(cp.timestampSeconds),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cp.type == VideoCheckpointType.prequestion
                                          ? Colors.amber
                                          : cp.type == VideoCheckpointType.retrievalPractice
                                              ? Colors.blue
                                              : Colors.teal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Text(
                      VideoEmbedResolver.formatTimestamp(widget.module.durationSeconds),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),

                // Controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      tooltip: 'Back 10 seconds',
                      onPressed: () => _seekTo(_currentSeconds - 10),
                    ),
                    IconButton(
                      key: const Key('play_pause_button'),
                      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      iconSize: 40,
                      color: theme.colorScheme.primary,
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                      onPressed: () {
                        if (_activeCheckpoint != null) return;
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      tooltip: 'Forward 10 seconds',
                      onPressed: () => _seekTo(_currentSeconds + 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final cp = _activeCheckpoint!;
    final isPrequestion = cp.type == VideoCheckpointType.prequestion;

    return SingleChildScrollView(
      key: Key('checkpoint_modal_${cp.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ER-10 Priming Banner
          if (isPrequestion)
            Container(
              key: const Key('er10_priming_badge'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Concept Priming Prequestion (ER-10: g = .54)\nGuessing primes attention specifically for the upcoming video concept.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer, color: Colors.lightBlueAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'In-Video Retrieval Practice Checkpoint',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Question Stem
          Text(
            cp.item.stem,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Options
          ...List.generate(cp.item.options.length, (idx) {
            final opt = cp.item.options[idx];
            final isSelected = _selectedOptionIndex == idx;

            Color tileColor = Colors.white12;
            BorderSide border = BorderSide.none;

            if (_hasSubmittedCurrent) {
              if (opt.isCorrect) {
                tileColor = Colors.green.shade900.withOpacity(0.6);
                border = const BorderSide(color: Colors.greenAccent, width: 2);
              } else if (isSelected && !opt.isCorrect) {
                tileColor = Colors.red.shade900.withOpacity(0.6);
                border = const BorderSide(color: Colors.redAccent, width: 2);
              }
            } else if (isSelected) {
              tileColor = theme.colorScheme.primary.withOpacity(0.3);
              border = BorderSide(color: theme.colorScheme.primary, width: 1.5);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: InkWell(
                key: Key('checkpoint_option_$idx'),
                onTap: _hasSubmittedCurrent
                    ? null
                    : () {
                        setState(() {
                          _selectedOptionIndex = idx;
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(8),
                    border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt.text,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Feedback upon submission
          if (_hasSubmittedCurrent) ...[
            const SizedBox(height: 8),
            if (_selectedOptionIndex != null &&
                !cp.item.options[_selectedOptionIndex!].isCorrect &&
                cp.item.options[_selectedOptionIndex!].misconception != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'Misconception: ${cp.item.options[_selectedOptionIndex!].misconception}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ),
            if (cp.item.explanation != null)
              Text(
                'Explanation: ${cp.item.explanation}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const Key('checkpoint_resume_button'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continue Video'),
              onPressed: _resumePlayback,
            ),
          ] else ...[
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('checkpoint_submit_button'),
              onPressed: _selectedOptionIndex != null ? _submitCheckpoint : null,
              child: const Text('Submit Answer'),
            ),
          ],
        ],
      ),
    );
  }
}
