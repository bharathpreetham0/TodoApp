import 'package:dartz/dartz.dart' hide Task;
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

/// Use case for creating a task
class CreateTaskUseCase {
  final TaskRepository repository;

  CreateTaskUseCase(this.repository);

  Future<Either<String, Task>> call({
    required String description,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    String? noteId,
    bool createReminder = false,
  }) async {
    // Business logic validation
    if (description.trim().isEmpty) {
      return const Left('Task description cannot be empty');
    }

    // Validate due date is not in the past
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      return const Left('Due date cannot be in the past');
    }

    return await repository.createTask(
      description: description.trim(),
      priority: priority,
      dueDate: dueDate,
      noteId: noteId,
      createReminder: createReminder,
    );
  }
}
