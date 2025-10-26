import 'package:equatable/equatable.dart';

/// Task priority levels
enum TaskPriority {
  none,
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
}

/// Pure domain entity for Task
/// No dependencies on data layer or external packages
class Task extends Equatable {
  final String id;
  final String description;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? noteId; // Associated note ID if task extracted from note
  final bool hasReminder;

  const Task({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isCompleted = false,
    this.priority = TaskPriority.none,
    this.dueDate,
    this.completedAt,
    this.noteId,
    this.hasReminder = false,
  });

  Task copyWith({
    String? id,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    DateTime? completedAt,
    String? noteId,
    bool? hasReminder,
  }) {
    return Task(
      id: id ?? this.id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      noteId: noteId ?? this.noteId,
      hasReminder: hasReminder ?? this.hasReminder,
    );
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Check if task is due today
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  @override
  List<Object?> get props => [
        id,
        description,
        isCompleted,
        priority,
        createdAt,
        updatedAt,
        dueDate,
        completedAt,
        noteId,
        hasReminder,
      ];
}
