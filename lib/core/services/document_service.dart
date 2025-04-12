import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:happ/core/models/record.dart';

class DocumentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ensure DocumentService uses the correct collection paths
  Future<Record?> saveScannedDocument({
    required String userId,
    required String title,
    required String content,
    required String category,
    required File? imageFile,
    required List<String> tags,
  }) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(userId, imageFile);
      }

      final record = Record(
        id: '',
        userId: userId,
        title: title,
        description: content,
        category: category,
        date: DateTime.now(),
        tags: tags,
        fileUrls: imageUrl != null ? [imageUrl] : [],
        isPrivate: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to the correct collection path
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .add(record.toJson());

      return Record(
        id: docRef.id,
        userId: record.userId,
        title: record.title,
        description: record.description,
        category: record.category,
        date: record.date,
        tags: record.tags,
        fileUrls: record.fileUrls,
        isPrivate: record.isPrivate,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
    } catch (e) {
      debugPrint('Error saving scanned document: $e');
      return null;
    }
  }

  Future<bool> deleteDocument(Record record) async {
    try {
      // Delete files from storage
      for (String fileUrl in record.fileUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(fileUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting file: $e');
          // Continue with deletion even if file removal fails
        }
      }

      // Delete record from Firestore - FIX: Use correct collection path
      await _firestore
          .collection('users')
          .doc(record.userId)
          .collection('records')
          .doc(record.id)
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  Future<List<Record>> getRecentDocuments(
    String userId, {
    int limit = 10,
  }) async {
    try {
      // FIX: Use correct collection path
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Record.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent documents: $e');
      return [];
    }
  }

  Future<String?> uploadImage(String userId, File imageFile) async {
    try {
      final String fileName = '${_uuid.v4()}${path.extension(imageFile.path)}';
      final String filePath = 'images/$userId/$fileName';

      final uploadTask = await _storage.ref(filePath).putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
}
