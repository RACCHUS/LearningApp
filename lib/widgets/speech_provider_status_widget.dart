import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';

/// Widget that displays current speech provider status and provides manual input when needed
class SpeechProviderStatusWidget extends ConsumerStatefulWidget {
  final Function(String)? onManualInput;
  final bool showManualInput;
  
  const SpeechProviderStatusWidget({
    super.key,
    this.onManualInput,
    this.showManualInput = false,
  });

  @override
  ConsumerState<SpeechProviderStatusWidget> createState() => _SpeechProviderStatusWidgetState();
}

class _SpeechProviderStatusWidgetState extends ConsumerState<SpeechProviderStatusWidget> {
  final TextEditingController _manualInputController = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioNotifier = ref.watch(audioPlaybackProvider.notifier);
    final audioState = ref.watch(audioPlaybackProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Provider status
            _buildProviderStatus(audioNotifier),
            
            const SizedBox(height: 8),
            
            // Setup instructions if needed
            if (!audioState.hasPermissions || !audioNotifier.canListen)
              _buildSetupInstructions(audioNotifier),
            
            // Manual input section
            if (widget.showManualInput || audioNotifier.isManualInputMode)
              _buildManualInputSection(audioNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderStatus(AudioPlaybackNotifier audioNotifier) {
    final isManualMode = audioNotifier.isManualInputMode;
    final canListen = audioNotifier.canListen;
    
    IconData statusIcon;
    Color statusColor;
    String statusText;
    
    if (isManualMode) {
      statusIcon = Icons.keyboard;
      statusColor = Colors.blue;
      statusText = 'Manual Input Mode';
    } else if (canListen) {
      statusIcon = Icons.mic;
      statusColor = Colors.green;
      statusText = 'Voice Commands Ready';
    } else {
      statusIcon = Icons.mic_off;
      statusColor = Colors.orange;
      statusText = 'Voice Setup Needed';
    }
    
    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ),
        if (!isManualMode && !canListen)
          TextButton(
            onPressed: () => _requestPermissions(audioNotifier),
            child: const Text('Setup'),
          ),
      ],
    );
  }

  Widget _buildSetupInstructions(AudioPlaybackNotifier audioNotifier) {
    final instructions = audioNotifier.getSetupInstructions();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Setup Instructions:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...instructions.map((instruction) => Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              '• $instruction',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildManualInputSection(AudioPlaybackNotifier audioNotifier) {
    if (!_showInput && !audioNotifier.isManualInputMode) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          onPressed: () => setState(() => _showInput = true),
          icon: const Icon(Icons.keyboard, size: 16),
          label: const Text('Use Manual Input'),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            audioNotifier.isManualInputMode
                ? 'Manual Input (Voice not available)'
                : 'Manual Input Alternative',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          
          // Command mappings
          if (audioNotifier.isManualInputMode)
            _buildCommandMappings(audioNotifier),
          
          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  decoration: const InputDecoration(
                    hintText: 'Type command or answer...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    isDense: true,
                  ),
                  onSubmitted: _submitManualInput,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _submitManualInput(_manualInputController.text),
                child: const Text('Submit'),
              ),
            ],
          ),
          
          if (!audioNotifier.isManualInputMode)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => setState(() => _showInput = false),
                child: const Text('Hide Manual Input'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandMappings(AudioPlaybackNotifier audioNotifier) {
    final mappings = audioNotifier.getCommandMappings();
    
    if (mappings.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Commands:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: mappings.entries.map((entry) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 10),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  void _submitManualInput(String input) {
    if (input.trim().isEmpty) return;
    
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    
    // Submit to the speech manager
    audioNotifier.submitManualInput(input.trim());
    
    // Call the callback if provided
    widget.onManualInput?.call(input.trim());
    
    // Clear the input
    _manualInputController.clear();
    
    // Hide manual input if not in manual mode
    if (!audioNotifier.isManualInputMode) {
      setState(() => _showInput = false);
    }
  }

  void _requestPermissions(AudioPlaybackNotifier audioNotifier) async {
    try {
      final granted = await audioNotifier.requestMicrophonePermissions();
      
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission required for voice commands'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _requestPermissions(audioNotifier),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission request failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
