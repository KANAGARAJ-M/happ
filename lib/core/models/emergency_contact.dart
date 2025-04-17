import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String relationship;
  final String phoneNumber;
  final bool isPrimaryContact;
  final bool notifyOnEmergency;
  final DateTime createdAt;
  final String? email;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    this.email,
    required this.isPrimaryContact,
    required this.notifyOnEmergency,
    required this.createdAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      isPrimaryContact: json['isPrimaryContact'] ?? false,
      notifyOnEmergency: json['notifyOnEmergency'] ?? true,
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'phoneNumber': phoneNumber,
      'isPrimaryContact': isPrimaryContact,
      'notifyOnEmergency': notifyOnEmergency,
      'createdAt': createdAt,
    };
  }
}