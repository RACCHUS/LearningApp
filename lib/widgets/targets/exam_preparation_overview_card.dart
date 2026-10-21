import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/assessment_engine/exam_reference_manifest.dart';
import '../../models/learning_target.dart';
import '../../services/assessment/exam_reference_manifest_service.dart';
import '../../services/assessment/exam_reference_drill_event_service.dart';
import 'saved_reference_drill_history_card.dart';
import 'reviewed_reference_drill_practice_card.dart';

/// Exam dates and approved reference lookup belong inside the existing goal.
/// Unsourced exam rules are never substituted with practice defaults.
class ExamPreparationOverviewCard extends StatefulWidget {
  final TargetVersion targetVersion;
  final ExamReferenceManifestService? manifestService;
  final ExamReferenceDrillEventService? drillEventService;

  const ExamPreparationOverviewCard({
    super.key,
    required this.targetVersion,
    this.manifestService,
    this.drillEventService,
  });

  @override
  State<ExamPreparationOverviewCard> createState() =>
      _ExamPreparationOverviewCardState();
}

class _ExamPreparationOverviewCardState
    extends State<ExamPreparationOverviewCard> {
  DateTime? _examDate;
  String? _partKey;
  Future<ExamManifestSelection>? _lookup;

  Future<void> _chooseExamDate(
    ExamPreparationProfile profile,
    ExamPartSpec part,
  ) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _examDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select your actual exam administration date',
    );
    if (!mounted || chosen == null) return;

    setState(() {
      _examDate = chosen;
      _partKey = part.key;
      _lookup = (widget.manifestService ?? ExamReferenceManifestService())
          .resolveForExamDate(
            profile: profile,
            examPartKey: part.key,
            administrationDate: chosen,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    ExamPreparationProfile? profile;
    try {
      profile = ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: widget.targetVersion.id,
        metadata: widget.targetVersion.metadata,
      );
    } on FormatException {
      return const SizedBox.shrink();
    }
    if (profile == null) return const SizedBox.shrink();

    final typedProfile = profile;
    final theme = Theme.of(context);
    return Card(
      key: const Key('exam-preparation-overview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam preparation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what to study in Learn or Library. '
              'Exam parts below organize practice; they do not verify '
              'your eligibility or predict a passing result.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final part in typedProfile.examParts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.book_outlined, size: 17),
                    const SizedBox(width: 8),
                    Expanded(child: Text(part.displayName)),
                    TextButton(
                      onPressed: () => _chooseExamDate(typedProfile, part),
                      child: const Text('Check references'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Official reference lists, permitted book editions, '
              'room rules, and exam-time limits are not verified here. '
              'A dated checklist appears only for an independently '
              'reviewed manifest covering your actual exam date.',
              key: const Key('exam-reference-unknown-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_lookup != null) ...[
              const SizedBox(height: 14),
              Text(
                'Reference check for ' + (_partKey ?? 'selected part') + ' · ' +
                    (_examDate?.toIso8601String().substring(0, 10) ?? ''),
                style: theme.textTheme.titleSmall,
              ),
              FutureBuilder<ExamManifestSelection>(
                future: _lookup,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Reference verification is unavailable. '
                      'Confirm applicable editions with the official provider.',
                      key: Key('exam-reference-unavailable'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  return _renderSelection(snapshot.data!);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _renderSelection(ExamManifestSelection selection) {
    if (!selection.isSelected) {
      String notice;
      switch (selection.status) {
        case ExamManifestSelectionStatus.noApplicableRevision:
          notice = 'No approved reference list is available for this exam '
              'date. Continue general study; do not assume an edition.';
          break;
        case ExamManifestSelectionStatus.conflictingRevisions:
          notice = 'Conflicting reference revisions were found. Reference '
              'preparation is withheld until the sources are reconciled.';
          break;
        case ExamManifestSelectionStatus.unavailableSource:
          notice = 'The reference list could not be verified. Try again '
              'later and confirm the rules with the exam provider.';
          break;
        default:
          notice = 'A specific exam part and administration date are '
              'required before reference details can be verified.';
      }
      return Text(notice, key: const Key('exam-reference-unavailable'));
    }

    final revision = selection.revision!;
    if (_examDate == null || _partKey != revision.examPartKey ||
        !revision.covers(_examDate!)) {
      return const Text('No approved reference list matches this exam date.',
          key: Key('exam-reference-unavailable'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviewed reference list (revision ' +
              revision.revision.toString() +
              '). Confirm the latest rules with the exam provider.',
          key: const Key('exam-reference-reviewed'),
        ),
        const SizedBox(height: 8),
        for (final book in revision.references)
          Text('• ' + (book['title'] ?? book['key']).toString() +
              ' — Edition ' + book['edition'].toString()),
        const SizedBox(height: 8),
        Text(
          'Only reviewed reference metadata is shown. '
          'Check the primary source for exam-room rules, '
          'approved materials and any later corrections.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (revision.officialSourceUrl != null)
          TextButton.icon(
            onPressed: () {
              final url = Uri.tryParse(revision.officialSourceUrl!);
              if (url != null && url.scheme == 'https' && url.host.isNotEmpty) {
                launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open official reference source'),
          ),
        ReviewedReferenceDrillPracticeCard(
          manifestRevisionId: revision.id,
          examPartKey: revision.examPartKey,
          administrationDate: _examDate!,
          eventService: widget.drillEventService,
        ),
        SavedReferenceDrillHistoryCard(
          manifestRevisionId: revision.id,
          eventService: widget.drillEventService,
        ),
      ],
    );
  }
}
