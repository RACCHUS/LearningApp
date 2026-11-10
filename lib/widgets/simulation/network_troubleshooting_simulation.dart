import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';

class NetworkTroubleshootingSimulation extends ConsumerStatefulWidget {
  final SimulationSession session;
  final VoidCallback onFinished;

  const NetworkTroubleshootingSimulation({
    super.key,
    required this.session,
    required this.onFinished,
  });

  @override
  ConsumerState<NetworkTroubleshootingSimulation> createState() =>
      _NetworkTroubleshootingSimulationState();
}

class _NetworkTroubleshootingSimulationState
    extends ConsumerState<NetworkTroubleshootingSimulation> {
  String? _selectedLink;
  String? _selectedRepair;
  String? _selectedReason;
  bool _showHints = false;
  bool _showExplanation = false;
  bool _speakGuidance = true;

  bool get _hasCompleteResponse =>
      _selectedLink != null &&
      _selectedRepair != null &&
      _selectedReason != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Practice mode. This activity does not assess or certify networking skill.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Speak hints and explanations'),
          subtitle: const Text(
            'Turn off to avoid overlapping screen reader audio.',
          ),
          value: _speakGuidance,
          onChanged: (enabled) {
            setState(() => _speakGuidance = enabled);
            if (!enabled) ref.read(preReaderAudioServiceProvider).stop();
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => ref.read(preReaderAudioServiceProvider).stop(),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop narration'),
          ),
        ),
        const SizedBox(height: 16),
        const _NetworkDiagram(),
        const SizedBox(height: 16),
        _buildChoiceGroup(
          title: '1. Which connection is broken?',
          groupValue: _selectedLink,
          choices: const {
            'modem_router': 'Between the modem and the router',
            'router_laptop': 'Between the router and the laptop',
            'router_printer': 'Between the router and the printer',
          },
          onChanged: (value) => setState(() {
            _selectedLink = value;
            _showExplanation = false;
          }),
        ),
        _buildChoiceGroup(
          title: '2. What should you check first?',
          groupValue: _selectedRepair,
          choices: const {
            'reseat_cable':
                'Reconnect the Ethernet cable between router and laptop',
            'change_password': 'Change the Wi-Fi password',
            'replace_screen': 'Replace the laptop screen',
          },
          onChanged: (value) => setState(() {
            _selectedRepair = value;
            _showExplanation = false;
          }),
        ),
        _buildChoiceGroup(
          title: '3. Why is that the right first step?',
          groupValue: _selectedReason,
          choices: const {
            'link_carries_traffic':
                'The cable carries network traffic from the router to the laptop.',
            'screen_routes_traffic':
                'The laptop screen routes traffic between devices.',
            'password_repairs_cable':
                'Changing a password reconnects a physically loose cable.',
          },
          onChanged: (value) => setState(() {
            _selectedReason = value;
            _showExplanation = false;
          }),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _showHints = !_showHints);
              if (!_showHints) return;
              _readGuidance(
                'Hint: Follow the connection from the router to the '
                'laptop. A screen or password cannot repair a loose cable.',
              );
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_showHints ? 'Hide hint' : 'Get a hint'),
          ),
        ),
        if (_showHints)
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              'Follow the connection from the router to the laptop. '
              'A screen or password cannot repair a loose cable.',
            ),
          ),
        OutlinedButton(
          onPressed: _hasCompleteResponse
              ? () {
                  setState(() => _showExplanation = true);
                  _readGuidance(
                    'The Ethernet link between the router and laptop is '
                    'disconnected. Reseat the cable, then check whether '
                    'the laptop reconnects.',
                  );
                }
              : null,
          child: const Text('Review the scenario'),
        ),
        if (_showExplanation)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  'The router is online, but the Ethernet link to the laptop '
                  'is disconnected. Reseat that cable first. A password '
                  'change or screen replacement cannot restore a physical '
                  'network link.',
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('finish-network-simulation'),
          onPressed: _showExplanation
              ? () {
                  if (widget.session.complete()) {
                    widget.onFinished();
                  }
                }
              : null,
          child: const Text('Finish practice'),
        ),
      ],
    );
  }

  void _readGuidance(String text) {
    if (_speakGuidance) ref.read(preReaderAudioServiceProvider).speak(text);
  }

  Widget _buildChoiceGroup({
    required String title,
    required String? groupValue,
    required Map<String, String> choices,
    required ValueChanged<String?> onChanged,
  }) {
    // Each question is its own labelled radio group so assistive technology
    // announces which question a choice belongs to (WCAG 1.3.1).
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: title,
        child: RadioGroup<String>(
          groupValue: groupValue,
          onChanged: onChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final entry in choices.entries)
                RadioListTile<String>(
                  value: entry.key,
                  title: Text(entry.value),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkDiagram extends StatelessWidget {
  const _NetworkDiagram();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Network map', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The router is online. The laptop cannot connect. '
              'The router-to-laptop cable is loose.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const _NetworkNode(
                  label: 'Internet',
                  icon: Icons.cloud_outlined,
                ),
                const Icon(Icons.arrow_forward, semanticLabel: 'Connected'),
                const _NetworkNode(
                  label: 'Modem',
                  icon: Icons.settings_input_antenna,
                ),
                const Icon(Icons.arrow_forward, semanticLabel: 'Connected'),
                const _NetworkNode(
                  label: 'Router',
                  icon: Icons.router_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Router connections',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                _NetworkBranch(
                  device: 'Laptop',
                  connected: false,
                  errorColor: Theme.of(context).colorScheme.error,
                  primaryColor: Theme.of(context).colorScheme.primary,
                ),
                _NetworkBranch(
                  device: 'Printer',
                  connected: true,
                  errorColor: Theme.of(context).colorScheme.error,
                  primaryColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The router connects separately to the laptop and printer. '
              'Only the laptop link is disconnected.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkBranch extends StatelessWidget {
  final String device;
  final bool connected;
  final Color errorColor;
  final Color primaryColor;

  const _NetworkBranch({
    required this.device,
    required this.connected,
    required this.errorColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final icon = connected ? Icons.link : Icons.link_off;
    return Semantics(
      label:
          '$device connection from router: ${connected ? 'connected' : 'disconnected'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: connected ? primaryColor : errorColor,
            semanticLabel: connected ? 'Connected' : 'Disconnected',
          ),
          const SizedBox(width: 4),
          Text(device),
        ],
      ),
    );
  }
}

class _NetworkNode extends StatelessWidget {
  final String label;
  final IconData icon;

  const _NetworkNode({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label network device',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 32), Text(label)],
      ),
    );
  }
}
