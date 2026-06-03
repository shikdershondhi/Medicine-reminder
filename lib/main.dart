import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:alarm/alarm.dart';
import 'core/services/database_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/alarm_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/navigation.dart';
import 'core/services/providers.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local key-value box database
  await DatabaseService().init();

  // 2. Initialize scheduled notifications service
  await NotificationService().init();

  // 3. Initialize background alarm engine
  await AlarmService().init();

  // Initialize Auth service (google_sign_in singleton initialization)
  await AuthService().init();

  // 4. Try loading Firebase configuration
  bool isFirebaseInitialized = false;
  try {
    // Under normal compile conditions, this checks for google-services.json (Android)
    // and GoogleService-Info.plist (iOS).
    await Firebase.initializeApp();
    AuthService.isFirebaseInitialized = true;
    isFirebaseInitialized = true;
    print("Firebase Initialized Successfully.");
  } catch (e) {
    print("Firebase App initialization failed. Running in Local Database Offline Mode.");
    print("Reason: $e");
  }

  runApp(
    ProviderScope(
      child: MyApp(isFirebaseConfigured: isFirebaseInitialized),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final bool isFirebaseConfigured;
  const MyApp({super.key, required this.isFirebaseConfigured});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<AlarmSettings>? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    // Globally listen to the ringing alarm stream. When it fires, 
    // we push the full-screen AlarmRingScreen overlay onto the navigation stack.
    _alarmSubscription = AlarmService().ringStream.listen((alarmSettings) {
      _navigateToAlarmRing(alarmSettings);
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  void _navigateToAlarmRing(AlarmSettings settings) {
    // Push the full-screen overlay onto the active context
    goRouter.push('/alarm-ring', extra: settings);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Medicine Reminder',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
