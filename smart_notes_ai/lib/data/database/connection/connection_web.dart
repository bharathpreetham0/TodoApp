import 'package:drift/web.dart';
import 'package:drift/drift.dart';

QueryExecutor connectToDatabase() {
  // Use in-memory database for web to avoid WebAssembly issues
  // Note: Data will be lost on page refresh
  // For persistent storage, you would need to properly configure sql.js WASM
  return WebDatabase('smart_notes_db', logStatements: true);
}