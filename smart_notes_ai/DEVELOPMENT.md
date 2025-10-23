# Smart Notes AI - Development Guide

## 🏗️ Architecture Overview

Smart Notes AI follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│        Presentation Layer (UI)          │
│  - Screens, Widgets, BLoC/Cubit         │
└─────────────────────────────────────────┘
                  │
┌─────────────────────────────────────────┐
│          Domain Layer                   │
│  - Entities, Use Cases, Repositories    │
└─────────────────────────────────────────┘
                  │
┌─────────────────────────────────────────┐
│          Data Layer                     │
│  - Models, Database, Services           │
└─────────────────────────────────────────┘
                  │
┌─────────────────────────────────────────┐
│       Native Layer (FFI)                │
│  - llama.cpp bindings, Platform code    │
└─────────────────────────────────────────┘
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/                     # Core utilities
│   ├── constants/           # App constants
│   ├── theme/               # Theme configuration
│   ├── utils/               # Helper functions
│   └── config/              # App configuration
├── data/                    # Data layer
│   ├── database/           # Drift database
│   │   ├── app_database.dart
│   │   ├── tables/         # Table definitions
│   │   └── daos/           # Data Access Objects
│   ├── models/             # Data models
│   └── repositories/       # Repository implementations
├── domain/                  # Domain layer
│   ├── entities/           # Business entities
│   ├── repositories/       # Repository interfaces
│   └── usecases/           # Business logic
├── services/               # Services
│   ├── ai/                # AI service (llama.cpp)
│   ├── encryption/        # Encryption service
│   ├── notifications/     # Notification service
│   └── search/            # Search service
├── presentation/           # UI layer
│   ├── bloc/              # BLoC state management
│   ├── screens/           # Screen widgets
│   └── widgets/           # Reusable widgets
└── native/                # Native code interface
    └── llama_ffi.dart     # FFI bindings
```

## 🔄 Data Flow

### Creating a Note with AI

```
User Input (Screen)
    ↓
NoteCubit.createNote()
    ↓
AIService.summarizeNote()
    ↓
LlamaFFI.generate() [Native]
    ↓
Parse JSON Response
    ↓
Database.insert()
    ↓
Emit New State
    ↓
UI Updates
```

## 🎯 Adding New Features

### 1. Adding a New Screen

```dart
// 1. Create screen file
// lib/presentation/screens/my_feature/my_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Feature')),
      body: BlocBuilder<MyCubit, MyState>(
        builder: (context, state) {
          // Build UI based on state
          return Container();
        },
      ),
    );
  }
}
```

### 2. Adding a New Database Table

```dart
// 1. Define table in lib/data/database/tables/
import 'package:drift/drift.dart';

class MyTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// 2. Add to database
@DriftDatabase(
  tables: [Notes, Tasks, Reminders, Embeddings, MyTable],
)
class AppDatabase extends _$AppDatabase {
  // ...
}

// 3. Regenerate code
// dart run build_runner build
```

### 3. Adding a New AI Prompt

```dart
// Add to lib/services/ai/prompt_templates.dart

class PromptTemplates {
  static const String myFeatureSystem = '''
System prompt for my feature...
''';

  static String myFeatureUser(String input) => '''
User prompt for my feature with $input...
''';
}

// Use in AIService
Future<String?> myFeature(String input) async {
  final prompt = PromptTemplates.buildPrompt(
    system: PromptTemplates.myFeatureSystem,
    user: PromptTemplates.myFeatureUser(input),
  );
  
  return await _llama.generate(prompt: prompt);
}
```

## 🧪 Testing Strategy

### Unit Tests

```dart
// test/services/ai/ai_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('AIService', () {
    late AIService aiService;
    late MockLlamaFFI mockLlama;

    setUp(() {
      mockLlama = MockLlamaFFI();
      aiService = AIService(llama: mockLlama);
    });

    test('summarizeNote returns valid result', () async {
      // Arrange
      when(mockLlama.generate(prompt: anyNamed('prompt')))
          .thenAnswer((_) async => '{"summary": "test"}');

      // Act
      final result = await aiService.summarizeNote('test note');

      // Assert
      expect(result, isNotNull);
      expect(result!.summary, equals('test'));
    });
  });
}
```

### Widget Tests

```dart
// test/presentation/screens/home_screen_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen shows notes list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen()),
    );

    expect(find.text('Smart Notes AI'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
```

## 🔧 State Management with BLoC

### Creating a BLoC

```dart
// lib/presentation/bloc/notes/notes_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// State
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
  
  const NotesLoaded(this.notes);
  
  @override
  List<Object> get props => [notes];
}

class NotesError extends NotesState {
  final String message;
  
  const NotesError(this.message);
  
  @override
  List<Object> get props => [message];
}

// Cubit
class NotesCubit extends Cubit<NotesState> {
  final AppDatabase _database;
  final AIService _aiService;

  NotesCubit(this._database, this._aiService) : super(NotesInitial());

  Future<void> loadNotes() async {
    emit(NotesLoading());
    try {
      final notes = await _database.select(_database.notes).get();
      emit(NotesLoaded(notes.map((n) => NoteModel.fromData(n)).toList()));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> createNote(String title, String content) async {
    try {
      // Generate summary with AI
      final summary = await _aiService.summarizeNote(content);
      
      // Insert into database
      await _database.into(_database.notes).insert(
        NotesCompanion.insert(
          id: uuid.v4(),
          title: title,
          content: content,
          summary: Value(summary?.summary),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Reload notes
      await loadNotes();
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }
}
```

## 🎨 UI Design Guidelines

### Design Principles

1. **Minimalist**: Clean, focused interface
2. **Privacy-first**: Visual indicators for encryption/AI
3. **Fast**: Instant feedback, smooth animations
4. **Accessible**: High contrast, readable fonts

### Color Usage

```dart
// Primary actions
color: Theme.of(context).colorScheme.primary

// AI-related features
color: AppTheme.aiPurple

// Success states
color: AppTheme.successGreen

// Background surfaces
color: Theme.of(context).colorScheme.surface
```

### Common Widgets

```dart
// AI Indicator Badge
Widget aiIndicator() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.aiPurple,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
        SizedBox(width: 4),
        Text('AI', style: TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );
}

// Collapsible AI Insight Card
class AIInsightCard extends StatelessWidget {
  final String summary;
  final List<String> insights;
  
  const AIInsightCard({
    required this.summary,
    required this.insights,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.auto_awesome, color: AppTheme.aiPurple),
        title: Text('AI Summary'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                SizedBox(height: 12),
                ...insights.map((i) => Text('• $i')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 🔐 Security Best Practices

### Encryption

```dart
// Always encrypt sensitive notes
if (note.isEncrypted) {
  final encrypted = await encryptionService.encryptText(note.content);
  // Store encrypted bytes
} else {
  // Store plain text
}
```

### Biometric Authentication

```dart
final authenticated = await localAuth.authenticate(
  localizedReason: 'Unlock Smart Notes',
  options: AuthenticationOptions(
    stickyAuth: true,
    biometricOnly: true,
  ),
);
```

### Secure Storage

```dart
// NEVER store encryption keys in SharedPreferences
// ALWAYS use FlutterSecureStorage
await secureStorage.write(key: 'sensitive_key', value: value);
```

## 📊 Performance Optimization

### Database Queries

```dart
// ✅ Good: Use indexes
select(notes)
  ..where((n) => n.category.equals('Work'))  // Indexed
  ..orderBy([(n) => OrderingTerm.desc(n.createdAt)])  // Indexed
  
// ❌ Bad: Full table scan
select(notes)
  ..where((n) => n.content.contains('keyword'))  // Not indexed
```

### AI Model Loading

```dart
// Lazy load model only when needed
class AIService {
  Future<void> _ensureModelLoaded() async {
    if (!_isModelLoaded) {
      await _llama.initialize();
      _isModelLoaded = true;
    }
  }
}
```

### Widget Rebuilds

```dart
// ✅ Use const constructors
const Text('Hello')

// ✅ Use BlocBuilder with buildWhen
BlocBuilder<NotesCubit, NotesState>(
  buildWhen: (previous, current) => previous != current,
  builder: (context, state) { ... },
)
```

## 🐛 Debugging Tips

### Enable Logging

```dart
// Adjust log level in main.dart
Logger.level = Level.debug;  // Development
Logger.level = Level.warning;  // Production
```

### Database Inspection

```bash
# Android
adb shell
cd /data/data/com.yourapp.smart_notes_ai/databases
sqlite3 smart_notes.db
.schema
SELECT * FROM notes;

# iOS
# Use Xcode Devices window to download app container
```

### AI Response Debugging

```dart
// Log full AI responses
_logger.d('AI Response: $response');
_logger.d('Extracted JSON: ${PromptTemplates.extractJson(response)}');
```

## 🚀 Release Checklist

- [ ] All tests passing
- [ ] No debug logs in production code
- [ ] Encryption tested on real device
- [ ] AI model bundled and tested
- [ ] App size < 100MB per ABI
- [ ] Performance benchmarks met
- [ ] Privacy policy included
- [ ] No network permissions (verify manifest)
- [ ] Code obfuscation enabled
- [ ] Signed release build created

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [BLoC Pattern](https://bloclibrary.dev/)
- [Drift Database](https://drift.simonbinder.eu/)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)

---

Happy coding! 🎉
