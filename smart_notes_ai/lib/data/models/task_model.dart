import 'package:equatable/equatable.dart';

/// Task priority levels
enum TaskPriority {
  low(0),
  medium(1),
  high(2);

  final int value;
  const TaskPriority(this.value);

  static TaskPriority fromValue(int value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TaskPriority.low,
    );
  }
}

/// Task model for domain layer
class TaskModel extends Equatable {
  final String id;
  final String? noteId;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    this.noteId,
    required this.description,
    this.dueDate,
    this.priority = TaskPriority.low,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  TaskModel copyWith({
    String? id,
    String? noteId,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority.value,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      noteId: json['note_id'] as String?,
      description: json['description'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      priority: TaskPriority.fromValue(json['priority'] as int? ?? 0),
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return dueDate!.isBefore(DateTime.now());
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
        noteId,
        description,
        dueDate,
        priority,
        isCompleted,
        completedAt,
        createdAt,
        updatedAt,
      ];
}
