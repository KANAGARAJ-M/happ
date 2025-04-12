import 'package:cloud_firestore/cloud_firestore.dart';

class RecordModel {
  final String id;
  final String title;
  final String description;
  final String category; // e.g., 'medical', 'legal'
  final List<String> tags;
  final String filePath;
  final String thumbnailUrl;
  final String ownerId;
  final List<String> sharedWith;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecordModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.filePath,
    required this.thumbnailUrl,
    required this.ownerId,
    required this.sharedWith,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecordModel.fromJson(Map<String, dynamic> json) {
    return RecordModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      filePath: json['filePath'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      ownerId: json['ownerId'] ?? '',
      sharedWith: List<String>.from(json['sharedWith'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'filePath': filePath,
      'thumbnailUrl': thumbnailUrl,
      'ownerId': ownerId,
      'sharedWith': sharedWith,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
