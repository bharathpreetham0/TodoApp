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
