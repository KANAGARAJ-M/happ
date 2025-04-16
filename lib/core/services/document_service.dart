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
    File? imageFile,
    required List<String> tags,
    bool isPrivate = true,
    required String createdBy, // Make this required to avoid null errors
  }) async {
    try {
      // Upload image if provided
      String? imageUrl;
      if (imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
        final ref = _storage.ref().child('records/$userId/$fileName');
        final uploadTask = ref.putFile(imageFile);
        await uploadTask.whenComplete(() {});
        imageUrl = await ref.getDownloadURL();
      }

      final now = DateTime.now();
      
      // Create record
      final record = Record(
        id: '', // ID will be assigned by Firestore
        userId: userId,
        title: title,
        description: content,
        category: category,
        date: now,
        tags: tags,
        fileUrls: imageUrl != null ? [imageUrl] : [],
        isPrivate: true, // Always force to private
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy, // Set creator ID
      );

      // Save to the correct collection path
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .add(record.toJson());

      return record.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error saving scanned document: $e');
      return null;
    }
  }

  // Add this method to handle scanned documents with privacy
  Future<Record?> savePrivateScannedDocument({
    required String userId,
    required String title,
    required String content,
    required String category,
    required List<String> tags,
    File? imageFile,
    bool isPrivate = true, // Force private by default
  }) async {
    try {
      // Create a unique ID for the record
      final String recordId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create record data
      final now = DateTime.now();
      
      // Define the record
      final record = Record(
        id: recordId,
        userId: userId,
        title: title,
        description: content,
        category: category,
        date: now,
        tags: tags,
        fileUrls: [], // Will be updated later after image upload
        isPrivate: true, // Always make private
        createdAt: now,
        updatedAt: now,
      );
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordId)
          .set(record.toJson());
      
      // Return the record
      return record;
    } catch (e) {
      print('Error saving scanned document: $e');
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
