import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/chronic_condition.dart';
import 'package:nurseassist/models/patient.dart';

Patient _basePatient({List<ChronicCondition> chronicConditions = const []}) {
  return Patient(
    id: 'p1',
    mrn: 'MRN-001',
    name: 'Test Patient',
    age: 40,
    gender: 'Female',
    contact: '0123456789',
    registeredDate: DateTime(2026, 1, 1),
    staffIdAssignedTo: 'staff1',
    chronicConditions: chronicConditions,
  );
}

void main() {
  group('Patient chronicConditions persistence', () {
    test(
        'toJson -> fromJson round-trips multiple conditions, '
        'the exact map shape Firestore reads/writes', () {
      final patient = _basePatient(chronicConditions: [
        ChronicCondition(
          id: 'c1',
          name: 'Type 2 Diabetes',
          diagnosedDate: DateTime(2019, 3, 1),
        ),
        ChronicCondition(
          id: 'c2',
          name: 'Hypertension',
          diagnosedDate: DateTime(2022, 6, 1),
          isApproximate: true,
        ),
      ]);

      // This mirrors exactly what FirestoreService does: write patient.toJson()
      // as the document body, then rebuild a Patient from the map Firestore
      // hands back on read.
      final stored = patient.toJson();
      final reloaded = Patient.fromJson(stored);

      expect(stored['chronicConditions'], isA<List>());
      expect((stored['chronicConditions'] as List).length, 2);
      expect(stored.containsKey('chronicDiseases'), false);

      expect(reloaded.chronicConditions.length, 2);
      expect(reloaded.chronicConditions[0].name, 'Type 2 Diabetes');
      expect(reloaded.chronicConditions[0].diagnosedDate, DateTime(2019, 3, 1));
      expect(reloaded.chronicConditions[0].isApproximate, false);
      expect(reloaded.chronicConditions[1].name, 'Hypertension');
      expect(reloaded.chronicConditions[1].isApproximate, true);
    });

    test('toJson produces an empty list, not null, when there are no conditions',
        () {
      final stored = _basePatient().toJson();
      expect(stored['chronicConditions'], isEmpty);
    });

    test(
        'fromJson migrates a pre-existing legacy chronicDiseases string '
        'when chronicConditions is absent (old Firestore documents)', () {
      final legacyDoc = _basePatient().toJson()
        ..remove('chronicConditions')
        ..['chronicDiseases'] = 'Hypertension, Type 2 Diabetes';

      final reloaded = Patient.fromJson(legacyDoc);

      expect(reloaded.chronicConditions.length, 2);
      expect(reloaded.chronicConditions[0].name, 'Hypertension');
      expect(reloaded.chronicConditions[1].name, 'Type 2 Diabetes');
      expect(reloaded.chronicConditions.every((c) => c.diagnosedDate == null),
          true);
    });

    test('fromJson prefers chronicConditions over a lingering legacy string',
        () {
      final doc = _basePatient(chronicConditions: [
        ChronicCondition(id: 'c1', name: 'Asthma'),
      ]).toJson();
      // Simulate an old document that was re-saved: the new array exists,
      // but the orphaned legacy field is still sitting there inert.
      doc['chronicDiseases'] = 'Old Stale Value';

      final reloaded = Patient.fromJson(doc);

      expect(reloaded.chronicConditions.length, 1);
      expect(reloaded.chronicConditions[0].name, 'Asthma');
    });

    test('fromJson returns an empty list when neither field is present', () {
      final doc = _basePatient().toJson()..remove('chronicConditions');
      final reloaded = Patient.fromJson(doc);
      expect(reloaded.chronicConditions, isEmpty);
    });
  });
}
