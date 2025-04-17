import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:happ/core/models/emergency_contact.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/models/accident_report.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/services/notification_service.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Get current user's emergency contacts
  Future<List<EmergencyContact>> getEmergencyContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .orderBy('isPrimaryContact', descending: true)
          .get();
          
      return snapshot.docs.map((doc) {
        return EmergencyContact.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error getting emergency contacts: $e');
      return [];
    }
  }
  
  // Add or update emergency contact
  Future<EmergencyContact?> saveEmergencyContact(EmergencyContact contact) async {
    try {
      if (contact.id.isEmpty) {
        // New contact
        final docRef = await _firestore
            .collection('users')
            .doc(contact.userId)
            .collection('emergency_contacts')
            .add(contact.toJson());
            
        return contact = EmergencyContact(
          id: docRef.id,
          userId: contact.userId,
          name: contact.name,
          relationship: contact.relationship,
          phoneNumber: contact.phoneNumber,
          isPrimaryContact: contact.isPrimaryContact,
          notifyOnEmergency: contact.notifyOnEmergency,
          createdAt: contact.createdAt,
        );
      } else {
        // Update existing contact
        await _firestore
            .collection('users')
            .doc(contact.userId)
            .collection('emergency_contacts')
            .doc(contact.id)
            .update(contact.toJson());
            
        return contact;
      }
    } catch (e) {
      debugPrint('Error saving emergency contact: $e');
      return null;
    }
  }
  
  // Delete emergency contact
  Future<bool> deleteEmergencyContact(String userId, String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting emergency contact: $e');
      return false;
    }
  }
  
  // Trigger emergency alert
  Future<EmergencyAlert?> triggerEmergencyAlert({
    required EmergencyType type,
    required String userId,
    required String userName,
    String? additionalInfo,
  }) async {
    try {
      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }
      
      final location = GeoPoint(position.latitude, position.longitude);
      
      // Create emergency alert
      final alert = EmergencyAlert(
        id: '',
        userId: userId,
        userName: userName,
        timestamp: DateTime.now(),
        type: type,
        location: location,
        status: 'active',
        notifiedContacts: [],
        additionalInfo: additionalInfo,
      );
      
      // Save to Firestore
      final docRef = await _firestore
          .collection('emergency_alerts')
          .add(alert.toJson());
          
      final newAlert = EmergencyAlert(
        id: docRef.id,
        userId: alert.userId,
        userName: alert.userName,
        timestamp: alert.timestamp,
        type: alert.type,
        location: alert.location,
        status: alert.status,
        notifiedContacts: alert.notifiedContacts,
        additionalInfo: alert.additionalInfo,
      );
      
      // Notify emergency contacts
      await _notifyEmergencyContacts(newAlert);
      
      // If medical emergency, notify the user's healthcare providers
      if (type == EmergencyType.medical) {
        await _notifyHealthcareProviders(newAlert);
      }
      
      return newAlert;
    } catch (e) {
      debugPrint('Error triggering emergency alert: $e');
      return null;
    }
  }
  
  // Get user's active emergency alerts
  Future<List<EmergencyAlert>> getActiveAlerts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_alerts')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs.map((doc) {
        return EmergencyAlert.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error getting active alerts: $e');
      return [];
    }
  }
  
  // Get user's emergency alert history
  Future<List<EmergencyAlert>> getAlertHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_alerts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs.map((doc) {
        return EmergencyAlert.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error getting alert history: $e');
      return [];
    }
  }
  
  // Cancel an emergency alert
  Future<bool> cancelEmergencyAlert(String alertId) async {
    try {
      await _firestore
          .collection('emergency_alerts')
          .doc(alertId)
          .update({
            'status': 'canceled',
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': _auth.currentUser?.uid,
          });
      return true;
    } catch (e) {
      debugPrint('Error canceling emergency alert: $e');
      return false;
    }
  }
  
  // Submit accident report
  Future<AccidentReport?> submitAccidentReport(AccidentReport report) async {
    try {
      final docRef = await _firestore
          .collection('accident_reports')
          .add(report.toJson());
          
      return AccidentReport(
        id: docRef.id,
        userId: report.userId,
        timestamp: report.timestamp,
        location: report.location,
        accidentType: report.accidentType,
        description: report.description,
        requiresMedicalAttention: report.requiresMedicalAttention,
        injuries: report.injuries,
        involvedParties: report.involvedParties,
        status: report.status,
        fileUrls: report.fileUrls,
      );
    } catch (e) {
      debugPrint('Error submitting accident report: $e');
      return null;
    }
  }
  
  // Get user's accident reports
  Future<List<AccidentReport>> getAccidentReports(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('accident_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs.map((doc) {
        return AccidentReport.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error getting accident reports: $e');
      return [];
    }
  }
  
  // Call emergency services directly
  Future<bool> callEmergencyServices() async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return true;
      } 
      return false;
    } catch (e) {
      debugPrint('Error calling emergency services: $e');
      return false;
    }
  }
  
  // Helper methods
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever
      return null;
    }

    try {
      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      // Use last known position if current fails
      return await Geolocator.getLastKnownPosition();
    }
  }
  
  Future<void> _notifyEmergencyContacts(EmergencyAlert alert) async {
    try {
      // Get user's emergency contacts
      final contacts = await getEmergencyContacts(alert.userId);
      
      // Filter to get contacts that should be notified
      final contactsToNotify = contacts.where((c) => c.notifyOnEmergency).toList();
      
      if (contactsToNotify.isEmpty) return;
      
      // Get user info for more detailed alert
      final userDoc = await _firestore.collection('users').doc(alert.userId).get();
      final userData = userDoc.data();
      
      // Craft emergency message
      String emergencyType = alert.type.toString().split('.').last;
      String mapLink = 'https://www.google.com/maps/search/?api=1&query=${alert.location.latitude},${alert.location.longitude}';
      
      String message = 'EMERGENCY ALERT: ${alert.userName} has triggered a $emergencyType emergency. ';
      message += 'They are located at: $mapLink. ';
      
      // Add medical info if available
      if (userData != null) {
        if (userData['bloodGroup'] != null) {
          message += 'Blood Type: ${userData['bloodGroup']}. ';
        }
        if (userData['allergies'] != null && userData['allergies'].toString().isNotEmpty) {
          message += 'Allergies: ${userData['allergies']}. ';
        }
      }
      
      message += 'Please respond immediately.';
      
      // Send SMS to emergency contacts
      List<String> phoneNumbers = contactsToNotify.map((c) => c.phoneNumber).toList();
      await sendSMS(message: message, recipients: phoneNumbers);
      
      // Update the alert with notified contacts
      List<String> notifiedContactIds = contactsToNotify.map((c) => c.id).toList();
      await _firestore
          .collection('emergency_alerts')
          .doc(alert.id)
          .update({'notifiedContacts': notifiedContactIds});
    } catch (e) {
      debugPrint('Error notifying emergency contacts: $e');
    }
  }
  
  Future<void> _notifyHealthcareProviders(EmergencyAlert alert) async {
    try {
      // Get user's healthcare providers from appointments
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: alert.userId)
          .where('status', isEqualTo: 'confirmed')
          .get();
          
      if (appointmentsSnapshot.docs.isEmpty) return;
      
      // Extract unique doctor IDs
      final doctorIds = appointmentsSnapshot.docs
          .map((doc) => doc.data()['doctorId'] as String)
          .toSet()
          .toList();
          
      // Send notifications to each doctor
      for (var doctorId in doctorIds) {
        // Use the available notification method
        await _notificationService.sendNotification(
          userId: doctorId,
          title: 'EMERGENCY: Patient Alert',
          body: '${alert.userName} has triggered a medical emergency alert.',
          additionalData: {
            'type': 'patient_emergency',
            'patientId': alert.userId,
            'alertId': alert.id,
          },
        );
      }
    } catch (e) {
      debugPrint('Error notifying healthcare providers: $e');
    }
  }
}