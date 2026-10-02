import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/curriculum_node.dart';
import '../../models/learning_target.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../services/hive_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/targets/topic_lesson_sections.dart';

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

    final target = targetAsync.valueOrNull;
    final version = versionAsync.valueOrNull;
    final authState = ref.watch(authProvider);
    final currentUserId = authState is AuthSuccess ? authState.user.id : null;
    final bool isOwner = currentUserId != null && target?.createdBy == currentUserId;
    final bool canEditCurriculum = isOwner &&
        (version?.status != TargetVersionStatus.published) &&
        !(target?.isOfficial ?? false);

    return Scaffold(
      appBar: AppBar(
        title: targetAsync.when(
          data: (t) => Text(t?.title ?? 'Curriculum Outline'),
          loading: () => const Text('Loading outline...'),
          error: (_, __) => const Text('Curriculum Outline'),
        ),
        actions: [
          versionAsync.when(
            data: (version) => (version != null && canEditCurriculum)
                ? IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Topic',
                    onPressed: () => _showAddNodeDialog(context, version.id),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
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
                      if (_searchQuery.isEmpty) {
                        return _buildEmptyAuthoringState(
                          context,
                          version,
                          theme,
                          targetTitle: targetAsync.valueOrNull?.title,
                          canEditCurriculum: canEditCurriculum,
                        );
                      }
                      return Center(
                        child: Text(
                          'No matches found in outline',
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
                          onNodeSelected: () => _handleNodeTap(node, canEditCurriculum),
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

  void _handleNodeTap(CurriculumNode node, bool canEditCurriculum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: TopicLessonSections(
              node: node,
              canEditCurriculum: canEditCurriculum,
              onFocusRequested: () {
                Navigator.of(ctx).pop();
                _setNodeFocus(node);
              },
            ),
          ),
        );
      },
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

  Widget _buildEmptyAuthoringState(
    BuildContext context,
    TargetVersion version,
    ThemeData theme, {
    String? targetTitle,
    bool canEditCurriculum = false,
  }) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_outlined,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(
              canEditCurriculum ? 'No Curriculum Nodes Yet' : 'Curriculum Outline Empty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              canEditCurriculum
                  ? 'Start building this curriculum outline by adding topics or generating with AI.'
                  : 'This official target has no topics defined yet. You can create a standalone lesson in your Library.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            if (canEditCurriculum)
              Wrap(
                spacing: DesignTokens.space3,
                runSpacing: DesignTokens.space2,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showAddNodeDialog(context, version.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Topic'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _handleEmptyOutlineGenerate(
                      context,
                      version.id,
                      targetTitle ?? 'Curriculum Topic',
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate with AI'),
                  ),
                ],
              )
            else
              FilledButton.tonalIcon(
                key: const Key('create_standalone_lesson_button'),
                onPressed: () => context.push('/create-lesson'),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Create Standalone Lesson'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEmptyOutlineGenerate(
    BuildContext context,
    String versionId,
    String targetTitle,
  ) async {
    final titleController = TextEditingController(text: targetTitle);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Topic for Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A curriculum topic provides the structure to anchor your AI-generated lesson:',
            ),
            const SizedBox(height: DesignTokens.space3),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Topic Title',
                hintText: 'e.g. Core Concepts',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue to AI Generator'),
          ),
        ],
      ),
    );

    if (proceed == true && titleController.text.trim().isNotEmpty && context.mounted) {
      final service = ref.read(learningTargetServiceProvider);
      final node = await service.addCurriculumNode(
        targetVersionId: versionId,
        title: titleController.text.trim(),
        description: 'Curriculum unit for $targetTitle',
      );
      if (node != null && context.mounted) {
        ref.invalidate(targetCurriculumNodesProvider(versionId));
        context.push(
          '/create-lesson?nodeId=${node.id}&nodeTitle=${Uri.encodeComponent(node.title)}&targetVersionId=$versionId',
        );
      }
    }
  }

  Future<void> _showAddNodeDialog(BuildContext context, String versionId) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Curriculum Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Topic Title',
                hintText: 'e.g. Network Fundamentals',
              ),
              autofocus: true,
            ),
            const SizedBox(height: DesignTokens.space3),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Summary of what this unit covers',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      final service = ref.read(learningTargetServiceProvider);
      await service.addCurriculumNode(
        targetVersionId: versionId,
        title: titleController.text.trim(),
        description: descController.text.trim().isNotEmpty
            ? descController.text.trim()
            : null,
      );
      ref.invalidate(targetCurriculumNodesProvider(versionId));
    }
  }

  Widget _buildOfflineOrErrorState(ThemeData theme) {
    // Check if offline snapshot exists in Hive matching this target (§7.4)
    final hive = ref.read(hiveServiceProvider);
    final allContexts = ref.read(learningContextsProvider).contexts;
    final matchingContext = allContexts.where((c) => c.rootId == widget.targetId).firstOrNull;

    final snapshot = (matchingContext != null
            ? hive.contextSnapshotBox.get(matchingContext.id)
            : null) ??
        hive.contextSnapshotBox.values
            .where((s) => s.contextId == widget.targetId || s.targetVersionId == widget.targetId)
            .firstOrNull;

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
