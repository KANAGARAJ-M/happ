import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/record.dart';

class RecordsProvider with ChangeNotifier {
  final List<Record> _records = [];
  bool _initialized = false;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<Record> get records => [..._records];
  bool get initialized => _initialized;

  void resetInitializedState() {
    _initialized = false;
  }

  Future<void> fetchRecords(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Clear previous records to avoid duplicates
      _records.clear();
      
      print('Fetching records for user: $userId'); // Debug log
      
      final recordsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .get();
      
      print('Records fetched: ${recordsSnapshot.docs.length}');
      
      for (var doc in recordsSnapshot.docs) {
        final data = doc.data();
        // Add ID to the data map
        data['id'] = doc.id;
        
        // Proper handling of Firestore timestamps
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = data['createdAt'].toDate().toIso8601String();
        }
        if (data['updatedAt'] is Timestamp) {
          data['updatedAt'] = data['updatedAt'].toDate().toIso8601String();
        }
        if (data['date'] is Timestamp) {
          data['date'] = data['date'].toDate();  // Keep as DateTime instead of converting to string
        }
        
        _records.add(Record.fromJson(data));
      }
      
      _initialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching records: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Record?> addRecord(Record record) async {
    try {
      // Add record to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(record.userId)
          .collection('records')
          .add(record.toJson());
      
      // Create record with proper ID
      final newRecord = Record(
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
      
      // Add to local records list
      _records.add(newRecord);
      notifyListeners();
      return newRecord;
    } catch (e) {
      print('Error adding record: $e');
      return null;
    }
  }

  List<dynamic> search(String query) {
    // Implement search logic based on your record model
    // This is a basic implementation - update according to your actual data structure
    return records.where((record) => 
      record.title.toLowerCase().contains(query.toLowerCase()) ||
      record.description.toLowerCase().contains(query.toLowerCase()) ||
      (record.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())) ?? false)
    ).toList();
  }

  Future<bool> removeRecord(String recordId) async {
    try {
      // Find the record
      final recordIndex = _records.indexWhere((record) => record.id == recordId);
      
      if (recordIndex == -1) {
        print('Record not found: $recordId');
        return false;
      }
      
      final record = _records[recordIndex];
      
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(record.userId)
          .collection('records')
          .doc(recordId)
          .delete();
      
      // Delete from local list
      _records.removeAt(recordIndex);
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Error removing record: $e');
      return false;
    }
  }

  Future<bool> updateRecord(Record updatedRecord) async {
    try {
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedRecord.userId)
          .collection('records')
          .doc(updatedRecord.id)
          .update({
            'title': updatedRecord.title,
            'description': updatedRecord.description,
            'category': updatedRecord.category,
            'date': updatedRecord.date.toIso8601String(),
            'tags': updatedRecord.tags,
            'fileUrls': updatedRecord.fileUrls,
            'isPrivate': updatedRecord.isPrivate,
            'updatedAt': updatedRecord.updatedAt.toIso8601String(),
          });
      
      // Update the record in local memory
      final index = _records.indexWhere((record) => record.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating record: $e');
      return false;
    }
  }

  // Other methods like updateRecord, deleteRecord, etc.
}
