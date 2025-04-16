import 'package:flutter/material.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:happ/core/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:happ/firebase_options.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/splash_screen.dart';
import 'package:happ/ui/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service with error handling
  try {
    await NotificationService().init();
  } catch (e) {
    // Don't let notification initialization failure crash the app
    debugPrint('Failed to initialize notifications: $e');
  }
  
  // Try to load the plugins explicitly
  try {
    await SystemChannels.platform.invokeMethod('getDeviceInfo');
  } catch (e) {
    // Ignore errors - this is just to ensure the plugin is loaded
  }
  
  // Only set persistence on web
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  
  // Make sure records are refreshed on app restart
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      // Refresh records when user is authenticated
      final recordsProvider = RecordsProvider();
      recordsProvider.resetInitializedState();
      recordsProvider.fetchRecords(user.uid);
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecordsProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'MedicoLegal Records',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationService.navigatorKey,
        home: const SplashScreen(),
      ),
    );
  }
}
