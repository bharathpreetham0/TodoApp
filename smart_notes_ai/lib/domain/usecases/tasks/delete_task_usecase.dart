import 'package:dartz/dartz.dart';
import '../../repositories/task_repository.dart';

/// Use case for deleting a task
class DeleteTaskUseCase {
  final TaskRepository repository;

  DeleteTaskUseCase(this.repository);

  Future<Either<String, void>> call(String id) async {
    if (id.isEmpty) {
      return const Left('Task ID cannot be empty');
    }

    return await repository.deleteTask(id);
  }
}
