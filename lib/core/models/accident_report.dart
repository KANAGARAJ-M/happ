import 'package:cloud_firestore/cloud_firestore.dart';

class AccidentReport {
  final String id;
  final String userId;
  final DateTime timestamp;
  final GeoPoint location;
  final String accidentType;
  final String description;
  final bool requiresMedicalAttention;
  final List<String> injuries;
  final List<String> involvedParties;
  final String status; // 'submitted', 'processing', 'resolved'
  final List<String> fileUrls;

  AccidentReport({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.location,
    required this.accidentType,
    required this.description,
    required this.requiresMedicalAttention,
    required this.injuries,
    required this.involvedParties,
    required this.status,
    required this.fileUrls,
  });

  factory AccidentReport.fromJson(Map<String, dynamic> json) {
    return AccidentReport(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      timestamp: json['timestamp'] is Timestamp 
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      location: json['location'] ?? const GeoPoint(0, 0),
      accidentType: json['accidentType'] ?? '',
      description: json['description'] ?? '',
      requiresMedicalAttention: json['requiresMedicalAttention'] ?? false,
      injuries: List<String>.from(json['injuries'] ?? []),
      involvedParties: List<String>.from(json['involvedParties'] ?? []),
      status: json['status'] ?? 'submitted',
      fileUrls: List<String>.from(json['fileUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timestamp': timestamp,
      'location': location,
      'accidentType': accidentType,
      'description': description,
      'requiresMedicalAttention': requiresMedicalAttention,
      'injuries': injuries,
      'involvedParties': involvedParties,
      'status': status,
      'fileUrls': fileUrls,
    };
  }
}