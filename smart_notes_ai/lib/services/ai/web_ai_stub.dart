// Stub file for web_ai - not used on native platforms
// This prevents import errors when building for native platforms

class WebAI {
  WebAI({dynamic logger});
  
  Future<void> initialize() async {
    throw UnsupportedError('WebAI is only available on web platform');
  }
  
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    throw UnsupportedError('WebAI is only available on web platform');
  }
  
  bool get isInitialized => false;
  
  void dispose() {}
}
