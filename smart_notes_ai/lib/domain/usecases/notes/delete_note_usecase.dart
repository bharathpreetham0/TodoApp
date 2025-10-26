import 'package:dartz/dartz.dart';
import '../../repositories/note_repository.dart';

/// Use case for deleting a note
class DeleteNoteUseCase {
  final NoteRepository repository;

  DeleteNoteUseCase(this.repository);

  Future<Either<String, void>> call(String id) async {
    if (id.isEmpty) {
      return const Left('Note ID cannot be empty');
    }

    return await repository.deleteNote(id);
  }
}
