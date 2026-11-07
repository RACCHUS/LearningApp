import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:learning_pwa/widgets/literacy/currency_atm_widget.dart';
import 'package:learning_pwa/widgets/simulation/network_troubleshooting_simulation.dart';
import 'package:learning_pwa/widgets/simulation/simulation_navigation.dart';

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
  void dispose() {
    final session = _session;
    if (session != null) {
      if (!session.isClosed) {
        session.terminate(SimulationTerminationReason.runtimeEnded);
      }
      session.dispose();
    }
    super.dispose();
  }

  void _exit() {
    _terminateForLearnerExit();
    leaveSimulation(context);
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
        if (didPop) _terminateForLearnerExit();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _exit},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const Key('exit-simulation'),
                tooltip: 'Exit simulation',
                icon: const Icon(Icons.close),
                onPressed: _exit,
              ),
              title: Text(_titleFor(activity.id)),
              actions: const [HelpAction()],
            ),
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
                        NetworkTroubleshootingSimulation(session: session)
                      else
                        CurrencyAtmWidget(
                          initialSection: CurrencyActivitySection.atmSimulator,
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
        : _titleFor(activity.id);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to lesson',
          icon: const Icon(Icons.arrow_back),
          onPressed: _exit,
        ),
        title: Text(title),
        actions: const [HelpAction()],
      ),
      body: Center(
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
    );
  }

  String _titleFor(String id) => switch (id) {
    'networking-basics' => 'Network troubleshooting practice',
    'atm-withdrawal' => 'ATM withdrawal practice',
    _ => 'Interactive practice',
  };
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
