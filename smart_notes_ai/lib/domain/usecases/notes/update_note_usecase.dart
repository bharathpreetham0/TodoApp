import 'package:dartz/dartz.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';

/// Use case for updating a note
class UpdateNoteUseCase {
  final NoteRepository repository;

  UpdateNoteUseCase(this.repository);

  Future<Either<String, Note>> call({
    required String id,
    String? title,
    String? content,
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
    String? aiSummary,
  }) async {
    // Validation: at least one field must be provided
    if (title == null &&
        content == null &&
        isFavorite == null &&
        isArchived == null &&
        tags == null &&
        aiSummary == null) {
      return const Left('At least one field must be provided for update');
    }

    return await repository.updateNote(
      id: id,
      title: title?.trim(),
      content: content?.trim(),
      isFavorite: isFavorite,
      isArchived: isArchived,
      tags: tags,
      aiSummary: aiSummary,
    );
  }
}
