import 'package:dartz/dartz.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';

/// Use case for creating a note
/// Follows Single Responsibility Principle
class CreateNoteUseCase {
  final NoteRepository repository;

  CreateNoteUseCase(this.repository);

  Future<Either<String, Note>> call({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    // Business logic validation
    if (title.trim().isEmpty && content.trim().isEmpty) {
      return const Left('Title and content cannot both be empty');
    }

    return await repository.createNote(
      title: title.trim(),
      content: content.trim(),
      tags: tags,
    );
  }
}
