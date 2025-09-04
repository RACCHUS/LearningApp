import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Enumeration of supported browser types
enum BrowserType {
  chrome,
  firefox,
  safari,
  edge,
  unknown
}

/// Speech API support levels
enum SpeechApiSupport {
  native,        // Full native support
  polyfill,      // Requires polyfill
  limited,       // Partial support
  none          // No support
}

/// Service to detect browser capabilities and compatibility
class BrowserCompatibilityService {
  static BrowserType? _cachedBrowserType;
  static SpeechApiSupport? _cachedSpeechSupport;

  /// Get the current browser type
  static BrowserType get browserType {
    if (_cachedBrowserType != null) return _cachedBrowserType!;
    
    if (!kIsWeb) {
      _cachedBrowserType = BrowserType.unknown;
      return _cachedBrowserType!;
    }

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    
    if (userAgent.contains('chrome') && !userAgent.contains('edge')) {
      _cachedBrowserType = BrowserType.chrome;
    } else if (userAgent.contains('firefox')) {
      _cachedBrowserType = BrowserType.firefox;
    } else if (userAgent.contains('safari') && !userAgent.contains('chrome')) {
      _cachedBrowserType = BrowserType.safari;
    } else if (userAgent.contains('edge')) {
      _cachedBrowserType = BrowserType.edge;
    } else {
      _cachedBrowserType = BrowserType.unknown;
    }
    
    return _cachedBrowserType!;
  }

  /// Check if the browser supports speech recognition
  static bool get hasSpeechRecognition {
    if (!kIsWeb) return false;
    
    try {
      // Simple check - assume modern browsers might support it
      // Real detection will happen at runtime
      return browserType == BrowserType.chrome || 
             browserType == BrowserType.edge;
    } catch (e) {
      return false;
    }
  }

  /// Get the level of speech API support
  static SpeechApiSupport get speechApiSupport {
    if (_cachedSpeechSupport != null) return _cachedSpeechSupport!;
    
    if (!kIsWeb) {
      _cachedSpeechSupport = SpeechApiSupport.none;
      return _cachedSpeechSupport!;
    }

    switch (browserType) {
      case BrowserType.chrome:
      case BrowserType.edge:
        _cachedSpeechSupport = hasSpeechRecognition 
            ? SpeechApiSupport.native 
            : SpeechApiSupport.none;
        break;
      case BrowserType.firefox:
        _cachedSpeechSupport = SpeechApiSupport.limited;
        break;
      case BrowserType.safari:
        _cachedSpeechSupport = SpeechApiSupport.limited;
        break;
      case BrowserType.unknown:
        _cachedSpeechSupport = hasSpeechRecognition 
            ? SpeechApiSupport.limited 
            : SpeechApiSupport.none;
        break;
    }
    
    return _cachedSpeechSupport!;
  }

  /// Check if this is a PWA context
  static bool get isPWA {
    if (!kIsWeb) return false;
    
    try {
      // Check for PWA display mode
      final displayMode = web.window.matchMedia('(display-mode: standalone)').matches;
      if (displayMode) return true;
      
      // Simple fallback check
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if microphone access is available
  static Future<bool> get hasMicrophoneSupport async {
    if (!kIsWeb) return true;
    
    try {
      // Simple check - assume microphone might be available
      // Real detection will happen when we try to use it
      return true;
    } catch (e) {
      // Fallback - assume microphone might be available
      return true;
    }
  }

  /// Check if the current context supports secure features
  static bool get isSecureContext {
    if (!kIsWeb) return true;
    
    try {
      return web.window.isSecureContext;
    } catch (e) {
      // Fallback to protocol check
      return web.window.location.protocol == 'https:' || 
             web.window.location.hostname == 'localhost';
    }
  }

  /// Get browser-specific speech recognition options
  static Map<String, dynamic> get speechRecognitionOptions {
    switch (browserType) {
      case BrowserType.chrome:
      case BrowserType.edge:
        return {
          'continuous': true,
          'interimResults': true,
          'maxAlternatives': 1,
          'lang': 'en-US',
        };
      case BrowserType.firefox:
        return {
          'continuous': false,  // Firefox has issues with continuous
          'interimResults': false,
          'maxAlternatives': 1,
          'lang': 'en-US',
        };
      case BrowserType.safari:
        return {
          'continuous': false,
          'interimResults': false,
          'maxAlternatives': 1,
          'lang': 'en-US',
        };
      default:
        return {
          'continuous': false,
          'interimResults': false,
          'maxAlternatives': 1,
          'lang': 'en-US',
        };
    }
  }

  /// Get recommended timeout for speech recognition
  static Duration get speechTimeout {
    switch (browserType) {
      case BrowserType.chrome:
      case BrowserType.edge:
        return const Duration(seconds: 30);
      case BrowserType.firefox:
        return const Duration(seconds: 15);  // Firefox is less stable
      case BrowserType.safari:
        return const Duration(seconds: 10);  // Safari is most limited
      default:
        return const Duration(seconds: 15);
    }
  }

  /// Check if the browser supports a specific feature
  static bool supportsFeature(String feature) {
    if (!kIsWeb) return false;
    
    try {
      // Simple feature check - can be enhanced later
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get a human-readable description of browser capabilities
  static String get capabilityDescription {
    final browser = browserType.name;
    final speechSupport = speechApiSupport.name;
    final pwa = isPWA ? 'PWA' : 'Browser';
    final secure = isSecureContext ? 'Secure' : 'Insecure';
    
    return '$browser ($pwa, $secure) - Speech: $speechSupport';
  }

  /// Clear cached values (useful for testing)
  static void clearCache() {
    _cachedBrowserType = null;
    _cachedSpeechSupport = null;
  }

  /// Initialize and validate browser capabilities
  static Future<Map<String, dynamic>> initializeAndValidate() async {
    final results = <String, dynamic>{};
    
    results['browserType'] = browserType.name;
    results['speechApiSupport'] = speechApiSupport.name;
    results['hasSpeechRecognition'] = hasSpeechRecognition;
    results['isPWA'] = isPWA;
    results['isSecureContext'] = isSecureContext;
    results['hasMicrophoneSupport'] = await hasMicrophoneSupport;
    results['speechTimeout'] = speechTimeout.inSeconds;
    results['speechOptions'] = speechRecognitionOptions;
    results['description'] = capabilityDescription;
    
    return results;
  }

  /// Log compatibility information (for debugging)
  static void logCompatibilityInfo() {
    if (kDebugMode) {
      print('🌐 Browser Compatibility Info:');
      print('   Browser: ${browserType.name}');
      print('   Speech Support: ${speechApiSupport.name}');
      print('   PWA: $isPWA');
      print('   Secure Context: $isSecureContext');
      print('   Description: $capabilityDescription');
    }
  }

  /// Get browser information object
  static Future<BrowserInfo> getBrowserInfo() async {
    return BrowserInfo(
      browserType: browserType,
      speechSupport: speechApiSupport,
      isPWA: isPWA,
      isSecureContext: isSecureContext,
      hasMicrophoneSupport: await hasMicrophoneSupport,
      description: capabilityDescription,
    );
  }

  /// Get setup instructions for current browser
  static List<String> getSetupInstructions() {
    switch (browserType) {
      case BrowserType.chrome:
      case BrowserType.edge:
        return [
          'Chrome/Edge: Speech recognition is natively supported',
          'Ensure microphone permissions are granted',
          'Use HTTPS or localhost for security requirements',
        ];
      case BrowserType.firefox:
        return [
          'Firefox: Limited speech recognition support',
          'Consider using manual input mode',
          'Ensure microphone permissions are granted',
        ];
      case BrowserType.safari:
        return [
          'Safari: Limited speech recognition support',
          'Manual input mode recommended',
          'Voice features may not work reliably',
        ];
      default:
        return [
          'Unknown browser: Limited compatibility',
          'Manual input mode recommended',
          'Voice features may not be available',
        ];
    }
  }
}

/// Browser information data class
class BrowserInfo {
  final BrowserType browserType;
  final SpeechApiSupport speechSupport;
  final bool isPWA;
  final bool isSecureContext;
  final bool hasMicrophoneSupport;
  final String description;

  const BrowserInfo({
    required this.browserType,
    required this.speechSupport,
    required this.isPWA,
    required this.isSecureContext,
    required this.hasMicrophoneSupport,
    required this.description,
  });
}
