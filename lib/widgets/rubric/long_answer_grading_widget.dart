import 'package:flutter/material.dart';
import 'package:learning_pwa/models/rubric/long_answer_rubric.dart';
import 'package:learning_pwa/services/rubric/long_answer_evaluator_service.dart';

/// Interactive widget providing student open-ended essay response grading against an analytic rubric.
class LongAnswerGradingWidget extends StatefulWidget {
  final LongAnswerRubric rubric;
  final ValueChanged<LongAnswerEvaluationResult>? onEvaluated;
  final String? initialText;

  const LongAnswerGradingWidget({
    super.key,
    required this.rubric,
    this.onEvaluated,
    this.initialText,
  });

  @override
  State<LongAnswerGradingWidget> createState() => _LongAnswerGradingWidgetState();
}

class _LongAnswerGradingWidgetState extends State<LongAnswerGradingWidget> {
  late final TextEditingController _controller;
  int _wordCount = 0;
  bool _isEvaluating = false;
  LongAnswerEvaluationResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _updateWordCount();
    _controller.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateWordCount);
    _controller.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final count = LongAnswerEvaluatorService.instance.countWords(_controller.text);
    if (count != _wordCount) {
      setState(() {
        _wordCount = count;
      });
    }
  }

  void _submitForEvaluation() {
    setState(() {
      _isEvaluating = true;
    });

    final res = LongAnswerEvaluatorService.instance.evaluateSubmission(
      rubric: widget.rubric,
      studentText: _controller.text,
    );

    setState(() {
      _result = res;
      _isEvaluating = false;
    });

    widget.onEvaluated?.call(res);
  }

  void _resetSubmission() {
    setState(() {
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWithinRange = _wordCount >= widget.rubric.minWords &&
        _wordCount <= widget.rubric.maxWords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Topic
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rubric.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.school_outlined, size: 16),
                          label: Text(widget.rubric.domainTopic),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          avatar: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(
                            'Pass: ${widget.rubric.passingScore}/${widget.rubric.maxScore} pts',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Card
          Card(
            color: theme.colorScheme.primaryContainer.withAlpha(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Assignment Prompt',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.rubric.promptQuestion,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Collapsible Rubric Guidance
          ExpansionTile(
            title: Text(
              'View Grading Rubric (${widget.rubric.criteria.length} Criteria)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: const Icon(Icons.table_chart_outlined),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: widget.rubric.criteria.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${c.weight * 4} max pts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (c.mandatoryKeywords.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Key Terms: ${c.mandatoryKeywords.join(', ')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (c.regulatoryCitations.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Citations: ${c.regulatoryCitations.join(', ')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24),

          // Response Input
          Text(
            'Your Written Response:',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 8,
            minLines: 4,
            readOnly: _result != null,
            decoration: InputDecoration(
              hintText: 'Enter your response here with detailed explanations, technical terminology, and statutory citations...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _result != null
                  ? theme.colorScheme.surfaceContainerHighest.withAlpha(80)
                  : theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 8),

          // Word Count Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Words: $_wordCount (${widget.rubric.minWords}-${widget.rubric.maxWords} expected)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isWithinRange
                      ? Colors.green.shade700
                      : (_wordCount < widget.rubric.minWords
                          ? theme.colorScheme.error
                          : Colors.amber.shade800),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_result == null)
                ElevatedButton.icon(
                  onPressed: _wordCount >= 5 && !_isEvaluating
                      ? _submitForEvaluation
                      : null,
                  icon: _isEvaluating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Grade Response'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _resetSubmission,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Revise Response'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Results Presentation
          if (_result != null) ...[
            _buildResultSummaryCard(context, _result!),
            const SizedBox(height: 16),
            Text(
              'Criterion Breakdown:',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.rubric.criteria.map((c) {
              final score = _result!.criterionResults[c.id];
              if (score == null) return const SizedBox.shrink();
              return _buildCriterionResultCard(context, c, score);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSummaryCard(BuildContext context, LongAnswerEvaluationResult res) {
    final theme = Theme.of(context);
    final isPass = res.passed;

    return Card(
      color: isPass
          ? Colors.green.shade50
          : Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPass ? Colors.green.shade400 : Colors.amber.shade400,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPass ? Icons.verified : Icons.warning_amber_rounded,
                  color: isPass ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPass ? 'Standard Met (Passed)' : 'Developing (Needs Revision)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPass ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        'Total Score: ${res.totalScore} / ${res.maxScore} pts (${res.percentage}%)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              res.summaryFeedback,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            if (res.flagPotentialPromptInjection) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 16, color: Colors.red.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Invariant 4: Adversarial prompt instructions were detected and stripped.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCriterionResultCard(
    BuildContext context,
    RubricCriterion criterion,
    CriterionScoreResult score,
  ) {
    final theme = Theme.of(context);
    final Color badgeColor;
    switch (score.level) {
      case RubricScoreLevel.exemplary:
        badgeColor = Colors.green.shade700;
        break;
      case RubricScoreLevel.proficient:
        badgeColor = Colors.blue.shade700;
        break;
      case RubricScoreLevel.developing:
        badgeColor = Colors.orange.shade800;
        break;
      case RubricScoreLevel.emerging:
        badgeColor = Colors.amber.shade900;
        break;
      case RubricScoreLevel.unacceptable:
        badgeColor = Colors.red.shade700;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    criterion.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    '${score.level.label} (${score.points}/${criterion.weight * 4} pts)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              score.rationale,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (score.matchedKeywords.isNotEmpty || score.missingKeywords.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...score.matchedKeywords.map(
                    (kw) => Chip(
                      avatar: const Icon(Icons.check, size: 14, color: Colors.green),
                      label: Text(kw),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  ...score.missingKeywords.map(
                    (kw) => Chip(
                      avatar: const Icon(Icons.close, size: 14, color: Colors.red),
                      label: Text(kw),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      score.improvementTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

