import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';

class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Lazy so reading [loggedInStaff] never needs Firebase to be running
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Staff? _currentLoggedInStaff;

  // ── Public getters ─────────────────────────────────────────────────────────
  User?  get currentUser    => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Staff? get loggedInStaff  => _currentLoggedInStaff;

  /// Lets widget tests act as a signed-in staff member without Firebase.
  @visibleForTesting
  set loggedInStaffForTest(Staff? staff) => _currentLoggedInStaff = staff;

  // ── Sign in ────────────────────────────────────────────────────────────────
  // ── Staff ID → email lookup ────────────────────────────────────────────────
  /// staffLookup/{STAFF_ID} holds only { email, uid }. It is the one piece of
  /// staff data readable before login (see firestore.rules); full profiles in
  /// staff/ need a signed-in user.
  DocumentReference<Map<String, dynamic>>? _lookupRef(String normId) {
    // A '/' would turn the ID into a different document path
    if (normId.isEmpty || normId.contains('/')) return null;
    return _firestore.collection('staffLookup').doc(normId);
  }

  /// The email registered for [staffId], or null if there is none.
  Future<String?> _emailForStaffId(String staffId) async {
    final ref = _lookupRef(staffId.trim().toUpperCase());
    if (ref == null) return null;
    final doc = await ref.get();
    final email = doc.data()?['email'] as String?;
    return (email == null || email.isEmpty) ? null : email;
  }

  /// Sign in with [staffId] + [password].
  /// Looks up the staff email from Firestore, then authenticates with Firebase.
  Future<Staff?> signInWithStaffId(String staffId, String password) async {
    _currentLoggedInStaff = null;

    // 1–2. Find the email used for Firebase Auth
    final email = await _emailForStaffId(staffId);
    if (email == null) {
      throw Exception('Staff ID not found. Please check your Staff ID or register first.');
    }

    // 3. Sign in with email + password
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect password. Please try again.');
        case 'user-not-found':
          throw Exception('No account found for this Staff ID.');
        case 'user-disabled':
          throw Exception('This account has been disabled. Contact your administrator.');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later.');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    }

    // 4. Enforce email verification
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && !firebaseUser.emailVerified) {
      await _auth.signOut();
      throw Exception(
          'Email not verified. Please check your inbox (or spam/junk folder) and click the verification link before logging in.');
    }

    // 5. Load the full profile (readable now that we're signed in) and cache it
    final staff = await getCurrentStaff();
    if (staff == null) {
      await _auth.signOut();
      throw Exception('No staff profile found for this account. Please contact your administrator.');
    }
    return staff;
  }

  // ── Register ───────────────────────────────────────────────────────────────
  /// Create a new staff account.
  /// - Stores the real [email] and [password] in Firebase Auth.
  /// - Saves staff profile to Firestore with role='nurse'.
  /// - Sends a confirmation / verification email automatically.
  Future<Staff> registerStaff({
    required String staffId,
    required String fullName,
    required String department,
    required String email,
    required String password,
  }) async {
    final normId    = staffId.trim().toUpperCase();
    final normName  = fullName.trim();
    final normEmail = email.trim().toLowerCase();

    // 1. Ensure Staff ID is not already taken. This is just an early check for
    //    a friendly message — the rules also refuse to overwrite an existing
    //    staffLookup document, so two people can never claim the same ID.
    final lookupRef = _lookupRef(normId);
    if (lookupRef == null) {
      throw Exception('Staff ID must not be empty or contain "/".');
    }
    if ((await lookupRef.get()).exists) {
      throw Exception('Staff ID $normId is already registered.');
    }

    // 2. Create Firebase Auth account with REAL email + password
    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account with this email already exists.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 8 characters.');
        default:
          throw Exception(e.message ?? 'Registration failed.');
      }
    }

    // 3–4. Save the Staff ID lookup, the staff profile and roles/{uid} in one
    //      batch, so either all three exist or none do. roles/{uid} lets the
    //      Security Rules check the role without a query (rules only support
    //      direct document reads).
    try {
      final uid = credential.user!.uid;
      final staffDoc = _firestore.collection('staff').doc();
      final batch = _firestore.batch()
        ..set(lookupRef, {'email': normEmail, 'uid': uid})
        ..set(staffDoc, {
          'staffId':    normId,
          'name':       normName,
          'department': department.trim(),
          'email':      normEmail,
          'role':       'nurse',
          'createdAt':  FieldValue.serverTimestamp(),
        })
        ..set(_firestore.collection('roles').doc(uid),
            {'role': 'nurse', 'staffId': normId});
      await batch.commit();

      // 5. Send confirmation / verification email
      await credential.user?.sendEmailVerification();
      // Verification email sent;

      // 5. Sign out — user must log in manually after verifying
      _currentLoggedInStaff = null;
      await _auth.signOut();

      return Staff(
        id:         staffDoc.id,
        staffId:    normId,
        name:       normName,
        department: department.trim(),
        email:      normEmail,
        role:       'nurse',
      );
    } catch (e) {
      // Roll back Auth account if Firestore write fails
      try {
        await credential.user?.delete();
      } catch (_) {}
      await _auth.signOut();
      rethrow;
    }
  }

  // ── Forgot password ────────────────────────────────────────────────────────
  /// Send a password-reset email.
  /// Accepts either a Staff ID (looks up their email) or a direct email address.
  Future<void> sendPasswordReset(String staffIdOrEmail) async {
    String emailToReset;

    if (staffIdOrEmail.contains('@')) {
      // Direct email supplied
      emailToReset = staffIdOrEmail.trim().toLowerCase();
    } else {
      // Treat as Staff ID — look up email
      final storedEmail = await _emailForStaffId(staffIdOrEmail);
      if (storedEmail == null) {
        throw Exception('Staff ID not found.');
      }
      emailToReset = storedEmail;
    }

    await _auth.sendPasswordResetEmail(email: emailToReset);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _currentLoggedInStaff = null;
    await _auth.signOut();
  }

  // ── Get current staff ──────────────────────────────────────────────────────
  Future<Staff?> getCurrentStaff() async {
    try {
      final user = currentUser;
      if (user == null) {
        _currentLoggedInStaff = null;
        return null;
      }

      final email = user.email;
      if (email == null) {
        _currentLoggedInStaff = null;
        return null;
      }

      // Return cached value if it matches the current user
      if (_currentLoggedInStaff != null &&
          _currentLoggedInStaff!.email?.toLowerCase() == email.toLowerCase()) {
        return _currentLoggedInStaff;
      }

      // Query Firestore by email
      final query = await _firestore
          .collection('staff')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      // Fallback: legacy accounts stored staffId derived from email
      if (query.docs.isEmpty) {
        final staffIdFromEmail = email.split('@')[0].toUpperCase();
        final fallback = await _firestore
            .collection('staff')
            .where('staffId', isEqualTo: staffIdFromEmail)
            .limit(1)
            .get();

        if (fallback.docs.isEmpty) {
          _currentLoggedInStaff = null;
          return null;
        }

        final staff = Staff.fromJson({'id': fallback.docs.first.id, ...fallback.docs.first.data()});
        _currentLoggedInStaff = staff;
        return staff;
      }

      final staff = Staff.fromJson({'id': query.docs.first.id, ...query.docs.first.data()});
      _currentLoggedInStaff = staff;
      return staff;
    } catch (_) {
      _currentLoggedInStaff = null;
      return null;
    }
  }
}
