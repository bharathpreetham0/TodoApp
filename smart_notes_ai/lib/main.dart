import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/app_database.dart';
import 'services/ai/ai_service.dart';
import 'services/encryption/encryption_service.dart';
import 'services/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/bloc/notes/notes_cubit.dart';
import 'presentation/bloc/tasks/tasks_cubit.dart';
import 'presentation/bloc/search/search_cubit.dart';
import 'presentation/bloc/settings/settings_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final logger = Logger();
  final database = AppDatabase();
  final encryptionService = EncryptionService(logger: logger);
  final notificationService = NotificationService(logger: logger);
  final aiService = AIService(logger: logger);
  final prefs = await SharedPreferences.getInstance();

  try {
    // Initialize encryption
    await encryptionService.initialize();
    logger.i('Encryption service initialized');

    // Initialize notifications
    await notificationService.initialize();
    logger.i('Notification service initialized');

    // Initialize AI (optional - can fail gracefully)
    try {
      await aiService.initialize();
      logger.i('AI service initialized');
    } catch (e) {
      logger.w('AI service initialization failed: $e');
      aiService.setEnabled(false);
    }
  } catch (e) {
    logger.e('Service initialization failed: $e');
  }

  runApp(SmartNotesApp(
    database: database,
    encryptionService: encryptionService,
    notificationService: notificationService,
    aiService: aiService,
    prefs: prefs,
  ));
}

class SmartNotesApp extends StatelessWidget {
  final AppDatabase database;
  final EncryptionService encryptionService;
  final NotificationService notificationService;
  final AIService aiService;
  final SharedPreferences prefs;

  const SmartNotesApp({
    super.key,
    required this.database,
    required this.encryptionService,
    required this.notificationService,
    required this.aiService,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: database),
        RepositoryProvider.value(value: encryptionService),
        RepositoryProvider.value(value: notificationService),
        RepositoryProvider.value(value: aiService),
        RepositoryProvider.value(value: prefs),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => NotesCubit(
              database: database,
              aiService: aiService,
              encryptionService: encryptionService,
            ),
          ),
          BlocProvider(
            create: (context) => TasksCubit(
              database: database,
              notificationService: notificationService,
            ),
          ),
          BlocProvider(
            create: (context) => SearchCubit(
              database: database,
              aiService: aiService,
            ),
          ),
          BlocProvider(
            create: (context) => SettingsCubit(
              aiService: aiService,
              encryptionService: encryptionService,
              notificationService: notificationService,
              prefs: prefs,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Smart Notes AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
