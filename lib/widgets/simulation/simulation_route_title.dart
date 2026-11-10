import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/widgets/simulation/simulation_navigation.dart';

class SimulationRouteTitle extends StatefulWidget {
  const SimulationRouteTitle({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<SimulationRouteTitle> createState() => _SimulationRouteTitleState();
}

class _SimulationRouteTitleState extends State<SimulationRouteTitle> {
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_scheduleUpdate);
  }

  @override
  void didUpdateWidget(covariant SimulationRouteTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_scheduleUpdate);
      widget.router.routerDelegate.addListener(_scheduleUpdate);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_scheduleUpdate);
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final uri = currentVisibleRouteUri(widget.router);
    final segments = uri.pathSegments;
    var title = BrandConfig.appName;
    if (segments.length == 3 && segments.first == 'simulation') {
      final activity = SimulationActivityRegistry.resolve(
        segments[1],
        segments[2],
      );
      final activityTitle = activity == null
          ? 'Interactive practice unavailable'
          : simulationActivityTitle(activity.id);
      title = '$activityTitle - ${BrandConfig.appName}';
    }
    return Title(
      title: title,
      color: Theme.of(context).colorScheme.primary,
      child: widget.child,
    );
  }
}
