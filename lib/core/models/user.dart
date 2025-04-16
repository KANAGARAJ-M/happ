import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final DateTime? dob;
  final int? age;
  final String? aadhaarNumber;
  final double? height;
  final double? weight;
  final String? emergencyContact;
  final String? allergies;
  final String? bloodGroup;
  final String? profileImageUrl;
  final String? patientId; // Add this new field for patient identification
  final String? specialization; // For doctors
  final String? bio; // For doctors

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.dob,
    this.age,
    this.aadhaarNumber,
    this.height,
    this.weight,
    this.emergencyContact,
    this.allergies,
    this.bloodGroup,
    this.profileImageUrl,
    this.patientId,
    this.specialization,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse date of birth
    DateTime? dobDate;
    if (json['dob'] is Timestamp) {
      dobDate = json['dob'].toDate();
    } else if (json['dob'] is String) {
      try {
        dobDate = DateTime.parse(json['dob']);
      } catch (_) {}
    }
    
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'patient',
      phone: json['phone'],
      dob: dobDate,
      age: json['age'],
      aadhaarNumber: json['aadhaarNumber'],
      height: json['height'] is num ? (json['height'] as num).toDouble() : null,
      weight: json['weight'] is num ? (json['weight'] as num).toDouble() : null,
      emergencyContact: json['emergencyContact'],
      allergies: json['allergies'],
      bloodGroup: json['bloodGroup'],
      profileImageUrl: json['profileImageUrl'],
      patientId: json['patientId'], // Add to fromJson method
      specialization: json['specialization'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'dob': dob,
      'age': age,
      'aadhaarNumber': aadhaarNumber,
      'height': height,
      'weight': weight,
      'emergencyContact': emergencyContact,
      'allergies': allergies,
      'bloodGroup': bloodGroup,
      'profileImageUrl': profileImageUrl,
      'patientId': patientId, // Add to toJson method
      'specialization': specialization,
      'bio': bio,
    };
  }
}
