import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/ai/ai_service.dart';
import '../../../services/encryption/encryption_service.dart';
import '../../../services/notifications/notification_service.dart';

// State
class SettingsState extends Equatable {
  final bool aiEnabled;
  final bool encryptionEnabled;
  final bool biometricEnabled;
  final bool dailyDigestEnabled;
  final bool taskRemindersEnabled;
  final bool notificationsEnabled;
  final int dailyDigestHour;
  final int dailyDigestMinute;
  final String theme; // 'light', 'dark', 'system'

  const SettingsState({
    this.aiEnabled = true,
    this.encryptionEnabled = false,
    this.biometricEnabled = false,
    this.dailyDigestEnabled = true,
    this.taskRemindersEnabled = true,
    this.notificationsEnabled = true,
    this.dailyDigestHour = 9,
    this.dailyDigestMinute = 0,
    this.theme = 'system',
  });

  // Convenience getter for ThemeMode
  ThemeMode get themeMode {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  SettingsState copyWith({
    bool? aiEnabled,
    bool? encryptionEnabled,
    bool? biometricEnabled,
    bool? dailyDigestEnabled,
    bool? taskRemindersEnabled,
    bool? notificationsEnabled,
    int? dailyDigestHour,
    int? dailyDigestMinute,
    String? theme,
  }) {
    return SettingsState(
      aiEnabled: aiEnabled ?? this.aiEnabled,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyDigestHour: dailyDigestHour ?? this.dailyDigestHour,
      dailyDigestMinute: dailyDigestMinute ?? this.dailyDigestMinute,
      theme: theme ?? this.theme,
    );
  }

  @override
  List<Object?> get props => [
        aiEnabled,
        encryptionEnabled,
        biometricEnabled,
        dailyDigestEnabled,
        taskRemindersEnabled,
        notificationsEnabled,
        dailyDigestHour,
        dailyDigestMinute,
        theme,
      ];
}

// Cubit
class SettingsCubit extends Cubit<SettingsState> {
  final AIService _aiService;
  final EncryptionService _encryptionService;
  final NotificationService _notificationService;
  final SharedPreferences _prefs;

  SettingsCubit({
    required AIService aiService,
    required EncryptionService encryptionService,
    required NotificationService notificationService,
    required SharedPreferences prefs,
  })  : _aiService = aiService,
        _encryptionService = encryptionService,
        _notificationService = notificationService,
        _prefs = prefs,
        super(const SettingsState()) {
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final aiEnabled = _prefs.getBool('ai_enabled') ?? true;
    final encryptionEnabled = _prefs.getBool('encryption_enabled') ?? false;
    final biometricEnabled = _prefs.getBool('biometric_enabled') ?? false;
    final dailyDigestEnabled = _prefs.getBool('daily_digest_enabled') ?? true;
    final taskRemindersEnabled = _prefs.getBool('task_reminders_enabled') ?? true;
    final notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    final dailyDigestHour = _prefs.getInt('daily_digest_hour') ?? 9;
    final dailyDigestMinute = _prefs.getInt('daily_digest_minute') ?? 0;
    final theme = _prefs.getString('theme') ?? 'system';

    emit(SettingsState(
      aiEnabled: aiEnabled,
      encryptionEnabled: encryptionEnabled,
      biometricEnabled: biometricEnabled,
      dailyDigestEnabled: dailyDigestEnabled,
      taskRemindersEnabled: taskRemindersEnabled,
      notificationsEnabled: notificationsEnabled,
      dailyDigestHour: dailyDigestHour,
      dailyDigestMinute: dailyDigestMinute,
      theme: theme,
    ));

    // Apply settings
    _aiService.setEnabled(aiEnabled);
  }

  /// Set AI enabled/disabled
  Future<void> setAIEnabled(bool enabled) async {
    await _prefs.setBool('ai_enabled', enabled);
    _aiService.setEnabled(enabled);
    emit(state.copyWith(aiEnabled: enabled));
  }

  /// Set encryption enabled/disabled
  Future<void> setEncryptionEnabled(bool enabled) async {
    await _prefs.setBool('encryption_enabled', enabled);
    
    if (enabled) {
      // Initialize encryption if not already done
      if (!await _encryptionService.isSetup()) {
        await _encryptionService.initialize();
      }
    }
    
    emit(state.copyWith(encryptionEnabled: enabled));
  }

  /// Set biometric authentication enabled/disabled
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool('biometric_enabled', enabled);
    emit(state.copyWith(biometricEnabled: enabled));
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('notifications_enabled', enabled);
    emit(state.copyWith(notificationsEnabled: enabled));
  }

  /// Set daily digest enabled/disabled
  Future<void> setDailyDigestEnabled(bool enabled) async {
    await _prefs.setBool('daily_digest_enabled', enabled);
    
    if (enabled) {
      await _notificationService.scheduleDailyDigest(
        hour: state.dailyDigestHour,
        minute: state.dailyDigestMinute,
      );
    } else {
      await _notificationService.cancelNotification(0); // Daily digest uses ID 0
    }
    
    emit(state.copyWith(dailyDigestEnabled: enabled));
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    String theme;
    switch (mode) {
      case ThemeMode.light:
        theme = 'light';
        break;
      case ThemeMode.dark:
        theme = 'dark';
        break;
      case ThemeMode.system:
        theme = 'system';
        break;
    }
    await _prefs.setString('theme', theme);
    emit(state.copyWith(theme: theme));
  }
  
  /// Toggle methods for quick switching
  Future<void> toggleAI() => setAIEnabled(!state.aiEnabled);
  Future<void> toggleEncryption() => setEncryptionEnabled(!state.encryptionEnabled);
  Future<void> toggleBiometric() => setBiometricEnabled(!state.biometricEnabled);
  Future<void> toggleDailyDigest() => setDailyDigestEnabled(!state.dailyDigestEnabled);
  Future<void> toggleTaskReminders() async {
    final enabled = !state.taskRemindersEnabled;
    await _prefs.setBool('task_reminders_enabled', enabled);
    emit(state.copyWith(taskRemindersEnabled: enabled));
  }

  /// Reset all settings to defaults
  Future<void> resetSettings() async {
    await _prefs.clear();
    emit(const SettingsState());
    _aiService.setEnabled(true);
  }
}
