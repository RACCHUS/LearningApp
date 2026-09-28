import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/curriculum_node.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../services/hive_service.dart';
import '../../theme/design_tokens.dart';

class TargetOutlineScreen extends ConsumerStatefulWidget {
  final String targetId;

  const TargetOutlineScreen({super.key, required this.targetId});

  @override
  ConsumerState<TargetOutlineScreen> createState() => _TargetOutlineScreenState();
}

class _TargetOutlineScreenState extends ConsumerState<TargetOutlineScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetAsync = ref.watch(targetDetailProvider(widget.targetId));
    final versionAsync = ref.watch(targetVersionProvider(widget.targetId));

    return Scaffold(
      appBar: AppBar(
        title: targetAsync.when(
          data: (t) => Text(t?.title ?? 'Curriculum Outline'),
          loading: () => const Text('Loading outline...'),
          error: (_, __) => const Text('Curriculum Outline'),
        ),
      ),
      body: Column(
        children: [
          // In-context outline search filter (§10.1 & §11.2)
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space3),
            child: TextField(
              key: const Key('outline-search-field'),
              decoration: InputDecoration(
                hintText: 'Search within curriculum outline...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Outline Content
          Expanded(
            child: versionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildOfflineOrErrorState(theme),
              data: (version) {
                if (version == null) {
                  return _buildOfflineOrErrorState(theme);
                }

                final nodesAsync = ref.watch(targetCurriculumNodesProvider(version.id));
                return nodesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _buildOfflineOrErrorState(theme),
                  data: (nodes) {
                    final filteredNodes = _searchQuery.isEmpty
                        ? nodes
                        : nodes.where((n) {
                            return n.title.toLowerCase().contains(_searchQuery) ||
                                (n.code?.toLowerCase().contains(_searchQuery) ?? false) ||
                                (n.description?.toLowerCase().contains(_searchQuery) ?? false);
                          }).toList();

                    if (filteredNodes.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No curriculum nodes found for this version'
                              : 'No matches found in outline',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(DesignTokens.space3),
                      itemCount: filteredNodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.space2),
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        return _CurriculumNodeCard(
                          node: node,
                          onNodeSelected: () => _handleNodeTap(node),
                          onFocusRequested: () => _setNodeFocus(node),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleNodeTap(CurriculumNode node) {
    // If the node has an attached lesson or course, direct jump (<2 taps)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${node.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _setNodeFocus(CurriculumNode node) async {
    final activeContext = ref.read(learningContextsProvider).active;
    if (activeContext != null) {
      await ref.read(learningContextsProvider.notifier).updateFocus(
            activeContext.id,
            activeFocusType: node.nodeType,
            activeFocusId: node.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scope focused on: ${node.title}')),
        );
      }
    }
  }

  Widget _buildOfflineOrErrorState(ThemeData theme) {
    // Check if offline snapshot exists in Hive (§7.4)
    final hive = ref.read(hiveServiceProvider);
    final activeCtx = ref.read(learningContextsProvider).active;
    final snapshot = activeCtx != null ? hive.contextSnapshotBox.get(activeCtx.id) : null;

    if (snapshot != null && snapshot.nodes.isNotEmpty) {
      final nodes = snapshot.nodes;
      final filtered = _searchQuery.isEmpty
          ? nodes
          : nodes.where((n) {
              return n.title.toLowerCase().contains(_searchQuery) ||
                  (n.code?.toLowerCase().contains(_searchQuery) ?? false);
            }).toList();

      return ListView.separated(
        padding: const EdgeInsets.all(DesignTokens.space3),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.space2),
        itemBuilder: (context, index) {
          final n = filtered[index];
          return Card(
            child: ListTile(
              leading: n.code != null
                  ? Chip(
                      label: Text(n.code!),
                      visualDensity: VisualDensity.compact,
                    )
                  : const Icon(Icons.folder_outlined),
              title: Text(n.title),
              subtitle: Text('Offline snapshot · ${n.nodeType}'),
            ),
          );
        },
      );
    }

    return Center(
      child: Text(
        'Unable to load curriculum outline',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CurriculumNodeCard extends StatelessWidget {
  final CurriculumNode node;
  final VoidCallback onNodeSelected;
  final VoidCallback onFocusRequested;

  const _CurriculumNodeCard({
    required this.node,
    required this.onNodeSelected,
    required this.onFocusRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (node.code != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      node.code!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space2),
                ],
                Expanded(
                  child: Text(
                    node.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'focus') onFocusRequested();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'focus',
                      child: Text('Focus active scope on this domain'),
                    ),
                  ],
                ),
              ],
            ),
            if (node.description != null && node.description!.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space1),
              Text(
                node.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: DesignTokens.space2),
            Row(
              children: [
                _importanceBadge(node.importance, theme),
                const Spacer(),
                TextButton.icon(
                  onPressed: onNodeSelected,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _importanceBadge(CurriculumImportance importance, ThemeData theme) {
    Color bg;
    Color fg;
    String label;

    switch (importance) {
      case CurriculumImportance.core:
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        label = 'Core Requirement';
        break;
      case CurriculumImportance.recommended:
        bg = theme.colorScheme.secondaryContainer;
        fg = theme.colorScheme.onSecondaryContainer;
        label = 'Recommended';
        break;
      case CurriculumImportance.optional:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
        label = 'Elective / Optional';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
