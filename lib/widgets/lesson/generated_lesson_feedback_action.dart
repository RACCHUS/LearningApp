import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The five feedback chips for AI-generated lessons (master plan v2.6
/// §5.7.6, signal 2). Wire values match migration 20261121060000.
enum LessonFeedbackChip {
  tooHard('too_hard', 'Too hard'),
  tooEasy('too_easy', 'Too easy'),
  confusing('confusing', 'Confusing'),
  wrong('wrong', 'Wrong'),
  notWhatINeeded('not_what_i_needed', 'Not what I needed');

  const LessonFeedbackChip(this.wire, this.label);
  final String wire;
  final String label;

  static LessonFeedbackChip? fromWire(Object? v) {
    for (final c in values) {
      if (c.wire == v) return c;
    }
    return null;
  }
}

abstract class LessonFeedbackApi {
  Future<LessonFeedbackChip?> mine(String lessonId);

  /// Sets, changes or (with null) clears the learner's chip.
  Future<void> set(String lessonId, LessonFeedbackChip? chip);
}

class SupabaseLessonFeedbackApi implements LessonFeedbackApi {
  SupabaseLessonFeedbackApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<LessonFeedbackChip?> mine(String lessonId) async => LessonFeedbackChip.fromWire(
    await _client.rpc('get_my_generated_lesson_feedback', params: {'p_lesson_id': lessonId}),
  );

  @override
  Future<void> set(String lessonId, LessonFeedbackChip? chip) => _client.rpc(
    'set_generated_lesson_feedback',
    params: {'p_lesson_id': lessonId, 'p_chip': chip?.wire},
  );
}

final lessonFeedbackEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentFeedbackChips,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final lessonFeedbackApiProvider = Provider<LessonFeedbackApi>(
  (ref) => SupabaseLessonFeedbackApi(),
);

/// Shown on a lesson only when it is AI-generated, the switch is on and a
/// permanent account is signed in.
bool showLessonFeedback({
  required bool enabled,
  required AuthState auth,
  required List<String> tags,
}) =>
    enabled &&
    auth is AuthSuccess &&
    !auth.user.isAnonymous &&
    tags.contains('ai-generated');

/// "Rate this lesson" for AI-generated lessons: one tap on a chip records
/// it (tap it again to clear). Feedback improves the prompts that made the
/// lesson; it does not change the lesson.
class GeneratedLessonFeedbackAction extends ConsumerWidget {
  const GeneratedLessonFeedbackAction({
    super.key,
    required this.lessonId,
    required this.tags,
  });

  final String lessonId;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cheap checks first: most lessons are not AI-generated, and the sign-in
    // state is only read when the button could actually be shown.
    if (!tags.contains('ai-generated') ||
        !ref.watch(lessonFeedbackEnabledProvider) ||
        !showLessonFeedback(
          enabled: true,
          auth: ref.watch(authProvider),
          tags: tags,
        )) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('generated_lesson_feedback_action'),
      icon: const Icon(Icons.rate_review_outlined),
      tooltip: 'Rate this generated lesson',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => GeneratedLessonFeedbackSheet(lessonId: lessonId),
      ),
    );
  }
}

class GeneratedLessonFeedbackSheet extends ConsumerStatefulWidget {
  const GeneratedLessonFeedbackSheet({super.key, required this.lessonId});
  final String lessonId;

  @override
  ConsumerState<GeneratedLessonFeedbackSheet> createState() =>
      _GeneratedLessonFeedbackSheetState();
}

class _GeneratedLessonFeedbackSheetState
    extends ConsumerState<GeneratedLessonFeedbackSheet> {
  LessonFeedbackChip? _chip;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    ref
        .read(lessonFeedbackApiProvider)
        .mine(widget.lessonId)
        .then((c) {
          if (mounted) setState(() => _chip = c);
        })
        .catchError((_) {})
        .whenComplete(() {
          if (mounted) setState(() => _loading = false);
        });
  }

  Future<void> _pick(LessonFeedbackChip chip) async {
    final next = _chip == chip ? null : chip;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(lessonFeedbackApiProvider).set(widget.lessonId, next);
      if (mounted) {
        setState(() {
          _chip = next;
          _message = next == null ? 'Cleared.' : 'Thanks, noted.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not save that. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        key: const Key('generated_lesson_feedback_sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was this generated lesson?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Your answer helps improve the prompts that made it. It does not '
              'change the lesson. Tap your choice again to clear it.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in LessonFeedbackChip.values)
                    ChoiceChip(
                      key: Key('lesson_feedback_${c.wire}'),
                      label: Text(c.label),
                      selected: _chip == c,
                      onSelected: _saving ? null : (_) => _pick(c),
                    ),
                ],
              ),
            if (_message case final m?) ...[
              const SizedBox(height: 8),
              Text(m),
            ],
          ],
        ),
      ),
    );
  }
}
