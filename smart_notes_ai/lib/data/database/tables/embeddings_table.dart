import 'package:drift/drift.dart';

/// Embeddings table - stores vector embeddings for semantic search
class Embeddings extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  BlobColumn get embedding => blob()(); // Vector embedding as blob
  IntColumn get dimension => integer().withDefault(const Constant(384))();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE',
  ];
}
