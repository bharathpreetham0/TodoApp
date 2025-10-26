import 'package:dartz/dartz.dart' hide Task;
import 'package:uuid/uuid.dart';
import '../../domain/entities/task.dart' as domain;
import '../../domain/repositories/task_repository.dart';
import '../database/app_database.dart';
import '../models/task_model.dart' as model;
import '../../services/notifications/notification_service.dart';

/// Implementation of TaskRepository
/// This bridges the domain layer with the data layer
class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase database;
  final NotificationService notificationService;
  final Uuid uuid;

  TaskRepositoryImpl({
    required this.database,
    required this.notificationService,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  @override
  Future<Either<String, domain.Task>> createTask({
    required String description,
    domain.TaskPriority priority = domain.TaskPriority.none,
    DateTime? dueDate,
    String? noteId,
    bool createReminder = false,
  }) async {
    try {
      final now = DateTime.now();
      final id = uuid.v4();

      final task = await database.createTask(
        model.TaskModel(
          id: id,
          description: description,
          priority: _mapPriorityToModel(priority),
          dueDate: dueDate,
          noteId: noteId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create reminder if requested
      if (createReminder && dueDate != null) {
        await notificationService.scheduleTaskReminder(
          taskId: id,
          title: 'Task Due',
          body: description,
          scheduledDate: dueDate.subtract(const Duration(hours: 1)),
        );
      }

      return Right(_mapToEntity(task, hasReminder: createReminder));
    } catch (e) {
      return Left('Failed to create task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Task>>> getTasks({
    bool? isCompleted,
    domain.TaskPriority? priority,
    String? noteId,
  }) async {
    try {
      final tasks = await database.getAllTasks();
      
      var filtered = tasks.where((task) {
        if (isCompleted != null && task.isCompleted != isCompleted) return false;
        if (priority != null && _mapPriorityToEntity(task.priority) != priority) return false;
        if (noteId != null && task.noteId != noteId) return false;
        return true;
      }).toList();

      // Sort: incomplete first, then by priority, then by due date
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.priority.value != b.priority.value) {
          return b.priority.value.compareTo(a.priority.value);
        }
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return Right(filtered.map((t) => _mapToEntity(t)).toList());
    } catch (e) {
      return Left('Failed to get tasks: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Task>> getTaskById(String id) async {
    try {
      final task = await database.getTaskById(id);
      if (task == null) {
        return const Left('Task not found');
      }
      return Right(_mapToEntity(task));
    } catch (e) {
      return Left('Failed to get task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Task>> updateTask({
    required String id,
    String? description,
    domain.TaskPriority? priority,
    DateTime? dueDate,
    bool? hasReminder,
  }) async {
    try {
      final existingTask = await database.getTaskById(id);
      if (existingTask == null) {
        return const Left('Task not found');
      }

      final updatedTask = await database.updateTask(
        existingTask.copyWith(
          description: description ?? existingTask.description,
          priority: priority != null ? _mapPriorityToModel(priority) : existingTask.priority,
          dueDate: dueDate ?? existingTask.dueDate,
          updatedAt: DateTime.now(),
        ),
      );

      // Update reminder if needed
      if (hasReminder != null && hasReminder && dueDate != null) {
        await notificationService.scheduleTaskReminder(
          taskId: id,
          title: 'Task Due',
          body: description ?? existingTask.description,
          scheduledDate: dueDate.subtract(const Duration(hours: 1)),
        );
      } else if (hasReminder != null && !hasReminder) {
        await notificationService.cancelTaskReminder(id);
      }

      return Right(_mapToEntity(updatedTask, hasReminder: hasReminder ?? false));
    } catch (e) {
      return Left('Failed to update task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Task>> completeTask(String id) async {
    try {
      final existingTask = await database.getTaskById(id);
      if (existingTask == null) {
        return const Left('Task not found');
      }

      final updatedTask = await database.updateTask(
        existingTask.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Cancel reminder when task is completed
      await notificationService.cancelTaskReminder(id);

      return Right(_mapToEntity(updatedTask));
    } catch (e) {
      return Left('Failed to complete task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Task>> uncompleteTask(String id) async {
    try {
      final existingTask = await database.getTaskById(id);
      if (existingTask == null) {
        return const Left('Task not found');
      }

      final updatedTask = await database.updateTask(
        existingTask.copyWith(
          isCompleted: false,
          completedAt: null,
          updatedAt: DateTime.now(),
        ),
      );

      return Right(_mapToEntity(updatedTask));
    } catch (e) {
      return Left('Failed to uncomplete task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, void>> deleteTask(String id) async {
    try {
      await database.deleteTask(id);
      await notificationService.cancelTaskReminder(id);
      return const Right(null);
    } catch (e) {
      return Left('Failed to delete task: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Task>>> getTasksDueToday() async {
    try {
      final tasks = await database.getAllTasks();
      final now = DateTime.now();
      
      final dueToday = tasks.where((task) {
        if (task.dueDate == null || task.isCompleted) return false;
        return task.dueDate!.year == now.year &&
            task.dueDate!.month == now.month &&
            task.dueDate!.day == now.day;
      }).map(_mapToEntity).toList();

      return Right(dueToday);
    } catch (e) {
      return Left('Failed to get tasks due today: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Task>>> getOverdueTasks() async {
    try {
      final tasks = await database.getAllTasks();
      final now = DateTime.now();
      
      final overdue = tasks.where((task) {
        if (task.dueDate == null || task.isCompleted) return false;
        return task.dueDate!.isBefore(now);
      }).map(_mapToEntity).toList();

      return Right(overdue);
    } catch (e) {
      return Left('Failed to get overdue tasks: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Task>>> extractTasksFromNote(String noteId) async {
    try {
      // TODO: Integrate with AI service to extract tasks
      // For now, return empty list
      return const Right([]);
    } catch (e) {
      return Left('Failed to extract tasks: ${e.toString()}');
    }
  }

  /// Map TaskModel to Task entity
  domain.Task _mapToEntity(model.TaskModel task, {bool hasReminder = false}) {
    return domain.Task(
      id: task.id,
      description: task.description,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      isCompleted: task.isCompleted,
      priority: _mapPriorityToEntity(task.priority),
      dueDate: task.dueDate,
      completedAt: task.completedAt,
      noteId: task.noteId,
      hasReminder: hasReminder,
    );
  }

  /// Map model priority to entity priority
  domain.TaskPriority _mapPriorityToEntity(model.TaskPriority priority) {
    switch (priority) {
      case model.TaskPriority.low:
        return domain.TaskPriority.low;
      case model.TaskPriority.medium:
        return domain.TaskPriority.medium;
      case model.TaskPriority.high:
        return domain.TaskPriority.high;
    }
  }

  /// Map entity priority to model priority
  model.TaskPriority _mapPriorityToModel(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.none:
      case domain.TaskPriority.low:
        return model.TaskPriority.low;
      case domain.TaskPriority.medium:
        return model.TaskPriority.medium;
      case domain.TaskPriority.high:
        return model.TaskPriority.high;
    }
  }
}
