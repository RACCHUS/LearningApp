/// Abstract base class for speech recognition providers
/// Allows different implementations for different browsers and platforms
abstract class SpeechRecognitionProvider {
  /// Check if this provider is supported on the current platform
  Future<bool> isSupported();
  
  /// Request microphone permissions
  Future<bool> requestPermissions();
  
  /// Check if permissions are granted
  Future<bool> hasPermissions();
  
  /// Start listening for speech input
  Future<bool> startListening({
    Duration? timeout,
    String? language,
    bool continuous = false,
  });
  
  /// Stop listening for speech input
  Future<void> stopListening();
  
  /// Cancel current listening session
  Future<void> cancel();
  
  /// Get the last recognized text
  String? get lastRecognizedText;
  
  /// Get confidence score for last recognition (0.0 - 1.0)
  double get confidence;
  
  /// Get current listening state
  bool get isListening;
  
  /// Get any error message from last operation
  String? get errorMessage;
  
  /// Get provider-specific information
  String get providerName;
  
  /// Get provider capabilities
  Map<String, dynamic> get capabilities;
  
  /// Dispose of any resources
  void dispose();
}

/// Provider priority levels for fallback hierarchy
enum ProviderPriority { primary, secondary, fallback, emergency }

/// Provider information for the speech recognition system
class ProviderInfo {
  final String name;
  final ProviderPriority priority;
  final Map<String, dynamic> capabilities;
  final String description;
  
  const ProviderInfo({
    required this.name,
    required this.priority,
    required this.capabilities,
    required this.description,
  });
}
