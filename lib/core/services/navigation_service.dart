import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool get isNavigatorReady =>
      navigatorKey.currentState != null && navigatorKey.currentContext != null;

  // Safe navigation methods with null checks
  static Future<T?> navigateTo<T extends Object?>(Widget page) {
    if (!isNavigatorReady) {
      debugPrint('NavigationService: Navigator is not ready');
      throw Exception('Navigator is not ready');
    }
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  static Future<T?>
  navigateToReplacement<T extends Object?, TO extends Object?>(Widget page) {
    if (!isNavigatorReady) {
      debugPrint('NavigationService: Navigator is not ready');
      throw Exception('Navigator is not ready');
    }
    return navigatorKey.currentState!.pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  static Future<T?> navigateToAndClearStack<T extends Object?>(Widget page) {
    if (!isNavigatorReady) {
      debugPrint('NavigationService: Navigator is not ready');
      throw Exception('Navigator is not ready');
    }
    return navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page),
      (route) => false,
    );
  }

  // Fallback navigation method that accepts BuildContext
  static Future<T?> navigateWithContext<T extends Object?>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Safe pop method
  static void goBack([dynamic result]) {
    if (isNavigatorReady && navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop(result);
    } else {
      debugPrint('NavigationService: Cannot pop, no routes to pop');
    }
  }
}
