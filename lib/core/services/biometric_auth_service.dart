import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _isBiometricsEnabledKey = 'isBiometricsEnabled';
  static const String _userIdKey = 'userId';
  static const String _userLoggedInKey = 'userLoggedIn';
  static const String _userEmailKey = 'userEmail';

  // For secure storage
  static const _secureStorage = FlutterSecureStorage();

  // Check if device supports biometrics
  static Future<bool> isBiometricsAvailable() async {
    try {
      final LocalAuthentication auth = LocalAuthentication();
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();
      
      debugPrint("Can check biometrics: $canCheckBiometrics");
      debugPrint("Is device supported: $isDeviceSupported");
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }
      
      final List<BiometricType> availableBiometrics = 
          await auth.getAvailableBiometrics();
      
      debugPrint("Available biometrics: $availableBiometrics");
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking biometrics availability: $e");
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate with biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      // First check if we have biometrics enabled in preferences
      final isEnabled = await isBiometricsEnabled();
      if (!isEnabled) {
        debugPrint('Biometrics is not enabled in app preferences');
        return false;
      }
      
      // Check if device supports biometrics
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        debugPrint('Device does not support biometrics: canCheck=$canCheckBiometrics, isSupported=$isDeviceSupported');
        return false;
      }
      
      // Get available biometrics
      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometrics available on device');
        return false;
      }
      
      // Authenticate
      final result = await _auth.authenticate(
        localizedReason: 'Authenticate to access your medical records',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
          useErrorDialogs: true, // Show system error dialogs
          sensitiveTransaction: true, // Indicate this is a sensitive operation
        ),
      );
      
      debugPrint('Authentication result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error authenticating with biometrics: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      debugPrint('Unexpected error in authenticateWithBiometrics: $e');
      return false;
    }
  }

  // Enable biometric authentication for the user
  static Future<bool> enableBiometrics(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isBiometricsEnabledKey, true);
      await prefs.setString(_userIdKey, userId);
      return true;
    } catch (e) {
      debugPrint('Error enabling biometrics: $e');
      return false;
    }
  }

  // Disable biometric authentication
  static Future<bool> disableBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isBiometricsEnabledKey, false);
      return true;
    } catch (e) {
      debugPrint('Error disabling biometrics: $e');
      return false;
    }
  }

  // Check if biometrics is enabled
  static Future<bool> isBiometricsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isBiometricsEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking if biometrics is enabled: $e');
      return false;
    }
  }

  // Get saved user ID
  static Future<String?> getSavedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      debugPrint('Error getting saved user ID: $e');
      return null;
    }
  }

  // Save user login state
  static Future<bool> saveUserLoginState(
    String userId,
    String email,
    String password,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('Saving user login state for user: $userId, email: $email');
      
      // Store non-sensitive info in SharedPreferences
      await prefs.setBool(_userLoggedInKey, true);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userEmailKey, email);

      // Store password securely
      await _secureStorage.write(key: email, value: password);
      
      debugPrint('User login state saved successfully');
      return true;
    } catch (e) {
      debugPrint('Error saving user login state: $e');
      return false;
    }
  }

  // Check if user has active login
  static Future<bool> hasActiveLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_userLoggedInKey) ?? false;
    } catch (e) {
      debugPrint('Error checking active login: $e');
      return false;
    }
  }

  // Get stored login credentials
  static Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);
      debugPrint('Getting stored credentials. Email found: ${email != null}');

      if (email == null) {
        debugPrint('No email found in preferences');
        return null;
      }

      final password = await _secureStorage.read(key: email);
      debugPrint('Password found for email: ${password != null}');

      if (password == null) {
        debugPrint('No password found in secure storage');
        return null;
      }

      return {'email': email, 'password': password};
    } catch (e) {
      debugPrint('Error getting stored credentials: $e');
      return null;
    }
  }

  // Clear login state (for logout)
  static Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);

      await prefs.setBool(_userLoggedInKey, false);

      if (email != null) {
        await _secureStorage.delete(key: email);
      }
    } catch (e) {
      debugPrint('Error clearing login state: $e');
    }
  }
}
