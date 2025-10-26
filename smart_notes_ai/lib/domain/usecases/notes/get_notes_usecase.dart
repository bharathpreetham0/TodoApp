import 'package:dartz/dartz.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';

/// Use case for getting all notes with filters
class GetNotesUseCase {
  final NoteRepository repository;

  GetNotesUseCase(this.repository);

  Future<Either<String, List<Note>>> call({
    bool? isFavorite,
    bool? isArchived,
    String? searchQuery,
  }) async {
    return await repository.getNotes(
      isFavorite: isFavorite,
      isArchived: isArchived,
      searchQuery: searchQuery,
    );
  }
}
