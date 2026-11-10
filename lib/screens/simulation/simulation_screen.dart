import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:learning_pwa/widgets/literacy/currency_atm_widget.dart';
import 'package:learning_pwa/widgets/simulation/network_troubleshooting_simulation.dart';
import 'package:learning_pwa/widgets/simulation/simulation_navigation.dart';
import 'package:learning_pwa/widgets/software_learning/excel_upload_card.dart';

class SimulationScreen extends StatefulWidget {
  final String simulationId;
  final String version;
  final bool previewEnabled;

  const SimulationScreen({
    super.key,
    required this.simulationId,
    required this.version,
    this.previewEnabled = simulationPreviewEnabled,
  });

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  late final SimulationActivityConfig? _activity;
  SimulationSession? _session;
  GoRouter? _router;
  bool _narrationStopped = false;

  @override
  void initState() {
    super.initState();
    _activity = SimulationActivityRegistry.resolve(
      widget.simulationId,
      widget.version,
    );
    final activity = _activity;
    if (activity != null &&
        isSimulationPreviewAllowed(requested: widget.previewEnabled)) {
      _session = SimulationSession(
        activity: activity,
        enabled: widget.previewEnabled,
      )..start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) return;
    final router = GoRouter.maybeOf(context);
    if (identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _router?.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    final session = _session;
    if (session != null) {
      if (!session.isClosed) {
        session.terminate(SimulationTerminationReason.runtimeEnded);
      }
      session.dispose();
    }
    super.dispose();
  }

  void _onRouteChanged() {
    final router = _router;
    if (!mounted || router == null) return;
    final segments = currentVisibleRouteUri(router).pathSegments;
    if (segments.length != 3 ||
        segments[0] != 'simulation' ||
        segments[1] != widget.simulationId ||
        segments[2] != widget.version) {
      _stopNarrationForExit();
    } else {
      _narrationStopped = false;
    }
  }

  void _exit() {
    _stopNarrationForExit();
    _terminateForLearnerExit();
    leaveSimulation(context);
  }

  void _stopNarrationForExit() {
    if (_session == null || _narrationStopped) return;
    _narrationStopped = true;
    final audio = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(preReaderAudioServiceProvider);
    unawaited(audio.stop());
  }

  void _terminateForLearnerExit() {
    final session = _session;
    if (session != null && !session.isClosed) {
      session.terminate(SimulationTerminationReason.learnerExit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final session = _session;
    if (activity == null || session == null) {
      return _buildFallback(context);
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _stopNarrationForExit();
          _terminateForLearnerExit();
        }
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _exit},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: _buildAppBar(context, simulationActivityTitle(activity.id)),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (activity.id ==
                          SimulationActivityRegistry.atmWithdrawal.id)
                        const _PracticeSafetyNotice(
                          message:
                              'Practice only. Do not enter a real card number or PIN.',
                        ),
                      const SizedBox(height: 8),
                      if (activity.id ==
                          SimulationActivityRegistry.networking.id)
                        NetworkTroubleshootingSimulation(
                          session: session,
                          onFinished: _exit,
                        )
                      else if (activity.id ==
                          SimulationActivityRegistry.excelBudget.id)
                        ExcelUploadCard(
                          exerciseId: activity.id,
                        )
                      else
                        CurrencyAtmWidget(
                          initialSection: CurrencyActivitySection.atmSimulator,
                          showNarrationControls: true,
                          onAtmCompleted: () => session.complete(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final activity = _activity;
    final title = activity == null
        ? 'Interactive practice unavailable'
        : simulationActivityTitle(activity.id);
    return Scaffold(
      appBar: _buildAppBar(context, title, fallback: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 40),
                        const SizedBox(height: 16),
                        const Text(
                          'This simulation is unavailable. Use the lesson’s '
                          'alternative activity to continue learning.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _exit,
                          child: const Text('Return to lesson'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String title, {
    bool fallback = false,
  }) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;
    final titleWidth = math.max(
      1.0,
      MediaQuery.sizeOf(context).width - 2 * kToolbarHeight - 32,
    );
    final painter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: titleWidth);
    final toolbarHeight = math.max(kToolbarHeight, painter.height + 16);
    painter.dispose();
    return AppBar(
      toolbarHeight: toolbarHeight,
      leading: IconButton(
        key: fallback ? null : const Key('exit-simulation'),
        tooltip: fallback ? 'Return to lesson' : 'Exit simulation',
        icon: Icon(fallback ? Icons.arrow_back : Icons.close),
        onPressed: _exit,
      ),
      title: DefaultTextStyle(style: titleStyle, child: Text(title)),
      actions: const [HelpAction()],
    );
  }
}

class _PracticeSafetyNotice extends StatelessWidget {
  final String message;

  const _PracticeSafetyNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
