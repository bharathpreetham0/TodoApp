import 'dart:convert';
import 'package:logger/logger.dart';
import '../../native/llama_ffi.dart';
import 'prompt_templates.dart';

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
  final Logger _logger;
  bool _isEnabled = true;

  AIService({LlamaFFI? llama, Logger? logger})
      : _llama = llama ?? LlamaFFI(),
        _logger = logger ?? Logger();

  /// Initialize the AI service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing AI service...');
      await _llama.initialize();
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

      final response = await _llama.generate(
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

      final response = await _llama.generate(
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

      final response = await _llama.generate(
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

      final response = await _llama.generate(
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

      final response = await _llama.generate(
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

  /// Dispose resources
  void dispose() {
    _llama.dispose();
  }
}
