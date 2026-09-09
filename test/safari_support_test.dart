import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/safari_compatibility_service.dart';
import 'package:learning_pwa/services/safari_audio_service.dart';
import 'package:learning_pwa/services/speech_recognition/safari_speech_provider.dart';

void main() {
  group('Safari Compatibility Service Tests', () {
    test('should detect Safari browser correctly', () {
      // Note: These tests would need to be run in different browser environments
      // to properly test browser detection
      expect(SafariCompatibilityService.isSafari, isA<bool>());
      expect(SafariCompatibilityService.safariVersion, isA<String>());
      expect(SafariCompatibilityService.isSafariMobile, isA<bool>());
      expect(SafariCompatibilityService.isSafariDesktop, isA<bool>());
    });

    test('should provide speech recognition support info', () {
      final supportsRecognition = SafariCompatibilityService.supportsSpeechRecognition;
      final hasReliableSupport = SafariCompatibilityService.hasReliableSpeechSupport;
      
      expect(supportsRecognition, isA<bool>());
      expect(hasReliableSupport, isA<bool>());
      
      // If has reliable support, should also support recognition
      if (hasReliableSupport) {
        expect(supportsRecognition, isTrue);
      }
    });

    test('should provide compatibility warnings', () {
      final warnings = SafariCompatibilityService.compatibilityWarnings;
      expect(warnings, isA<List<String>>());
    });

    test('should provide permission instructions', () {
      final instructions = SafariCompatibilityService.permissionInstructions;
      expect(instructions, isA<List<String>>());
      expect(instructions.isNotEmpty, isTrue);
    });

    test('should provide fallback options', () {
      final fallbacks = SafariCompatibilityService.fallbackOptions;
      expect(fallbacks, isA<Map<String, String>>());
      expect(fallbacks.containsKey('voiceInput'), isTrue);
    });

    test('should provide Safari-specific speech config', () {
      final config = SafariCompatibilityService.safariSpeechConfig;
      expect(config, isA<Map<String, dynamic>>());
      expect(config.containsKey('continuous'), isTrue);
      expect(config.containsKey('interimResults'), isTrue);
      expect(config.containsKey('requiresUserGesture'), isTrue);
    });

    test('should detect private browsing mode', () {
      final isPrivate = SafariCompatibilityService.isPrivateBrowsing;
      expect(isPrivate, isA<bool>());
    });

    test('should support feature detection', () {
      expect(SafariCompatibilityService.supportsFeature('speechrecognition'), isA<bool>());
      expect(SafariCompatibilityService.supportsFeature('tts'), isA<bool>());
      expect(SafariCompatibilityService.supportsFeature('pwa'), isA<bool>());
      expect(SafariCompatibilityService.supportsFeature('serviceworker'), isA<bool>());
      expect(SafariCompatibilityService.supportsFeature('invalid_feature'), isFalse);
    });

    test('should provide appropriate error messages', () {
      final permissionError = SafariCompatibilityService.getErrorMessage('permission_denied');
      final speechError = SafariCompatibilityService.getErrorMessage('speech_not_supported');
      final timeoutError = SafariCompatibilityService.getErrorMessage('timeout');
      
      expect(permissionError.isNotEmpty, isTrue);
      expect(speechError.isNotEmpty, isTrue);
      expect(timeoutError.isNotEmpty, isTrue);
      
      expect(permissionError.toLowerCase().contains('safari') || permissionError.toLowerCase().contains('microphone'), isTrue);
      expect(speechError.toLowerCase().contains('voice') || speechError.toLowerCase().contains('speech'), isTrue);
    });

    test('should initialize Safari optimizations', () async {
      final results = await SafariCompatibilityService.initializeSafariOptimizations();
      
      expect(results, isA<Map<String, dynamic>>());
      expect(results.containsKey('isSafari'), isTrue);
      expect(results.containsKey('safariVersion'), isTrue);
      expect(results.containsKey('supportsSpeech'), isTrue);
      expect(results.containsKey('warnings'), isTrue);
      expect(results.containsKey('fallbacks'), isTrue);
    });

    test('should test speech capabilities', () async {
      final testResults = await SafariCompatibilityService.testSpeechCapabilities();
      
      expect(testResults, isA<Map<String, dynamic>>());
      expect(testResults.containsKey('supported'), isTrue);
      expect(testResults.containsKey('available'), isTrue);
      expect(testResults.containsKey('error'), isTrue);
    });
  });

  group('Safari Audio Service Tests', () {
    late SafariAudioService audioService;

    setUp(() {
      audioService = SafariAudioService();
    });

    test('should initialize audio service', () async {
      final initialized = await audioService.initialize();
      expect(initialized, isA<bool>());
      expect(audioService.isInitialized, isTrue);
    });

    test('should handle audio context initialization', () async {
      await audioService.initialize();
      
      final contextReady = await audioService.initializeAudioContextWithGesture();
      expect(contextReady, isA<bool>());
      
      if (SafariCompatibilityService.isSafari) {
        expect(audioService.userGestureReceived, isTrue);
      }
    });

    test('should provide audio capabilities', () async {
      await audioService.initialize();
      
      final capabilities = audioService.audioCapabilities;
      expect(capabilities, isA<Map<String, bool>>());
      expect(capabilities.containsKey('speechSynthesis'), isTrue);
      expect(capabilities.containsKey('audioContext'), isTrue);
      expect(capabilities.containsKey('userGestureRequired'), isTrue);
    });

    test('should provide audio recommendations', () async {
      await audioService.initialize();
      
      final recommendations = audioService.audioRecommendations;
      expect(recommendations, isA<Map<String, dynamic>>());
      expect(recommendations.containsKey('userGestureRequired'), isTrue);
      expect(recommendations.containsKey('recommendations'), isTrue);
    });

    test('should handle speech synthesis', () async {
      await audioService.initialize();
      
      final speechResult = await audioService.speak('Test speech');
      expect(speechResult, isA<bool>());
    });

    test('should provide diagnostic information', () async {
      await audioService.initialize();
      
      final diagnostics = audioService.getDiagnosticInfo();
      expect(diagnostics, isA<Map<String, dynamic>>());
      expect(diagnostics.containsKey('isInitialized'), isTrue);
      expect(diagnostics.containsKey('audioContextReady'), isTrue);
      expect(diagnostics.containsKey('capabilities'), isTrue);
    });

    test('should reset and dispose properly', () async {
      await audioService.initialize();
      
      audioService.reset();
      expect(audioService.audioContextReady, isFalse);
      expect(audioService.userGestureReceived, isFalse);
      
      audioService.dispose();
      expect(audioService.isInitialized, isFalse);
    });
  });

  group('Safari Speech Provider Tests', () {
    late SafariSpeechProvider speechProvider;

    setUp(() {
      speechProvider = SafariSpeechProvider();
    });

    tearDown(() {
      speechProvider.dispose();
    });

    test('should have correct provider name and capabilities', () {
      expect(speechProvider.providerName, equals('Safari Web Speech API'));
      
      final capabilities = speechProvider.capabilities;
      expect(capabilities, isA<Map<String, dynamic>>());
      expect(capabilities['continuous'], isFalse); // Safari doesn't handle continuous well
      expect(capabilities['interimResults'], isFalse); // Safari has issues with interim results
      expect(capabilities['requiresUserGesture'], isTrue);
      expect(capabilities['isSafariOptimized'], isTrue);
    });

    test('should check support correctly', () async {
      final isSupported = await speechProvider.isSupported();
      expect(isSupported, isA<bool>());
      
      // If we're in Safari and it supports speech recognition, should be supported
      if (SafariCompatibilityService.isSafari && 
          SafariCompatibilityService.supportsSpeechRecognition) {
        expect(isSupported, isTrue);
      }
    });

    test('should handle permissions correctly', () async {
      final hasPermissions = await speechProvider.hasPermissions();
      expect(hasPermissions, isA<bool>());
      
      // Set user gesture to test permission request
      speechProvider.setUserGestureReceived();
      
      final permissionGranted = await speechProvider.requestPermissions();
      expect(permissionGranted, isA<bool>());
    });

    test('should handle listening state correctly', () async {
      expect(speechProvider.isListening, isFalse);
      
      // Set user gesture and try to start listening
      speechProvider.setUserGestureReceived();
      
      final started = await speechProvider.startListening();
      expect(started, isA<bool>());
      
      if (started) {
        expect(speechProvider.isListening, isTrue);
        
        await speechProvider.stopListening();
        expect(speechProvider.isListening, isFalse);
      }
    });

    test('should provide setup instructions and warnings', () {
      final instructions = speechProvider.getSetupInstructions();
      expect(instructions, isA<List<String>>());
      expect(instructions.isNotEmpty, isTrue);
      
      final warnings = speechProvider.getCompatibilityWarnings();
      expect(warnings, isA<List<String>>());
      
      final fallbacks = speechProvider.getFallbackOptions();
      expect(fallbacks, isA<Map<String, String>>());
    });

    test('should handle cancellation correctly', () async {
      speechProvider.setUserGestureReceived();
      await speechProvider.startListening();
      
      await speechProvider.cancel();
      expect(speechProvider.isListening, isFalse);
      expect(speechProvider.lastRecognizedText, isNull);
      expect(speechProvider.confidence, equals(0.0));
    });

    test('should handle user gesture requirement', () {
      expect(speechProvider.userGestureReceived, isFalse);
      
      speechProvider.setUserGestureReceived();
      expect(speechProvider.userGestureReceived, isTrue);
    });
  });

  group('Safari Integration Tests', () {
    test('should work together properly', () async {
      // Test that Safari services work together
      final safariInfo = await SafariCompatibilityService.initializeSafariOptimizations();
      final audioService = SafariAudioService();
      final speechProvider = SafariSpeechProvider();
      
      // Initialize services
      await audioService.initialize();
      final speechSupported = await speechProvider.isSupported();
      
      // Verify consistent state
      expect(safariInfo['isSafari'], equals(SafariCompatibilityService.isSafari));
      expect(safariInfo['supportsSpeech'], equals(SafariCompatibilityService.supportsSpeechRecognition));
      
      if (SafariCompatibilityService.isSafari && SafariCompatibilityService.supportsSpeechRecognition) {
        expect(speechSupported, isTrue);
      }
      
      // Clean up
      audioService.dispose();
      speechProvider.dispose();
    });

    test('should handle error scenarios gracefully', () async {
      final speechProvider = SafariSpeechProvider();
      
      // Try to start listening without user gesture
      final startedWithoutGesture = await speechProvider.startListening();
      
      if (SafariCompatibilityService.isSafari) {
        // Should fail without user gesture
        expect(startedWithoutGesture, isFalse);
        expect(speechProvider.errorMessage, isNotNull);
      }
      
      speechProvider.dispose();
    });
  });
}
