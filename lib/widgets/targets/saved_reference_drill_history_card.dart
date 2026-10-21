import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_drill_event_service.dart';

/// Only visible for a verified reference revision. No answer keys, scoring,
/// or learner-only metadata are exposed by this saved observation panel.
class SavedReferenceDrillHistoryCard extends ConsumerWidget {
  final String manifestRevisionId;
  final ExamReferenceDrillEventService? eventService;

  const SavedReferenceDrillHistoryCard({
    super.key,
    required this.manifestRevisionId,
    this.eventService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    if (session is! AuthSuccess || session.user.isAnonymous) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sign in to save private reference-practice history. '
            'Guest practice is not stored on the server.'),
      );
    }
    return _OwnedReferenceDrillHistory(
      key: ValueKey('reference-history:${session.user.id}:$manifestRevisionId'),
      ownerId: session.user.id,
      manifestRevisionId: manifestRevisionId,
      service: eventService,
    );
  }
}

class _OwnedReferenceDrillHistory extends StatefulWidget {
  final String ownerId;
  final String manifestRevisionId;
  final ExamReferenceDrillEventService? service;

  const _OwnedReferenceDrillHistory({
    super.key,
    required this.ownerId,
    required this.manifestRevisionId,
    this.service,
  });

  @override
  State<_OwnedReferenceDrillHistory> createState() =>
      _OwnedReferenceDrillHistoryState();
}

class _OwnedReferenceDrillHistoryState
    extends State<_OwnedReferenceDrillHistory> {
  bool _open = false;
  late Future<List<Map<String, dynamic>>> _events;
  late final ExamReferenceDrillEventService _defaultService =
      ExamReferenceDrillEventService();

  ExamReferenceDrillEventService get _service =>
      widget.service ?? _defaultService;

  @override
  void initState() {
    super.initState();
    // Do not hit the network before the learner explicitly opens history.
    _events = Future.value(const []);
  }

  void _refresh() {
    setState(() {
      _events = _service.listMyEvents(
        limit: 100,
        manifestRevisionId: widget.manifestRevisionId,
        expectedOwnerId: widget.ownerId,
      );
    });
  }

  Future<void> _deleteAttempt(String attemptId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved practice?'),
        content: const Text('Delete all saved step observations for this '
            'attempt? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete practice'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;
    try {
      await _service.deleteMyAttempt(
        attemptId,
        manifestRevisionId: widget.manifestRevisionId,
        expectedOwnerId: widget.ownerId,
      );
      if (!mounted) return;
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete saved practice.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('reference-drill-history'),
      initiallyExpanded: false,
      title: const Text('Saved reference practice'),
      subtitle: const Text('Private, ungraded activity for this reference list'),
      onExpansionChanged: (open) {
        if (open && !_open) _refresh();
        _open = open;
      },
      children: [
        if (_open)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _events,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Could not load history. Retry'),
                  ),
                );
              }
              final events = snapshot.data ?? [];
              // Extra defense: reject broader/mock server responses.
              final matches = events.where((event) =>
                  event['owner_auth_uid'] == widget.ownerId &&
                  event['manifest_revision_id'] == widget.manifestRevisionId);
              final attempts = <String, List<Map<String, dynamic>>>{};
              for (final event in matches) {
                final key = event['client_attempt_id']?.toString();
                if (key != null && key.isNotEmpty) {
                  attempts.putIfAbsent(key, () => []).add(event);
                }
              }
              if (attempts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No saved reference practice for this edition.'),
                );
              }
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('These are activity observations, not '
                        'verified scores or passing predictions.'),
                  ),
                  for (final attempt in attempts.entries)
                    ListTile(
                      key: Key('practice-attempt:${attempt.key}'),
                      title: const Text('Reference practice attempt'),
                      subtitle: Text(
                        '${attempt.value.length} recorded step(s) · '
                        'Exam date: ${attempt.value.first['administration_date'] ?? 'unknown'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete saved practice',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteAttempt(attempt.key),
                      ),
                    ),
                  if (events.length >= 100)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Showing only the 100 most recent step records.'),
                    ),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh history'),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
