import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// The three persistent destinations remain Learn, Library, and Progress.
/// The desktop/tablet rail can collapse to icons; expanded search navigates
/// directly into Library search rather than adding another destination.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _destinations = <_Destination>[
    _Destination('Learn', Icons.school_outlined, Icons.school, '/learn'),
    _Destination('Library', Icons.grid_view_outlined, Icons.grid_view, '/library'),
    _Destination('Progress', Icons.insights_outlined, Icons.insights, '/progress'),
  ];

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool? _expandedOverride;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index =
        _destinations.indexWhere((d) => location.startsWith(d.route));
    return index < 0 ? 0 : index;
  }

  void _onSelect(BuildContext context, int index) {
    final target = _destinations[index].route;
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

  Widget _railLeading(bool expanded) {
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
                    hintText: 'Search library',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Search learning library',
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
              tooltip: 'Search learning library',
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
              leading: _railLeading(expanded),
              onDestinationSelected: (i) => _onSelect(context, i),
              destinations: [
                for (final d in _destinations)
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
          for (final d in _destinations)
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
