import 'package:intl/intl.dart';

class Record {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final DateTime date;
  final List<String> tags;
  final List<String> fileUrls;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy; // Ensure this is added

  Record({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.tags,
    required this.fileUrls,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy, // Include in constructor
  });

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);

  String get categoryName =>
      category.substring(0, 1).toUpperCase() + category.substring(1);

  factory Record.fromJson(Map<String, dynamic> json) {
    // Parse the creation date, update date, and record date
    DateTime createdAt = json['createdAt'] is String 
        ? DateTime.parse(json['createdAt']) 
        : (json['createdAt'] ?? DateTime.now());
    
    DateTime updatedAt = json['updatedAt'] is String 
        ? DateTime.parse(json['updatedAt']) 
        : (json['updatedAt'] ?? DateTime.now());
    
    DateTime date = json['date'] is DateTime 
        ? json['date'] 
        : DateTime.parse(json['date'] ?? DateTime.now().toIso8601String());
    
    // Parse the list of tags and file URLs
    List<String> tags = [];
    if (json['tags'] != null) {
      tags = List<String>.from(json['tags']);
    }
    
    List<String> fileUrls = [];
    if (json['fileUrls'] != null) {
      fileUrls = List<String>.from(json['fileUrls']);
    }
    
    return Record(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      date: date,
      tags: tags,
      fileUrls: fileUrls,
      isPrivate: json['isPrivate'] ?? true,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: json['createdBy'], // Add this line
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'tags': tags,
      'fileUrls': fileUrls,
      'isPrivate': isPrivate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy, // Add this line
    };
  }

  Record copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? category,
    DateTime? date,
    List<String>? tags,
    List<String>? fileUrls,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Record(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      fileUrls: fileUrls ?? this.fileUrls,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
