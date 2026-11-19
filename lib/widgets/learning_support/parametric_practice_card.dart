import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/parametric_practice_service.dart';

/// "More practice with new numbers" for one reviewed family (master plan
/// v2.6 §6.6). Items come from the server without their answers; the
/// server checks each answer. Practice only: nothing here is progress.
class ParametricPracticeCard extends ConsumerStatefulWidget {
  const ParametricPracticeCard({super.key, required this.family});

  final ParametricFamily family;

  @override
  ConsumerState<ParametricPracticeCard> createState() =>
      _ParametricPracticeCardState();
}

class _ParametricPracticeCardState
    extends ConsumerState<ParametricPracticeCard> {
  final _input = TextEditingController();
  ParametricItem? _item;
  ParametricResult? _result;
  String? _error;
  bool _busy = false;

  ParametricPracticeService get _service =>
      ref.read(parametricPracticeServiceProvider);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await _service.nextItem(widget.family.id);
      if (!mounted) return;
      setState(() {
        _item = item;
        _result = null;
        _input.clear();
      });
    } on ParametricPracticeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final item = _item;
    if (item == null || _input.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await _service.submit(item.instanceId, _input.text);
      if (mounted) setState(() => _result = r);
    } on ParametricPracticeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _verdict(ParametricResult r) {
    if (!r.readable) return 'Type a number, for example 25 or 0.75.';
    if (r.correct == true) return 'Correct!';
    return 'Not quite. The answer is ${r.answer}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = widget.family.id;
    final item = _item;
    final result = _result;
    final answered = result != null && result.readable;
    return Card(
      key: Key('parametric-$id'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.family.title, style: theme.textTheme.titleSmall),
            Text(
              'New numbers each time, checked automatically. '
              'Practice only.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (item == null)
              FilledButton.tonal(
                key: Key('parametric-start-$id'),
                onPressed: _busy ? null : _next,
                child: const Text('Start'),
              )
            else ...[
              Text(item.prompt, key: Key('parametric-prompt-$id')),
              const SizedBox(height: 8),
              TextField(
                key: Key('parametric-input-$id'),
                controller: _input,
                enabled: !answered,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: item.acceptsPercentSign
                      ? 'Your answer, e.g. -25 or 25%'
                      : 'Your answer, e.g. 0.75',
                ),
                onSubmitted: (_) => answered ? null : _check(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!answered)
                    OutlinedButton(
                      key: Key('parametric-check-$id'),
                      onPressed: _busy ? null : _check,
                      child: const Text('Check'),
                    )
                  else
                    FilledButton.tonal(
                      key: Key('parametric-next-$id'),
                      onPressed: _busy ? null : _next,
                      child: const Text('Next question'),
                    ),
                  if (result != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _verdict(result),
                        key: Key('parametric-result-$id'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                key: Key('parametric-error-$id'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
