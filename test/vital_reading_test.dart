import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/patient.dart';
import 'package:nurseassist/models/vital_reading.dart';
import 'package:nurseassist/models/wound_assessment.dart';
import 'package:nurseassist/widgets/vital_signs.dart';

VitalReading _reading({
  int? sys,
  int? dia,
  int? hr,
  int? spo2,
  double? temp,
  double? rbs,
  int? pain,
  DateTime? at,
}) =>
    VitalReading(
      systolic: sys,
      diastolic: dia,
      heartRate: hr,
      spo2: spo2,
      temperature: temp,
      rbs: rbs,
      painScore: pain,
      takenAt: at ?? DateTime(2026, 10, 3, 9),
    );

void main() {
  group('VitalReading flags', () {
    test('normal adult values are not flagged', () {
      final r = _reading(
          sys: 120, dia: 80, hr: 80, spo2: 98, temp: 36.8, rbs: 6.5, pain: 2);
      expect(r.hasAbnormal, isFalse);
    });

    test('flags high and low values', () {
      final r = _reading(hr: 110, spo2: 92, temp: 38.2, rbs: 3.5, pain: 7);
      expect(r.flagOf(VitalSign.hr), VitalFlag.high);
      expect(r.flagOf(VitalSign.spo2), VitalFlag.low);
      expect(r.flagOf(VitalSign.temp), VitalFlag.high);
      expect(r.flagOf(VitalSign.rbs), VitalFlag.low);
      expect(r.flagOf(VitalSign.pain), VitalFlag.high);
    });

    test('BP is flagged when either number is out of range', () {
      expect(_reading(sys: 128, dia: 92).flagOf(VitalSign.bp), VitalFlag.high);
      expect(_reading(sys: 85, dia: 70).flagOf(VitalSign.bp), VitalFlag.low);
      expect(_reading(sys: 118, dia: 76).flagOf(VitalSign.bp), VitalFlag.normal);
      expect(_reading(sys: 118, dia: 76).displayOf(VitalSign.bp), '118/76');
    });

    test('unrecorded values are not shown or flagged', () {
      final r = _reading(hr: 80);
      expect(r.displayOf(VitalSign.temp), isNull);
      expect(r.flagOf(VitalSign.temp), VitalFlag.normal);
    });
  });

  group('Storage', () {
    test('round-trips through JSON', () {
      final r = VitalReading(
        systolic: 130,
        diastolic: 85,
        heartRate: 90,
        spo2: 97,
        temperature: 37.6,
        rbs: 8.2,
        painScore: 4,
        takenAt: DateTime(2026, 10, 3, 14, 30),
        takenBy: 'WRN-002',
        takenByName: 'Test Nurse',
      );
      expect(VitalReading.fromJson(r.toJson()).toJson(), r.toJson());
    });

    test('patient keeps a dated history and finds the latest reading', () {
      final older = _reading(hr: 70, at: DateTime(2026, 10, 1));
      final newer = _reading(hr: 95, at: DateTime(2026, 10, 3));
      final json = {
        'id': 'p1',
        'mrn': 'MRN-001',
        'name': 'Test',
        'age': 60,
        'gender': 'Female',
        'contact': '0123',
        'registeredDate': '2026-01-01T00:00:00.000',
        'staffIdAssignedTo': 's1',
        // Firestore may return them in any order
        'vitalReadings': [newer.toJson(), older.toJson()],
      };
      final p = Patient.fromJson(json);
      expect(p.vitalReadings.first.heartRate, 70); // sorted oldest first
      expect(p.latestVitals!.heartRate, 95);

      final legacy = Patient.fromJson(json..remove('vitalReadings'));
      expect(legacy.vitalReadings, isEmpty);
      expect(legacy.latestVitals, isNull);
    });
  });

  group('Entry validation', () {
    test('blank is allowed, typos are caught', () {
      final inputs = VitalInputs();
      expect(inputs.isEmpty, isTrue);
      expect(inputs.validate(), isNull);

      inputs.spo2.text = '980';
      expect(inputs.validate(), contains('SpO₂'));

      inputs.spo2.text = '98';
      inputs.systolic.text = '120';
      expect(inputs.validate(), contains('both systolic and diastolic'));

      inputs.diastolic.text = '130';
      expect(inputs.validate(), contains('lower than systolic'));

      inputs.diastolic.text = '80';
      inputs.temperature.text = '37,4'; // comma decimal is accepted
      expect(inputs.validate(), isNull);
      expect(inputs.preview.temperature, 37.4);
      inputs.dispose();
    });
  });

  test('vitals are stored on the wound assessment and survive copyWith', () {
    final reading = _reading(sys: 120, dia: 80, temp: 38.1);
    final assessment = WoundAssessment(
      id: 'a1',
      patientId: 'p1',
      imageUrl: 'x',
      assessmentDate: DateTime(2026, 10, 3),
      vitals: reading,
    );

    final restored = WoundAssessment.fromJson(assessment.toJson());
    expect(restored.vitals!.toJson(), reading.toJson());
    expect(restored.vitals!.flagOf(VitalSign.temp), VitalFlag.high);
    expect(restored.copyWith(additionalNotes: 'x').vitals, isNotNull);

    final legacy = WoundAssessment.fromJson(assessment.toJson()..remove('vitals'));
    expect(legacy.vitals, isNull);
  });

  test('timestamp label', () {
    expect(formatVitalsTimestamp(DateTime(2026, 10, 3, 14, 5)), '3 Oct 2026, 2:05 PM');
    expect(formatVitalsTimestamp(DateTime(2026, 10, 3, 0, 30)), '3 Oct 2026, 12:30 AM');
  });

  test('age label', () {
    final now = DateTime(2026, 10, 3, 12);
    expect(formatVitalsAge(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(formatVitalsAge(now.subtract(const Duration(minutes: 45)), now: now), '45 min ago');
    expect(formatVitalsAge(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(formatVitalsAge(now.subtract(const Duration(days: 2)), now: now), '2 days ago');
    expect(formatVitalsAge(DateTime(2026, 9, 1), now: now), '1 Sep 2026');
  });
}
