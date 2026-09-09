import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Persistent three-destination shell: Learn · Library · Progress.
///
/// No destination may display a badge, dot, count, or animation. Nothing may
/// summon the learner away from Learn (`UI_ARCHITECTURE_LOCKED.md` §3).
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _destinations = <_Destination>[
    _Destination('Learn', Icons.school_outlined, Icons.school, '/learn'),
    _Destination(
        'Library', Icons.grid_view_outlined, Icons.grid_view, '/library'),
    _Destination('Progress', Icons.insights_outlined, Icons.insights, '/progress'),
  ];

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final index = _indexFor(context);

    if (width >= DesignTokens.breakpointTablet) {
      final extended = width >= DesignTokens.breakpointDesktop;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
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
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
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

/// Centres a doing-screen column. A wider window gets more whitespace, not
/// more widgets (§7.2).
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
