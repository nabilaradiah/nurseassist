import 'package:nurseassist/models/patient.dart';
import 'package:nurseassist/models/vital_reading.dart';
import 'package:nurseassist/models/wound_assessment.dart';
import 'package:nurseassist/services/firestore_service.dart';

/// In-memory stand-in for [FirestoreService] so screens can be tested
/// without Firebase. Records what each screen tried to save.
class FakeFirestoreService implements FirestoreService {
  FakeFirestoreService({
    this.patient,
    List<WoundAssessment>? assessments,
  }) : assessments = assessments ?? [];

  Patient? patient;
  final List<WoundAssessment> assessments;

  // ── What the screens saved ────────────────────────────────────────────────
  final savedTimeAssessments = <String, TimeAssessment>{};
  final savedAssessmentVitals = <String, VitalReading>{};
  final addedVitalReadings = <String, List<VitalReading>>{};
  final updatedAssessments = <WoundAssessment>[];
  final addedPatients = <Patient>[];
  final updatedPatients = <Patient>[];

  @override
  Future<void> saveTimeAssessment({
    required String assessmentId,
    required TimeAssessment timeAssessment,
    required String correctedBy,
  }) async {
    savedTimeAssessments[assessmentId] = timeAssessment;
  }

  @override
  Future<void> saveAssessmentVitals(
      String assessmentId, VitalReading reading) async {
    savedAssessmentVitals[assessmentId] = reading;
  }

  @override
  Future<void> addVitalReading(String patientId, VitalReading reading) async {
    addedVitalReadings.putIfAbsent(patientId, () => []).add(reading);
    final p = patient;
    if (p != null && p.id == patientId) {
      patient = Patient.fromJson({
        ...p.toJson(),
        'vitalReadings': [
          ...p.vitalReadings.map((v) => v.toJson()),
          reading.toJson(),
        ],
      });
    }
  }

  @override
  Future<Patient?> getPatient(String patientId) async => patient;

  @override
  Future<List<WoundAssessment>> getWoundAssessments(String patientId) async =>
      assessments.where((a) => a.patientId == patientId).toList();

  @override
  Future<List<WoundAssessment>> getPendingApprovalAssessments() async =>
      List.of(assessments);

  @override
  Future<void> updateWoundAssessment(WoundAssessment assessment) async {
    updatedAssessments.add(assessment);
  }

  @override
  Future<void> addPatient(Patient patient) async => addedPatients.add(patient);

  @override
  Future<void> updatePatient(Patient patient, {VitalReading? newReading}) async {
    updatedPatients.add(patient);
    if (newReading != null) await addVitalReading(patient.id, newReading);
  }

  @override
  Future<void> recordAssessmentVitals({
    required String patientId,
    required String assessmentId,
    required VitalReading reading,
  }) async {
    await addVitalReading(patientId, reading);
    await saveAssessmentVitals(assessmentId, reading);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeFirestoreService: ${invocation.memberName}');
}
