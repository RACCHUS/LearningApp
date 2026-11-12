import 'package:flutter/material.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/services/learning_support/bridge_check_evaluator.dart';

/// One practice check inside a Bridge. Answers are graded locally against
/// the Bridge's verified expected value and are never recorded as progress
/// or mastery (master plan v2.6 §10.9: unreviewed practice is exploratory).
class BridgeCheckCard extends StatefulWidget {
  const BridgeCheckCard({
    super.key,
    required this.check,
    required this.index,
    this.onFirstAttempt,
    this.onDispute,
  });

  final BridgeCheck check;
  final int index;

  /// Called once, with the first readable answer's result. Retries are not
  /// reported: they follow feedback and are not independent evidence.
  final void Function(String itemId, bool correct)? onFirstAttempt;

  /// Called when the learner says the question seems wrong.
  final void Function(String itemId)? onDispute;

  @override
  State<BridgeCheckCard> createState() => _BridgeCheckCardState();
}

enum _Result { none, unreadable, correct, wrong }

class _BridgeCheckCardState extends State<BridgeCheckCard> {
  final _input = TextEditingController();
  int? _selected;
  _Result _result = _Result.none;
  bool _showExplanation = false;
  bool _reported = false;
  bool _disputed = false;

  BridgeCheck get _check => widget.check;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _grade() {
    _gradeOnly();
    if (!_reported &&
        (_result == _Result.correct || _result == _Result.wrong)) {
      _reported = true;
      widget.onFirstAttempt?.call(_check.itemId, _result == _Result.correct);
    }
  }

  void _gradeOnly() {
    setState(() {
      _showExplanation = false;
      if (_check.kind == BridgeCheckKind.choice) {
        if (_selected == null) {
          _result = _Result.unreadable;
          return;
        }
        _result = _selected == _check.correctOptionIndex
            ? _Result.correct
            : _Result.wrong;
        return;
      }
      final graded = BridgeCheckEvaluator.gradeNumeric(
        _input.text,
        _check.expected,
        allowPercentSign: _check.acceptsPercentSign,
      );
      _result = switch (graded) {
        null => _Result.unreadable,
        true => _Result.correct,
        false => _Result.wrong,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = _check.itemId;
    return Card(
      key: Key('bridge-check-$id'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${widget.index + 1}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(_check.prompt, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            if (_check.kind == BridgeCheckKind.numeric)
              TextField(
                key: Key('bridge-check-input-$id'),
                controller: _input,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Your answer',
                  hintText: _check.acceptsPercentSign ? 'e.g. 15 or 15%' : null,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _grade(),
              )
            else
              for (final (i, option) in _check.options.indexed)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: _selected == i,
                  child: ListTile(
                    key: Key('bridge-check-option-$id-${option.optionId}'),
                    leading: Icon(
                      _selected == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(option.text),
                    selected: _selected == i,
                    onTap: () => setState(() {
                      _selected = i;
                      _result = _Result.none;
                    }),
                  ),
                ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: Key('bridge-check-submit-$id'),
              onPressed: _grade,
              child: const Text('Check'),
            ),
            if (_result != _Result.none) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (_result) {
                    _Result.correct => 'Correct!',
                    _Result.wrong =>
                      'Not quite. Try again, or see how it works.',
                    _Result.unreadable =>
                      _check.kind == BridgeCheckKind.choice
                          ? 'Choose an answer first.'
                          : 'Type a number, for example 15 or 0.75.',
                    _Result.none => '',
                  },
                  key: Key('bridge-check-result-$id'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _result == _Result.correct
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            if (_result == _Result.correct || _showExplanation)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _check.feedback,
                  key: Key('bridge-check-feedback-$id'),
                ),
              )
            else if (_result == _Result.wrong)
              TextButton(
                key: Key('bridge-check-explain-$id'),
                onPressed: () => setState(() => _showExplanation = true),
                child: const Text('Show how it works'),
              ),
            if (widget.onDispute != null)
              _disputed
                  ? Text(
                      "Thanks. This question won't count toward suggestions.",
                      key: Key('bridge-check-disputed-$id'),
                      style: theme.textTheme.bodySmall,
                    )
                  : TextButton(
                      key: Key('bridge-check-dispute-$id'),
                      onPressed: () {
                        setState(() => _disputed = true);
                        widget.onDispute!(_check.itemId);
                      },
                      child: const Text('This question seems wrong'),
                    ),
          ],
        ),
      ),
    );
  }
}
