import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/patient.dart';
import 'package:nurseassist/models/wound_assessment.dart';
import 'package:nurseassist/models/wound_types_database.dart';

Patient _patient(String? allergies) => Patient(
      id: 'p1',
      mrn: 'MRN-001',
      name: 'Test Patient',
      age: 60,
      gender: 'Female',
      contact: '0123456789',
      registeredDate: DateTime(2026, 1, 1),
      staffIdAssignedTo: 'staff1',
      allergies: allergies,
    );

TimeAssessment _ta({
  bool over25 = false,
  String infection = 'Nil',
  String moisture = TimeAssessment.moistureDry,
}) =>
    TimeAssessment(
      necroticPct: over25 ? 40 : 10,
      sloughPct: 0,
      necroticSloughOver25: over25,
      infection: infection,
      moisture: moisture,
      edges: 'Attached',
    );

void main() {
  group('Wound Care Quick Reference scoring (T + I + M = type)', () {
    // Summary slide: <25%/>25%, infection no/yes, dry/wet → Types 1–8
    const table = [
      (false, false, false, 1),
      (false, false, true, 2),
      (false, true, false, 3),
      (false, true, true, 4),
      (true, false, false, 5),
      (true, false, true, 6),
      (true, true, false, 7),
      (true, true, true, 8),
    ];

    for (final (over25, infected, wet, type) in table) {
      test('Type $type', () {
        final ta = _ta(
          over25: over25,
          infection: infected ? 'Local signs' : 'Nil',
          moisture:
              wet ? TimeAssessment.moistureWet : TimeAssessment.moistureDry,
        );
        expect(ta.woundType, type);

        final decoded = TimFactors.fromWoundType(type);
        expect(decoded.over25, over25);
        expect(decoded.infected, infected);
        expect(decoded.wet, wet);
      });
    }

    test('is null until T, I and M are all recorded', () {
      expect(const TimeAssessment(infection: 'Nil').woundType, isNull);
    });

    test('names the factors that differ from the AI type', () {
      final assessment = WoundAssessment(
        id: 'a1',
        patientId: 'p1',
        imageUrl: 'x',
        assessmentDate: DateTime(2026, 10, 3),
        modelPredictedType: 6, // >25%, no infection, wet
        timeAssessment: _ta(
          over25: true,
          infection: 'Spreading / systemic',
          moisture: TimeAssessment.moistureWet,
        ), // Type 8
      );
      expect(assessment.timeAssessment!.woundType, 8);
      expect(assessment.timeDifferencesFromAi, ['Infection']);
      expect(assessment.timeDisagreesWithAi, isTrue);
    });

    test('per-factor AI probabilities sum the matching types', () {
      final probs = TimProbabilities.fromClassProbabilities(
          [0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.0, 0.4])!;
      expect(probs.over25, closeTo(1.0, 1e-9));
      expect(probs.infected, closeTo(0.4, 1e-9));
      expect(probs.wet, closeTo(1.0, 1e-9));
      expect(TimProbabilities.fromClassProbabilities(null), isNull);
    });
  });

  group('TimeAssessment JSON', () {
    test('round-trips through the JSON stored in Firestore', () {
      final ta = TimeAssessment(
        necroticPct: 10,
        sloughPct: 40,
        granulationPct: 30,
        epithelialPct: 20,
        necroticSloughOver25: true,
        infection: 'Nil',
        inflammation: 'Nil',
        moisture: TimeAssessment.moistureWet,
        heavyExudate: true,
        edges: 'Undermining',
        edgeDetails: "12–3 o'clock, 2 cm",
        surroundingSkin: const ['Dry / desiccation'],
        surroundingSkinNotes: 'HPSC-2A',
        assessedBy: 'WRN-002',
        assessedByName: 'Test Nurse',
        assessedAt: DateTime(2026, 10, 3, 9, 30),
      );

      final restored = TimeAssessment.fromJson(ta.toJson());

      expect(restored.toJson(), ta.toJson());
      expect(restored.woundType, 6);
      expect(restored.tissueTotal, 100);
      expect(restored.assessedByDisplay, 'Test Nurse (WRN-002)');
    });

    test('keeps the nurse\'s answer at exactly 25%', () {
      final ta = TimeAssessment.fromJson({
        'necroticPct': 15,
        'sloughPct': 10,
        'necroticSloughOver25': true,
        'infection': 'Nil',
        'moisture': TimeAssessment.moistureDry,
      });
      expect(ta.necroticSloughPct, 25);
      expect(ta.woundType, 5);
    });

    test('migrates the earlier Dry / Moist / Wet records', () {
      TimeAssessment legacy(String moisture, String? exudate) =>
          TimeAssessment.fromJson({
            'necroticPct': 10,
            'infection': 'Nil',
            'moisture': moisture,
            'exudateAmount': exudate,
          });

      expect(legacy('Dry', 'Nil').moisture, TimeAssessment.moistureDry);
      expect(legacy('Moist', 'Minimal').moisture, TimeAssessment.moistureDry);
      expect(legacy('Moist', 'Moderate').moisture, TimeAssessment.moistureWet);
      expect(legacy('Wet', 'Heavy').heavyExudate, isTrue);
      // 10% → under 25% derived when the answer wasn't stored
      expect(legacy('Dry', 'Nil').woundType, 1);
    });

    test('is carried through WoundAssessment JSON and copyWith', () {
      final assessment = WoundAssessment(
        id: 'a1',
        patientId: 'p1',
        imageUrl: 'https://example.com/w.jpg',
        assessmentDate: DateTime(2026, 10, 3),
        timeAssessment: const TimeAssessment(edges: 'Attached'),
      );

      final restored = WoundAssessment.fromJson(assessment.toJson());
      expect(restored.timeAssessment?.edges, 'Attached');

      final legacy = WoundAssessment.fromJson(
        assessment.toJson()..remove('timeAssessment'),
      );
      expect(legacy.timeAssessment, isNull);

      final kept = restored.copyWith(additionalNotes: 'note');
      expect(kept.timeAssessment?.edges, 'Attached');
    });
  });

  group('Wound type reference table', () {
    test('matches the Wound Care Quick Reference slide for every type', () {
      for (var type = 1; type <= 8; type++) {
        final f = TimFactors.fromWoundType(type);
        final c = WoundTypesDatabase.getWoundTypeData('Type_$type')[
            'characteristics'] as Map<String, dynamic>;

        expect(c['necroticTissue'],
            'Necrotic tissue / slough ${f.over25 ? '>' : '<'}25%',
            reason: 'Type $type');
        expect(c['infection'],
            f.infected ? 'Presence of infection' : 'No signs of infection',
            reason: 'Type $type');
        expect(c['exudateLevel'],
            f.wet ? 'Moderate exudates / wet' : 'Dry / minimal exudates',
            reason: 'Type $type');
      }
    });
  });

  group('Patient.hasKnownAllergies', () {
    test('treats blank and "none" placeholders as no allergy', () {
      for (final v in [null, '', '  ', 'None', 'nil', 'NKDA', 'NKDA.', 'NKMI', 'No known allergies']) {
        expect(_patient(v).hasKnownAllergies, isFalse, reason: '"$v"');
      }
    });

    test('recognises a real allergy', () {
      expect(_patient('Povidone-iodine').hasKnownAllergies, isTrue);
      expect(_patient('Seafood').hasKnownAllergies, isTrue);
    });
  });
}
