import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

/// A name that arrived from another page: control characters removed, spaces
/// collapsed, capped. It is only ever shown as text and saved as a title.
String cleanCapturedTitle(String? raw) {
  final text = (raw ?? '')
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length > LearnerResource.maxTitleLength
      ? text.substring(0, LearnerResource.maxTitleLength).trimRight()
      : text;
}

/// The bookmarklet that sends the page the learner is on to [origin]'s
/// add-from-a-link route. Everything after `#` is the URL fragment, which a
/// browser never sends to a server.
String captureBookmarklet(String origin) =>
    "javascript:(function(){location.href='$origin/#/add-resource?url='"
    "+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)})();";

/// "Add from a link" (companion plan v1.0 §5.1 layer L2, EX-6): a link and a
/// page title arrive in the URL fragment from a bookmarklet, a Shortcut or a
/// share, and the learner chooses the goal and saves. Nothing is saved until
/// they do, the link is cleaned on the device, and LearningApp never opens
/// it. Behind `content.companion_capture`; the save itself goes through the
/// existing learner-resources server gate.
class AddResourceScreen extends ConsumerStatefulWidget {
  const AddResourceScreen({
    super.key,
    this.initialUrl,
    this.initialTitle,
    this.appOrigin,
  });

  final String? initialUrl;
  final String? initialTitle;

  /// Where this app is served, for the bookmarklet. Defaults to the page's
  /// own origin on the web.
  final String? appOrigin;

  @override
  ConsumerState<AddResourceScreen> createState() => _AddResourceScreenState();
}

class _AddResourceScreenState extends ConsumerState<AddResourceScreen> {
  late final TextEditingController _title;
  late final TextEditingController _link;
  LearnerResourceKind _kind = LearnerResourceKind.course;
  String? _targetId;
  String? _titleError;
  String? _linkError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: cleanCapturedTitle(widget.initialTitle),
    );
    final raw = (widget.initialUrl ?? '').trim();
    final cleaned = normalizeLearnerLink(raw);
    // A refused link is shown, capped, so the learner can see why.
    _linkError = cleaned.error;
    _link = TextEditingController(
      text: cleaned.url ?? (raw.length > 300 ? raw.substring(0, 300) : raw),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save(List<CaptureGoal> goals) async {
    final target = _targetId ?? goals.firstOrNull?.targetId;
    final title = _title.text.trim();
    final link = normalizeLearnerLink(_link.text);
    setState(() {
      _titleError = title.isEmpty
          ? 'Give it a name.'
          : (title.length > LearnerResource.maxTitleLength
                ? 'Use a shorter name.'
                : null);
      _linkError = link.error;
      _saveError = null;
    });
    if (target == null || _titleError != null || _linkError != null) return;
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(learnerResourceStoreProvider)
          .save(targetId: target, title: title, kind: _kind, url: link.url);
      ref.invalidate(learnerResourcesProvider(target));
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your goal.')),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      router?.go('/target/$target');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = "Couldn't save. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final enabled = ref.watch(companionCaptureEnabledProvider);
    final goals = ref.watch(captureGoalsProvider);
    final origin = widget.appOrigin ?? (kIsWeb ? Uri.base.origin : '');
    final selected = goals.any((g) => g.targetId == _targetId)
        ? _targetId
        : goals.firstOrNull?.targetId;

    final Widget body;
    if (!enabled) {
      body = const Padding(
        padding: EdgeInsets.all(DesignTokens.space4),
        child: Text(
          'Adding from a link is not available right now. You can still add it from a goal: '
          'open the goal and choose "Add something you\'re using".',
          key: Key('capture_unavailable'),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Text(
            'Add a course, video or book you are using to one of your goals.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.space3),
          TextField(
            key: const Key('capture_title'),
            controller: _title,
            maxLength: LearnerResource.maxTitleLength,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Name',
              hintText: 'The course, video or book',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          TextField(
            key: const Key('capture_link'),
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Link (optional)',
              hintText: 'https://',
              errorText: _linkError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
          DropdownButtonFormField<LearnerResourceKind>(
            key: const Key('capture_kind'),
            isExpanded: true,
            initialValue: _kind,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'What is it?',
            ),
            items: [
              for (final k in LearnerResourceKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          const SizedBox(height: DesignTokens.space3),
          if (goals.isEmpty) ...[
            const Text(
              'Choose a goal first. What you study outside LearningApp is kept with the goal it is for.',
              key: Key('capture_no_goal'),
            ),
            const SizedBox(height: DesignTokens.space2),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('capture_find_goal'),
                onPressed: () => GoRouter.maybeOf(context)?.go('/library'),
                icon: const Icon(Icons.search),
                label: const Text('Find a goal'),
              ),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              key: ValueKey('capture_goal_$selected'),
              isExpanded: true,
              initialValue: selected,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Goal',
              ),
              items: [
                for (final g in goals)
                  DropdownMenuItem(
                    value: g.targetId,
                    child: Text(g.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
            const SizedBox(height: DesignTokens.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('capture_save'),
                onPressed: _saving ? null : () => _save(goals),
                icon: const Icon(Icons.add),
                label: const Text('Add to this goal'),
              ),
            ),
          ],
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: DesignTokens.space2),
              child: Text(
                _saveError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: DesignTokens.space3),
          Text(
            'Nothing is saved until you choose Add. LearningApp has not opened this link and does not '
            'read the page behind it. Only you can see what you add.',
            key: const Key('capture_privacy_note'),
            style: muted,
          ),
          if (origin.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space4),
            ExpansionTile(
              key: const Key('capture_how'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Send a page here with one tap'),
              subtitle: const Text('A bookmark for a computer browser'),
              childrenPadding: const EdgeInsets.only(
                bottom: DesignTokens.space2,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              expandedAlignment: Alignment.centerLeft,
              children: [
                Text(
                  'Make a new bookmark and paste this as its address. On a page you are studying, '
                  'choose the bookmark: this form opens with the page\'s name and link filled in. '
                  'The link goes straight from your browser to this form. It is not sent to LearningApp '
                  'unless you choose Add.',
                  style: muted,
                ),
                const SizedBox(height: DesignTokens.space2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(DesignTokens.space2),
                  ),
                  child: SelectableText(
                    captureBookmarklet(origin),
                    key: const Key('capture_bookmarklet'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('capture_bookmarklet_copy'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: captureBookmarklet(origin)),
                        );
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Copied.')),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't copy. Select the text and copy it yourself.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add from a link'),
        actions: const [HelpAction()],
      ),
      body: body,
    );
  }
}
