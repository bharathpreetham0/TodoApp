import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Domain
import '../../domain/repositories/note_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/notes/create_note_usecase.dart';
import '../../domain/usecases/notes/get_notes_usecase.dart';
import '../../domain/usecases/notes/update_note_usecase.dart';
import '../../domain/usecases/notes/delete_note_usecase.dart';
import '../../domain/usecases/tasks/create_task_usecase.dart';
import '../../domain/usecases/tasks/get_tasks_usecase.dart';
import '../../domain/usecases/tasks/update_task_usecase.dart';
import '../../domain/usecases/tasks/complete_task_usecase.dart';
import '../../domain/usecases/tasks/delete_task_usecase.dart';

// Data
import '../../data/repositories/note_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../data/database/app_database.dart';

// Services
import '../../services/encryption/encryption_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/ai/ai_service.dart';
import '../../services/speech/speech_service.dart';

// Presentation
import '../../presentation/bloc/notes/notes_cubit.dart';
import '../../presentation/bloc/tasks/tasks_cubit.dart';
import '../../presentation/bloc/search/search_cubit.dart';
import '../../presentation/bloc/settings/settings_cubit.dart';

/// Service Locator for Dependency Injection
/// Using get_it for simple and efficient DI
final sl = GetIt.instance;

/// Initialize all dependencies
/// Call this once at app startup
Future<void> initializeDependencies() async {
  // ============ External Dependencies ============
  sl.registerLazySingleton(() => const Uuid());
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => prefs);

  // ============ Core Services ============
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  sl.registerLazySingleton<EncryptionService>(() => EncryptionService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<AIService>(() => AIService());
  sl.registerLazySingleton<SpeechService>(() => SpeechService());

  // Initialize services
  await sl<NotificationService>().initialize();

  // ============ Repositories ============
  sl.registerLazySingleton<NoteRepository>(
    () => NoteRepositoryImpl(
      database: sl<AppDatabase>(),
      uuid: sl<Uuid>(),
    ),
  );

  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      database: sl<AppDatabase>(),
      notificationService: sl<NotificationService>(),
      uuid: sl<Uuid>(),
    ),
  );

  // ============ Use Cases - Notes ============
  sl.registerLazySingleton(() => CreateNoteUseCase(sl<NoteRepository>()));
  sl.registerLazySingleton(() => GetNotesUseCase(sl<NoteRepository>()));
  sl.registerLazySingleton(() => UpdateNoteUseCase(sl<NoteRepository>()));
  sl.registerLazySingleton(() => DeleteNoteUseCase(sl<NoteRepository>()));

  // ============ Use Cases - Tasks ============
  sl.registerLazySingleton(() => CreateTaskUseCase(sl<TaskRepository>()));
  sl.registerLazySingleton(() => GetTasksUseCase(sl<TaskRepository>()));
  sl.registerLazySingleton(() => UpdateTaskUseCase(sl<TaskRepository>()));
  sl.registerLazySingleton(() => CompleteTaskUseCase(sl<TaskRepository>()));
  sl.registerLazySingleton(() => DeleteTaskUseCase(sl<TaskRepository>()));

  // ============ BLoCs/Cubits ============
  // Register as factories so we get new instances when needed
  sl.registerFactory(
    () => NotesCubit(
      database: sl<AppDatabase>(),
      aiService: sl<AIService>(),
      encryptionService: sl<EncryptionService>(),
    ),
  );

  sl.registerFactory(
    () => TasksCubit(
      database: sl<AppDatabase>(),
      notificationService: sl<NotificationService>(),
    ),
  );

  sl.registerFactory(
    () => SearchCubit(
      database: sl<AppDatabase>(),
      aiService: sl<AIService>(),
    ),
  );

  sl.registerFactory(
    () => SettingsCubit(
      aiService: sl<AIService>(),
      encryptionService: sl<EncryptionService>(),
      notificationService: sl<NotificationService>(),
      prefs: sl<SharedPreferences>(),
    ),
  );
}

/// Clean up resources on app close
Future<void> disposeDependencies() async {
  await sl<AppDatabase>().close();
  await sl.reset();
}
