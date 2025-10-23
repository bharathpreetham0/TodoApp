import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/app_database.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/bloc/notes/notes_cubit.dart';
import 'presentation/bloc/tasks/tasks_cubit.dart';
import 'presentation/bloc/search/search_cubit.dart';
import 'presentation/bloc/settings/settings_cubit.dart';
import 'services/ai/ai_service.dart';
import 'services/encryption/encryption_service.dart';
import 'services/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Starting app initialization...');
  
  try {
    // Initialize only database for now
    final database = AppDatabase();
    print('Database initialized');
    
    // Get SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    print('SharedPreferences initialized');
    
    // Create mock services to avoid initialization issues
    final mockAiService = AIService(logger: null);
    final mockEncryptionService = EncryptionService(logger: null);
    final mockNotificationService = NotificationService(logger: null);
    
    print('Mock services created');
    
    runApp(DebugApp(
      database: database,
      aiService: mockAiService,
      encryptionService: mockEncryptionService,
      notificationService: mockNotificationService,
      prefs: prefs,
    ));
    
    print('App started successfully');
  } catch (e, stackTrace) {
    print('Error during initialization: $e');
    print('Stack trace: $stackTrace');
    
    // Run a minimal error app
    runApp(const ErrorApp());
  }
}

class DebugApp extends StatelessWidget {
  final AppDatabase database;
  final AIService aiService;
  final EncryptionService encryptionService;
  final NotificationService notificationService;
  final SharedPreferences prefs;

  const DebugApp({
    super.key,
    required this.database,
    required this.aiService,
    required this.encryptionService,
    required this.notificationService,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
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
        title: 'Smart Notes AI (Debug)',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const TestScreen(),
      ),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Notes AI - Debug Mode'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              'App is working!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Flutter web compilation successful',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the full home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        },
        child: const Icon(Icons.home),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error',
      home: Scaffold(
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 100, color: Colors.red),
              SizedBox(height: 20),
              Text('Initialization Error', style: TextStyle(fontSize: 24)),
              Text('Check console for details', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}