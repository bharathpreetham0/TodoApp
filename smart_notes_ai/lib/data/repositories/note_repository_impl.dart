import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/note.dart' as domain;
import '../../domain/repositories/note_repository.dart';
import '../database/app_database.dart';
import '../models/note_model.dart';

/// Implementation of NoteRepository
/// This bridges the domain layer with the data layer
class NoteRepositoryImpl implements NoteRepository {
  final AppDatabase database;
  final Uuid uuid;

  NoteRepositoryImpl({
    required this.database,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  @override
  Future<Either<String, domain.Note>> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    try {
      final now = DateTime.now();
      final id = uuid.v4();

      final note = await database.createNote(
        NoteModel(
          id: id,
          title: title,
          content: content,
          tags: tags,
          createdAt: now,
          updatedAt: now,
        ),
      );

      return Right(_mapToEntity(note));
    } catch (e) {
      return Left('Failed to create note: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Note>>> getNotes({
    bool? isFavorite,
    bool? isArchived,
    String? searchQuery,
  }) async {
    try {
      final notes = await database.getAllNotes();
      
      var filtered = notes.where((note) {
        if (isFavorite != null && note.isFavorite != isFavorite) return false;
        if (isArchived != null && note.isArchived != isArchived) return false;
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          return note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query);
        }
        return true;
      }).toList();

      // Sort by updated date (newest first)
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return Right(filtered.map(_mapToEntity).toList());
    } catch (e) {
      return Left('Failed to get notes: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Note>> getNoteById(String id) async {
    try {
      final note = await database.getNoteById(id);
      if (note == null) {
        return const Left('Note not found');
      }
      return Right(_mapToEntity(note));
    } catch (e) {
      return Left('Failed to get note: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, domain.Note>> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
    String? aiSummary,
  }) async {
    try {
      final existingNote = await database.getNoteById(id);
      if (existingNote == null) {
        return const Left('Note not found');
      }

      final updatedNote = await database.updateNote(
        existingNote.copyWith(
          title: title ?? existingNote.title,
          content: content ?? existingNote.content,
          isFavorite: isFavorite ?? existingNote.isFavorite,
          isArchived: isArchived ?? existingNote.isArchived,
          tags: tags ?? existingNote.tags,
          summary: aiSummary ?? existingNote.summary,
          updatedAt: DateTime.now(),
        ),
      );

      return Right(_mapToEntity(updatedNote));
    } catch (e) {
      return Left('Failed to update note: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, void>> deleteNote(String id) async {
    try {
      await database.deleteNote(id);
      return const Right(null);
    } catch (e) {
      return Left('Failed to delete note: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, List<domain.Note>>> searchNotes(String query) async {
    return getNotes(searchQuery: query);
  }

  @override
  Future<Either<String, List<domain.Note>>> getNotesByTag(String tag) async {
    try {
      final notes = await database.getAllNotes();
      final filtered = notes
          .where((note) => note.tags.contains(tag))
          .map(_mapToEntity)
          .toList();
      return Right(filtered);
    } catch (e) {
      return Left('Failed to get notes by tag: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, String>> generateSummary(String noteId) async {
    try {
      // This would integrate with AI service
      // For now, return a placeholder
      final note = await database.getNoteById(noteId);
      if (note == null) {
        return const Left('Note not found');
      }
      
      // TODO: Integrate with actual AI service
      final summary = 'Summary: ${note.content.substring(0, note.content.length > 100 ? 100 : note.content.length)}...';
      
      await database.updateNote(note.copyWith(summary: summary));
      
      return Right(summary);
    } catch (e) {
      return Left('Failed to generate summary: ${e.toString()}');
    }
  }

  /// Map NoteModel to Note entity
  domain.Note _mapToEntity(NoteModel model) {
    return domain.Note(
      id: model.id,
      title: model.title,
      content: model.content,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isFavorite: model.isFavorite,
      isArchived: model.isArchived,
      tags: model.tags,
      aiSummary: model.summary,
    );
  }
}
