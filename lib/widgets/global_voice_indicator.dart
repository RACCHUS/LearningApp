import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

/// Widget that displays global voice status and provides controls
class GlobalVoiceIndicator extends ConsumerWidget {
  final bool showToggle;
  final bool compact;
  
  const GlobalVoiceIndicator({
    super.key,
    this.showToggle = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVoiceState = ref.watch(globalVoiceProvider);
    final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);

    if (!globalVoiceState.isAvailable) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactIndicator(context, globalVoiceState, globalVoiceNotifier);
    }

    return _buildFullIndicator(context, globalVoiceState, globalVoiceNotifier);
  }

  Widget _buildCompactIndicator(
    BuildContext context, 
    GlobalVoiceState state, 
    GlobalVoiceNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: state.isEnabled 
            ? (state.isListening ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1))
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isEnabled 
              ? (state.isListening ? Colors.red : Colors.green)
              : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.isListening 
                ? Icons.mic 
                : (state.isEnabled ? Icons.mic_none : Icons.mic_off),
            size: 16,
            color: state.isEnabled 
                ? (state.isListening ? Colors.red : Colors.green)
                : Colors.grey,
          ),
          if (showToggle) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => notifier.toggle(),
              child: Text(
                state.isEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: state.isEnabled ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullIndicator(
    BuildContext context, 
    GlobalVoiceState state, 
    GlobalVoiceNotifier notifier,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  state.isListening 
                      ? Icons.mic 
                      : (state.isEnabled ? Icons.mic_none : Icons.mic_off),
                  color: state.isEnabled 
                      ? (state.isListening ? Colors.red : Colors.green)
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Global Voice Commands',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (showToggle)
                  Switch(
                    value: state.isEnabled,
                    onChanged: (enabled) => enabled ? notifier.enable() : notifier.disable(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: state.isListening ? Colors.red : null,
              ),
            ),
            if (state.lastCommand != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last command: ${state.lastCommand!.phrase}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showVoiceHelp(context, notifier),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Voice Help'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showContextHelp(context, notifier),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Context Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceHelp(BuildContext context, GlobalVoiceNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Global Voice Commands'),
        content: SingleChildScrollView(
          child: Text(GlobalVoiceCommand.getGlobalCommandsHelp()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContextHelp(BuildContext context, GlobalVoiceNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Context-Specific Commands'),
        content: SingleChildScrollView(
          child: Text(notifier.getContextualHelp()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A floating action button for global voice control
class GlobalVoiceFAB extends ConsumerWidget {
  final String? heroTag;
  
  const GlobalVoiceFAB({super.key, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVoiceState = ref.watch(globalVoiceProvider);
    final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);

    if (!globalVoiceState.isAvailable) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      heroTag: heroTag ?? "globalVoiceFAB", // Provide unique hero tag
      onPressed: () => globalVoiceNotifier.toggle(),
      backgroundColor: globalVoiceState.isEnabled 
          ? (globalVoiceState.isListening ? Colors.red : Colors.green)
          : Colors.grey,
      child: Icon(
        globalVoiceState.isListening 
            ? Icons.mic 
            : (globalVoiceState.isEnabled ? Icons.mic_none : Icons.mic_off),
        color: Colors.white,
      ),
    );
  }
}

/// App bar widget with global voice indicator
class AppBarWithGlobalVoice extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AppBarWithGlobalVoice({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVoiceState = ref.watch(globalVoiceProvider);

    final allActions = <Widget>[
      if (globalVoiceState.isAvailable)
        const GlobalVoiceIndicator(compact: true),
      ...?actions,
    ];

    return AppBar(
      title: Text(title),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: allActions.isNotEmpty ? allActions : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
