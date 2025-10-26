import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:logger/logger.dart';

/// Service for handling local notifications and reminders
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications;
  final Logger _logger;
  bool _isInitialized = false;

  NotificationService({
    FlutterLocalNotificationsPlugin? notifications,
    Logger? logger,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _logger = logger ?? Logger();

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing notification service...');
      
      // Initialize timezone data
      tz.initializeTimeZones();
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      _logger.i('Notification service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final iosImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _logger.d('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Schedule a reminder notification
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Reminders',
            channelDescription: 'Smart reminders for your notes and tasks',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      _logger.i('Scheduled reminder: $title at $scheduledTime');
    } catch (e) {
      _logger.e('Failed to schedule reminder: $e');
      rethrow;
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'general_channel',
            'General',
            channelDescription: 'General notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );

      _logger.d('Showed notification: $title');
    } catch (e) {
      _logger.e('Failed to show notification: $e');
      rethrow;
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      _logger.d('Cancelled notification: $id');
    } catch (e) {
      _logger.e('Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.i('Cancelled all notifications');
    } catch (e) {
      _logger.e('Failed to cancel all notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      _logger.e('Failed to get pending notifications: $e');
      return [];
    }
  }

  /// Schedule daily digest notification
  Future<void> scheduleDailyDigest({
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time is in the past, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        0, // Use ID 0 for daily digest
        '📊 Daily Digest',
        'Here\'s your summary for today',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_digest_channel',
            'Daily Digest',
            channelDescription: 'Daily summary of your notes and tasks',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      _logger.i('Scheduled daily digest at $hour:$minute');
    } catch (e) {
      _logger.e('Failed to schedule daily digest: $e');
      rethrow;
    }
  }

  /// Schedule a task reminder notification
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Use hash code of task ID as notification ID to ensure uniqueness
    final notificationId = taskId.hashCode;
    
    await scheduleReminder(
      id: notificationId,
      title: title,
      body: body,
      scheduledTime: scheduledDate,
      payload: 'task:$taskId',
    );
  }

  /// Cancel a task reminder notification
  Future<void> cancelTaskReminder(String taskId) async {
    final notificationId = taskId.hashCode;
    await cancelNotification(notificationId);
  }
}
