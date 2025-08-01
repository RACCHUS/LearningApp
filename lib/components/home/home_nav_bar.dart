import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeNavBar extends StatelessWidget {
  final String currentRoute;

  const HomeNavBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : Colors.white,
      elevation: 8,
      padding: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      child: SizedBox(
        height: kBottomNavigationBarHeight,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildNavBarItem(
              context: context,
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              isActive: currentRoute == '/home',
              onTap: () {
                if (currentRoute != '/home') {
                  context.go('/home');
                }
              },
            ),
            _buildNavBarItem(
              context: context,
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
              label: 'Explore',
              isActive: currentRoute == '/explore',
              onTap: () => context.go('/explore'),
            ),
            _buildNavBarItem(
              context: context,
              icon: Icons.bookmark_border,
              activeIcon: Icons.bookmark,
              label: 'Saved',
              isActive: currentRoute == '/saved',
              onTap: () => context.go('/saved'),
            ),
            _buildNavBarItem(
              context: context,
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              isActive: currentRoute == '/profile',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
