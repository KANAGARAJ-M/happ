import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmergencyAlert {
  final String id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final EmergencyType type;
  final GeoPoint location;
  final String status; // 'active', 'resolved', 'canceled'
  final List<String> notifiedContacts;
  final String? additionalInfo;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.type,
    required this.location,
    required this.status,
    required this.notifiedContacts,
    this.additionalInfo,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      timestamp: json['timestamp'] is Timestamp 
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: _parseEmergencyType(json['type']),
      location: json['location'] ?? const GeoPoint(0, 0),
      status: json['status'] ?? 'active',
      notifiedContacts: List<String>.from(json['notifiedContacts'] ?? []),
      additionalInfo: json['additionalInfo'],
      resolvedBy: json['resolvedBy'],
      resolvedAt: json['resolvedAt'] is Timestamp 
          ? (json['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp,
      'type': type.toString().split('.').last,
      'location': location,
      'status': status,
      'notifiedContacts': notifiedContacts,
      'additionalInfo': additionalInfo,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt,
    };
  }

  static EmergencyType _parseEmergencyType(String? typeStr) {
    switch (typeStr) {
      case 'medical':
        return EmergencyType.medical;
      case 'accident':
        return EmergencyType.accident;
      case 'other':
        return EmergencyType.other;
      default:
        return EmergencyType.medical;
    }
  }
}

enum EmergencyType {
  medical,
  accident,
  other,
}