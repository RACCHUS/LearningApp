import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where a learner lands when a simulation was opened without an originating
/// lesson, such as a direct link in a new browser tab.
const String simulationExitFallbackLocation = '/learn';

Uri currentVisibleRouteUri(GoRouter router) {
  final matches = router.routerDelegate.currentConfiguration;
  final last = matches.lastOrNull;
  return last is ImperativeRouteMatch ? last.matches.uri : matches.uri;
}

/// Leaves a simulation: returns to the originating page when one exists,
/// otherwise navigates to [simulationExitFallbackLocation].
void leaveSimulation(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (Navigator.of(context).canPop()) {
    if (router != null) {
      context.pop();
    } else {
      Navigator.of(context).pop();
    }
    return;
  }
  router?.go(simulationExitFallbackLocation);
}
