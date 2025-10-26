import 'package:logger/logger.dart';

/// Stub implementation of LlamaFFI for web platform
/// FFI is not available on web, so this provides a no-op implementation
class LlamaFFI {
  bool _isInitialized = false;
  final Logger _logger = Logger();

  /// Initialize (no-op on web)
  Future<void> initialize({String? modelPath}) async {
    if (_isInitialized) return;
    _logger.i('Running on web - FFI not available');
    _isInitialized = true;
  }

  /// Load model (no-op on web)
  Future<bool> loadModel(String modelPath) async {
    _logger.w('Model loading not supported on web');
    return false;
  }

  /// Generate text (returns empty string on web)
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    _logger.w('Text generation not supported via FFI on web');
    return '';
  }

  /// Unload model (no-op on web)
  Future<void> unloadModel() async {
    // No-op
  }

  /// Dispose (no-op on web)
  void dispose() {
    _isInitialized = false;
  }

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}
