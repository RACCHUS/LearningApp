import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:learning_pwa/services/safari_compatibility_service.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_manager.dart';

/// Safari-aware voice input widget that provides appropriate UI based on Safari capabilities
class SafariAwareVoiceInput extends StatefulWidget {
  final Function(String)? onVoiceResult;
  final Function(String)? onManualInput;
  final Function()? onStartListening;
  final Function()? onStopListening;
  final String? placeholder;
  final bool autoStart;
  final Duration? timeout;

  const SafariAwareVoiceInput({
    super.key,
    this.onVoiceResult,
    this.onManualInput,
    this.onStartListening,
    this.onStopListening,
    this.placeholder,
    this.autoStart = false,
    this.timeout,
  });

  @override
  State<SafariAwareVoiceInput> createState() => _SafariAwareVoiceInputState();
}

class _SafariAwareVoiceInputState extends State<SafariAwareVoiceInput> {
  final SpeechRecognitionManager _speechManager = SpeechRecognitionManager();
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _showManualInput = false;
  String? _errorMessage;
  String? _statusMessage;
  List<String> _compatibilityWarnings = [];

  @override
  void initState() {
    super.initState();
    _initializeSafariCapabilities();
  }

  /// Initialize Safari-specific capabilities and determine input mode
  Future<void> _initializeSafariCapabilities() async {
    try {
      if (SafariCompatibilityService.isSafari) {
        final optimizations = await SafariCompatibilityService.initializeSafariOptimizations();
        
        setState(() {
          _compatibilityWarnings = List<String>.from(optimizations['warnings'] ?? []);
          
          // Determine if we should show manual input based on Safari capabilities
          if (!SafariCompatibilityService.supportsSpeechRecognition) {
            _showManualInput = true;
            _statusMessage = 'Voice input not available in Safari ${SafariCompatibilityService.safariVersion}';
          } else if (!SafariCompatibilityService.hasReliableSpeechSupport) {
            _statusMessage = 'Voice input may be unreliable in this Safari version';
          }
        });

        if (kDebugMode) {
          print('🍎 Safari voice input initialized');
          print('🍎 Manual input mode: $_showManualInput');
          print('🍎 Warnings: ${_compatibilityWarnings.length}');
        }
      }

      // Initialize speech manager
      await _speechManager.initialize();

      if (widget.autoStart && !_showManualInput) {
        _startVoiceInput();
      }
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error initializing Safari voice input: $e');
      }
      setState(() {
        _errorMessage = 'Failed to initialize voice input: $e';
        _showManualInput = true;
      });
    }
  }

  /// Start voice input with Safari-specific handling
  Future<void> _startVoiceInput() async {
    if (_isListening) return;

    try {
      setState(() {
        _errorMessage = null;
        _statusMessage = 'Starting voice input...';
      });

      // Handle Safari-specific requirements
      if (SafariCompatibilityService.isSafari) {
        // Notify Safari provider that user gesture was received
        final currentProvider = _speechManager.currentProviderName;
        if (currentProvider?.contains('Safari') == true) {
          // This is a placeholder - in real implementation, we'd get the actual provider
          if (kDebugMode) {
            print('🍎 Notifying Safari provider of user gesture');
          }
        }
      }

      // Check permissions
      final hasPermissions = await _speechManager.hasPermissions();
      if (!hasPermissions) {
        final granted = await _speechManager.requestPermissions();
        if (!granted) {
          setState(() {
            _errorMessage = SafariCompatibilityService.isSafari 
                ? SafariCompatibilityService.getErrorMessage('permission_denied')
                : 'Microphone permission denied';
            _showManualInput = true;
          });
          return;
        }
      }

      // Start listening
      final started = await _speechManager.startListening(
        timeout: widget.timeout ?? const Duration(seconds: 10),
      );

      if (started) {
        setState(() {
          _isListening = true;
          _statusMessage = SafariCompatibilityService.isSafari 
              ? 'Listening... (Safari may timeout in 10 seconds)'
              : 'Listening...';
        });

        widget.onStartListening?.call();

        // Monitor for results
        _monitorSpeechResults();
      } else {
        setState(() {
          _errorMessage = _speechManager.errorMessage ?? 'Failed to start voice input';
          _showManualInput = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error starting voice input: $e');
      }
      setState(() {
        _errorMessage = SafariCompatibilityService.isSafari 
            ? SafariCompatibilityService.getErrorMessage('speech_not_supported')
            : 'Voice input error: $e';
        _showManualInput = true;
      });
    }
  }

  /// Monitor speech recognition results
  void _monitorSpeechResults() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }

      final result = _speechManager.lastRecognizedText;
      if (result != null && result.isNotEmpty) {
        timer.cancel();
        _handleVoiceResult(result);
      }

      // Check for errors
      final error = _speechManager.errorMessage;
      if (error != null) {
        timer.cancel();
        setState(() {
          _errorMessage = SafariCompatibilityService.isSafari 
              ? SafariCompatibilityService.getErrorMessage('timeout')
              : error;
          _isListening = false;
          _showManualInput = true;
        });
      }

      // Check if still listening
      if (!_speechManager.isListening) {
        timer.cancel();
        setState(() {
          _isListening = false;
          if (_speechManager.lastRecognizedText == null) {
            _statusMessage = 'No speech detected. Try manual input.';
            _showManualInput = true;
          }
        });
      }
    });
  }

  /// Handle voice recognition result
  void _handleVoiceResult(String result) {
    setState(() {
      _isListening = false;
      _statusMessage = 'Voice input: "$result"';
    });

    widget.onVoiceResult?.call(result);
    widget.onStopListening?.call();
  }

  /// Stop voice input
  Future<void> _stopVoiceInput() async {
    if (!_isListening) return;

    try {
      await _speechManager.stopListening();
      setState(() {
        _isListening = false;
        _statusMessage = 'Voice input stopped';
      });

      widget.onStopListening?.call();
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error stopping voice input: $e');
      }
    }
  }

  /// Handle manual text input
  void _handleManualInput() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _textController.clear();
      widget.onManualInput?.call(text);
    }
  }

  /// Toggle between voice and manual input modes
  void _toggleInputMode() {
    setState(() {
      _showManualInput = !_showManualInput;
      if (!_showManualInput && _isListening) {
        _stopVoiceInput();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Safari compatibility warnings
        if (_compatibilityWarnings.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Safari Compatibility',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._compatibilityWarnings.map((warning) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $warning',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Main input area
        if (_showManualInput) 
          _buildManualInputMode()
        else 
          _buildVoiceInputMode(),

        // Status messages
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Error messages
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],

        // Input mode toggle (if voice is available)
        if (SafariCompatibilityService.isSafari && 
            SafariCompatibilityService.supportsSpeechRecognition) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _toggleInputMode,
            icon: Icon(_showManualInput ? Icons.mic : Icons.keyboard),
            label: Text(_showManualInput ? 'Try Voice Input' : 'Use Text Input'),
          ),
        ],
      ],
    );
  }

  /// Build manual text input UI
  Widget _buildManualInputMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          SafariCompatibilityService.isSafari 
              ? 'Safari Text Input Mode'
              : 'Manual Text Input',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          SafariCompatibilityService.isSafari 
              ? 'Voice input is not available in this Safari version. Please type your command below:'
              : 'Please type your command below:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: widget.placeholder ?? 'Type your command here...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _handleManualInput,
                    icon: const Icon(Icons.send),
                  ),
                ),
                onSubmitted: (_) => _handleManualInput(),
              ),
            ),
          ],
        ),
        if (SafariCompatibilityService.isSafari) ...[
          const SizedBox(height: 8),
          Text(
            'Common commands: next, previous, repeat, A, B, C, D, true, false',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// Build voice input UI
  Widget _buildVoiceInputMode() {
    return Column(
      children: [
        Text(
          'Voice Input',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        
        // Microphone button
        GestureDetector(
          onTap: _isListening ? _stopVoiceInput : _startVoiceInput,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening 
                  ? Colors.red.shade400 
                  : Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: _isListening 
                      ? Colors.red.withOpacity(0.3)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: _isListening ? 4 : 2,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          _isListening 
              ? 'Listening... Tap to stop'
              : 'Tap microphone to start',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        // Safari-specific instructions
        if (SafariCompatibilityService.isSafari) ...[
          const SizedBox(height: 8),
          Text(
            'Safari will ask for microphone permission on first use',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _speechManager.dispose();
    super.dispose();
  }
}
