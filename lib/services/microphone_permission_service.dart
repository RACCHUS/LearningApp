import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service responsible for handling microphone permissions and testing
/// Extracted from VoiceInputService for better separation of concerns
class MicrophonePermissionService {
  static final MicrophonePermissionService _instance = MicrophonePermissionService._internal();
  factory MicrophonePermissionService() => _instance;
  MicrophonePermissionService._internal();

  SpeechToText? _speechToText;
  bool _hasPermissions = false;
  bool _isInitialized = false;

  /// Current permission state
  bool get hasPermissions => _hasPermissions;
  bool get isInitialized => _isInitialized;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    try {
      _speechToText = SpeechToText();
      
      if (kDebugMode) {
        print('🎙️ Initializing microphone permission service...');
      }
      
      // Initialize with enhanced settings for better web compatibility
      _isInitialized = await _speechToText!.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
        finalTimeout: const Duration(seconds: 5),
      );
      
      if (_isInitialized) {
        if (kDebugMode) {
          print('🎙️ Microphone service initialized successfully');
        }
        await _checkPermissions();
      } else {
        if (kDebugMode) {
          print('🎙️ Failed to initialize microphone service');
        }
      }
      
      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Microphone initialization error: $e');
      }
      return false;
    }
  }

  /// Check current microphone permissions
  Future<bool> checkPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await _checkPermissions();
  }

  /// Internal permission check
  Future<bool> _checkPermissions() async {
    if (_speechToText == null) return false;
    
    try {
      if (kDebugMode) {
        print('🎙️ Checking microphone permissions...');
      }
      
      // For web, we need to actually try listening to check permissions
      // because hasPermission() doesn't work reliably on web
      if (kIsWeb) {
        return await _testWebPermissions();
      } else {
        _hasPermissions = await _speechToText!.hasPermission;
        if (kDebugMode) {
          print('🎙️ Native permission check - current state: $_hasPermissions');
        }
        return _hasPermissions;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Permission check error: $e');
      }
      return false;
    }
  }

  /// Test permissions on web by attempting to start listening
  Future<bool> _testWebPermissions() async {
    try {
      if (kDebugMode) {
        print('🎙️ Web permission check - current state: $_hasPermissions');
      }
      
      // Try to start listening briefly to test permissions
      final result = await _speechToText!.listen(
        onResult: (_) {}, // Empty callback for permission test
        listenFor: const Duration(milliseconds: 100),
        pauseFor: const Duration(milliseconds: 100),
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
      
      if (result) {
        // Stop immediately after starting
        await _speechToText!.stop();
        _hasPermissions = true;
        if (kDebugMode) {
          print('🎙️ Web permissions granted');
        }
      } else {
        _hasPermissions = false;
        if (kDebugMode) {
          print('🎙️ Web permissions denied or unavailable');
        }
      }
      
      return _hasPermissions;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Web permission test error: $e');
      }
      _hasPermissions = false;
      return false;
    }
  }

  /// Test microphone by attempting to start and stop listening
  Future<bool> testMicrophone() async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('🎙️ Cannot test microphone - service not initialized');
      }
      return false;
    }

    if (kDebugMode) {
      print('🎙️ Starting microphone test...');
    }

    try {
      final started = await _speechToText!.listen(
        onResult: (_) {}, // Empty callback for test
        listenFor: const Duration(seconds: 2),
        pauseFor: const Duration(milliseconds: 500),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      if (kDebugMode) {
        print('🎙️ Microphone test - startListening result: $started, isListening: ${_speechToText!.isListening}');
      }

      // Check if we're actually listening (double-check for web compatibility)
      final isActuallyListening = _speechToText!.isListening;

      if (started || isActuallyListening) {
        // Stop the test listening
        await _speechToText!.stop();
        _hasPermissions = true;
        
        if (kDebugMode) {
          print('🎙️ Microphone test succeeded - permissions granted');
        }
        return true;
      } else {
        _hasPermissions = false;
        if (kDebugMode) {
          print('🎙️ Microphone test failed');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Microphone test error: $e');
      }
      _hasPermissions = false;
      return false;
    }
  }

  /// Manually set permission state (for when we know permissions are granted)
  void setPermissionGranted(bool granted) {
    if (kDebugMode) {
      print('🎙️ Manually setting permission state to: $granted');
    }
    _hasPermissions = granted;
  }

  /// Get user-friendly permission instructions
  String getPermissionInstructions() {
    return '''
Microphone Permission Instructions:

Chrome:
1. Click the microphone icon in the address bar
2. Select "Always allow" for this site
3. Refresh the page if needed

Firefox:
1. Click the microphone icon next to the URL
2. Choose "Allow" and check "Remember this decision"
3. Refresh if needed

Edge:
1. Click the lock/microphone icon in the address bar
2. Set microphone to "Allow"
3. Refresh the page

If you don't see a microphone icon:
1. Go to browser settings
2. Search for "microphone" or "site permissions"
3. Find this site and enable microphone access
4. Refresh the page
    ''';
  }

  /// Error handler for speech recognition
  void _onError(dynamic error) {
    if (kDebugMode) {
      print('🎙️ Microphone error: $error');
    }
    
    // Some errors indicate permission issues
    if (error.toString().contains('permission') || 
        error.toString().contains('not-allowed')) {
      _hasPermissions = false;
    }
  }

  /// Status handler for speech recognition
  void _onStatus(String status) {
    if (kDebugMode && status != 'listening') {
      print('🎙️ Microphone status: $status');
    }
    
    // Update permission state based on status
    if (status == 'listening') {
      _hasPermissions = true;
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    _speechToText = null;
    _isInitialized = false;
    _hasPermissions = false;
  }
}
