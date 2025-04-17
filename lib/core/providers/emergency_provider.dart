import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happ/core/models/emergency_contact.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/models/accident_report.dart';
import 'package:happ/core/services/emergency_service.dart';

class EmergencyProvider with ChangeNotifier {
  final EmergencyService _emergencyService = EmergencyService();
  
  List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyAlert> _activeAlerts = [];
  List<EmergencyAlert> _alertHistory = [];
  List<AccidentReport> _accidentReports = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  List<EmergencyAlert> get activeAlerts => _activeAlerts;
  List<EmergencyAlert> get alertHistory => _alertHistory;
  List<AccidentReport> get accidentReports => _accidentReports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Load emergency contacts
  Future<void> loadEmergencyContacts(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _emergencyContacts = await _emergencyService.getEmergencyContacts(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load emergency contacts: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Save emergency contact
  Future<bool> saveEmergencyContact(EmergencyContact contact) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final savedContact = await _emergencyService.saveEmergencyContact(contact);
      
      if (savedContact != null) {
        // Update contacts list
        if (contact.id.isEmpty) {
          // Add new contact
          _emergencyContacts.add(savedContact);
        } else {
          // Update existing contact
          final index = _emergencyContacts.indexWhere((c) => c.id == contact.id);
          if (index != -1) {
            _emergencyContacts[index] = savedContact;
          }
        }
        
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to save emergency contact: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Delete emergency contact
  Future<bool> deleteEmergencyContact(String userId, String contactId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final success = await _emergencyService.deleteEmergencyContact(userId, contactId);
      
      if (success) {
        _emergencyContacts.removeWhere((c) => c.id == contactId);
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete emergency contact: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _isLoading = true;
      notifyListeners();
      
      final alert = await _emergencyService.triggerEmergencyAlert(
        type: type,
        userId: userId,
        userName: userName,
        additionalInfo: additionalInfo,
      );
      
      if (alert != null) {
        _activeAlerts.add(alert);
        _alertHistory.add(alert);
        _errorMessage = null;
        notifyListeners();
        return alert;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to trigger emergency alert: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load active alerts
  Future<void> loadActiveAlerts(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _activeAlerts = await _emergencyService.getActiveAlerts(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load active alerts: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load alert history
  Future<void> loadAlertHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _alertHistory = await _emergencyService.getAlertHistory(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load alert history: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Cancel emergency alert
  Future<bool> cancelEmergencyAlert(String alertId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final success = await _emergencyService.cancelEmergencyAlert(alertId);
      
      if (success) {
        // Update alert status in lists
        final activeIndex = _activeAlerts.indexWhere((a) => a.id == alertId);
        if (activeIndex != -1) {
          _activeAlerts.removeAt(activeIndex);
        }
        
        final historyIndex = _alertHistory.indexWhere((a) => a.id == alertId);
        if (historyIndex != -1) {
          final updatedAlert = _alertHistory[historyIndex].copyWith(
            status: 'canceled',
            resolvedAt: DateTime.now(),
          );
          _alertHistory[historyIndex] = updatedAlert;
        }
        
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to cancel emergency alert: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Submit accident report
  Future<AccidentReport?> submitAccidentReport(AccidentReport report) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final submittedReport = await _emergencyService.submitAccidentReport(report);
      
      if (submittedReport != null) {
        _accidentReports.add(submittedReport);
        _errorMessage = null;
        notifyListeners();
        return submittedReport;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to submit accident report: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load accident reports
  Future<void> loadAccidentReports(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _accidentReports = await _emergencyService.getAccidentReports(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load accident reports: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Call emergency services
  Future<bool> callEmergencyServices() async {
    return await _emergencyService.callEmergencyServices();
  }

  // Add emergency contact (convenience method)
  Future<bool> addEmergencyContact(EmergencyContact contact) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Ensure this is a new contact
      final newContact = contact.copyWith(
        id: '', // Empty ID to indicate a new contact
      );
      
      return await saveEmergencyContact(newContact);
    } catch (e) {
      _errorMessage = 'Failed to add emergency contact: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update emergency contact (convenience method)
  Future<bool> updateEmergencyContact(EmergencyContact contact) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Validate that this is an existing contact
      if (contact.id.isEmpty) {
        throw Exception('Cannot update a contact without an ID');
      }
      
      return await saveEmergencyContact(contact);
    } catch (e) {
      _errorMessage = 'Failed to update emergency contact: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}


// Extension for EmergencyAlert
extension EmergencyAlertExtension on EmergencyAlert {
  EmergencyAlert copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? timestamp,
    EmergencyType? type,
    GeoPoint? location,
    String? status,
    List<String>? notifiedContacts,
    String? additionalInfo,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return EmergencyAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      location: location ?? this.location,
      status: status ?? this.status,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

// Add EmergencyContact extension for copyWith method
extension EmergencyContactExtension on EmergencyContact {
  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? relationship,
    String? phoneNumber,
    String? email,
    bool? isPrimaryContact,
    bool? notifyOnEmergency,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      isPrimaryContact: isPrimaryContact ?? this.isPrimaryContact,
      notifyOnEmergency: notifyOnEmergency ?? this.notifyOnEmergency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}