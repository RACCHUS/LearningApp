import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/safari_compatibility_service.dart';
import 'package:learning_pwa/services/safari_audio_service.dart';
import 'package:learning_pwa/widgets/safari_permission_dialog.dart';
import 'package:learning_pwa/widgets/safari_aware_voice_input.dart';

/// Comprehensive Safari support widget that integrates all Safari-specific features
class SafariSupportWidget extends StatefulWidget {
  final Widget child;
  final bool showCompatibilityInfo;
  final bool enableVoiceInput;
  final Function(String)? onVoiceCommand;

  const SafariSupportWidget({
    super.key,
    required this.child,
    this.showCompatibilityInfo = true,
    this.enableVoiceInput = true,
    this.onVoiceCommand,
  });

  @override
  State<SafariSupportWidget> createState() => _SafariSupportWidgetState();
}

class _SafariSupportWidgetState extends State<SafariSupportWidget> {
  final SafariAudioService _audioService = SafariAudioService();
  bool _safariInitialized = false;
  bool _showVoiceInput = false;
  Map<String, dynamic>? _safariInfo;

  @override
  void initState() {
    super.initState();
    _initializeSafariSupport();
  }

  Future<void> _initializeSafariSupport() async {
    try {
      // Initialize Safari-specific services
      if (SafariCompatibilityService.isSafari) {
        _safariInfo = await SafariCompatibilityService.initializeSafariOptimizations();
        await _audioService.initialize();
        
        setState(() {
          _safariInitialized = true;
          _showVoiceInput = widget.enableVoiceInput && 
                           SafariCompatibilityService.supportsSpeechRecognition;
        });

        if (kDebugMode) {
          print('🍎 Safari support widget initialized');
          print('🍎 Voice input enabled: $_showVoiceInput');
        }
      } else {
        setState(() {
          _safariInitialized = true;
          _showVoiceInput = widget.enableVoiceInput;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error initializing Safari support: $e');
      }
      setState(() {
        _safariInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_safariInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // Safari compatibility info banner
        if (widget.showCompatibilityInfo && SafariCompatibilityService.isSafari)
          _buildSafariCompatibilityBanner(),

        // Main content
        Expanded(child: widget.child),

        // Safari-aware voice input
        if (_showVoiceInput)
          _buildVoiceInputSection(),
      ],
    );
  }

  Widget _buildSafariCompatibilityBanner() {
    final warnings = SafariCompatibilityService.compatibilityWarnings;
    
    if (warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.laptop_mac,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Safari ${SafariCompatibilityService.safariVersion} Detected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                onPressed: _showSafariInfoDialog,
              ),
            ],
          ),
          
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              warnings.first,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
              ),
            ),
            if (warnings.length > 1)
              Text(
                '${warnings.length - 1} more compatibility notes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SafariAwareVoiceInput(
        onVoiceResult: (result) {
          widget.onVoiceCommand?.call(result);
        },
        onManualInput: (input) {
          widget.onVoiceCommand?.call(input);
        },
        onStartListening: () async {
          // Initialize audio context for Safari when user starts voice input
          if (SafariCompatibilityService.isSafari) {
            await _audioService.initializeAudioContextWithGesture();
          }
        },
        placeholder: 'Enter voice command or type manually...',
      ),
    );
  }

  void _showSafariInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => _SafariInfoDialog(safariInfo: _safariInfo),
    );
  }
}

/// Detailed Safari information dialog
class _SafariInfoDialog extends StatelessWidget {
  final Map<String, dynamic>? safariInfo;

  const _SafariInfoDialog({this.safariInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.laptop_mac,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Safari Compatibility'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Safari version info
            _buildInfoSection(
              'Browser Information',
              {
                'Version': SafariCompatibilityService.safariVersion,
                'Platform': SafariCompatibilityService.isSafariMobile ? 'Mobile' : 'Desktop',
                'Private Browsing': SafariCompatibilityService.isPrivateBrowsing ? 'Yes' : 'No',
              },
            ),
            
            const SizedBox(height: 16),
            
            // Feature support
            _buildInfoSection(
              'Feature Support',
              {
                'Voice Recognition': SafariCompatibilityService.supportsSpeechRecognition ? 'Supported' : 'Not Supported',
                'Reliable Speech': SafariCompatibilityService.hasReliableSpeechSupport ? 'Yes' : 'Limited',
                'PWA Installation': SafariCompatibilityService.supportsPWAInstallation ? 'Supported' : 'Not Available',
                'Service Workers': SafariCompatibilityService.supportsServiceWorkers ? 'Supported' : 'Limited',
              },
            ),
            
            const SizedBox(height: 16),
            
            // Compatibility warnings
            if (SafariCompatibilityService.compatibilityWarnings.isNotEmpty) ...[
              Text(
                'Compatibility Notes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...SafariCompatibilityService.compatibilityWarnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
            
            // Setup instructions
            Text(
              'Setup Instructions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...SafariCompatibilityService.permissionInstructions.map(
              (instruction) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  instruction,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, Map<String, String> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...info.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Safari-specific floating action button with voice input
class SafariVoiceFab extends StatefulWidget {
  final VoidCallback? onPressed;
  final Function(String)? onVoiceResult;

  const SafariVoiceFab({
    super.key,
    this.onPressed,
    this.onVoiceResult,
  });

  @override
  State<SafariVoiceFab> createState() => _SafariVoiceFabState();
}

class _SafariVoiceFabState extends State<SafariVoiceFab> {
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    if (!SafariCompatibilityService.isSafari) {
      return FloatingActionButton(
        onPressed: widget.onPressed,
        child: const Icon(Icons.mic),
      );
    }

    return FloatingActionButton.extended(
      onPressed: SafariCompatibilityService.supportsSpeechRecognition
          ? _handleVoiceInput
          : _showManualInputDialog,
      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(_isListening ? 'Listening...' : 'Voice'),
      backgroundColor: _isListening 
          ? Colors.red.shade400 
          : Theme.of(context).colorScheme.primary,
    );
  }

  void _handleVoiceInput() async {
    if (_isListening) return;

    try {
      setState(() {
        _isListening = true;
      });

      // Show Safari permission dialog if needed
      await showSafariPermissionDialog(
        context,
        onPermissionGranted: () {
          // Start voice recognition
          widget.onPressed?.call();
        },
        onPermissionDenied: () {
          setState(() {
            _isListening = false;
          });
        },
        onFallbackToManual: () {
          setState(() {
            _isListening = false;
          });
          _showManualInputDialog();
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voice input is not available. Please type your command:'),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type your command...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) {
                Navigator.of(context).pop();
                widget.onVoiceResult?.call(text);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
