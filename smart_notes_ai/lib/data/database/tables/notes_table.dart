import 'package:drift/drift.dart';

/// Notes table - stores user notes with optional encryption
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get content => text()();
  BlobColumn get encryptedContent => blob().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON array of tags
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'CHECK(length(title) > 0)',
  ];
}
