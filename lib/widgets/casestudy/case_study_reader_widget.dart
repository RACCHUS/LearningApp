import 'package:flutter/material.dart';
import '../../models/casestudy/case_study_scenario.dart';

/// Immersive scenario-based case study reader widget with evidence exhibits and branching decisions (P8-5).
class CaseStudyReaderWidget extends StatefulWidget {
  final CaseStudyScenario scenario;
  final void Function(bool passedAllSteps, int optimalDecisions)? onCompleted;

  const CaseStudyReaderWidget({
    super.key,
    required this.scenario,
    this.onCompleted,
  });

  @override
  State<CaseStudyReaderWidget> createState() => _CaseStudyReaderWidgetState();
}

class _CaseStudyReaderWidgetState extends State<CaseStudyReaderWidget> {
  int _currentStepIndex = 0;
  int? _selectedChoiceIndex;
  bool _isDecisionSubmitted = false;
  int _optimalDecisionsCount = 0;

  void _submitDecision() {
    if (_selectedChoiceIndex == null) return;
    final step = widget.scenario.steps[_currentStepIndex];
    final choice = step.choices[_selectedChoiceIndex!];

    setState(() {
      _isDecisionSubmitted = true;
      if (choice.isOptimal) {
        _optimalDecisionsCount++;
      }
    });
  }

  void _nextStep() {
    if (_currentStepIndex < widget.scenario.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _selectedChoiceIndex = null;
        _isDecisionSubmitted = false;
      });
    } else {
      final passed = _optimalDecisionsCount == widget.scenario.steps.length;
      widget.onCompleted?.call(passed, _optimalDecisionsCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.scenario.steps[_currentStepIndex];
    final isLastStep = _currentStepIndex >= widget.scenario.steps.length - 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Step Tracker
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.scenario.domain} • ${widget.scenario.difficulty}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Step ${step.stepNumber} of ${widget.scenario.steps.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              widget.scenario.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            // Narrative Block
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Text(
                step.narrative,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Evidence Exhibits
            if (step.exhibits.isNotEmpty) ...[
              Text(
                'Evidence Exhibits & Context',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...step.exhibits.map((ex) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: Icon(
                      ex.type == 'citation'
                          ? Icons.gavel
                          : (ex.type == 'log'
                              ? Icons.description
                              : Icons.assignment),
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      ex.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          ex.contentMarkdown,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Decision Fork Point
            Text(
              'Your Strategic Decision:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            ...step.choices.asMap().entries.map((entry) {
              final idx = entry.key;
              final choice = entry.value;
              final isSelected = _selectedChoiceIndex == idx;

              Color? borderColor;
              if (_isDecisionSubmitted) {
                if (choice.isOptimal) {
                  borderColor = Colors.green;
                } else if (isSelected && !choice.isOptimal) {
                  borderColor = Colors.red;
                }
              } else if (isSelected) {
                borderColor = theme.colorScheme.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: InkWell(
                  key: Key('case_choice_$idx'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isDecisionSubmitted
                      ? null
                      : () => setState(() => _selectedChoiceIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.08)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor ?? theme.colorScheme.outlineVariant,
                        width: isSelected || (_isDecisionSubmitted && choice.isOptimal)
                            ? 2.0
                            : 1.0,
                      ),
                    ),
                    child: Text(
                      choice.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Feedback Panel upon Decision Submission
            if (_isDecisionSubmitted && _selectedChoiceIndex != null) ...[
              Builder(
                builder: (context) {
                  final chosen = step.choices[_selectedChoiceIndex!];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: chosen.isOptimal
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: chosen.isOptimal ? Colors.green : Colors.red,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              chosen.isOptimal
                                  ? Icons.verified
                                  : Icons.warning_amber_rounded,
                              color: chosen.isOptimal
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              chosen.isOptimal
                                  ? 'Optimal Regulatory Decision'
                                  : 'Sub-Optimal Decision',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: chosen.isOptimal
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          chosen.feedback,
                          style: TextStyle(
                            fontSize: 13,
                            color: chosen.isOptimal
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                        if (chosen.regulatoryCitation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Citation: ${chosen.regulatoryCitation!}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: chosen.isOptimal
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('case_action_button'),
                onPressed: _selectedChoiceIndex != null
                    ? (!_isDecisionSubmitted ? _submitDecision : _nextStep)
                    : null,
                child: Text(
                  !_isDecisionSubmitted
                      ? 'Submit Decision'
                      : (isLastStep ? 'Complete Case Study' : 'Next Step in Scenario'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

