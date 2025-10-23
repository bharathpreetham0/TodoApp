# 📊 Smart Notes AI - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Notes   │  │  Tasks   │  │  Search  │  │ Settings │       │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │              │             │             │
└───────┼─────────────┼──────────────┼─────────────┼─────────────┘
        │             │              │             │
        └─────────────┴──────────────┴─────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐            ┌───────▼────────┐
│  State Mgmt    │            │   Navigation   │
│  (BLoC/Cubit)  │            │   Controller   │
└───────┬────────┘            └────────────────┘
        │
┌───────┴──────────────────────────────────────────────┐
│                   BUSINESS LOGIC                     │
│                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Notes     │  │   Tasks     │  │   Search    │  │
│  │  Use Cases  │  │  Use Cases  │  │  Use Cases  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                 │         │
└─────────┼────────────────┼─────────────────┼─────────┘
          │                │                 │
┌─────────┴────────────────┴─────────────────┴─────────┐
│                  SERVICES LAYER                      │
│                                                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────┐ │
│  │    AI    │  │Encryption│  │  Notify  │  │Search│ │
│  │ Service  │  │ Service  │  │ Service  │  │  Svc │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬──┘ │
│       │             │              │             │   │
└───────┼─────────────┼──────────────┼─────────────┼───┘
        │             │              │             │
┌───────▼─────────────▼──────────────▼─────────────▼───┐
│                  DATA LAYER                          │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │          SQLite Database (Drift)               │  │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │  │
│  │  │Notes │  │Tasks │  │Remind│  │Embed │      │  │
│  │  │Table │  │Table │  │Table │  │Table │      │  │
│  │  └──────┘  └──────┘  └──────┘  └──────┘      │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │         Secure Storage (Keychain/Keystore)     │  │
│  │         - Encryption Keys                      │  │
│  │         - User Preferences                     │  │
│  └────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
        │
┌───────▼───────────────────────────────────────────────┐
│               NATIVE LAYER (FFI)                      │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │           llama.cpp (C++ Library)              │  │
│  │  - Model Loading (.gguf files)                 │  │
│  │  - Tokenization                                │  │
│  │  - Inference Engine                            │  │
│  │  - Sampling & Generation                       │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │         Platform-Specific Code                 │  │
│  │  Android: JNI, Notifications                   │  │
│  │  iOS: Swift, UserNotifications                 │  │
│  └────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

## Data Flow: Creating a Note with AI

```
1. User Types Note
   │
   ▼
2. NoteEditorScreen captures input
   │
   ▼
3. NoteCubit.createNote(title, content)
   │
   ├─────────────────────┐
   │                     │
   ▼                     ▼
4a. AIService           4b. EncryptionService
   .summarizeNote()         .encryptText() (if enabled)
   │                     │
   ▼                     │
5. LlamaFFI             │
   .generate()          │
   │                     │
   ▼                     │
6. llama.cpp [Native]   │
   - Tokenize            │
   - Run inference       │
   - Sample tokens       │
   - Generate summary    │
   │                     │
   ▼                     │
7. Parse JSON response  │
   - summary            │
   - insights           │
   - key_points         │
   │                     │
   └─────────┬───────────┘
             │
             ▼
8. Database.insert(Note)
   - Store plain/encrypted content
   - Store AI summary
   - Update FTS index
   │
   ▼
9. Emit Updated State
   │
   ▼
10. UI Rebuilds
    - Show new note
    - Display AI summary card
    - Update note count
```

## AI Processing Pipeline

```
┌─────────────────────────────────────────────────────┐
│              TEXT INPUT (Note Content)              │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐           ┌────────▼────────┐
│  Summarization │           │ Task Extraction │
│    Pipeline    │           │    Pipeline     │
└───────┬────────┘           └────────┬────────┘
        │                             │
        │  1. Build Prompt            │
        │  2. Add System Context      │
        │  3. Call llama.cpp          │
        │  4. Parse JSON Response     │
        │                             │
┌───────▼────────┐           ┌────────▼────────┐
│  Summary       │           │  Tasks List     │
│  Insights      │           │  Priorities     │
│  Key Points    │           │  Due Dates      │
└───────┬────────┘           └────────┬────────┘
        │                             │
        └──────────────┬──────────────┘
                       │
        ┌──────────────▼──────────────┐
        │                             │
┌───────▼────────┐           ┌────────▼────────┐
│   Store in     │           │   Create        │
│   Database     │           │   Reminders     │
└────────────────┘           └─────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────┐
│                   USER DATA                         │
│  (Notes, Tasks, Reminders, Personal Information)    │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐           ┌────────▼────────┐
│   Encryption   │           │   Biometric     │
│   (Optional)   │           │   Auth          │
│                │           │   (Optional)    │
│  AES-256-GCM   │           │                 │
│  Random IV     │           │  Face ID        │
│  Secure Key    │           │  Touch ID       │
│  Storage       │           │  Fingerprint    │
└───────┬────────┘           └────────┬────────┘
        │                             │
        └──────────────┬──────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│           DEVICE SECURE STORAGE                     │
│                                                      │
│  iOS: Keychain (Hardware-backed)                    │
│  Android: Keystore (Hardware-backed)                │
│                                                      │
│  - Encryption Master Key                            │
│  - User Preferences                                 │
│  - Authentication Tokens                            │
└──────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              SECURITY GUARANTEES                    │
│                                                      │
│  ✅ No Network Permissions                          │
│  ✅ All Data Stored Locally                         │
│  ✅ Optional End-to-End Encryption                  │
│  ✅ Biometric Protection                            │
│  ✅ No Third-Party Services                         │
│  ✅ No Analytics or Tracking                        │
│  ✅ Open Source (Auditable)                         │
└─────────────────────────────────────────────────────┘
```

## Storage Layout

```
App Container
│
├── Documents/
│   ├── smart_notes.db              # Main SQLite database
│   ├── smart_notes.db-shm          # Shared memory file
│   └── smart_notes.db-wal          # Write-ahead log
│
├── Library/
│   ├── Preferences/                # Shared preferences
│   └── Application Support/
│       └── models/
│           └── phi-3-mini.Q4_K_M.gguf  # AI model (2.3GB)
│
└── Keychain/Keystore (System)
    ├── encryption_master_key       # AES-256 key
    ├── encryption_iv               # Initialization vector
    └── user_settings               # Secure preferences
```

## Component Interaction Map

```
┌─────────────┐
│   Screen    │
└──────┬──────┘
       │ user interaction
       ▼
┌─────────────┐
│   Cubit     │◄──── state changes ─────┐
└──────┬──────┘                          │
       │ business logic                  │
       ▼                                 │
┌─────────────┐                          │
│  Use Case   │                          │
└──────┬──────┘                          │
       │ data operations                 │
       ▼                                 │
┌─────────────┐                          │
│ Repository  │                          │
└──────┬──────┘                          │
       │                                 │
       ├─────────►┌─────────────┐       │
       │          │  Database   │       │
       │          └─────────────┘       │
       │                                 │
       ├─────────►┌─────────────┐       │
       │          │ AI Service  │       │
       │          └─────────────┘       │
       │                                 │
       └─────────►┌─────────────┐       │
                  │ Other Svc   │       │
                  └─────────────┘       │
                         │              │
                         └──────────────┘
```

## Tech Stack Visual

```
┌─────────────────────────────────────────────────────┐
│                    FRONTEND                         │
│  ┌───────────────────────────────────────────────┐  │
│  │              Flutter 3.x                      │  │
│  │  - Material Design 3                          │  │
│  │  - Responsive UI                              │  │
│  │  - Hot Reload                                 │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│               STATE MANAGEMENT                      │
│  ┌───────────────────────────────────────────────┐  │
│  │           flutter_bloc / Cubit                │  │
│  │  - Predictable State                          │  │
│  │  - Easy Testing                               │  │
│  │  - Time Travel Debugging                      │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                  DATABASE                           │
│  ┌───────────────────────────────────────────────┐  │
│  │          Drift (SQLite Wrapper)               │  │
│  │  - Type-Safe Queries                          │  │
│  │  - Reactive Streams                           │  │
│  │  - Migration Support                          │  │
│  │  - Full-Text Search (FTS5)                    │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                 AI/ML ENGINE                        │
│  ┌───────────────────────────────────────────────┐  │
│  │               llama.cpp                       │  │
│  │  - On-Device Inference                        │  │
│  │  - GGUF Model Support                         │  │
│  │  - Quantization (Q4_K_M)                      │  │
│  │  - Optimized for Mobile                       │  │
│  └───────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────┐  │
│  │         Models (Choose One)                   │  │
│  │  - Phi-3-mini (3.8B) ← Recommended            │  │
│  │  - Llama-3.2 (1B)    ← Lightweight            │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   SECURITY                          │
│  ┌───────────────────────────────────────────────┐  │
│  │         encrypt (AES-256-GCM)                 │  │
│  │  flutter_secure_storage (Keychain/Keystore)   │  │
│  │  local_auth (Biometric)                       │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              NOTIFICATIONS                          │
│  ┌───────────────────────────────────────────────┐  │
│  │      flutter_local_notifications              │  │
│  │  - Scheduled Reminders                        │  │
│  │  - Daily Digest                               │  │
│  │  - Time Zone Support                          │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Performance Characteristics

```
Operation               | Time      | Memory    | Notes
-----------------------|-----------|-----------|------------------
App Launch             | < 2s      | ~100MB    | Cold start
Note CRUD              | < 100ms   | Minimal   | Without AI
AI Summarization       | 2-5s      | ~1.5GB    | Model loaded
Task Extraction        | 2-5s      | ~1.5GB    | Model loaded
Semantic Search        | < 1s      | ~50MB     | FTS5
Database Query         | < 50ms    | Minimal   | Indexed
Encryption/Decryption  | < 10ms    | Minimal   | Per note
Full-Text Search       | < 500ms   | ~20MB     | 1000+ notes
```

---

This architecture ensures:
- 🚀 Fast performance
- 🔒 Maximum privacy
- 💪 Powerful AI features
- 📱 Cross-platform support
- 🔐 Strong security
