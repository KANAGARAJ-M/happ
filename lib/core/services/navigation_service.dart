import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static Future<dynamic> navigateTo(Widget screen) {
    // Wrap the screen in a Material widget to ensure Material context
    return navigator!.push(
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );
  }

  static Future<dynamic> navigateToAndClearStack(Widget screen) {
    return navigator!.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => screen,
      ),
      (route) => false,
    );
  }

  static bool get isNavigatorReady =>
      navigatorKey.currentState != null && navigatorKey.currentContext != null;

  // Safe navigation methods with null checks
  static Future<T?> navigateToSafe<T extends Object?>(Widget page) {
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
