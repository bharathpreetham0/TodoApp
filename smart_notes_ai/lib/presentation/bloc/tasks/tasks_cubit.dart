import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/task_model.dart';
import '../../../data/database/app_database.dart';
import '../../../services/notifications/notification_service.dart';

// States
abstract class TasksState extends Equatable {
  const TasksState();
}

class TasksInitial extends TasksState {
  @override
  List<Object> get props => [];
}

class TasksLoading extends TasksState {
  @override
  List<Object> get props => [];
}

class TasksLoaded extends TasksState {
  final List<TaskModel> tasks;
  final bool showCompleted;
  final TaskPriority? filterPriority;

  const TasksLoaded({
    required this.tasks,
    this.showCompleted = false,
    this.filterPriority,
  });

  TasksLoaded copyWith({
    List<TaskModel>? tasks,
    bool? showCompleted,
    TaskPriority? filterPriority,
  }) {
    return TasksLoaded(
      tasks: tasks ?? this.tasks,
      showCompleted: showCompleted ?? this.showCompleted,
      filterPriority: filterPriority ?? this.filterPriority,
    );
  }

  List<TaskModel> get pendingTasks =>
      tasks.where((t) => !t.isCompleted).toList();
  List<TaskModel> get completedTasks =>
      tasks.where((t) => t.isCompleted).toList();
  List<TaskModel> get overdueTasks =>
      tasks.where((t) => t.isOverdue).toList();
  List<TaskModel> get todayTasks =>
      tasks.where((t) => t.isDueToday).toList();

  @override
  List<Object?> get props => [tasks, showCompleted, filterPriority];
}

class TasksError extends TasksState {
  final String message;

  const TasksError(this.message);

  @override
  List<Object> get props => [message];
}

// Cubit
class TasksCubit extends Cubit<TasksState> {
  final AppDatabase _database;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  TasksCubit({
    required AppDatabase database,
    required NotificationService notificationService,
  })  : _database = database,
        _notificationService = notificationService,
        super(TasksInitial());

  /// Load all tasks
  Future<void> loadTasks({
    bool showCompleted = false,
    TaskPriority? priority,
  }) async {
    emit(TasksLoading());
    try {
      // TODO: Implement database query once generated code is available
      emit(TasksLoaded(
        tasks: [],
        showCompleted: showCompleted,
        filterPriority: priority,
      ));
    } catch (e) {
      emit(TasksError('Failed to load tasks: $e'));
    }
  }

  /// Create a new task
  Future<void> createTask({
    required String description,
    String? noteId,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.low,
    bool createReminder = false,
  }) async {
    try {
      final now = DateTime.now();
      final task = TaskModel(
        id: _uuid.v4(),
        noteId: noteId,
        description: description,
        dueDate: dueDate,
        priority: priority,
        createdAt: now,
        updatedAt: now,
      );

      // TODO: Insert into database once generated code is available

      // Create reminder if requested and has due date
      if (createReminder && dueDate != null) {
        await _notificationService.scheduleReminder(
          id: task.id.hashCode,
          title: 'Task Reminder',
          body: description,
          scheduledTime: dueDate,
          payload: 'task:${task.id}',
        );
      }

      await loadTasks();
    } catch (e) {
      emit(TasksError('Failed to create task: $e'));
    }
  }

  /// Update task
  Future<void> updateTask({
    required String id,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
  }) async {
    try {
      // TODO: Implement database update once generated code is available
      await loadTasks();
    } catch (e) {
      emit(TasksError('Failed to update task: $e'));
    }
  }

  /// Complete a task
  Future<void> completeTask(String id) async {
    try {
      final now = DateTime.now();
      // TODO: Update database once generated code is available
      
      // Cancel any associated reminders
      await _notificationService.cancelNotification(id.hashCode);
      
      await loadTasks();
    } catch (e) {
      emit(TasksError('Failed to complete task: $e'));
    }
  }

  /// Uncomplete a task
  Future<void> uncompleteTask(String id) async {
    try {
      // TODO: Update database once generated code is available
      await loadTasks();
    } catch (e) {
      emit(TasksError('Failed to uncomplete task: $e'));
    }
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    try {
      // TODO: Delete from database once generated code is available
      
      // Cancel any associated reminders
      await _notificationService.cancelNotification(id.hashCode);
      
      await loadTasks();
    } catch (e) {
      emit(TasksError('Failed to delete task: $e'));
    }
  }

  /// Toggle task completion
  Future<void> toggleTask(String id, bool currentStatus) async {
    if (currentStatus) {
      await uncompleteTask(id);
    } else {
      await completeTask(id);
    }
  }

  /// Filter by priority
  Future<void> filterByPriority(TaskPriority? priority) async {
    final currentState = state;
    if (currentState is TasksLoaded) {
      await loadTasks(
        showCompleted: currentState.showCompleted,
        priority: priority,
      );
    }
  }

  /// Toggle show completed tasks
  Future<void> toggleShowCompleted() async {
    final currentState = state;
    if (currentState is TasksLoaded) {
      await loadTasks(
        showCompleted: !currentState.showCompleted,
        priority: currentState.filterPriority,
      );
    }
  }
}
