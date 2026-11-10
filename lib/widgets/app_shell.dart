import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/l10n/app_localizations.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// The three persistent destinations remain Learn, Library, and Progress.
/// The desktop/tablet rail can collapse to icons; expanded search navigates
/// directly into Library search rather than adding another destination.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  DateTime? _lastFeatureRefreshAt;

  @override
  void initState() {
    super.initState();
    if (SiteFeatureRuntime.snapshotEnabled) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SiteFeatureRuntime.snapshotEnabled ||
        state != AppLifecycleState.resumed ||
        !mounted) {
      return;
    }
    // No periodic polling: refresh only when a learner returns to the app,
    // at most once per two minutes. Backend gates remain authoritative even
    // if a tab has a stale read-only visibility snapshot.
    final now = DateTime.now();
    if (_lastFeatureRefreshAt != null &&
        now.difference(_lastFeatureRefreshAt!) < const Duration(minutes: 2)) {
      return;
    }
    _lastFeatureRefreshAt = now;
    ref.invalidate(siteFeatureSnapshotProvider);
  }
  static const _routes = ['/learn', '/library', '/progress'];

  List<_Destination> _destinations(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _Destination(l10n?.navLearn ?? 'Learn', Icons.school_outlined, Icons.school, '/learn'),
      _Destination(l10n?.navLibrary ?? 'Library', Icons.grid_view_outlined, Icons.grid_view, '/library'),
      _Destination(l10n?.navProgress ?? 'Progress', Icons.insights_outlined, Icons.insights, '/progress'),
    ];
  }

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool? _expandedOverride;

  @override
  void dispose() {
    if (SiteFeatureRuntime.snapshotEnabled) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index =
        _routes.indexWhere((r) => location.startsWith(r));
    return index < 0 ? 0 : index;
  }

  void _onSelect(BuildContext context, int index) {
    final target = _routes[index];
    if (GoRouterState.of(context).uri.path != target) {
      context.go(target);
    }
  }

  void _searchLibrary() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _searchFocusNode.unfocus();
    context.go('/library?search=${Uri.encodeComponent(query)}');
  }

  void _expandAndFocus() {
    setState(() => _expandedOverride = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Widget _railLeading(BuildContext context, bool expanded) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            child: IconButton(
              key: const Key('sidebar-toggle'),
              tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
              icon: Icon(expanded ? Icons.menu_open : Icons.menu),
              onPressed: () =>
                  setState(() => _expandedOverride = !expanded),
            ),
          ),
          if (expanded)
            SizedBox(
              width: 224,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: TextField(
                  key: const Key('sidebar-search'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchLibrary(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n?.searchPlaceholder ?? 'Search library',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: l10n?.actionSearch ?? 'Search learning library',
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: _searchLibrary,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            )
          else
            IconButton(
              key: const Key('sidebar-open-search'),
              tooltip: l10n?.actionSearch ?? 'Search learning library',
              icon: const Icon(Icons.search),
              onPressed: _expandAndFocus,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final index = _indexFor(context);
    final destinations = _destinations(context);

    if (width >= DesignTokens.breakpointTablet) {
      final expanded =
          _expandedOverride ?? width >= DesignTokens.breakpointDesktop;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const Key('learning-sidebar'),
              selectedIndex: index,
              extended: expanded,
              labelType: expanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: _railLeading(context, expanded),
              onDestinationSelected: (i) => _onSelect(context, i),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onSelect(context, i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _Destination(this.label, this.icon, this.selectedIcon, this.route);
}

/// Centers the doing column without making Learn needlessly dense.
class LearnColumn extends StatelessWidget {
  final Widget child;
  const LearnColumn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < DesignTokens.breakpointMobile
        ? double.infinity
        : (width < DesignTokens.breakpointTablet ? 560.0 : 720.0);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space5,
          ),
          child: child,
        ),
      ),
    );
  }
}
