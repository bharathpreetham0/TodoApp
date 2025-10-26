import 'package:dartz/dartz.dart' hide Task;
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

/// Use case for completing a task
class CompleteTaskUseCase {
  final TaskRepository repository;

  CompleteTaskUseCase(this.repository);

  Future<Either<String, Task>> call(String id) async {
    if (id.isEmpty) {
      return const Left('Task ID cannot be empty');
    }

    return await repository.completeTask(id);
  }
}
