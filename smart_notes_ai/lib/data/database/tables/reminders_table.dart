import 'package:drift/drift.dart';
import 'notes_table.dart';
import 'tasks_table.dart';

/// Reminders table - stores time-based notifications
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get noteId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get triggerTime => dateTime()();
  BoolColumn get isTriggered => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()(); // RRULE format
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE',
    'FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE',
  ];
}
