import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling speech-to-text functionality
/// 
/// Features:
/// - Real-time speech recognition
/// - Language selection support
/// - Confidence scoring
/// - Error handling and permission management
/// - Continuous listening mode
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLocaleId = 'en_US';
  
  /// Stream controller for recognized text
  final _textController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textController.stream;
  
  /// Stream controller for listening state
  final _listeningController = StreamController<bool>.broadcast();
  Stream<bool> get listeningStream => _listeningController.stream;
  
  /// Stream controller for error messages
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;
  
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentLocale => _currentLocaleId;
  
  /// Initialize the speech recognition service
  /// 
  /// Returns true if initialization was successful
  Future<bool> initialize() async {
    try {
      // Check and request microphone permission
      final permissionStatus = await _checkMicrophonePermission();
      if (!permissionStatus) {
        _errorController.add('Microphone permission denied');
        return false;
      }
      
      // Initialize speech-to-text
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _errorController.add('Speech recognition error: ${error.errorMsg}');
          _isListening = false;
          _listeningController.add(false);
        },
        onStatus: (status) {
          if (kDebugMode) {
            print('Speech recognition status: $status');
          }
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _listeningController.add(false);
          }
        },
      );
      
      return _isInitialized;
    } catch (e) {
      _errorController.add('Failed to initialize speech recognition: $e');
      return false;
    }
  }
  
  /// Check and request microphone permission
  Future<bool> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      _errorController.add('Microphone permission permanently denied. Please enable it in settings.');
      return false;
    }
    
    return false;
  }
  
  /// Get list of available locales for speech recognition
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }
  
  /// Set the locale for speech recognition
  void setLocale(String localeId) {
    _currentLocaleId = localeId;
  }
  
  /// Start listening for speech input
  /// 
  /// [onResult] - Callback for partial and final recognition results
  /// [continuous] - Whether to continue listening after pause (default: false)
  /// [pauseFor] - Duration to wait before stopping (default: 3 seconds)
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    bool continuous = false,
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }
    
    if (_isListening) {
      if (kDebugMode) {
        print('Already listening');
      }
      return;
    }
    
    try {
      final available = await _speechToText.hasPermission;
      if (!available) {
        _errorController.add('Microphone permission not granted');
        return;
      }
      
      _isListening = true;
      _listeningController.add(true);
      
      await _speechToText.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          final isFinal = result.finalResult;
          
          if (text.isNotEmpty) {
            _textController.add(text);
            onResult(text, isFinal);
          }
        },
        localeId: _currentLocaleId,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: continuous ? ListenMode.confirmation : ListenMode.search,
        ),
        pauseFor: pauseFor,
      );
    } catch (e) {
      _errorController.add('Failed to start listening: $e');
      _isListening = false;
      _listeningController.add(false);
    }
  }
  
  /// Stop listening for speech input
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }
    
    try {
      await _speechToText.stop();
      _isListening = false;
      _listeningController.add(false);
    } catch (e) {
      _errorController.add('Failed to stop listening: $e');
    }
  }
  
  /// Cancel listening (similar to stop but may be faster)
  Future<void> cancelListening() async {
    if (!_isListening) {
      return;
    }
    
    try {
      await _speechToText.cancel();
      _isListening = false;
      _listeningController.add(false);
    } catch (e) {
      _errorController.add('Failed to cancel listening: $e');
    }
  }
  
  /// Toggle listening state (start if stopped, stop if listening)
  Future<void> toggleListening({
    required Function(String text, bool isFinal) onResult,
    bool continuous = false,
  }) async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening(
        onResult: onResult,
        continuous: continuous,
      );
    }
  }
  
  /// Get the last error message
  String? getLastError() {
    return _speechToText.lastError?.errorMsg;
  }
  
  /// Dispose of resources
  void dispose() {
    _speechToText.cancel();
    _textController.close();
    _listeningController.close();
    _errorController.close();
  }
}
