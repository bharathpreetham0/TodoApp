import 'package:dartz/dartz.dart';
import '../entities/note.dart';

/// Repository interface for Note operations
/// This is a contract that data layer must implement
/// Using Either for functional error handling (Left = Error, Right = Success)
abstract class NoteRepository {
  /// Create a new note
  Future<Either<String, Note>> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  });

  /// Get all notes with optional filters
  Future<Either<String, List<Note>>> getNotes({
    bool? isFavorite,
    bool? isArchived,
    String? searchQuery,
  });

  /// Get a single note by ID
  Future<Either<String, Note>> getNoteById(String id);

  /// Update an existing note
  Future<Either<String, Note>> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
    String? aiSummary,
  });

  /// Delete a note by ID
  Future<Either<String, void>> deleteNote(String id);

  /// Search notes by content or title
  Future<Either<String, List<Note>>> searchNotes(String query);

  /// Get notes by tag
  Future<Either<String, List<Note>>> getNotesByTag(String tag);

  /// Generate AI summary for a note
  Future<Either<String, String>> generateSummary(String noteId);
}
