import 'package:dartz/dartz.dart' hide Task;
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

/// Use case for updating a task
class UpdateTaskUseCase {
  final TaskRepository repository;

  UpdateTaskUseCase(this.repository);

  Future<Either<String, Task>> call({
    required String id,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? hasReminder,
  }) async {
    if (id.isEmpty) {
      return const Left('Task ID cannot be empty');
    }

    // Validate description if provided
    if (description != null && description.trim().isEmpty) {
      return const Left('Task description cannot be empty');
    }

    // Validate due date is not in the past
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      return const Left('Due date cannot be in the past');
    }

    return await repository.updateTask(
      id: id,
      description: description?.trim(),
      priority: priority,
      dueDate: dueDate,
      hasReminder: hasReminder,
    );
  }
}
