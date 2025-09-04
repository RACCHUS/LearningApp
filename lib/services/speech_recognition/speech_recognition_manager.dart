import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/browser_compatibility_service.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';
import 'package:learning_pwa/services/speech_recognition/native_web_speech_provider.dart';
import 'package:learning_pwa/services/speech_recognition/manual_input_provider.dart';

/// Speech recognition status
enum SpeechRecognitionStatus {
  initialized,
  listening,
  stopped,
  error,
  unavailable
}

/// Simple speech recognition manager
/// Manages speech recognition providers with fallback support
class SpeechRecognitionManager {
  static final SpeechRecognitionManager _instance = SpeechRecognitionManager._internal();
  factory SpeechRecognitionManager() => _instance;
  SpeechRecognitionManager._internal();

  SpeechRecognitionProvider? _currentProvider;
  List<SpeechRecognitionProvider> _availableProviders = [];
  bool _isInitialized = false;
  List<String> _statusLog = [];
  
  // Event controllers
  final StreamController<ProviderInfo> _providerChangesController = StreamController<ProviderInfo>.broadcast();

  // Public streams
  Stream<ProviderInfo> get providerChanges => _providerChangesController.stream;

  /// Initialize the speech recognition manager
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Log browser compatibility information
      BrowserCompatibilityService.logCompatibilityInfo();
      
      // Initialize providers
      await _initializeProviders();
      
      // Select the best available provider
      _selectBestProvider();
      
      _isInitialized = true;
      _logStatus('Speech recognition manager initialized successfully');
      
      return _availableProviders.isNotEmpty;
    } catch (e) {
      _logError('Failed to initialize speech recognition manager: $e');
      return false;
    }
  }

  /// Initialize all available providers
  Future<void> _initializeProviders() async {
    _availableProviders.clear();
    
    // Get browser compatibility info
    final browserInfo = await BrowserCompatibilityService.getBrowserInfo();
    
    // Add providers based on browser capabilities
    if (browserInfo.speechSupport == SpeechApiSupport.native) {
      _availableProviders.add(NativeWebSpeechProvider());
    }
    
    // Always add manual input as fallback
    _availableProviders.add(ManualInputProvider());
    
    _logStatus('Initialized ${_availableProviders.length} providers');
  }

  /// Select the best available provider
  void _selectBestProvider() {
    if (_availableProviders.isEmpty) {
      throw Exception('No speech recognition providers available');
    }
    
    // Select first available provider (prioritized order)
    _currentProvider = _availableProviders.first;
    _logStatus('Selected provider: ${_currentProvider!.providerName}');
    
    // Emit provider change event
    if (currentProviderInfo != null) {
      _providerChangesController.add(currentProviderInfo!);
    }
  }

  /// Start listening for speech
  Future<bool> startListening({
    String? language,
    Duration? timeout,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_currentProvider == null) {
      _logError('No speech recognition provider available');
      return false;
    }
    
    try {
      final success = await _currentProvider!.startListening(
        language: language,
        timeout: timeout,
      );
      
      if (success) {
        _logStatus('Started listening with ${_currentProvider!.providerName}');
      } else {
        _logError('Failed to start listening');
      }
      
      return success;
    } catch (e) {
      _logError('Error starting speech recognition: $e');
      return false;
    }
  }

  /// Stop listening for speech
  Future<bool> stopListening() async {
    if (_currentProvider == null) {
      return true;
    }
    
    try {
      await _currentProvider!.stopListening();
      _logStatus('Stopped listening');
      return true;
    } catch (e) {
      _logError('Error stopping speech recognition: $e');
      return false;
    }
  }

  /// Cancel current listening session
  Future<bool> cancel() async {
    if (_currentProvider == null) {
      return true;
    }
    
    try {
      await _currentProvider!.cancel();
      _logStatus('Cancelled listening');
      return true;
    } catch (e) {
      _logError('Error cancelling speech recognition: $e');
      return false;
    }
  }

  /// Check if currently listening
  bool get isListening => _currentProvider?.isListening ?? false;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get current provider name
  String? get currentProviderName => _currentProvider?.providerName;

  /// Get all available provider names
  List<String> get availableProviderNames => 
      _availableProviders.map((p) => p.providerName).toList();

  /// Get provider capabilities
  Map<String, dynamic> get providerCapabilities {
    if (_currentProvider == null) return {};
    return _currentProvider!.capabilities;
  }

  /// Get current status
  SpeechRecognitionStatus get currentStatus {
    if (_currentProvider == null) return SpeechRecognitionStatus.unavailable;
    if (_currentProvider!.isListening) return SpeechRecognitionStatus.listening;
    if (_currentProvider!.errorMessage != null) return SpeechRecognitionStatus.error;
    return SpeechRecognitionStatus.initialized;
  }

  /// Get last recognized text
  String? get lastRecognizedText => _currentProvider?.lastRecognizedText;

  /// Get confidence
  double get confidence => _currentProvider?.confidence ?? 0.0;

  /// Get error message
  String? get errorMessage => _currentProvider?.errorMessage;

  /// Get current provider info
  ProviderInfo? get currentProviderInfo {
    if (_currentProvider == null) return null;
    return ProviderInfo(
      name: _currentProvider!.providerName,
      priority: ProviderPriority.primary, // Default priority
      capabilities: _currentProvider!.capabilities,
      description: 'Current speech recognition provider',
    );
  }

  /// Get provider capabilities as Map<String, dynamic>
  Map<String, dynamic> get capabilities {
    if (_currentProvider == null) return {};
    return _currentProvider!.capabilities;
  }

  /// Get provider capability names as List<String>
  List<String> get capabilityNames {
    if (_currentProvider == null) return [];
    return _currentProvider!.capabilities.keys.toList();
  }

  /// Get status log
  List<String> get statusLog => _statusLog;

  /// Check if has permissions
  Future<bool> hasPermissions() async {
    if (_currentProvider == null) return false;
    return await _currentProvider!.hasPermissions();
  }

  /// Request permissions
  Future<bool> requestPermissions() async {
    if (_currentProvider == null) return false;
    
    try {
      final result = await _currentProvider!.requestPermissions();
      
      if (kDebugMode) {
        print('🎙️ SpeechManager: Permission request result from ${_currentProvider!.providerName}: $result');
      }
      
      // If native provider fails, try falling back to manual provider
      if (!result && _currentProvider is NativeWebSpeechProvider) {
        if (kDebugMode) {
          print('🎙️ SpeechManager: Native provider permission failed, attempting fallback to manual provider');
        }
        
        // Switch to manual provider
        final manualProvider = _availableProviders.firstWhere(
          (provider) => provider is ManualInputProvider,
          orElse: () => ManualInputProvider(),
        );
        
        if (await manualProvider.isSupported()) {
          _currentProvider = manualProvider;
          
          // Notify of provider change
          final providerInfo = ProviderInfo(
            name: _currentProvider!.providerName,
            priority: ProviderPriority.fallback,
            capabilities: _currentProvider!.capabilities,
            description: 'Fallback to manual input due to permission failure',
          );
          _providerChangesController.add(providerInfo);
          
          if (kDebugMode) {
            print('🎙️ SpeechManager: Switched to manual provider');
          }
          
          return true; // Manual provider doesn't need microphone permissions
        }
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ SpeechManager: Permission request error: $e');
      }
      return false;
    }
  }

  /// Submit manual input (for manual provider)
  void submitManualInput(String input) {
    if (_currentProvider is ManualInputProvider) {
      // Handle manual input - for now just log it
      _logStatus('Manual input: $input');
    }
  }

  /// Wait for manual input (for manual provider)
  Future<String?> waitForManualInput() async {
    if (_currentProvider is ManualInputProvider) {
      // Simulate waiting for manual input
      await Future.delayed(const Duration(milliseconds: 100));
      return _currentProvider!.lastRecognizedText;
    }
    return null;
  }

  /// Get command mappings
  Map<String, String> getCommandMappings() {
    // Return basic command mappings
    return {
      'next': 'Navigate to next item',
      'previous': 'Navigate to previous item',
      'repeat': 'Repeat current content',
      'pause': 'Pause playback',
      'play': 'Start playback',
    };
  }

  /// Fallback to next provider
  Future<bool> fallbackToNextProvider() async {
    if (_availableProviders.length <= 1) return false;
    
    final currentIndex = _availableProviders.indexOf(_currentProvider!);
    if (currentIndex < _availableProviders.length - 1) {
      _currentProvider = _availableProviders[currentIndex + 1];
      _logStatus('Switched to fallback provider: ${_currentProvider!.providerName}');
      
      // Emit provider change event
      if (currentProviderInfo != null) {
        _providerChangesController.add(currentProviderInfo!);
      }
      
      return true;
    }
    return false;
  }

  /// Switch to manual input mode
  Future<bool> switchToManualMode() async {
    final manualProvider = _availableProviders
        .whereType<ManualInputProvider>()
        .firstOrNull;
    
    if (manualProvider != null) {
      if (_currentProvider?.isListening == true) {
        await stopListening();
      }
      
      _currentProvider = manualProvider;
      _logStatus('Switched to manual input mode');
      return true;
    }
    
    return false;
  }

  /// Switch to voice input mode (if available)
  Future<bool> switchToVoiceMode() async {
    final voiceProvider = _availableProviders
        .where((p) => p is! ManualInputProvider)
        .firstOrNull;
    
    if (voiceProvider != null) {
      if (_currentProvider?.isListening == true) {
        await stopListening();
      }
      
      _currentProvider = voiceProvider;
      _logStatus('Switched to voice input mode');
      return true;
    }
    
    return false;
  }

  /// Get diagnostic information
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isInitialized': _isInitialized,
      'isListening': isListening,
      'currentProvider': _currentProvider?.providerName,
      'availableProviders': availableProviderNames,
      'providerCapabilities': providerCapabilities,
      'currentStatus': currentStatus.name,
      'lastRecognizedText': lastRecognizedText,
      'confidence': confidence,
      'errorMessage': errorMessage,
    };
  }

  /// Get setup instructions for current provider
  List<String> getSetupInstructions() {
    if (_currentProvider is ManualInputProvider) {
      return ['Type your commands using the text input field', 'Available commands: next, previous, repeat, pause, play'];
    }
    
    // Get browser-specific instructions
    return BrowserCompatibilityService.getSetupInstructions();
  }

  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
    
    // Dispose providers
    for (final provider in _availableProviders) {
      provider.dispose();
    }
    _availableProviders.clear();
    _currentProvider = null;
    
    // Close streams
    _providerChangesController.close();
    
    _logStatus('Speech recognition manager disposed');
  }

  /// Log status messages
  void _logStatus(String message) {
    _statusLog.add(message);
    if (_statusLog.length > 50) {
      _statusLog.removeAt(0); // Keep only last 50 entries
    }
    
    if (kDebugMode) {
      print('🎙️ SpeechManager: $message');
    }
  }

  /// Log error messages
  void _logError(String message) {
    if (kDebugMode) {
      print('❌ SpeechManager: $message');
    }
  }
}

/// Extension to add firstOrNull to Iterable
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
