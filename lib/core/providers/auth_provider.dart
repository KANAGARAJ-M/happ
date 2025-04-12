import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:happ/core/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/services/biometric_auth_service.dart';
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

  Future<bool> signUp(String name, String email, String password, String role) async {
    try {
      _isLoading = true;
      notifyListeners();
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        // Create user document in Firestore
        final newUser = User(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          role: role, // Will be either 'doctor' or 'patient'
          profileImageUrl: null,
        );
        await _firestore
            .collection('users')
            .doc(newUser.id)
            .set(newUser.toJson());
        _currentUser = newUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error signing up: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Clear login state in BiometricAuthService
      await BiometricAuthService.clearLoginState();

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
        profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
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
        profileImageUrl: _currentUser!.profileImageUrl,
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
}
