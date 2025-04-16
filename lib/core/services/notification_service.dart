import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:happ/core/models/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false;
  
  // Channel IDs for different notification types
  static const String appointmentChannelId = 'appointments_channel';
  static const String recordsChannelId = 'records_access_channel';
  static const String medicalInsightsChannelId = 'medical_insights_channel';
  
  // Initialize the notification services
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Request notification permissions from the user
      if (!kIsWeb) { // Check if not running on web
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
      
      // Initialize local notifications with error handling
      try {
        const AndroidInitializationSettings androidSettings = 
            AndroidInitializationSettings('@mipmap/ic_launcher');
            
        const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );
        
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );
        
        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
        
        // Create notification channels for Android
        await _createNotificationChannels();
      } catch (e) {
        debugPrint('Error initializing local notifications: $e');
      }
      
      // Handle FCM token refresh with error handling
      try {
        _messaging.onTokenRefresh.listen(_updateFcmToken);
        
        // Get the initial token
        final token = await _messaging.getToken();
        if (token != null) {
          await _updateFcmToken(token);
        }
      } catch (e) {
        debugPrint('Error setting up FCM: $e');
      }
      
      // Handle incoming FCM messages with error handling
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
        
        // Check for initial message if app was opened from a terminated state
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationOpened(initialMessage);
        }
      } catch (e) {
        debugPrint('Error setting up message handlers: $e');
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      // Still mark as initialized to prevent repeated initialization attempts
      _initialized = true;
    }
  }
  
  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    // Appointments channel
    const AndroidNotificationChannel appointmentsChannel = AndroidNotificationChannel(
      appointmentChannelId,
      'Appointment Notifications',
      description: 'Notifications about your medical appointments',
      importance: Importance.high,
    );
    
    // Records access channel
    const AndroidNotificationChannel recordsChannel = AndroidNotificationChannel(
      recordsChannelId,
      'Medical Records Access',
      description: 'Alerts about access to your medical records',
      importance: Importance.high,
    );
    
    // Medical insights channel
    const AndroidNotificationChannel insightsChannel = AndroidNotificationChannel(
      medicalInsightsChannelId,
      'Medical Insights',
      description: 'Important medical insights detected in your records',
      importance: Importance.high,
    );
    
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(appointmentsChannel);
      await androidPlugin.createNotificationChannel(recordsChannel);
      await androidPlugin.createNotificationChannel(insightsChannel);
    }
  }
  
  // Update FCM token in Firestore
  Future<void> _updateFcmToken(String token) async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      
      // Save token locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }
  }
  
  // Handle notifications when the app is in the foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: notification.title ?? 'New notification',
        body: notification.body ?? '',
        payload: jsonEncode(data),
        channelId: data['channel_id'] ?? appointmentChannelId,
      );
    }
  }
  
  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final payload = jsonDecode(response.payload!);
        // Navigate based on notification type
        _handleNavigation(payload);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }
  
  // Handle navigation based on notification type
  void _handleNavigation(Map<String, dynamic> data) {
    // This will be handled by the navigation service
    // Implementation depends on your app's navigation structure
  }
  
  // Handle when a notification is opened while app is in background
  void _handleNotificationOpened(RemoteMessage message) {
    _handleNavigation(message.data);
  }
  
  // Show a local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == appointmentChannelId
          ? 'Appointment Notifications'
          : channelId == recordsChannelId
              ? 'Medical Records Access'
              : 'Medical Insights',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: const BigTextStyleInformation(''),
    );
    
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  // PUBLIC METHODS TO SEND NOTIFICATIONS
  
  // Send appointment notification
  Future<void> sendAppointmentNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    // Get user's FCM tokens
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    
    final userData = userDoc.data();
    if (userData == null || !userData.containsKey('fcmTokens')) return;
    
    final List<dynamic> tokens = userData['fcmTokens'] ?? [];
    if (tokens.isEmpty) return;
    
    // Show notification locally if this is for current user
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == userId) {
      await _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: additionalData != null ? jsonEncode(additionalData) : null,
        channelId: appointmentChannelId,
      );
    }
    
    // Also save notification in Firestore for history
    await _firestore.collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': 'appointment',
          'read': false,
          'data': additionalData,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
  
  // Send record access notification
  Future<void> sendRecordAccessNotification({
    required String userId,
    required Record record,
    required String accessedBy,
    required String accessType,
  }) async {
    final title = 'Medical Record Access';
    final body = 'Your record "${record.title}" was $accessType by $accessedBy';
    
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'record_access',
        'recordId': record.id,
      }),
      channelId: recordsChannelId,
    );
    
    // Save notification in Firestore for history
    await _firestore.collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': 'record_access',
          'recordId': record.id,
          'accessedBy': accessedBy,
          'accessType': accessType,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
  
  // Send medical insight notification
  Future<void> sendMedicalInsightNotification({
    required String userId,
    required String condition,
    required String severity,
  }) async {
    final title = 'Important Medical Insight Detected';
    final body = 'A $severity condition "$condition" was detected in your records';
    
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      channelId: medicalInsightsChannelId,
    );
    
    // Save notification in Firestore for history
    await _firestore.collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': 'medical_insight',
          'condition': condition,
          'severity': severity,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}