import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/check_dispute_service.dart';

/// Moderator review of practice checks learners say are wrong (master plan
/// v2.6 §10.0 wrong-answer triage). One decision covers every open dispute
/// for a check version. Upholding quarantines that version until a fixed
/// Bridge ships; dismissing needs a note. The server re-checks the role,
/// the switch and the "not your own dispute" rule.
class CheckDisputeReviewScreen extends ConsumerStatefulWidget {
  const CheckDisputeReviewScreen({super.key});

  @override
  ConsumerState<CheckDisputeReviewScreen> createState() =>
      _CheckDisputeReviewScreenState();
}

class _CheckDisputeReviewScreenState
    extends ConsumerState<CheckDisputeReviewScreen> {
  List<DisputedCheck>? _items;
  Object? _loadError;
  bool _busy = false;

  CheckDisputeService get _service => ref.read(checkDisputeServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _loadError = null;
    });
    try {
      final items = await _service.openQueue();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<String?> _askNote({required bool uphold}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uphold ? 'Uphold: the question is wrong' : 'Dismiss'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uphold
                  ? 'Learners will no longer see this question in this '
                        'version. Fix the Bridge and raise its content version '
                        'to bring it back.'
                  : 'The question stays as it is.',
            ),
            TextField(
              key: const Key('dispute_note_field'),
              controller: controller,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: uphold
                    ? 'What needs fixing (optional)'
                    : 'Why it is fine (required)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('dispute_note_confirm'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(DisputedCheck item, {required bool uphold}) async {
    final note = await _askNote(uphold: uphold);
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await _service.decide(item.ref, uphold: uphold, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${uphold ? 'Upheld' : 'Dismissed'} $n dispute(s).'
              '${uphold ? ' The question is now hidden in that version.' : ''}',
            ),
          ),
        );
      ref.invalidate(quarantinedChecksProvider);
      await _load();
    } on CheckDisputeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(checkDisputesEnabledProvider);
    final roles = ref.watch(contributionRolesProvider);
    final library = ref.watch(bridgeLibraryProvider).valueOrNull;

    Widget body;
    if (!enabled) {
      body = const _Message(
        'Dispute review is switched off (learning.check_disputes).',
        key: Key('dispute_review_disabled'),
      );
    } else if (roles.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (roles.valueOrNull?.moderator != true) {
      body = const _Message(
        'Only moderators can review disputed questions.',
        key: Key('dispute_review_not_moderator'),
      );
    } else if (_loadError != null) {
      body = _Message(
        "Couldn't load the queue.",
        key: const Key('dispute_review_error'),
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = const _Message(
        'No open disputes.',
        key: Key('dispute_review_empty'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final item in _items!) _card(item, library)],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disputed questions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _card(DisputedCheck item, BridgeLibrary? library) {
    final theme = Theme.of(context);
    final r = item.ref;
    final bridge = library?[r.contentId];
    final check = bridge?.checks.where((c) => c.itemId == r.itemId).firstOrNull;
    final sameVersion = bridge?.contentVersion == r.contentVersion;

    return Card(
      key: Key('dispute_${r.key}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${bridge?.title ?? r.contentId} · ${r.itemId} · '
              'v${r.contentVersion}',
              style: theme.textTheme.titleSmall,
            ),
            if (bridge != null && !sameVersion)
              Text(
                'This app has version ${bridge.contentVersion}; the disputes '
                'are about ${r.contentVersion}.',
                key: const Key('dispute_version_mismatch'),
                style: theme.textTheme.bodySmall,
              ),
            if (check != null) ...[
              const SizedBox(height: 8),
              Text(check.prompt),
              Text(
                'Marked correct: ${_expected(check)}',
                key: Key('dispute_expected_${r.itemId}'),
                style: theme.textTheme.bodySmall,
              ),
            ] else
              Text(
                'This question is not in this app version.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              '${item.count} learner(s): ${[for (final e in item.reasons.entries) '${e.key.label} (${e.value})'].join('; ')}',
              key: Key('dispute_reasons_${r.itemId}'),
            ),
            for (final note in item.notes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('“$note”', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: Key('dispute_uphold_${r.itemId}'),
                  onPressed: _busy ? null : () => _decide(item, uphold: true),
                  child: const Text('Uphold (hide question)'),
                ),
                OutlinedButton(
                  key: Key('dispute_dismiss_${r.itemId}'),
                  onPressed: _busy ? null : () => _decide(item, uphold: false),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _expected(BridgeCheck check) {
    if (check.kind == BridgeCheckKind.choice) {
      final i = check.correctOptionIndex;
      return i < 0 ? '(none)' : check.options[i].text;
    }
    return check.expected.toString();
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
