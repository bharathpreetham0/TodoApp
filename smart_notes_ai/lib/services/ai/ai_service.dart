import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../native/llama_ffi_platform.dart';
import 'prompt_templates.dart';
import 'model_downloader.dart';
import 'web_ai.dart' if (dart.library.io) 'web_ai_stub.dart';

/// Result of AI summarization
class SummarizationResult {
  final String summary;
  final List<String> insights;
  final List<String> keyPoints;

  SummarizationResult({
    required this.summary,
    required this.insights,
    required this.keyPoints,
  });

  factory SummarizationResult.fromJson(Map<String, dynamic> json) {
    return SummarizationResult(
      summary: json['summary'] as String? ?? '',
      insights: (json['insights'] as List<dynamic>?)?.cast<String>() ?? [],
      keyPoints: (json['key_points'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Result of task extraction
class TaskExtractionResult {
  final List<ExtractedTask> tasks;
  final List<ExtractedReminder> reminders;

  TaskExtractionResult({
    required this.tasks,
    required this.reminders,
  });

  factory TaskExtractionResult.fromJson(Map<String, dynamic> json) {
    return TaskExtractionResult(
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => ExtractedTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((r) => ExtractedReminder.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ExtractedTask {
  final String description;
  final int priority;
  final String? dueDate;

  ExtractedTask({
    required this.description,
    required this.priority,
    this.dueDate,
  });

  factory ExtractedTask.fromJson(Map<String, dynamic> json) {
    return ExtractedTask(
      description: json['description'] as String,
      priority: json['priority'] as int? ?? 0,
      dueDate: json['due_date'] as String?,
    );
  }
}

class ExtractedReminder {
  final String task;
  final String date;
  final String? time;

  ExtractedReminder({
    required this.task,
    required this.date,
    this.time,
  });

  factory ExtractedReminder.fromJson(Map<String, dynamic> json) {
    return ExtractedReminder(
      task: json['task'] as String,
      date: json['date'] as String,
      time: json['time'] as String?,
    );
  }
}

/// Main AI service using llama.cpp
class AIService {
  final LlamaFFI _llama;
  final ModelDownloader _modelDownloader;
  final Logger _logger;
  WebAI? _webAI;
  bool _isEnabled = true;
  ModelSize? _currentModel;

  AIService({
    LlamaFFI? llama,
    ModelDownloader? modelDownloader,
    Logger? logger,
  })  : _llama = llama ?? LlamaFFI(),
        _modelDownloader = modelDownloader ?? ModelDownloader(),
        _logger = logger ?? Logger();

  /// Initialize the AI service
  Future<void> initialize({ModelSize? preferredModel}) async {
    try {
      _logger.i('Initializing AI service...');

      if (kIsWeb) {
        // Use WebAI for web platform
        _webAI = WebAI(logger: _logger);
        await _webAI!.initialize();
        _logger.i('AI service initialized for web');
      } else {
        // Use llama.cpp for native platforms
        await _llama.initialize();

        // Try to load a model if available
        final downloadedModels = await _modelDownloader.getDownloadedModels();
        
        if (downloadedModels.isNotEmpty) {
          final modelToLoad = preferredModel ?? downloadedModels.first;
          final modelPath = await _modelDownloader.getModelPath(modelToLoad);
          await _llama.loadModel(modelPath);
          _currentModel = modelToLoad;
          _logger.i('AI service initialized with model: ${modelToLoad.displayName}');
        } else {
          _logger.w('No models downloaded. AI will use mock responses.');
        }
      }

      _logger.i('AI service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize AI service: $e');
      _isEnabled = false;
      rethrow;
    }
  }

  /// Check if AI is enabled and available
  bool get isEnabled => _isEnabled;

  /// Enable/disable AI features
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Get the model downloader instance
  ModelDownloader get modelDownloader => _modelDownloader;

  /// Get currently loaded model
  ModelSize? get currentModel => _currentModel;

  /// Check if a model is available (downloaded or web AI)
  Future<bool> hasModel() async {
    if (kIsWeb) return true; // Web AI is always available
    return (await _modelDownloader.getDownloadedModels()).isNotEmpty;
  }

  /// Load a specific model
  Future<void> loadModel(ModelSize size) async {
    if (kIsWeb) {
      _logger.w('Model loading not needed on web');
      return;
    }

    if (!await _modelDownloader.isModelDownloaded(size)) {
      throw Exception('Model ${size.displayName} is not downloaded');
    }

    try {
      final modelPath = await _modelDownloader.getModelPath(size);
      await _llama.loadModel(modelPath);
      _currentModel = size;
      _logger.i('Switched to model: ${size.displayName}');
    } catch (e) {
      _logger.e('Error loading model: $e');
      rethrow;
    }
  }

  /// Summarize note content
  Future<SummarizationResult?> summarizeNote(String noteContent) async {
    if (!_isEnabled) {
      _logger.w('AI is disabled');
      return null;
    }

    try {
      _logger.d('Summarizing note...');
      
      final prompt = PromptTemplates.buildPrompt(
        system: PromptTemplates.summarizationSystem,
        user: PromptTemplates.summarizationUser(noteContent),
      );

      final response = await _generate(
        prompt: prompt,
        maxTokens: 512,
        temperature: 0.7,
      );

      final jsonStr = PromptTemplates.extractJson(response);
      if (jsonStr == null) {
        _logger.w('Failed to extract JSON from response');
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SummarizationResult.fromJson(json);
    } catch (e) {
      _logger.e('Error summarizing note: $e');
      return null;
    }
  }

  /// Extract tasks from note content
  Future<TaskExtractionResult?> extractTasks(String noteContent) async {
    if (!_isEnabled) {
      _logger.w('AI is disabled');
      return null;
    }

    try {
      _logger.d('Extracting tasks...');
      
      final prompt = PromptTemplates.buildPrompt(
        system: PromptTemplates.taskExtractionSystem,
        user: PromptTemplates.taskExtractionUser(noteContent),
      );

      final response = await _generate(
        prompt: prompt,
        maxTokens: 1024,
        temperature: 0.5,
      );

      final jsonStr = PromptTemplates.extractJson(response);
      if (jsonStr == null) {
        _logger.w('Failed to extract JSON from response');
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TaskExtractionResult.fromJson(json);
    } catch (e) {
      _logger.e('Error extracting tasks: $e');
      return null;
    }
  }

  /// Search notes with natural language query
  Future<String?> searchNotes({
    required String query,
    required List<String> relevantNotes,
  }) async {
    if (!_isEnabled) {
      _logger.w('AI is disabled');
      return null;
    }

    try {
      _logger.d('Searching notes with query: $query');
      
      final prompt = PromptTemplates.buildPrompt(
        system: PromptTemplates.searchSystem,
        user: PromptTemplates.searchUser(query, relevantNotes),
      );

      final response = await _generate(
        prompt: prompt,
        maxTokens: 512,
        temperature: 0.5,
      );

      return response.trim();
    } catch (e) {
      _logger.e('Error searching notes: $e');
      return null;
    }
  }

  /// Generate daily digest
  Future<String?> generateDailyDigest({
    required List<String> todayNotes,
    required List<String> pendingTasks,
    required List<String> upcomingReminders,
  }) async {
    if (!_isEnabled) {
      _logger.w('AI is disabled');
      return null;
    }

    try {
      _logger.d('Generating daily digest...');
      
      final prompt = PromptTemplates.buildPrompt(
        system: PromptTemplates.dailyDigestSystem,
        user: PromptTemplates.dailyDigestUser(
          todayNotes: todayNotes,
          pendingTasks: pendingTasks,
          upcomingReminders: upcomingReminders,
        ),
      );

      final response = await _generate(
        prompt: prompt,
        maxTokens: 1024,
        temperature: 0.7,
      );

      return response.trim();
    } catch (e) {
      _logger.e('Error generating daily digest: $e');
      return null;
    }
  }

  /// Suggest category and tags for a note
  Future<Map<String, dynamic>?> suggestCategorization(String noteContent) async {
    if (!_isEnabled) {
      _logger.w('AI is disabled');
      return null;
    }

    try {
      _logger.d('Suggesting categorization...');
      
      final prompt = PromptTemplates.buildPrompt(
        system: PromptTemplates.categorizationSystem,
        user: PromptTemplates.categorizationUser(noteContent),
      );

      final response = await _generate(
        prompt: prompt,
        maxTokens: 256,
        temperature: 0.5,
      );

      final jsonStr = PromptTemplates.extractJson(response);
      if (jsonStr == null) {
        _logger.w('Failed to extract JSON from response');
        return null;
      }

      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Error suggesting categorization: $e');
      return null;
    }
  }

  /// Internal method to generate text using appropriate platform implementation
  Future<String> _generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    if (kIsWeb) {
      // Use WebAI for web platform
      return await _webAI!.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    } else {
      // Use llama.cpp for native platforms
      return await _llama.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _llama.dispose();
    _webAI?.dispose();
  }
}
