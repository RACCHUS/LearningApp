import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/taxonomy/taxonomy.dart';
import '../../providers/taxonomy_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/taxonomy/cip_detail_sheet.dart';

/// Primary Interactive Taxonomy & Career Pathway Explorer
/// Allows learners to browse and discover:
/// 1. BLS SOC & O*NET Labor Market Occupations & Job Zones
/// 2. NCES CIP 2020 Instructional Programs & Disciplines
/// 3. Catalog Clusters & Internal Canonical Fields
class TaxonomyExplorerScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final String? initialQuery;

  const TaxonomyExplorerScreen({
    super.key,
    this.initialTab = 0,
    this.initialQuery,
  });

  @override
  ConsumerState<TaxonomyExplorerScreen> createState() =>
      _TaxonomyExplorerScreenState();
}

class _TaxonomyExplorerScreenState
    extends ConsumerState<TaxonomyExplorerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  int? _selectedJobZone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchQuery = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pathways & Taxonomy'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4,
                  vertical: 4,
                ),
                child: TextField(
                  key: const Key('taxonomy-search-field'),
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search SOC, O*NET, CIP codes, titles...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Tab Bar (hidden when actively searching)
              if (!isSearching)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.work_outline, size: 18),
                      text: 'Careers & SOC',
                    ),
                    Tab(
                      icon: Icon(Icons.school_outlined, size: 18),
                      text: 'CIP Programs',
                    ),
                    Tab(
                      icon: Icon(Icons.category_outlined, size: 18),
                      text: 'Disciplines',
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space4,
                    vertical: 8,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Search Results for "$_searchQuery"',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: isSearching
          ? _buildSearchResults(theme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOccupationsTab(theme),
                _buildCipTab(theme),
                _buildClustersTab(theme),
              ],
            ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 1: Occupations & Labor Taxonomy (BLS SOC + O*NET)
  // --------------------------------------------------------------------------

  Widget _buildOccupationsTab(ThemeData theme) {
    final occupationsAsync = ref.watch(occupationNodesProvider(null));

    return Column(
      children: [
        // Job Zone Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: 8,
          ),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Zones'),
                selected: _selectedJobZone == null,
                onSelected: (val) {
                  if (val) setState(() => _selectedJobZone = null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Zone 1–2 (Entry/Cert)'),
                selected: _selectedJobZone == 2,
                onSelected: (val) {
                  setState(() => _selectedJobZone = val ? 2 : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Zone 3 (Voc/Assoc)'),
                selected: _selectedJobZone == 3,
                onSelected: (val) {
                  setState(() => _selectedJobZone = val ? 3 : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Zone 4 (B.S./B.A.)'),
                selected: _selectedJobZone == 4,
                onSelected: (val) {
                  setState(() => _selectedJobZone = val ? 4 : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Zone 5 (Grad/Doc)'),
                selected: _selectedJobZone == 5,
                onSelected: (val) {
                  setState(() => _selectedJobZone = val ? 5 : null);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child: occupationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading occupations: $err')),
            data: (allOccupations) {
              var list = allOccupations;
              if (_selectedJobZone != null) {
                if (_selectedJobZone == 2) {
                  list = list.where((o) => (o.jobZone ?? 0) <= 2).toList();
                } else {
                  list = list.where((o) => o.jobZone == _selectedJobZone).toList();
                }
              }

              if (list.isEmpty) {
                return const Center(child: Text('No occupations match filter.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(DesignTokens.space4),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final occ = list[index];
                  return _buildOccupationCard(theme, occ);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOccupationCard(ThemeData theme, OccupationNode occ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/taxonomy/occupation/${occ.code}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      occ.code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (occ.isOnetExtension) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'O*NET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (occ.jobZone != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Zone ${occ.jobZone}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                occ.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (occ.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  occ.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 2: CIP Educational Programs (NCES CIP 2020)
  // --------------------------------------------------------------------------

  Widget _buildCipTab(ThemeData theme) {
    final cipNodesAsync = ref.watch(externalClassificationNodesProvider(null));

    return cipNodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading CIP programs: $err')),
      data: (nodes) {
        if (nodes.isEmpty) {
          return const Center(child: Text('No CIP programs available.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.space4),
          itemCount: nodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final cip = nodes[index];
            final isSeries = cip.levelCode == 'series';
            final isProgram = cip.levelCode == 'program';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSeries
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSeries
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cip.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSeries
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  cip.title,
                  style: TextStyle(
                    fontWeight: isSeries ? FontWeight.bold : FontWeight.w600,
                    fontSize: isSeries ? 15 : 14,
                  ),
                ),
                subtitle: cip.definition != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          cip.definition!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : null,
                trailing: Icon(
                  isProgram ? Icons.chevron_right : Icons.unfold_more,
                  size: 20,
                ),
                onTap: () {
                  CipDetailSheet.show(context, cipNode: cip);
                },
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Tab 3: Catalog Clusters & Disciplines
  // --------------------------------------------------------------------------

  Widget _buildClustersTab(ThemeData theme) {
    final clustersAsync = ref.watch(catalogClustersProvider);

    return clustersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading clusters: $err')),
      data: (clusters) {
        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.space4),
          itemCount: clusters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cluster = clusters[index];
            return _buildClusterCard(theme, cluster);
          },
        );
      },
    );
  }

  Widget _buildClusterCard(ThemeData theme, CatalogCluster cluster) {
    final fieldsAsync = ref.watch(canonicalFieldsProvider(cluster.slug));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              cluster.emoji ?? '🎯',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          cluster.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Academic Cluster ${cluster.sortOrder}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          fieldsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Failed to load fields: $e'),
            ),
            data: (fields) {
              if (fields.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No canonical fields bound to this cluster.'),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Canonical Fields & Disciplines',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...fields.map((f) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.arrow_right, size: 20),
                          title: Text(f.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            f.fieldKind.replaceAll('_', ' '),
                            style: theme.textTheme.labelSmall,
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Unified Search Results View
  // --------------------------------------------------------------------------

  Widget _buildSearchResults(ThemeData theme) {
    final searchAsync = ref.watch(taxonomySearchProvider(_searchQuery));

    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Search error: $err')),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('No matches found for "$_searchQuery".'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.space4),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = results[index];
            final isOcc = item.kind == TaxonomyItemKind.occupation;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOcc
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isOcc
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: item.description != null
                    ? Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  if (isOcc) {
                    context.push('/taxonomy/occupation/${item.code}');
                  } else if (item.kind == TaxonomyItemKind.cipProgram) {
                    final cipNode = ExternalClassificationNode(
                      id: item.id,
                      sourceReleaseId: 'rel-cip-2020',
                      system: item.system ?? 'cip',
                      version: '2020',
                      code: item.code,
                      levelCode: item.level ?? 'program',
                      title: item.title,
                      definition: item.description,
                    );
                    CipDetailSheet.show(context, cipNode: cipNode);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
