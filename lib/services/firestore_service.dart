import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import 'local_storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  // Patient operations
  Future<List<Patient>> getPatients() async {
    try {
      final querySnapshot = await _firestore
          .collection('patients')
          .orderBy('registeredDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Patient.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Get patients error: $e');
      return [];
    }
  }

  // Get patients assigned to a specific staff member
  Future<List<Patient>> getPatientsByStaffId(String staffId) async {
    try {
      print('🔍 Querying patients for staffId: "$staffId"');
      
      // First, check all patients to debug
      final allPatientsSnapshot = await _firestore
          .collection('patients')
          .get();
      print('📋 Total patients in Firebase: ${allPatientsSnapshot.docs.length}');
      
      // Print all patient data for debugging
      for (var doc in allPatientsSnapshot.docs) {
        final data = doc.data();
        print('  - Patient: ${data['name']} | staffIdAssignedTo: "${data['staffIdAssignedTo']}"');
      }
      
      // Now filter by staffId
      final querySnapshot = await _firestore
          .collection('patients')
          .where('staffIdAssignedTo', isEqualTo: staffId)
          .get();

      print('✅ Found ${querySnapshot.docs.length} patients for staffId: $staffId');
      
      final patients = querySnapshot.docs
          .map((doc) {
            print('  📄 Loading patient: ${doc.data()['name']}');
            return Patient.fromJson({
              'id': doc.id,
              ...doc.data(),
            });
          })
          .toList();
      
      // Sort by registeredDate in memory
      patients.sort((a, b) => b.registeredDate.compareTo(a.registeredDate));
      
      return patients;
    } catch (e) {
      print('❌ Get patients by staff ID error: $e');
      return [];
    }
  }

  Future<Patient?> getPatient(String patientId) async {
    try {
      final doc = await _firestore.collection('patients').doc(patientId).get();
      if (!doc.exists) return null;
      return Patient.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e) {
      print('Get patient error: $e');
      return null;
    }
  }

  Future<void> addPatient(Patient patient) async {
    await _firestore.collection('patients').doc(patient.id).set(patient.toJson());
  }

  Future<void> updatePatient(Patient patient) async {
    await _firestore.collection('patients').doc(patient.id).update(patient.toJson());
  }

  Future<Patient?> getPatientByMrn(String mrn) async {
    try {
      final query = await _firestore
          .collection('patients')
          .where('mrn', isEqualTo: mrn)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return Patient.fromJson({
        'id': doc.id,
        ...doc.data(),
      });
    } catch (e) {
      print('Get patient by MRN error: $e');
      return null;
    }
  }

  Future<void> deletePatientAndAssessments(String patientId) async {
    // Delete related wound assessments first
    final assessmentsSnapshot = await _firestore
        .collection('woundAssessments')
        .where('patientId', isEqualTo: patientId)
        .get();

    for (final doc in assessmentsSnapshot.docs) {
      await _firestore.collection('woundAssessments').doc(doc.id).delete();
    }

    // Delete patient record
    await _firestore.collection('patients').doc(patientId).delete();
  }

  // Wound Assessment operations
  Future<List<WoundAssessment>> getWoundAssessments(String patientId) async {
    try {
      final querySnapshot = await _firestore
          .collection('woundAssessments')
          .where('patientId', isEqualTo: patientId)
          .get();

      final items = querySnapshot.docs
          .map((doc) => WoundAssessment.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      items.sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
      return items;
    } catch (e) {
      print('Get wound assessments error: $e');
      return [];
    }
  }

  Future<WoundAssessment?> getWoundAssessment(String assessmentId) async {
    try {
      final doc = await _firestore.collection('woundAssessments').doc(assessmentId).get();
      if (!doc.exists) return null;
      return WoundAssessment.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e) {
      print('Get wound assessment error: $e');
      return null;
    }
  }

  Future<void> addWoundAssessment(WoundAssessment assessment) async {
    await _firestore
        .collection('woundAssessments')
        .doc(assessment.id)
        .set(assessment.toJson());

    // Update patient's wound assessment list
    await _firestore.collection('patients').doc(assessment.patientId).update({
      'woundAssessmentIds': FieldValue.arrayUnion([assessment.id]),
    });
  }

  Future<void> updateWoundAssessment(WoundAssessment assessment) async {
    await _firestore
        .collection('woundAssessments')
        .doc(assessment.id)
        .update(assessment.toJson());
  }

  Future<void> deleteWoundAssessment({
    required String assessmentId,
    required String patientId,
  }) async {
    await _firestore.collection('woundAssessments').doc(assessmentId).delete();
    await _firestore.collection('patients').doc(patientId).update({
      'woundAssessmentIds': FieldValue.arrayRemove([assessmentId]),
    });
  }

  // Save image to local device storage
  Future<String> uploadWoundImage(File imageFile, String fileName) async {
    try {
      final filePath = await _localStorage.saveWoundImage(imageFile, fileName);
      return filePath; // Return local file path instead of URL
    } catch (e) {
      print('Save image error: $e');
      rethrow;
    }
  }

  // Initialize sample data
  Future<void> initializeSampleData() async {
    try {
      // Always try to add sample staff (will update if exists)
      await _firestore.collection('staff').doc('staff1').set({
        'staffId': '22167',
        'name': 'AISHA',
        'department': 'Nursing',
      });

      // Check if patients already exist
      final patientsSnapshot = await _firestore.collection('patients').limit(1).get();
      if (patientsSnapshot.docs.isNotEmpty) {
        print('Sample data already initialized');
        return; // Patients already exist
      }

      // Add sample patients
      final patients = [
        Patient(
          id: 'patient1',
          mrn: 'MRN-001234',
          name: 'Sabrina Elyasa',
          age: 29,
          gender: 'Female',
          contact: '0174067606',
          registeredDate: DateTime(2025, 12, 14),
          staffIdAssignedTo: 'WRN-001',
        ),
        Patient(
          id: 'patient2',
          mrn: 'MRN-001235',
          name: 'Abdul Wahab',
          age: 67,
          gender: 'Male',
          contact: '0123456789',
          registeredDate: DateTime(2025, 12, 10),
          staffIdAssignedTo: 'WRN-001',
        ),
        Patient(
          id: 'patient3',
          mrn: 'MRN-001236',
          name: 'Nik Marwaa',
          age: 32,
          gender: 'Female',
          contact: '0198765432',
          registeredDate: DateTime(2025, 12, 5),
          staffIdAssignedTo: 'WRN-002',
        ),
      ];

      for (var patient in patients) {
        await addPatient(patient);
      }
      
      print('Sample data initialized successfully');
    } catch (e) {
      print('Error initializing sample data: $e');
    }
  }
}
