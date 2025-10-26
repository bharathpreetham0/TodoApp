import 'package:dartz/dartz.dart' hide Task;
import '../entities/task.dart';

/// Repository interface for Task operations
/// This is a contract that data layer must implement
/// Using Either for functional error handling (Left = Error, Right = Success)
abstract class TaskRepository {
  /// Create a new task
  Future<Either<String, Task>> createTask({
    required String description,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    String? noteId,
    bool createReminder = false,
  });

  /// Get all tasks with optional filters
  Future<Either<String, List<Task>>> getTasks({
    bool? isCompleted,
    TaskPriority? priority,
    String? noteId,
  });

  /// Get a single task by ID
  Future<Either<String, Task>> getTaskById(String id);

  /// Update an existing task
  Future<Either<String, Task>> updateTask({
    required String id,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? hasReminder,
  });

  /// Mark task as completed
  Future<Either<String, Task>> completeTask(String id);

  /// Mark task as not completed
  Future<Either<String, Task>> uncompleteTask(String id);

  /// Delete a task by ID
  Future<Either<String, void>> deleteTask(String id);

  /// Get tasks due today
  Future<Either<String, List<Task>>> getTasksDueToday();

  /// Get overdue tasks
  Future<Either<String, List<Task>>> getOverdueTasks();

  /// Extract tasks from note content using AI
  Future<Either<String, List<Task>>> extractTasksFromNote(String noteId);
}
