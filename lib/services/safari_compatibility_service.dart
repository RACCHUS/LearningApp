import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/browser_compatibility_service.dart';

/// Safari-specific compatibility and feature detection service
/// Extends BrowserCompatibilityService with Safari-focused functionality
class SafariCompatibilityService extends BrowserCompatibilityService {
  
  /// Check if the current browser is Safari
  static bool get isSafari => BrowserCompatibilityService.browserType == BrowserType.safari;
  
  /// Check if Safari is running on mobile device (iPhone/iPad)
  static bool get isSafariMobile {
    if (!kIsWeb || !isSafari) return false;
    
    // For now, return false in test mode or when we can't detect
    // In a real web environment, this would use proper web APIs
    if (kDebugMode) {
      return false; // Mock value for testing
    }
    return false;
  }
  
  /// Check if Safari is running on desktop (macOS)
  static bool get isSafariDesktop {
    if (!kIsWeb || !isSafari) return false;
    return !isSafariMobile;
  }
  
  /// Get Safari version string
  static String get safariVersion {
    if (!kIsWeb || !isSafari) return '';
    
    // Mock version for testing - in real implementation this would parse user agent
    if (kDebugMode) {
      return '16.5'; // Mock Safari version
    }
    return '';
  }
  
  /// Get Safari major version number
  static double get safariMajorVersion {
    final version = safariVersion;
    if (version.isEmpty) return 0.0;
    
    try {
      return double.parse(version.split('.').first);
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Check if Safari version supports speech recognition
  static bool get supportsSpeechRecognition {
    if (!isSafari) return true; // Assume other browsers work
    
    // Safari 16.4+ has improved speech recognition support
    // Earlier versions have very limited or no support
    final majorVersion = safariMajorVersion;
    return majorVersion >= 16.4;
  }
  
  /// Check if Safari version supports reliable Web Speech API
  static bool get hasReliableSpeechSupport {
    if (!isSafari) return true;
    
    // Safari 17+ has more reliable speech support
    final majorVersion = safariMajorVersion;
    return majorVersion >= 17.0;
  }
  
  /// Check if Safari supports microphone access without additional setup
  static bool get supportsDirectMicrophoneAccess {
    if (!isSafari) return true;
    
    // Safari always requires user gesture for microphone access
    return false;
  }
  
  /// Check if Safari supports PWA installation
  static bool get supportsPWAInstallation {
    if (!isSafari) return true;
    
    // Safari supports PWA installation but with limited features
    return isSafariMobile; // Only mobile Safari supports PWA installation
  }
  
  /// Check if Safari supports service workers reliably
  static bool get supportsServiceWorkers {
    if (!isSafari) return true;
    
    // Safari has service worker support but with restrictions
    final majorVersion = safariMajorVersion;
    return majorVersion >= 16.0;
  }
  
  /// Check if Safari supports audio context without user gesture
  static bool get supportsAudioContextWithoutGesture {
    if (!isSafari) return true;
    
    // Safari always requires user gesture for AudioContext
    return false;
  }
  
  /// Check if Safari is in private browsing mode
  static bool get isPrivateBrowsing {
    if (!kIsWeb || !isSafari) return false;
    
    // Mock implementation for testing
    if (kDebugMode) {
      return false; // Mock value - not in private browsing
    }
    
    // In real implementation, this would test localStorage access
    return false;
  }
  
  /// Get Safari-specific speech recognition configuration
  static Map<String, dynamic> get safariSpeechConfig {
    return {
      'continuous': false, // Safari doesn't handle continuous well
      'interimResults': false, // Safari has issues with interim results
      'maxAlternatives': 1, // Keep it simple for Safari
      'lang': 'en-US',
      'requiresUserGesture': true,
      'timeoutDuration': 10, // Shorter timeout for Safari
      'retryAttempts': 2, // Limited retries for Safari
    };
  }
  
  /// Get Safari-specific permission request instructions
  static List<String> get permissionInstructions {
    if (!isSafari) return BrowserCompatibilityService.getSetupInstructions();
    
    final instructions = <String>[
      'Safari Speech Recognition Setup:',
      '1. Click the microphone button to start voice input',
      '2. Safari will ask for microphone permission',
      '3. Click "Allow" to enable voice commands',
    ];
    
    if (isSafariMobile) {
      instructions.addAll([
        '4. On mobile, speak clearly and wait for results',
        '5. Voice input may timeout after 10 seconds',
      ]);
    } else {
      instructions.addAll([
        '4. On desktop, ensure microphone is working in System Preferences',
        '5. Refresh the page if voice input stops working',
      ]);
    }
    
    if (isPrivateBrowsing) {
      instructions.add('Note: Private browsing may limit voice features');
    }
    
    return instructions;
  }
  
  /// Get Safari compatibility issues and warnings
  static List<String> get compatibilityWarnings {
    if (!isSafari) return [];
    
    final warnings = <String>[];
    
    if (!supportsSpeechRecognition) {
      warnings.add('Voice recognition not supported in Safari ${safariVersion}');
      warnings.add('Manual text input will be used instead');
    } else if (!hasReliableSpeechSupport) {
      warnings.add('Voice recognition may be unreliable in Safari ${safariVersion}');
      warnings.add('Consider updating to Safari 17+ for better performance');
    }
    
    if (isSafariMobile && !supportsPWAInstallation) {
      warnings.add('PWA installation not available on this Safari version');
    }
    
    if (isPrivateBrowsing) {
      warnings.add('Private browsing may limit app functionality');
      warnings.add('Some features may not work as expected');
    }
    
    return warnings;
  }
  
  /// Get recommended fallback options for Safari
  static Map<String, String> get fallbackOptions {
    return {
      'voiceInput': 'Manual text input field',
      'speechSynthesis': 'Text display instead of audio',
      'offlineStorage': 'Session-only storage in private mode',
      'pushNotifications': 'Browser notifications may be limited',
      'installation': 'Bookmark to home screen for app-like experience',
    };
  }
  
  /// Initialize Safari-specific optimizations
  static Future<Map<String, dynamic>> initializeSafariOptimizations() async {
    final results = <String, dynamic>{};
    
    results['isSafari'] = isSafari;
    results['safariVersion'] = safariVersion;
    results['isMobile'] = isSafariMobile;
    results['isDesktop'] = isSafariDesktop;
    results['supportsSpeech'] = supportsSpeechRecognition;
    results['hasReliableSpeech'] = hasReliableSpeechSupport;
    results['isPrivateBrowsing'] = isPrivateBrowsing;
    results['warnings'] = compatibilityWarnings;
    results['fallbacks'] = fallbackOptions;
    results['instructions'] = permissionInstructions;
    results['speechConfig'] = safariSpeechConfig;
    
    if (kDebugMode && isSafari) {
      print('🍎 Safari Compatibility Analysis:');
      print('   Version: ${safariVersion}');
      print('   Platform: ${isSafariMobile ? 'Mobile' : 'Desktop'}');
      print('   Speech Support: ${supportsSpeechRecognition}');
      print('   Reliable Speech: ${hasReliableSpeechSupport}');
      print('   Private Browsing: ${isPrivateBrowsing}');
      print('   Warnings: ${compatibilityWarnings.length}');
    }
    
    return results;
  }
  
  /// Check if a specific Safari feature is supported
  static bool supportsFeature(String feature) {
    switch (feature.toLowerCase()) {
      case 'speechrecognition':
      case 'voice':
        return isSafari ? supportsSpeechRecognition : true;
      case 'speechsynthesis':
      case 'tts':
        return true; // Safari supports TTS, other browsers too
      case 'serviceworker':
        return isSafari ? supportsServiceWorkers : true;
      case 'pwa':
      case 'installation':
        return isSafari ? supportsPWAInstallation : true;
      case 'audiocontext':
        return true; // Supported but requires user gesture in Safari
      case 'microphone':
        return true; // Supported but requires user gesture in Safari
      case 'localstorage':
        return isSafari ? !isPrivateBrowsing : true;
      case 'indexeddb':
        return isSafari ? !isPrivateBrowsing : true;
      default:
        return false; // Unknown features are not supported
    }
  }
  
  /// Get Safari-specific error messages
  static String getErrorMessage(String errorType) {
    switch (errorType.toLowerCase()) {
      case 'permission_denied':
        return isSafari 
            ? 'Microphone access denied. Please allow microphone access in Safari settings and try again.'
            : 'Microphone access denied. Please allow microphone access in your browser settings and try again.';
      case 'speech_not_supported':
        return isSafari
            ? 'Voice recognition is not supported in Safari ${safariVersion}. Please use manual text input.'
            : 'Voice recognition is not supported in this browser. Please use manual text input.';
      case 'audio_context_failed':
        return isSafari
            ? 'Audio features require user interaction. Please tap a button to enable audio.'
            : 'Audio features require user interaction. Please tap a button to enable audio.';
      case 'private_browsing':
        return isSafari
            ? 'Some features are limited in Safari private browsing mode.'
            : 'Some features are limited in private browsing mode.';
      case 'timeout':
        return isSafari
            ? 'Voice input timed out. Safari has shorter timeout periods. Please try again.'
            : 'Voice input timed out. Please try again.';
      default:
        return isSafari
            ? 'Safari compatibility issue. Please try refreshing the page or using manual input.'
            : 'Browser compatibility issue. Please try refreshing the page or using manual input.';
    }
  }
  
  /// Test Safari speech recognition capabilities
  static Future<Map<String, dynamic>> testSpeechCapabilities() async {
    final results = <String, dynamic>{
      'supported': false,
      'available': false,
      'permissionGranted': false,
      'error': null,
      'testResult': null,
    };
    
    if (!kIsWeb || !isSafari) {
      results['error'] = 'Not running in Safari browser';
      return results;
    }
    
    try {
      // Check if SpeechRecognition is available
      // Mock implementation for testing
      if (kDebugMode) {
        results['supported'] = isSafari;
        results['available'] = isSafari && supportsSpeechRecognition;
        
        print('🍎 Safari speech test (mock):');
        print('   Safari detected: $isSafari');
        print('   Version support: $supportsSpeechRecognition');
        print('   Mock user agent test');
        
        return results;
      }
      
      // In real implementation, this would check actual web APIs
      results['supported'] = false;
      results['available'] = false;
      
    } catch (e) {
      results['error'] = e.toString();
      if (kDebugMode) {
        print('🍎 Safari speech test error: $e');
      }
    }
    
    return results;
  }
}
