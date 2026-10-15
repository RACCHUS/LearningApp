import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/canonical_field.dart';
import '../../providers/taxonomy_provider.dart';

/// Expandable node in the internal field hierarchy
/// (broad field -> subfield -> program field).
///
/// Children are fetched only when the tile is expanded, one parent at a time,
/// so thousands of CIP-backed fields never load as a single flat list.
class FieldHierarchyTile extends ConsumerWidget {
  const FieldHierarchyTile({super.key, required this.field, this.depth = 0});

  final CanonicalField field;
  final int depth;

  /// Guards against cyclic parent data rendering forever.
  static const int maxDepth = 6;

  static String kindLabel(String fieldKind) => switch (fieldKind) {
        'broad_field' => 'Broad field',
        'subfield' => 'Subfield',
        'program_classification' => 'Program field',
        'native_field' => 'Learning area',
        _ => fieldKind.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final indent = EdgeInsets.only(left: 16.0 * depth, right: 8);
    final title = Text(
      field.name,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    final subtitle = Text(
      kindLabel(field.fieldKind),
      style: theme.textTheme.labelSmall,
    );

    if (!field.canHaveChildren || depth >= maxDepth) {
      return ListTile(
        key: ValueKey('field-tile-${field.id}'),
        dense: true,
        contentPadding: indent,
        leading: const Icon(Icons.school_outlined, size: 18),
        title: title,
        subtitle: subtitle,
      );
    }

    return ExpansionTile(
      key: PageStorageKey('field-tile-${field.id}'),
      tilePadding: indent,
      visualDensity: VisualDensity.compact,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.account_tree_outlined, size: 18),
      title: title,
      subtitle: subtitle,
      children: [_FieldChildren(parentId: field.id, depth: depth + 1)],
    );
  }
}

class _FieldChildren extends ConsumerWidget {
  const _FieldChildren({required this.parentId, required this.depth});

  final String parentId;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final childrenAsync = ref.watch(childFieldsProvider(parentId));
    final padding = EdgeInsets.fromLTRB(16.0 * depth + 16, 4, 16, 8);

    return childrenAsync.when(
      loading: () => Padding(
        padding: padding,
        child: const LinearProgressIndicator(),
      ),
      error: (error, _) => ListTile(
        dense: true,
        contentPadding: padding,
        leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
        title: const Text('Could not load narrower fields.'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(childFieldsProvider(parentId)),
          child: const Text('Retry'),
        ),
      ),
      data: (page) {
        if (page.fields.isEmpty) {
          return Padding(
            padding: padding,
            child: Text(
              'No narrower fields yet.',
              style: theme.textTheme.bodySmall,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in page.fields)
              FieldHierarchyTile(field: child, depth: depth),
            if (page.hasMore)
              Padding(
                padding: padding,
                child: Text(
                  'Showing the first ${page.fields.length} narrower fields. '
                  'Use search to find others.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}
