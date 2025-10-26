import 'package:dartz/dartz.dart' hide Task;
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

/// Use case for getting all tasks with filters
class GetTasksUseCase {
  final TaskRepository repository;

  GetTasksUseCase(this.repository);

  Future<Either<String, List<Task>>> call({
    bool? isCompleted,
    TaskPriority? priority,
    String? noteId,
  }) async {
    return await repository.getTasks(
      isCompleted: isCompleted,
      priority: priority,
      noteId: noteId,
    );
  }
}
