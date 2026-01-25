import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Store the current logged-in staff
  Staff? _currentLoggedInStaff;

  // Private constructor
  AuthService._internal();

  // Factory constructor to return singleton instance
  factory AuthService() {
    return _instance;
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get the current logged-in staff
  Staff? get loggedInStaff => _currentLoggedInStaff;

  // Sign in with staff ID and department
  Future<Staff?> signInWithStaffId(String staffId, String department) async {
    try {
      // Clear any previous cached staff when logging in
      _currentLoggedInStaff = null;
      
      // Query Firestore for staff with matching staffId and department
      final querySnapshot = await _firestore
          .collection('staff')
          .where('staffId', isEqualTo: staffId)
          .where('department', isEqualTo: department)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid staff ID or department');
      }

      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();
      
      print('📝 Staff sign-in data from Firebase: $staffData');

      // For demo purposes, create/sign in with a Firebase user
      // In production, you'd use a proper authentication method
      final email = '${staffId.toLowerCase()}@nurseassist.app';
      final password = 'password123'; // Firebase requires min 6 characters

      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // If user doesn't exist, create it
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // Don't cache here - let getCurrentStaff() query and cache on demand
      final staff = Staff.fromJson({
        'id': staffDoc.id,
        ...staffData,
      });
      
      print('✅ Staff signed in: ${staff.name} (${staff.staffId})');
      
      return staff;
    } catch (e) {
      print('❌ Sign in error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _currentLoggedInStaff = null;
    await _auth.signOut();
  }

  // Get current staff data
  Future<Staff?> getCurrentStaff() async {
    try {
      final user = currentUser;
      if (user == null) {
        print('❌ No current user');
        _currentLoggedInStaff = null;
        return null;
      }

      // Always extract staff ID from current Firebase user's email to get the correct staff
      final email = user.email;
      if (email == null) {
        print('❌ User email is null');
        _currentLoggedInStaff = null;
        return null;
      }

      final staffIdFromEmail = email.split('@')[0].toUpperCase();
      print('🔍 Current Firebase user email: $email');
      print('🔍 Extracted staffId from email: $staffIdFromEmail');

      // Check if cached staff matches the current user
      if (_currentLoggedInStaff != null && _currentLoggedInStaff!.staffId == staffIdFromEmail) {
        print('✅ Returning cached staff: ${_currentLoggedInStaff!.name} (${_currentLoggedInStaff!.staffId})');
        return _currentLoggedInStaff;
      }

      // Cache doesn't match or is null, query Firebase for current user's staff data
      final querySnapshot = await _firestore
          .collection('staff')
          .where('staffId', isEqualTo: staffIdFromEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ No staff document found for staffId: $staffIdFromEmail');
        _currentLoggedInStaff = null;
        return null;
      }

      final staffDoc = querySnapshot.docs.first;
      print('📄 Staff document data: ${staffDoc.data()}');
      
      final staff = Staff.fromJson({
        'id': staffDoc.id,
        ...staffDoc.data(),
      });
      
      print('✅ Staff retrieved: ${staff.name} (${staff.staffId})');
      _currentLoggedInStaff = staff;
      return staff;
    } catch (e) {
      print('❌ Get staff error: $e');
      _currentLoggedInStaff = null;
      return null;
    }
  }
}
