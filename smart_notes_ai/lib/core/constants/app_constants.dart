import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Smart Notes AI';
  static const String appVersion = '1.0.0';
  
  // Database
  static const String databaseName = 'smart_notes.db';
  static const int databaseVersion = 1;
  
  // Encryption
  static const String encryptionKeyName = 'note_encryption_key';
  
  // Notifications
  static const String notificationChannelId = 'smart_notes_tasks';
  static const String notificationChannelName = 'Task Reminders';
  
  // AI Models
  static const String defaultModel = 'gemma-2b';
  static const int maxTokens = 2048;
  
  // UI
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Pagination
  static const int pageSize = 20;
  
  // Search
  static const int searchDebounceMs = 500;
  static const int minSearchLength = 2;
}

/// App-wide colors
class AppColors {
  // Priority colors
  static const Color priorityLow = Color(0xFF4CAF50);
  static const Color priorityMedium = Color(0xFFFF9800);
  static const Color priorityHigh = Color(0xFFF44336);
  
  // Status colors
  static const Color completed = Color(0xFF8BC34A);
  static const Color overdue = Color(0xFFE57373);
  static const Color dueToday = Color(0xFFFFB74D);
  
  // Category colors
  static const List<Color> categoryColors = [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF26A69A),
    Color(0xFFEC407A),
    Color(0xFF5C6BC0),
  ];
}

/// Text styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
}
