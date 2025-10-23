import 'package:equatable/equatable.dart';

/// Reminder model for domain layer
class ReminderModel extends Equatable {
  final String id;
  final String? taskId;
  final String? noteId;
  final String title;
  final String? description;
  final DateTime triggerTime;
  final bool isTriggered;
  final bool isRecurring;
  final String? recurrenceRule;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    this.taskId,
    this.noteId,
    required this.title,
    this.description,
    required this.triggerTime,
    this.isTriggered = false,
    this.isRecurring = false,
    this.recurrenceRule,
    required this.createdAt,
  });

  ReminderModel copyWith({
    String? id,
    String? taskId,
    String? noteId,
    String? title,
    String? description,
    DateTime? triggerTime,
    bool? isTriggered,
    bool? isRecurring,
    String? recurrenceRule,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      description: description ?? this.description,
      triggerTime: triggerTime ?? this.triggerTime,
      isTriggered: isTriggered ?? this.isTriggered,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'note_id': noteId,
      'title': title,
      'description': description,
      'trigger_time': triggerTime.toIso8601String(),
      'is_triggered': isTriggered,
      'is_recurring': isRecurring,
      'recurrence_rule': recurrenceRule,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      taskId: json['task_id'] as String?,
      noteId: json['note_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      triggerTime: DateTime.parse(json['trigger_time'] as String),
      isTriggered: json['is_triggered'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceRule: json['recurrence_rule'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Check if reminder is upcoming (within next hour)
  bool get isUpcoming {
    if (isTriggered) return false;
    final now = DateTime.now();
    final oneHourFromNow = now.add(const Duration(hours: 1));
    return triggerTime.isAfter(now) && triggerTime.isBefore(oneHourFromNow);
  }

  /// Check if reminder is overdue
  bool get isOverdue {
    if (isTriggered) return false;
    return triggerTime.isBefore(DateTime.now());
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        noteId,
        title,
        description,
        triggerTime,
        isTriggered,
        isRecurring,
        recurrenceRule,
        createdAt,
      ];
}
