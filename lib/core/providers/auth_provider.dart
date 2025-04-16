import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:happ/core/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/providers/records_provider.dart';

class AuthProvider with ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isLoading = false;

  // Reference to the RecordsProvider - will be set in initAuthState
  RecordsProvider? _recordsProvider;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _initAuthState();
  }

  void setRecordsProvider(RecordsProvider provider) {
    _recordsProvider = provider;
  }

  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void _initAuthState() {
    _firebaseAuth.authStateChanges().listen((
      firebase_auth.User? firebaseUser,
    ) async {
      if (firebaseUser != null) {
        _currentUser = await _getUserFromFirestore(firebaseUser.uid);

        // If we have a user and the RecordsProvider, fetch records
        if (_currentUser != null && _recordsProvider != null) {
          _recordsProvider!.fetchRecords(_currentUser!.id);
        }
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<User?> _getUserFromFirestore(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return User.fromJson({'id': userId, ...userDoc.data() ?? {}});
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user from Firestore: $e');
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _currentUser = await _getUserFromFirestore(userCredential.user!.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error signing in: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password, {Map<String, dynamic>? additionalInfo}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        // Create base user data
        Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'role': additionalInfo?['role'] ?? 'patient',
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        // Remove role from additionalInfo to avoid duplication
        if (additionalInfo != null) {
          final Map<String, dynamic> remainingInfo = Map.from(additionalInfo);
          remainingInfo.remove('role');
          
          // Convert DateTime to Timestamp for Firestore
          if (remainingInfo['dob'] != null && remainingInfo['dob'] is DateTime) {
            remainingInfo['dob'] = Timestamp.fromDate(remainingInfo['dob']);
          }
          
          userData.addAll(remainingInfo);
        }
        
        // Save to Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);
        
        // Create updated User object
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (userDoc.exists) {
          _currentUser = User.fromJson({
            'id': userCredential.user!.uid,
            ...userDoc.data()!,
          });
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Error signing up: $e');
      _isLoading = false;
      notifyListeners();
      rethrow; // Rethrow to be caught by UI
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Sign out from Firebase
      await _firebaseAuth.signOut();
      _currentUser = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) return false;
      _isLoading = true;
      notifyListeners();

      final updatedUser = User(
        id: _currentUser!.id,
        name: name,
        email: _currentUser!.email,
        role: _currentUser!.role,
        // profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
      );

      await _firestore.collection('users').doc(_currentUser!.id).update({
        'name': name,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      });

      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserRole(String role) async {
    try {
      if (_currentUser == null) return false;

      await _firestore.collection('users').doc(_currentUser!.id).update({
        'role': role,
      });

      _currentUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        role: role,
        // profileImageUrl: _currentUser!.profileImageUrl,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating role: $e');
      return false;
    }
  }

  Future<bool> signInWithId(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get user data from Firestore
      _currentUser = await _getUserFromFirestore(userId);

      _isLoading = false;
      notifyListeners();

      return _currentUser != null;
    } catch (e) {
      debugPrint('Error signing in with ID: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserData(Map<String, dynamic> userData) async {
    try {
      if (_currentUser == null) return false;
      
      _isLoading = true;
      notifyListeners();

      // Convert DateTime fields to Timestamp for Firestore
      final Map<String, dynamic> firestoreData = {...userData};
      if (firestoreData['dob'] != null && firestoreData['dob'] is DateTime) {
        firestoreData['dob'] = Timestamp.fromDate(firestoreData['dob']);
      }

      await _firestore.collection('users').doc(_currentUser!.id).update(firestoreData);

      // Create updated User object
      final userDoc = await _firestore.collection('users').doc(_currentUser!.id).get();
      if (userDoc.exists) {
        _currentUser = User.fromJson({
          'id': _currentUser!.id,
          ...userDoc.data()!,
        });
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating user data: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
