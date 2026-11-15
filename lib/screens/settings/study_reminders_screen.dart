import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/study_reminders_provider.dart';
import 'package:learning_pwa/services/study_reminder_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Settings › Study reminders (`learning.study_reminders`).
///
/// Opt-in only: nothing here is offered during first run (UI spec F1), and
/// the copy never uses urgency, streak or loss framing (§9).
class StudyRemindersScreen extends ConsumerWidget {
  const StudyRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study reminders')),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [_body(context, ref)],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    if (!ref.watch(studyRemindersEnabledProvider)) {
      return const _Notice(
        key: ValueKey('reminders-planned'),
        text: 'Study reminders are planned and not yet connected.',
      );
    }
    if (ref.watch(webPushVapidPublicKeyProvider).isEmpty) {
      return const _Notice(
        key: ValueKey('reminders-not-configured'),
        text: 'Study reminders are not set up on this server yet.',
      );
    }
    return const _RemindersBody();
  }
}

class _RemindersBody extends ConsumerStatefulWidget {
  const _RemindersBody();

  @override
  ConsumerState<_RemindersBody> createState() => _RemindersBodyState();
}

class _RemindersBodyState extends ConsumerState<_RemindersBody> {
  bool _busy = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _snack(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOnBrowser() => _run(() async {
        final client = ref.read(webPushClientProvider);
        final result =
            await client.subscribe(ref.read(webPushVapidPublicKeyProvider));
        switch (result.status) {
          case WebPushSubscribeStatus.subscribed:
            await ref
                .read(studyReminderServiceProvider)
                .registerBrowser(result.subscription!);
            ref.invalidate(browserPushSubscriptionProvider);
          case WebPushSubscribeStatus.denied:
            _snack('Notifications are blocked for this site. '
                'You can allow them in your browser settings.');
          case WebPushSubscribeStatus.unsupported:
            _snack('This browser cannot receive reminders.');
          case WebPushSubscribeStatus.failed:
            _snack('Could not turn on reminders for this browser.');
        }
      }, 'Could not turn on reminders for this browser.');

  Future<void> _turnOffBrowser() => _run(() async {
        final endpoint = await ref.read(webPushClientProvider).unsubscribe();
        if (endpoint != null) {
          await ref.read(studyReminderServiceProvider).unregisterBrowser(endpoint);
        }
        ref.invalidate(browserPushSubscriptionProvider);
      }, 'Could not turn off reminders for this browser.');

  Future<void> _edit([StudyReminder? existing]) async {
    final timeZone = ref.read(webPushClientProvider).timeZone ?? 'UTC';
    final draft = await showDialog<_Draft>(
      context: context,
      builder: (_) => _ReminderDialog(existing: existing),
    );
    if (draft == null) return;
    await _run(() async {
      await ref.read(studyReminderServiceProvider).save(
            id: existing?.id,
            hour: draft.time.hour,
            minute: draft.time.minute,
            daysOfWeek: draft.days,
            // Saved in this browser's current time zone.
            timezone: timeZone,
            isActive: existing?.isActive ?? true,
          );
      ref.invalidate(studyRemindersProvider);
    }, 'Could not save the reminder.');
  }

  Future<void> _setActive(StudyReminder r, bool active) => _run(() async {
        await ref.read(studyReminderServiceProvider).save(
              id: r.id,
              hour: r.hour,
              minute: r.minute,
              daysOfWeek: r.daysOfWeek,
              timezone: r.timezone,
              isActive: active,
            );
        ref.invalidate(studyRemindersProvider);
      }, 'Could not update the reminder.');

  Future<void> _delete(StudyReminder r) => _run(() async {
        await ref.read(studyReminderServiceProvider).delete(r.id);
        ref.invalidate(studyRemindersProvider);
      }, 'Could not delete the reminder.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = ref.watch(webPushClientProvider);
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    if (!client.supported) {
      return const _Notice(
        key: ValueKey('reminders-unsupported'),
        text: 'This browser cannot receive reminders. On iPhone and iPad, '
            'add LearningApp to your Home Screen first, then open it from there.',
      );
    }

    final subscription = ref.watch(browserPushSubscriptionProvider);
    final reminders = ref.watch(studyRemindersProvider);
    final browserOn = subscription.valueOrNull != null;
    final list = reminders.valueOrNull ?? const <StudyReminder>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reminders arrive as notifications from your browser, even when '
          'LearningApp is closed. They go to every browser you turn them on in.',
          style: muted,
        ),
        const SizedBox(height: DesignTokens.space4),
        Card(
          child: ListTile(
            leading: Icon(browserOn
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined),
            title: Text(browserOn
                ? 'On for this browser'
                : 'Off for this browser'),
            trailing: subscription.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _busy
                        ? null
                        : (browserOn ? _turnOffBrowser : _turnOnBrowser),
                    child: Text(browserOn ? 'Turn off' : 'Turn on'),
                  ),
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text('Reminders', style: theme.textTheme.titleMedium),
        const SizedBox(height: DesignTokens.space2),
        if (reminders.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (reminders.hasError)
          Text('Reminders are unavailable right now.', style: muted)
        else if (list.isEmpty)
          Text('No reminders yet.', style: muted)
        else
          for (final r in list)
            Card(
              child: ListTile(
                key: ValueKey('reminder-${r.id}'),
                title: Text(r.localTime),
                subtitle: Text(r.daysLabel),
                onTap: _busy ? null : () => _edit(r),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: r.isActive,
                      onChanged: _busy ? null : (v) => _setActive(r, v),
                    ),
                    IconButton(
                      tooltip: 'Delete reminder',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _delete(r),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: DesignTokens.space3),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy || list.length >= StudyReminderService.maxReminders
                ? null
                : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add reminder'),
          ),
        ),
        if (list.length >= StudyReminderService.maxReminders)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space2),
            child: Text('You can have up to 5 reminders.', style: muted),
          ),
        if (!browserOn && list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space3),
            child: Text(
              'Turn reminders on for this browser to receive them here.',
              style: muted,
            ),
          ),
      ],
    );
  }
}

class _Draft {
  const _Draft(this.time, this.days);
  final TimeOfDay time;
  final List<int> days;
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({this.existing});
  final StudyReminder? existing;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  late TimeOfDay _time;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _time = e == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay(hour: e.hour, minute: e.minute);
    _days = e == null ? {1, 2, 3, 4, 5} : e.daysOfWeek.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add reminder' : 'Edit reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('reminder-time'),
            icon: const Icon(Icons.schedule),
            label: Text(_time.format(context)),
            onPressed: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: DesignTokens.space3),
          Wrap(
            spacing: DesignTokens.space1,
            runSpacing: DesignTokens.space1,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_names[d - 1]),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(
                      () => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _days.isEmpty
              ? null
              : () => Navigator.pop(
                  context, _Draft(_time, _days.toList()..sort())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
