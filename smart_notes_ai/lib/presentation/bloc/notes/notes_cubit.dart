import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../../data/models/note_model.dart';
import '../../../data/database/app_database.dart';
import '../../../services/ai/ai_service.dart';
import '../../../services/encryption/encryption_service.dart';

// States
abstract class NotesState extends Equatable {
  const NotesState();
}

class NotesInitial extends NotesState {
  @override
  List<Object> get props => [];
}

class NotesLoading extends NotesState {
  @override
  List<Object> get props => [];
}

class NotesLoaded extends NotesState {
  final List<NoteModel> notes;
  final String? filterCategory;
  final String sortBy;

  const NotesLoaded({
    required this.notes,
    this.filterCategory,
    this.sortBy = 'date',
  });

  NotesLoaded copyWith({
    List<NoteModel>? notes,
    String? filterCategory,
    String? sortBy,
  }) {
    return NotesLoaded(
      notes: notes ?? this.notes,
      filterCategory: filterCategory ?? this.filterCategory,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [notes, filterCategory, sortBy];
}

class NotesError extends NotesState {
  final String message;

  const NotesError(this.message);

  @override
  List<Object> get props => [message];
}

class NoteOperationInProgress extends NotesState {
  final String operation;

  const NoteOperationInProgress(this.operation);

  @override
  List<Object> get props => [operation];
}

// Cubit
class NotesCubit extends Cubit<NotesState> {
  final AppDatabase _database;
  final AIService _aiService;
  final EncryptionService _encryptionService;
  final Uuid _uuid = const Uuid();

  NotesCubit({
    required AppDatabase database,
    required AIService aiService,
    required EncryptionService encryptionService,
  })  : _database = database,
        _aiService = aiService,
        _encryptionService = encryptionService,
        super(NotesInitial());

  /// Load all notes from database
  Future<void> loadNotes({String? category, String sortBy = 'date'}) async {
    emit(NotesLoading());
    try {
      List<Note> driftNotes;
      
      if (category != null) {
        // Filter by category
        driftNotes = await (_database.select(_database.notes)
              ..where((n) => n.category.equals(category))
              ..orderBy([(n) => _getSortOrder(sortBy, n)]))
            .get();
      } else {
        // Get all notes
        driftNotes = await (_database.select(_database.notes)
              ..orderBy([(n) => _getSortOrder(sortBy, n)]))
            .get();
      }
      
      // Convert Drift Note objects to NoteModel objects
      final notes = driftNotes.map((driftNote) => NoteModel(
        id: driftNote.id,
        title: driftNote.title,
        content: driftNote.content,
        summary: driftNote.summary,
        category: driftNote.category,
        tags: driftNote.tags?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        createdAt: driftNote.createdAt,
        updatedAt: driftNote.updatedAt,
        isEncrypted: driftNote.isEncrypted,
        isFavorite: driftNote.isFavorite,
        isArchived: driftNote.isArchived,
      )).toList();
      
      emit(NotesLoaded(
        notes: notes,
        filterCategory: category,
        sortBy: sortBy,
      ));
    } catch (e) {
      emit(NotesError('Failed to load notes: $e'));
    }
  }

  /// Helper method to get sort order
  OrderingTerm _getSortOrder(String sortBy, $NotesTable n) {
    switch (sortBy) {
      case 'title':
        return OrderingTerm.asc(n.title);
      case 'updated':
        return OrderingTerm.desc(n.updatedAt);
      case 'date':
      default:
        return OrderingTerm.desc(n.createdAt);
    }
  }

  /// Create a new note
  Future<void> createNote({
    required String title,
    required String content,
    String? category,
    List<String> tags = const [],
    bool encrypt = false,
    bool autoSummarize = true,
  }) async {
    emit(const NoteOperationInProgress('Creating note...'));
    
    try {
      final now = DateTime.now();
      String? summary;
      List<String>? insights;
      List<String>? keyPoints;

      // Generate AI summary if enabled
      if (autoSummarize && _aiService.isEnabled && content.isNotEmpty) {
        final result = await _aiService.summarizeNote(content);
        if (result != null) {
          summary = result.summary;
          insights = result.insights;
          keyPoints = result.keyPoints;
        }
      }

      // Encrypt content if requested
      final finalContent = encrypt
          ? await _encryptionService.encryptText(content)
          : null;

      final note = NoteModel(
        id: _uuid.v4(),
        title: title,
        content: content,
        summary: summary,
        category: category,
        tags: tags,
        createdAt: now,
        updatedAt: now,
        isEncrypted: encrypt,
      );

      // Insert into database
      await _database.into(_database.notes).insert(NotesCompanion.insert(
        id: note.id,
        title: note.title,
        content: encrypt ? '' : note.content, // Store empty content if encrypted
        encryptedContent: encrypt ? Value(await _encryptionService.encryptText(content)) : const Value.absent(),
        summary: Value.ofNullable(note.summary),
        category: Value.ofNullable(note.category),
        tags: Value.ofNullable(note.tags.join(',')),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        isEncrypted: Value(note.isEncrypted),
        isFavorite: Value(note.isFavorite),
        isArchived: Value(note.isArchived),
      ));

      // Extract tasks if content has actionable items
      if (_aiService.isEnabled && content.isNotEmpty) {
        final taskResult = await _aiService.extractTasks(content);
        if (taskResult != null && taskResult.tasks.isNotEmpty) {
          // TODO: Create tasks in database
        }
      }

      await loadNotes();
    } catch (e) {
      emit(NotesError('Failed to create note: $e'));
    }
  }

  /// Update existing note
  Future<void> updateNote({
    required String id,
    String? title,
    String? content,
    String? summary,
    String? category,
    List<String>? tags,
    bool? isFavorite,
    bool? isArchived,
  }) async {
    emit(const NoteOperationInProgress('Updating note...'));
    
    try {
      final updateCompanion = NotesCompanion(
        id: Value(id),
        title: title != null ? Value(title) : const Value.absent(),
        content: content != null ? Value(content) : const Value.absent(),
        summary: summary != null ? Value(summary) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        tags: tags != null ? Value(tags.join(',')) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isFavorite: isFavorite != null ? Value(isFavorite) : const Value.absent(),
        isArchived: isArchived != null ? Value(isArchived) : const Value.absent(),
      );

      await (_database.update(_database.notes)
        ..where((n) => n.id.equals(id))).write(updateCompanion);
      
      await loadNotes();
    } catch (e) {
      emit(NotesError('Failed to update note: $e'));
    }
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    emit(const NoteOperationInProgress('Deleting note...'));
    
    try {
      await (_database.delete(_database.notes)
        ..where((n) => n.id.equals(id))).go();
      
      await loadNotes();
    } catch (e) {
      emit(NotesError('Failed to delete note: $e'));
    }
  }

  /// Summarize existing note
  Future<void> summarizeNote(String id, String content) async {
    if (!_aiService.isEnabled) {
      emit(const NotesError('AI service is disabled'));
      return;
    }

    emit(const NoteOperationInProgress('Generating summary...'));
    
    try {
      final result = await _aiService.summarizeNote(content);
      
      if (result != null) {
        await updateNote(id: id, summary: result.summary);
      } else {
        emit(const NotesError('Failed to generate summary'));
      }
    } catch (e) {
      emit(NotesError('Failed to summarize note: $e'));
    }
  }

  /// Archive a note
  Future<void> archiveNote(String id) async {
    await updateNote(id: id, isArchived: true);
  }

  /// Unarchive a note
  Future<void> unarchiveNote(String id) async {
    await updateNote(id: id, isArchived: false);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id, bool currentStatus) async {
    await updateNote(id: id, isFavorite: !currentStatus);
  }

  /// Filter notes by category
  Future<void> filterByCategory(String? category) async {
    await loadNotes(category: category);
  }

  /// Sort notes
  Future<void> sortNotes(String sortBy) async {
    final currentState = state;
    if (currentState is NotesLoaded) {
      await loadNotes(
        category: currentState.filterCategory,
        sortBy: sortBy,
      );
    }
  }

  /// Search notes
  Future<void> searchNotes(String query) async {
    if (query.isEmpty) {
      await loadNotes();
      return;
    }

    emit(NotesLoading());
    try {
      // TODO: Implement FTS search once generated code is available
      emit(const NotesLoaded(notes: []));
    } catch (e) {
      emit(NotesError('Failed to search notes: $e'));
    }
  }
}
