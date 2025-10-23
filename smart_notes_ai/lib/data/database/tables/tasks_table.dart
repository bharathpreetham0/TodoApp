import 'package:drift/drift.dart';
import 'notes_table.dart';

/// Tasks table - stores actionable items extracted from notes
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().nullable()();
  TextColumn get description => text().withLength(min: 1, max: 1000)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0=low, 1=medium, 2=high
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE',
  ];
}
