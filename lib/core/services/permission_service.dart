import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  // Permission types needed by the app
  static const List<Permission> _requiredPermissions = [
    Permission.camera,
    Permission.storage,
    Permission.microphone, // Replace with an actual permission from the package
  ];

  // Optional permissions that enhance functionality but aren't critical
  static const List<Permission> _optionalPermissions = [Permission.location];

  // Check if all required permissions are granted
  static Future<bool> hasRequiredPermissions() async {
    for (var permission in _requiredPermissions) {
      if (!await permission.isGranted) {
        return false;
      }
    }
    return true;
  }

  // Request all required permissions
  static Future<Map<Permission, PermissionStatus>>
  requestRequiredPermissions() async {
    return await PermissionListExtension(_requiredPermissions).request();
  }

  // Request a specific permission with explanation
  static Future<PermissionStatus> requestPermission(
    Permission permission,
  ) async {
    final status = await permission.status;

    // If already granted, return status
    if (status.isGranted) {
      return status;
    }

    // If permanently denied, can only be enabled from app settings
    if (status.isPermanentlyDenied) {
      return status;
    }

    // Request the permission
    return await permission.request();
  }

  // Show a dialog explaining why a permission is needed
  static Future<bool> showPermissionDialog(
    BuildContext context,
    Permission permission,
    String title,
    String message,
  ) async {
    final status = await permission.status;

    if (status.isGranted) return true;

    // Show dialog only if not permanently denied
    if (!status.isPermanentlyDenied) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('NOT NOW'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ALLOW'),
                ),
              ],
            ),
      );

      // If user agreed, request permission
      if (result == true) {
        final newStatus = await permission.request();
        return newStatus.isGranted;
      }

      return false;
    } else {
      // Permission is permanently denied, ask user to go to settings
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: Text(
                '$permission is required for this feature. Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('OPEN SETTINGS'),
                ),
              ],
            ),
      );

      return result == true;
    }
  }

  // Check if first run to decide whether to show onboarding permissions
  static Future<bool> isFirstRun() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

    if (isFirstRun) {
      await prefs.setBool('isFirstRun', false);
    }

    return isFirstRun;
  }

  // Get friendly name for permissions
  static String getPermissionFriendlyName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.storage:
        return 'Storage';
      case Permission.microphone: // Updated to match the permission above
        return 'Biometric Authentication';
      case Permission.location:
        return 'Location';
      default:
        return permission.toString();
    }
  }

  // Get permission description
  static String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Required to scan documents and take photos of medical records.';
      case Permission.storage:
        return 'Required to save and access your medical documents.';
      case Permission.microphone: // Updated to match the permission above
        return 'Allows you to securely log in using your fingerprint or face recognition.';
      case Permission.location:
        return 'Helps find medical facilities near you (optional).';
      default:
        return 'This permission is required for app functionality.';
    }
  }
}

// Extension to make requesting multiple permissions easier
extension PermissionListExtension on List<Permission> {
  Future<Map<Permission, PermissionStatus>> request() async {
    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in this) {
      statuses[permission] = await permission.request();
    }
    return statuses;
  }
}
