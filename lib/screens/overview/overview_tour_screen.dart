import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_context.dart';
import '../../models/learning_strategy.dart';
import '../../models/learning_target.dart';
import '../../models/overview_outline.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_strategy_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../services/planning/overview_planner.dart';
import '../../theme/design_tokens.dart';
import '../../utils/uuid_validator.dart';
import '../../widgets/help/help_action.dart';

/// Read-only Subject Overview Tour screen (`TEL-03`).
///
/// Architectural guarantees:
/// - Does NOT create, switch, or pin any [LearningContext] on open or preset change.
/// - Does NOT write to `learner_activity_progress`, `user_concept_state`,
///   `learning_events`, or FSRS scheduling tables.
/// - Optional comprehension checks in the 30-minute view are strictly transient
///   widget state and never count as mastery or diagnostic evidence.
class OverviewTourScreen extends ConsumerStatefulWidget {
  final String targetSlugOrId;
  final String? targetSlug;
  final OverviewDurationPreset initialPreset;

  const OverviewTourScreen({
    super.key,
    required this.targetSlugOrId,
    this.targetSlug,
    this.initialPreset = OverviewDurationPreset.fifteenMinutes,
  });

  @override
  ConsumerState<OverviewTourScreen> createState() => _OverviewTourScreenState();
}

class _OverviewTourScreenState extends ConsumerState<OverviewTourScreen> {
  late OverviewDurationPreset _selectedPreset;
  String? _targetResolutionError;

  /// Strictly transient, in-memory-only selections for optional 30-minute
  /// self-check items. Cleared on dispose and never persisted.
  final Map<String, int> _transientCheckSelections = {};

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flags = ref.watch(telFeatureFlagsProvider);
    final planner = ref.watch(overviewPlannerProvider);

    var isAllowed =
        flags.isOverviewEnabledForTarget(widget.targetSlugOrId) ||
        flags.isOverviewEnabledForTarget(widget.targetSlug);
    var outline = isAllowed
        ? (planner.findOutlineForTarget(widget.targetSlugOrId) ??
              planner.findOutlineForTarget(widget.targetSlug))
        : null;

    LearningTarget? resolvedTarget;
    if (outline == null && isValidUuid(widget.targetSlugOrId)) {
      resolvedTarget = ref
          .watch(targetDetailProvider(widget.targetSlugOrId))
          .valueOrNull;
      if (resolvedTarget != null) {
        isAllowed =
            isAllowed ||
            flags.isOverviewEnabledForTarget(resolvedTarget.id) ||
            flags.isOverviewEnabledForTarget(resolvedTarget.slug);
        if (isAllowed) {
          outline =
              planner.findOutlineForTarget(resolvedTarget.slug) ??
              planner.findOutlineForTarget(resolvedTarget.id) ??
              planner.findOutlineForTarget(resolvedTarget.title);
        }
      }
    }

    if (outline == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quick overview'),
          actions: const [HelpAction()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_outlined, size: 48),
                const SizedBox(height: DesignTokens.space3),
                Text(
                  'Quick overview is not available for this topic yet.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space4),
                FilledButton(
                  key: const Key('overview-unavailable-library-button'),
                  onPressed: () => context.go('/library'),
                  child: const Text('Browse Library'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final resolvedOutline = outline;
    final target = resolvedTarget;
    final planView = planner.project(
      outline: resolvedOutline,
      preset: _selectedPreset,
    );
    final canTryFast =
        flags.isFastEnabledForTarget(
          resolvedOutline.targetId,
          isExamTarget: true,
        ) ||
        flags.isFastEnabledForTarget(
          resolvedOutline.targetSlug,
          isExamTarget: true,
        ) ||
        flags.isFastEnabledForTarget(
          widget.targetSlugOrId,
          isExamTarget: true,
        ) ||
        flags.isFastEnabledForTarget(
          widget.targetSlug,
          isExamTarget: true,
        ) ||
        (target != null &&
            (flags.isFastEnabledForTarget(target.id, isExamTarget: true) ||
                flags.isFastEnabledForTarget(target.slug, isExamTarget: true)));

    return Scaffold(
      appBar: AppBar(
        title: Text('${resolvedOutline.title} · Overview'),
        actions: const [HelpAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          // Read-only orientation disclosure banner
          Card(
            key: const Key('overview-readonly-disclosure-banner'),
            elevation: 0,
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Get oriented in minutes · Read-only tour',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on College Board’s published exam topic outline. '
                          'Exploring this overview does not create a goal, record lesson completion, or measure exam readiness.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          // Duration preset selector (5 / 15 / 30 min)
          Text(
            'Choose overview depth',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          Semantics(
            label: 'Overview duration preset selector',
            child: SegmentedButton<OverviewDurationPreset>(
              key: const Key('overview-duration-selector'),
              segments: OverviewDurationPreset.values
                  .map(
                    (preset) => ButtonSegment<OverviewDurationPreset>(
                      value: preset,
                      label: Text(preset.shortLabel),
                      tooltip: preset.description,
                    ),
                  )
                  .toList(),
              selected: {_selectedPreset},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() {
                    _selectedPreset = selection.first;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          Text(
            _selectedPreset.description,
            key: const Key('overview-preset-description'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          // Premise & central questions
          Text(
            resolvedOutline.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          Text(
            resolvedOutline.plainLanguagePremise,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            'Central questions in this subject',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          ...resolvedOutline.centralQuestions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(q, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          // 7 Reviewed Topic Families
          Text(
            'Map of major topic areas (${planView.familyCount} topic families · ${planView.officialDomainCount} official exam areas)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
          ...planView.projectedFamilies.map(
            (projected) => _buildFamilyCard(context, projected),
          ),

          const SizedBox(height: DesignTokens.space4),

          // Official 13-domain published weight table
          _buildOfficialBlueprintSection(context, resolvedOutline),

          const SizedBox(height: DesignTokens.space4),

          // Explicit Omitted / Unassessed Disclosures & Provenance
          _buildOmittedAndProvenanceCard(context, planView),

          const SizedBox(height: DesignTokens.space5),

          // Explicit learner-initiated next steps (never triggered automatically)
          Text(
            'Ready to study?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          if (_targetResolutionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space3),
              child: Card(
                key: const Key('overview-target-resolution-error-banner'),
                elevation: 0,
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: DesignTokens.space2),
                      Expanded(
                        child: Text(
                          _targetResolutionError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: DesignTokens.space3,
            runSpacing: DesignTokens.space2,
            children: [
              FilledButton.icon(
                key: const Key('overview-start-standard-button'),
                onPressed: () => _startGoalWithStrategy(
                  resolvedOutline,
                  target,
                  PersistedLearningStrategy.standard,
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start learning'),
              ),
              if (canTryFast)
                FilledButton.tonalIcon(
                  key: const Key('overview-try-fast-button'),
                  onPressed: () => _startGoalWithStrategy(
                    resolvedOutline,
                    target,
                    PersistedLearningStrategy.fast,
                  ),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Try Fast (prioritize key areas)'),
                ),
              OutlinedButton.icon(
                key: const Key('overview-full-outline-button'),
                onPressed: () => _openFullOutline(resolvedOutline, target),
                icon: const Icon(Icons.list_alt),
                label: const Text('Full outline'),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space6),
        ],
      ),
    );
  }

  /// Resolves a verified canonical target UUID, returning `null` if only an
  /// unresolved slug is available so goal creation never persists a non-UUID
  /// `rootId`.
  Future<String?> _resolveCanonicalTargetId(
    OverviewOutline outline,
    LearningTarget? resolvedTarget,
  ) async {
    if (resolvedTarget != null && isValidUuid(resolvedTarget.id.trim())) {
      return resolvedTarget.id.trim();
    }
    final passedId = widget.targetSlugOrId.trim();
    if (isValidUuid(passedId)) {
      return passedId;
    }

    try {
      final lookupKey =
          (widget.targetSlug != null && widget.targetSlug!.trim().isNotEmpty)
              ? widget.targetSlug!.trim()
              : (passedId.isNotEmpty ? passedId : outline.targetSlug);
      final target = await ref
          .read(learningTargetServiceProvider)
          .getTarget(lookupKey);
      if (target != null && isValidUuid(target.id.trim())) {
        return target.id.trim();
      }
    } catch (_) {
      // Offline or test environment without Supabase initialized
    }

    final contextsState = ref.read(learningContextsProvider);
    final normalizedTitle = outline.title.trim().toLowerCase();
    for (final ctx in [
      ...contextsState.contexts,
      ...contextsState.archivedContexts,
    ]) {
      if (ctx.rootType == ContextRootType.target &&
          isValidUuid(ctx.rootId.trim()) &&
          ctx.label.trim().toLowerCase() == normalizedTitle) {
        return ctx.rootId.trim();
      }
    }

    return null;
  }

  Future<void> _openFullOutline(
    OverviewOutline outline,
    LearningTarget? resolvedTarget,
  ) async {
    final canonicalTargetId = await _resolveCanonicalTargetId(
      outline,
      resolvedTarget,
    );
    if (canonicalTargetId == null || !isValidUuid(canonicalTargetId)) {
      if (mounted) {
        setState(() {
          _targetResolutionError =
              'Could not verify the canonical goal identity right now. Please try again when connected or browse from the Library.';
        });
      }
      return;
    }
    if (mounted) {
      if (_targetResolutionError != null) {
        setState(() {
          _targetResolutionError = null;
        });
      }
      context.push('/target/$canonicalTargetId/outline');
    }
  }

  Future<void> _startGoalWithStrategy(
    OverviewOutline outline,
    LearningTarget? resolvedTarget,
    PersistedLearningStrategy strategy,
  ) async {
    final userId = ref.read(learnerIdProvider);
    final canonicalTargetId = await _resolveCanonicalTargetId(
      outline,
      resolvedTarget,
    );
    if (canonicalTargetId == null || !isValidUuid(canonicalTargetId)) {
      if (mounted) {
        setState(() {
          _targetResolutionError =
              'Could not verify the canonical goal identity right now. Please try again when connected or start from the Library.';
        });
      }
      return;
    }

    if (mounted && _targetResolutionError != null) {
      setState(() {
        _targetResolutionError = null;
      });
    }

    String? targetVersionId;
    try {
      final latestVersion = await ref
          .read(learningTargetServiceProvider)
          .getLatestVersion(canonicalTargetId);
      targetVersionId = latestVersion?.id;
    } catch (_) {
      // Offline or test environment without Supabase initialized
    }

    await ref.read(learningContextsProvider.notifier).createOrSwitch(
      userId: userId,
      label: resolvedTarget?.title ?? outline.title,
      rootType: ContextRootType.target,
      rootId: canonicalTargetId,
      targetVersionId: targetVersionId,
      emoji: resolvedTarget?.emoji ?? '🧠',
    );

    final activeContext = ref.read(learningContextsProvider).active;
    if (activeContext != null) {
      ref.read(learningStrategyProvider.notifier).setStrategy(
        contextId: activeContext.id,
        strategy: strategy,
      );
    }

    if (mounted) {
      context.go('/learn');
    }
  }

  Widget _buildFamilyCard(
    BuildContext context,
    OverviewProjectedFamily projected,
  ) {
    final theme = Theme.of(context);
    final family = projected.family;

    return Card(
      key: Key('overview-family-card-${family.id}'),
      margin: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${family.order}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        family.publishedShareSummary,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(projected.takeaway, style: theme.textTheme.bodyMedium),

            if (projected.expandedExplanation != null) ...[
              const SizedBox(height: DesignTokens.space3),
              Text(
                projected.expandedExplanation!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (projected.keyDistinctions.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space3),
              Text(
                'Key distinctions',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space1),
              ...projected.keyDistinctions.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $d', style: theme.textTheme.bodySmall),
                ),
              ),
            ],

            if (projected.commonMisconception != null) ...[
              const SizedBox(height: DesignTokens.space3),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        'Common pitfall: ${projected.commonMisconception!}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (projected.vocabularyCards.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space3),
              Text(
                'Essential vocabulary',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              ...projected.vocabularyCards.map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.space2),
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.space2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.term,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.plainMeaning,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Why it matters: ${card.whyItMatters}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (projected.realWorldApplication != null) ...[
              const SizedBox(height: DesignTokens.space3),
              Text(
                'Real-world application: ${projected.realWorldApplication!}',
                style: theme.textTheme.bodySmall,
              ),
            ],

            if (projected.connectionNotes != null) ...[
              const SizedBox(height: DesignTokens.space2),
              Text(
                'How it connects: ${projected.connectionNotes!}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (projected.comprehensionChecks.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space3),
              ...projected.comprehensionChecks.map(
                (check) => _buildTransientCheck(context, check),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransientCheck(
    BuildContext context,
    OverviewComprehensionCheck check,
  ) {
    final theme = Theme.of(context);
    final selectedIdx = _transientCheckSelections[check.id];

    return Padding(
      key: Key('overview-transient-check-${check.id}'),
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional quick self-check (not recorded)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                check.prompt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              ...List.generate(check.options.length, (idx) {
                final isSelected = selectedIdx == idx;
                return RadioListTile<int>(
                  key: Key('overview-check-${check.id}-option-$idx'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: idx,
                  groupValue: selectedIdx,
                  title: Text(
                    check.options[idx],
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _transientCheckSelections[check.id] = val;
                      });
                    }
                  },
                  selected: isSelected,
                );
              }),
              if (selectedIdx != null) ...[
                const SizedBox(height: DesignTokens.space2),
                Text(
                  selectedIdx == check.correctOptionIndex
                      ? 'Correct — ${check.explanation}'
                      : 'Not quite — ${check.explanation}',
                  key: Key('overview-check-${check.id}-feedback'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selectedIdx == check.correctOptionIndex
                        ? Colors.green.shade800
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialBlueprintSection(
    BuildContext context,
    OverviewOutline outline,
  ) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('overview-official-blueprint-card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Published exam topic ranges (13 official areas)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            ...outline.officialDomains.map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d.domainNumber}. ${d.title}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      d.publishedWeightRangeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOmittedAndProvenanceCard(
    BuildContext context,
    OverviewPlanView planView,
  ) {
    final theme = Theme.of(context);
    final prov = planView.provenance;
    return Card(
      key: const Key('overview-provenance-card'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What this overview leaves out & source attribution',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            ...planView.omittedOrDeferredNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $note', style: theme.textTheme.bodySmall),
              ),
            ),
            const Divider(height: DesignTokens.space4),
            Text(prov.blueprintSummary, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${prov.openTextbookAttribution} (${prov.openTextbookLicense})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              prov.verificationDisclosure,
              key: const Key('overview-provenance-verification-disclosure'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
