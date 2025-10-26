import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'connection/connection.dart';
import 'tables/notes_table.dart';
import 'tables/tasks_table.dart';
import 'tables/reminders_table.dart';
import 'tables/embeddings_table.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';

part 'app_database.g.dart';

/// Main database class for Smart Notes AI
@DriftDatabase(
  tables: [Notes, Tasks, Reminders, Embeddings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        
        // Only create FTS5 on native platforms (not web)
        // Web version of sql.js doesn't include FTS5 by default
        if (!kIsWeb) {
          // Create full-text search virtual table for notes
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
              title, 
              content, 
              summary,
              content=notes,
              content_rowid=rowid
            );
          ''');
          
          // Create triggers to keep FTS table in sync
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
              INSERT INTO notes_fts(rowid, title, content, summary)
              VALUES (new.rowid, new.title, new.content, new.summary);
            END;
          ''');
          
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
              UPDATE notes_fts 
              SET title = new.title, content = new.content, summary = new.summary
              WHERE rowid = new.rowid;
            END;
          ''');
          
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
              DELETE FROM notes_fts WHERE rowid = old.rowid;
            END;
          ''');
        }
        
        // Create indexes for better query performance
        await customStatement('CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_date);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_note ON tasks(note_id);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_time);');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future schema migrations here
      },
    );
  }

  /// Full-text search for notes
  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return [];
    
    // Use FTS5 on native platforms, fallback to LIKE on web
    if (kIsWeb) {
      // Simple LIKE-based search for web (no FTS5)
      final queryPattern = '%$query%';
      return (select(notes)
        ..where((n) => 
          n.title.like(queryPattern) | 
          n.content.like(queryPattern) |
          n.summary.like(queryPattern)
        )
        ..orderBy([(n) => OrderingTerm.desc(n.createdAt)])
        ..limit(50)
      ).get();
    } else {
      // FTS5-based search for native platforms
      final results = await customSelect(
        '''
        SELECT n.* FROM notes n
        JOIN notes_fts fts ON n.rowid = fts.rowid
        WHERE notes_fts MATCH ?
        ORDER BY rank
        LIMIT 50
        ''',
        variables: [Variable.withString(query)],
        readsFrom: {notes},
      ).get();

      return results.map((row) => notes.map(row.data)).toList();
    }
  }

  /// Get notes with their task counts
  Future<List<NoteWithTaskCount>> getNotesWithTaskCounts() async {
    final query = select(notes).join([
      leftOuterJoin(
        tasks,
        tasks.noteId.equalsExp(notes.id),
      ),
    ])..orderBy([OrderingTerm.desc(notes.createdAt)]);

    final results = await query.get();
    
    final Map<String, NoteWithTaskCount> noteMap = {};
    
    for (final row in results) {
      final note = row.readTable(notes);
      final task = row.readTableOrNull(tasks);
      
      if (!noteMap.containsKey(note.id)) {
        noteMap[note.id] = NoteWithTaskCount(
          note: note,
          totalTasks: 0,
          completedTasks: 0,
        );
      }
      
      if (task != null) {
        noteMap[note.id] = noteMap[note.id]!.copyWith(
          totalTasks: noteMap[note.id]!.totalTasks + 1,
          completedTasks: noteMap[note.id]!.completedTasks + 
              (task.isCompleted ? 1 : 0),
        );
      }
    }
    
    return noteMap.values.toList();
  }

  /// Get upcoming reminders
  Future<List<Reminder>> getUpcomingReminders({int days = 7}) async {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    
    return (select(reminders)
          ..where((r) => 
              r.triggerTime.isBiggerOrEqualValue(now) &
              r.triggerTime.isSmallerOrEqualValue(future) &
              r.isTriggered.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.triggerTime)]))
        .get();
  }

  /// Get pending tasks
  Future<List<Task>> getPendingTasks() async {
    return (select(tasks)
          ..where((t) => t.isCompleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.dueDate),
          ]))
        .get();
  }

  // ==================== NOTE CRUD OPERATIONS ====================
  
  /// Create a new note
  Future<NoteModel> createNote(NoteModel noteModel) async {
    final companion = NotesCompanion.insert(
      id: noteModel.id,
      title: noteModel.title,
      content: noteModel.content,
      summary: Value.absentIfNull(noteModel.summary),
      category: Value.absentIfNull(noteModel.category),
      tags: Value(noteModel.tags.join(',')),
      createdAt: noteModel.createdAt,
      updatedAt: noteModel.updatedAt,
      isEncrypted: Value(noteModel.isEncrypted),
      isFavorite: Value(noteModel.isFavorite),
      isArchived: Value(noteModel.isArchived),
    );
    
    await into(notes).insert(companion);
    return (await getNoteById(noteModel.id))!;
  }

  /// Get all notes
  Future<List<NoteModel>> getAllNotes() async {
    final notesList = await (select(notes)
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
    ).get();
    
    return notesList.map(_mapNoteToModel).toList();
  }

  /// Get note by ID
  Future<NoteModel?> getNoteById(String id) async {
    final note = await (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
    return note != null ? _mapNoteToModel(note) : null;
  }

  /// Update a note
  Future<NoteModel> updateNote(NoteModel noteModel) async {
    final companion = NotesCompanion(
      id: Value(noteModel.id),
      title: Value(noteModel.title),
      content: Value(noteModel.content),
      summary: Value.absentIfNull(noteModel.summary),
      category: Value.absentIfNull(noteModel.category),
      tags: Value(noteModel.tags.join(',')),
      updatedAt: Value(DateTime.now()),
      isEncrypted: Value(noteModel.isEncrypted),
      isFavorite: Value(noteModel.isFavorite),
      isArchived: Value(noteModel.isArchived),
    );
    
    await (update(notes)..where((n) => n.id.equals(noteModel.id))).write(companion);
    return (await getNoteById(noteModel.id))!;
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    await (delete(notes)..where((n) => n.id.equals(id))).go();
    // Also delete associated tasks
    await (delete(tasks)..where((t) => t.noteId.equals(id))).go();
  }

  // ==================== TASK CRUD OPERATIONS ====================
  
  /// Create a new task
  Future<TaskModel> createTask(TaskModel taskModel) async {
    final companion = TasksCompanion.insert(
      id: taskModel.id,
      noteId: Value.absentIfNull(taskModel.noteId),
      description: taskModel.description,
      dueDate: Value.absentIfNull(taskModel.dueDate),
      priority: Value(taskModel.priority.value),
      isCompleted: Value(taskModel.isCompleted),
      completedAt: Value.absentIfNull(taskModel.completedAt),
      createdAt: taskModel.createdAt,
      updatedAt: taskModel.updatedAt,
    );
    
    await into(tasks).insert(companion);
    return (await getTaskById(taskModel.id))!;
  }

  /// Get all tasks
  Future<List<TaskModel>> getAllTasks() async {
    final tasksList = await (select(tasks)
      ..orderBy([
        (t) => OrderingTerm.asc(t.isCompleted),
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.asc(t.dueDate),
      ])
    ).get();
    
    return tasksList.map(_mapTaskToModel).toList();
  }

  /// Get task by ID
  Future<TaskModel?> getTaskById(String id) async {
    final task = await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    return task != null ? _mapTaskToModel(task) : null;
  }

  /// Update a task
  Future<TaskModel> updateTask(TaskModel taskModel) async {
    final companion = TasksCompanion(
      id: Value(taskModel.id),
      noteId: Value(taskModel.noteId),
      description: Value(taskModel.description),
      dueDate: Value(taskModel.dueDate),
      priority: Value(taskModel.priority.value),
      isCompleted: Value(taskModel.isCompleted),
      completedAt: Value(taskModel.completedAt),
      updatedAt: Value(DateTime.now()),
    );
    
    await (update(tasks)..where((t) => t.id.equals(taskModel.id))).write(companion);
    return (await getTaskById(taskModel.id))!;
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  // ==================== MAPPING FUNCTIONS ====================
  
  /// Map Drift Note to NoteModel
  NoteModel _mapNoteToModel(Note note) {
    return NoteModel(
      id: note.id,
      title: note.title,
      content: note.content,
      summary: note.summary,
      category: note.category,
      tags: (note.tags != null && note.tags!.isNotEmpty) ? note.tags!.split(',') : [],
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      isEncrypted: note.isEncrypted,
      isFavorite: note.isFavorite,
      isArchived: note.isArchived,
    );
  }

  /// Map Drift Task to TaskModel
  TaskModel _mapTaskToModel(Task task) {
    return TaskModel(
      id: task.id,
      noteId: task.noteId,
      description: task.description,
      dueDate: task.dueDate,
      priority: TaskPriority.fromValue(task.priority),
      isCompleted: task.isCompleted,
      completedAt: task.completedAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }
}

/// Helper class for notes with task counts
class NoteWithTaskCount {
  final Note note;
  final int totalTasks;
  final int completedTasks;

  NoteWithTaskCount({
    required this.note,
    required this.totalTasks,
    required this.completedTasks,
  });

  NoteWithTaskCount copyWith({
    Note? note,
    int? totalTasks,
    int? completedTasks,
  }) {
    return NoteWithTaskCount(
      note: note ?? this.note,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
    );
  }
}
