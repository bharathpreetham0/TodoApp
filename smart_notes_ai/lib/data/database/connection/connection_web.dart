import 'package:drift/web.dart';
import 'package:drift/drift.dart';

QueryExecutor connectToDatabase() {
  // Use volatile (in-memory) storage for web to avoid sql.js issues
  // Data will be lost on page refresh, but it's better for demo purposes
  return WebDatabase.withStorage(
    DriftWebStorage.volatile(),
  );
}