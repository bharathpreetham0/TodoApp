# 🚀 Smart Notes AI - Quick Reference

## 📂 Project Overview

**Smart Notes AI** is a fully offline, privacy-first AI notepad for mobile devices.

- **Platform**: Flutter (iOS & Android)
- **Database**: SQLite with Drift
- **AI**: llama.cpp with Phi-3-mini
- **State Management**: BLoC/Cubit
- **Security**: AES-256 encryption, biometric auth

## ⚡ Quick Start

```bash
# 1. Setup
cd smart_notes_ai
./setup.sh

# 2. Generate database code
dart run build_runner build

# 3. Run app
flutter run
```

## 📁 File Structure

```
smart_notes_ai/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/theme/                  # Theming
│   ├── data/
│   │   ├── database/               # Database tables & DAOs
│   │   └── models/                 # Data models
│   ├── services/
│   │   ├── ai/                     # AI service
│   │   ├── encryption/             # Encryption
│   │   └── notifications/          # Notifications
│   ├── presentation/
│   │   ├── screens/                # UI screens
│   │   └── bloc/                   # State management
│   └── native/                     # FFI bindings
├── assets/
│   ├── models/                     # AI models (.gguf)
│   └── prompts/                    # Prompt templates
├── android/                        # Android-specific
├── ios/                           # iOS-specific
└── docs/                          # Documentation
    ├── README.md                  # Project overview
    ├── SETUP.md                   # Setup guide
    ├── DEVELOPMENT.md             # Dev guide
    ├── ARCHITECTURE.md            # Architecture
    ├── TODO.md                    # Task list
    └── PRIVACY.md                 # Privacy policy
```

## 🔑 Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App initialization & entry point |
| `lib/data/database/app_database.dart` | Database definition |
| `lib/services/ai/ai_service.dart` | AI operations |
| `lib/services/encryption/encryption_service.dart` | Encryption |
| `lib/native/llama_ffi.dart` | llama.cpp FFI bindings |
| `pubspec.yaml` | Dependencies |

## 🛠️ Common Commands

```bash
# Install dependencies
flutter pub get

# Generate database code
dart run build_runner build --delete-conflicting-outputs

# Run app (debug)
flutter run

# Run app (release)
flutter run --release

# Run tests
flutter test

# Build Android APK
flutter build apk --release --split-per-abi

# Build iOS IPA
flutter build ios --release

# Clean build
flutter clean
```

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test

# Specific test file
flutter test test/services/ai/ai_service_test.dart

# With coverage
flutter test --coverage
```

## 🎨 UI Components

### Theme Colors
- Primary: `#2196F3` (Blue)
- Accent: `#FFC107` (Amber)
- AI Indicator: `#9C27B0` (Purple)
- Success: `#4CAF50` (Green)

### Key Widgets
- `HomeScreen` - Main navigation
- `NoteEditorScreen` - Create/edit notes
- `TasksBoardScreen` - Task management
- `SearchScreen` - Semantic search

## 🗄️ Database Schema

```sql
-- Notes
CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    summary TEXT,
    created_at INTEGER
);

-- Tasks
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    note_id TEXT,
    description TEXT NOT NULL,
    priority INTEGER DEFAULT 0,
    due_date INTEGER
);

-- Reminders
CREATE TABLE reminders (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    trigger_time INTEGER NOT NULL
);
```

## 🤖 AI Prompts

Located in `assets/prompts/`:
- `summarize.txt` - Note summarization
- `extract_tasks.txt` - Task extraction
- `search.txt` - Semantic search

## 🔐 Security Features

- **Encryption**: AES-256-GCM
- **Key Storage**: FlutterSecureStorage (Keychain/Keystore)
- **Biometric**: Face ID, Touch ID, Fingerprint
- **Privacy**: No network permissions

## 📱 Platform-Specific

### Android
- Min SDK: 24 (Android 7.0)
- Target SDK: 34 (Android 14)
- Permissions: Notifications, Biometric

### iOS
- Min iOS: 12.0
- Frameworks: UserNotifications, LocalAuthentication

## 🐛 Debugging

```bash
# Enable verbose logging
flutter run -v

# Profile mode
flutter run --profile

# Dart DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Android logcat
adb logcat | grep flutter

# iOS logs
idevicesyslog
```

## 📦 Dependencies

### Core
- `flutter_bloc` - State management
- `drift` - Database
- `encrypt` - Encryption
- `ffi` - Native interop

### Platform
- `flutter_local_notifications` - Notifications
- `local_auth` - Biometric
- `flutter_secure_storage` - Secure storage

### Dev
- `build_runner` - Code generation
- `drift_dev` - Drift codegen
- `mockito` - Testing

## 🚨 Common Issues

### 1. Model Not Found
```
Error: Model file not found
```
**Solution**: Download model to `assets/models/`

### 2. Build Runner Fails
```
Error: Build failed
```
**Solution**: 
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 3. FFI Library Not Found
```
Error: Failed to load libllama.so
```
**Solution**: Build llama.cpp native libraries (see SETUP.md)

## 🎯 Development Workflow

1. **Make changes** to Dart code
2. **Hot reload** with `r` in terminal
3. **Generate code** if database changed:
   ```bash
   dart run build_runner build
   ```
4. **Test** changes
5. **Commit** to git

## 📊 Performance Tips

- Use `const` constructors
- Minimize widget rebuilds
- Use `BlocBuilder` with `buildWhen`
- Index database queries
- Lazy load AI model
- Profile with DevTools

## 🔗 Useful Links

- [Flutter Docs](https://flutter.dev/docs)
- [Drift Database](https://drift.simonbinder.eu/)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [BLoC Library](https://bloclibrary.dev/)
- [Material Design 3](https://m3.material.io/)

## 📞 Getting Help

1. Check `TODO.md` for known issues
2. Review `DEVELOPMENT.md` for patterns
3. Check Flutter docs
4. Review llama.cpp issues

## 🎉 Current Status

✅ **Complete** (40%):
- Project structure
- Database schema
- Data models
- Service layer (encryption, notifications)
- AI service structure
- Basic UI

⏳ **In Progress** (60%):
- llama.cpp FFI implementation
- State management (BLoC)
- Full UI screens
- Testing

**Next**: Implement llama.cpp FFI bindings

## 🚀 Release Checklist

- [ ] All features working
- [ ] Tests passing
- [ ] No debug logs
- [ ] Privacy policy included
- [ ] App signed
- [ ] Tested on devices
- [ ] Performance optimized
- [ ] App store assets ready

---

## 💡 One-Line Commands

```bash
# Full setup
./setup.sh && dart run build_runner build

# Clean rebuild
flutter clean && flutter pub get && flutter run

# Release build
flutter build apk --release --split-per-abi

# Quick test
flutter test test/services/

# Format code
dart format lib/
```

---

**Happy coding! 🎨**

For detailed info, see:
- `README.md` - Overview
- `SETUP.md` - Installation
- `DEVELOPMENT.md` - Dev guide
- `TODO.md` - Tasks
