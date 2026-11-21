import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/providers/local_ai_provider.dart';
import 'package:learning_pwa/providers/reading_position_provider.dart';
import 'package:learning_pwa/providers/unified_lesson_provider.dart';
import 'package:learning_pwa/services/ai/local_ai/local_ai_benchmark.dart';
import 'package:learning_pwa/services/ai/local_ai/local_ai_section_text.dart';
import 'package:learning_pwa/services/ai/local_ai/local_summarizer.dart';

/// "Key points (on this device)" for the lesson section being read (plan
/// v2.6 P4.1). Shown only when `ai.local_experimental` is on and the
/// browser has a built-in model this device can run; otherwise nothing is
/// rendered. Before a first-time model download the learner sees what will
/// be downloaded and must agree. The summary is not saved or graded.
class LocalKeyPointsAction extends ConsumerStatefulWidget {
  const LocalKeyPointsAction({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LocalKeyPointsAction> createState() =>
      _LocalKeyPointsActionState();
}

class _LocalKeyPointsActionState extends ConsumerState<LocalKeyPointsAction> {
  bool _busy = false;

  Future<void> _run(LocalAiAvailability availability) async {
    final messenger = ScaffoldMessenger.of(context);
    final currentBlock = ref.read(readingBlockProvider(widget.lessonId));
    var blocks = const <LessonBlock>[];
    try {
      blocks =
          (await ref.read(unifiedLessonProvider(widget.lessonId).future))
              .blocks;
    } catch (_) {}
    if (!mounted) return;
    final text = sectionTextForSummary(blocks, currentBlockId: currentBlock);
    if (text.length < 80) {
      messenger.showSnackBar(
        const SnackBar(content: Text('There is not enough reading text here to summarize.')),
      );
      return;
    }
    if (availability == LocalAiAvailability.downloadable &&
        !await _confirmDownload()) {
      return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<double?>(null);
    final waiting = _showWaiting(progress, availability);
    final watch = Stopwatch()..start();
    var bench = await LocalAiBenchmark.load();
    try {
      final points = await ref
          .read(localSummarizerProvider)
          .keyPoints(text, onDownloadProgress: (f) => progress.value = f);
      watch.stop();
      bench = bench.recordSuccess(watch.elapsed);
      await bench.save();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await waiting;
      if (!mounted) return;
      ref.invalidate(localAiAvailabilityProvider);
      await _showResult(points, watch.elapsed, bench);
    } catch (_) {
      await bench.recordFailure().save();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Your browser couldn't make key points for this section. "
            'Nothing was sent anywhere.',
          ),
        ),
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDownload() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download the on-device model?'),
        content: const SingleChildScrollView(
          child: Text(
            'Your browser (Chrome) can make key points with its own built-in AI '
            'model, but it has to download that model to this device first.\n\n'
            '• This is a one-time download of several gigabytes. Chrome needs at '
            'least 22 GB free on this drive and removes the model if space runs low.\n'
            '• Use Wi-Fi or another unmetered connection.\n'
            '• After that it works offline. Chrome states that no data is sent to '
            'Google or anyone else when the model is used, and LearningApp does not '
            'send your lesson text anywhere.\n\n'
            'This is an experiment: the key points can be wrong. Always check them '
            'against the lesson.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('local_ai_download_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download and summarize'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showWaiting(
    ValueNotifier<double?> progress,
    LocalAiAvailability availability,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, fraction, _) {
            final downloading =
                availability != LocalAiAvailability.available &&
                fraction != null &&
                fraction < 1;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  downloading
                      ? 'Downloading the on-device model… ${(fraction * 100).round()}%'
                      : 'Making key points on this device…',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: downloading ? fraction : null),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showResult(
    String points,
    Duration took,
    LocalAiBenchmark bench,
  ) {
    final seconds = (took.inMilliseconds / 1000).toStringAsFixed(1);
    final median = bench.medianMs;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            key: const Key('local_ai_key_points_sheet'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key points (on this device)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Made by your browser\'s built-in model. It can be wrong; check '
                  'it against the lesson. Not saved.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SelectableText(points.trim()),
                const SizedBox(height: 12),
                Text(
                  'Took $seconds s on this device'
                  '${median != null && bench.recentMs.length > 1 ? ' (usually ${(median / 1000).toStringAsFixed(1)} s)' : ''}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(localAiEnabledProvider)) return const SizedBox.shrink();
    final availability = ref.watch(localAiAvailabilityProvider).valueOrNull;
    if (availability == null || !availability.usable) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('local_ai_key_points_action'),
      icon: const Icon(Icons.summarize_outlined),
      tooltip: 'Key points (on this device)',
      onPressed: _busy ? null : () => _run(availability),
    );
  }
}
