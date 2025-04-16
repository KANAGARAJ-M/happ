import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String patientName;
  final String doctorName;
  final DateTime date;
  final String timeSlot;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected', 'cancelled', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId, 
    required this.patientName,
    required this.doctorName,
    required this.date,
    required this.timeSlot,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    // For debugging
    print('Parsing appointment JSON: $json');
    
    // Parse date more safely
    DateTime parseDate() {
      try {
        if (json['date'] is Timestamp) {
          return json['date'].toDate();
        } else if (json['date'] is String) {
          return DateTime.parse(json['date']);
        } else if (json['date'] is DateTime) {
          return json['date'];
        }
      } catch (e) {
        print('Error parsing date: $e');
      }
      return DateTime.now();
    }
    
    // Parse createdAt more safely
    DateTime parseCreatedAt() {
      try {
        if (json['createdAt'] is Timestamp) {
          return json['createdAt'].toDate();
        } else if (json['createdAt'] is String) {
          return DateTime.parse(json['createdAt']);
        } else if (json['createdAt'] is DateTime) {
          return json['createdAt'];
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
      return DateTime.now();
    }
    
    // Parse updatedAt more safely
    DateTime parseUpdatedAt() {
      try {
        if (json['updatedAt'] is Timestamp) {
          return json['updatedAt'].toDate();
        } else if (json['updatedAt'] is String) {
          return DateTime.parse(json['updatedAt']);
        } else if (json['updatedAt'] is DateTime) {
          return json['updatedAt'];
        }
      } catch (e) {
        print('Error parsing updatedAt: $e');
      }
      return DateTime.now();
    }
    
    return Appointment(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      patientName: json['patientName'] ?? '',
      doctorName: json['doctorName'] ?? '',
      date: parseDate(),
      timeSlot: json['timeSlot'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: parseCreatedAt(),
      updatedAt: parseUpdatedAt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'patientName': patientName,
      'doctorName': doctorName,
      'date': date,
      'timeSlot': timeSlot,
      'reason': reason,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Appointment copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? patientName,
    String? doctorName,
    DateTime? date,
    String? timeSlot,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}