import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/biometric_auth_service.dart';
import 'package:happ/ui/screens/auth/login_screen.dart';
import 'package:happ/ui/screens/home_screen.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider, User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthAndNavigate());
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Request permissions first
    final status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      await Permission.storage.request();
    }
    
    // First, check if biometrics is enabled and try biometric auth
    final isBiometricsEnabled = await BiometricAuthService.isBiometricsEnabled();
    debugPrint('Biometrics enabled: $isBiometricsEnabled');
    
    if (isBiometricsEnabled) {
      debugPrint('Attempting biometric authentication...');
      final authenticated = await BiometricAuthService.authenticateWithBiometrics();
      debugPrint('Biometric authentication result: $authenticated');
      
      if (authenticated) {
        // Get stored credentials
        debugPrint('Getting stored credentials...');
        final credentials = await BiometricAuthService.getStoredCredentials();
        debugPrint('Credentials found: ${credentials != null}');
        
        if (credentials != null) {
          debugPrint('Attempting sign-in with stored credentials...');
          // Auto-login with credentials
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final success = await authProvider.signIn(
            credentials['email']!,
            credentials['password']!,
          );
          
          debugPrint('Sign-in result: $success');
          if (success && mounted) {
            debugPrint('Sign-in successful, loading records...');
            final recordsProvider = Provider.of<RecordsProvider>(context, listen: false);
            recordsProvider.resetInitializedState();
            await recordsProvider.fetchRecords(authProvider.currentUser!.id);
            NavigationService.navigateToAndClearStack(const HomeScreen());
            return; // Skip the rest of the method
          }
        }
      }
    }

    // If biometrics didn't work, check for Firebase auth state
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // User is logged in - reset RecordsProvider
        final recordsProvider = Provider.of<RecordsProvider>(context, listen: false);
        recordsProvider.resetInitializedState();
        
        // Get user details from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (!mounted) return;
            
        if (userDoc.exists) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          
          // Create User model from Firestore document
          final userData = userDoc.data()!;
          final appUser = User(
            id: user.uid,
            email: userData['email'] ?? user.email ?? '',
            name: userData['name'] ?? user.displayName ?? '',
            role: userData['role'] ?? 'user',
          );
          
          // Update auth provider with user data
          authProvider.setCurrentUser(appUser);
          
          // Force records to load
          await recordsProvider.fetchRecords(user.uid);
        }
        
        NavigationService.navigateToAndClearStack(const HomeScreen());
      } catch (e) {
        print('Error in splash screen: $e');
        NavigationService.navigateToAndClearStack(const LoginScreen());
      }
    } else {
      NavigationService.navigateToAndClearStack(const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_information,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'MedicoLegal Records',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}


