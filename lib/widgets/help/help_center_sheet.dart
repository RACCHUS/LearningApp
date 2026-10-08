import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/data/help_topics.dart';
import 'package:learning_pwa/models/help_topic.dart';
import 'package:learning_pwa/services/help_search_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/help/help_topic_view.dart';

Future<void> showHelpCenter(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  if (width < DesignTokens.breakpointTablet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.9,
        child: const HelpCenterSheet(),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
        ),
        child: const SizedBox(
          width: 560,
          child: HelpCenterSheet(),
        ),
      ),
    ),
  );
}

class HelpCenterSheet extends StatefulWidget {
  const HelpCenterSheet({super.key});

  @override
  State<HelpCenterSheet> createState() => _HelpCenterSheetState();
}

class _HelpCenterSheetState extends State<HelpCenterSheet> {
  static const _searchService = HelpSearchService();

  final _searchController = TextEditingController();
  String _query = '';
  HelpTopic? _selectedTopic;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTopic(HelpTopic topic) {
    setState(() => _selectedTopic = topic);
  }

  void _closeHelpAndPush(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedTopic;
    if (selected != null) {
      return Column(
        children: [
          _HelpHeader(onClose: () => Navigator.of(context).pop()),
          const Divider(height: 1),
          Expanded(
            child: HelpTopicView(
              topic: selected,
              onBack: () => setState(() => _selectedTopic = null),
              onAction: selected.actionRoute == null
                  ? null
                  : () => _closeHelpAndPush(selected.actionRoute!),
            ),
          ),
        ],
      );
    }

    final results = _searchService.search(helpTopics, _query);
    final isSearching = _query.trim().isNotEmpty;

    return Column(
      children: [
        _HelpHeader(onClose: () => Navigator.of(context).pop()),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.space4,
            DesignTokens.space2,
            DesignTokens.space4,
            DesignTokens.space3,
          ),
          child: TextField(
            key: const Key('help-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search help',
              hintText: 'Timer, progress, goals...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? _NoHelpResults(
                  onOpenSettings: () => _closeHelpAndPush('/settings'),
                )
              : isSearching
                  ? _SearchResults(
                      topics: results,
                      onOpen: _openTopic,
                    )
                  : _CategoryResults(
                      topics: results,
                      onOpen: _openTopic,
                    ),
        ),
      ],
    );
  }
}

class _HelpHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _HelpHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space4,
        DesignTokens.space3,
        DesignTokens.space2,
        DesignTokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Help',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            key: const Key('help-close'),
            tooltip: 'Close help',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<HelpTopic> topics;
  final ValueChanged<HelpTopic> onOpen;

  const _SearchResults({required this.topics, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('help-search-results'),
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        return ListTile(
          key: Key('help-result-${topic.id}'),
          title: Text(topic.title),
          subtitle: Text(topic.summary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen(topic),
        );
      },
    );
  }
}

class _CategoryResults extends StatelessWidget {
  final List<HelpTopic> topics;
  final ValueChanged<HelpTopic> onOpen;

  const _CategoryResults({required this.topics, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = HelpCategory.values
        .where((category) => topics.any((topic) => topic.category == category))
        .toList();

    return ListView.builder(
      key: const Key('help-category-results'),
      padding: const EdgeInsets.only(bottom: DesignTokens.space5),
      itemCount: categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        final categoryTopics =
            topics.where((topic) => topic.category == category).toList();

        return Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4,
                  vertical: DesignTokens.space1,
                ),
                child: Text(
                  category.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...categoryTopics.map(
                (topic) => ListTile(
                  key: Key('help-topic-row-${topic.id}'),
                  title: Text(topic.title),
                  subtitle: Text(topic.summary),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(topic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoHelpResults extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _NoHelpResults({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(
              'No help topics matched that search.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Try a shorter phrase or open Settings to browse available controls.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space4),
            OutlinedButton(
              key: const Key('help-no-results-settings'),
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
