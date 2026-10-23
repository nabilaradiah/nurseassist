import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/wound_assessment.dart';
import 'package:nurseassist/models/wound_types_database.dart';

void main() {
  group('Management plan (Wound Care Quick Reference slide)', () {
    // Pins the slide wording so it can't drift from the single source again
    const antibioticYes =
        'Yes, based on tissue C&S result and current guidelines';
    const antibioticMaybe =
        'May or may not, based on tissue C&S result or other infectious '
        'disease, and current guidelines';
    const secondary = '*May require secondary dressing';

    final expected = <int, (List<String>, String?, String, List<String>)>{
      1: (
        ['Foam', 'Polymeric membrane', 'Island dressing'],
        null,
        'No',
        [
          'Ready for secondary wound closure',
          'If wound is small, continue dressing till wound heals by secondary intention',
          'Frequency of dressing varies depending on wound type and dressing material used',
        ],
      ),
      2: (
        ['Foam', 'Alginate', 'Hydrofiber', 'Polymeric membrane'],
        null,
        antibioticMaybe,
        ['Find underlying cause', 'Treat underlying cause if necessary'],
      ),
      3: (
        ['Tulle*', 'Hydrogel*', 'Hydrocolloid*', 'Silver dressing*',
         'Iodine base dressing*', 'Any secondary dressing**'],
        '*May require secondary dressing\n'
            '**Options: Gamgee, gauze, foam, island dressing, etc.',
        antibioticYes,
        ['Debridement may be needed'],
      ),
      4: (
        ['Alginate*', 'Foam', 'Silver*', 'Hydrofiber*', 'Polymeric membrane',
         'Iodine base dressing*'],
        secondary,
        antibioticYes,
        ['Debridement may be needed'],
      ),
      5: (
        ['Hydrogel*', 'Hydrocolloid', 'Polymeric membrane',
         'Composite medical grade honey*'],
        secondary,
        'No',
        ['Debridement is needed'],
      ),
      6: (
        ['Alginate*', 'Foam', 'Polymeric membrane', 'Hydrofiber*'],
        secondary,
        antibioticMaybe,
        ['Surgical/mechanical debridement is recommended',
         'May need repeated debridement'],
      ),
      7: (
        ['Silver*', 'Hydrogel*', 'Hydrocolloid', 'Iodine based dressing*',
         'Polymeric membrane', 'Composite medical grade honey*'],
        null,
        antibioticYes,
        ['Surgical debridement is strongly recommended'],
      ),
      8: (
        ['Alginate*', 'Hydrofiber*', 'Foam*', 'Polymeric membrane*',
         'Iodine base dressing*', 'Silver*', 'Charcoal*'],
        '*Require combination or composite antimicrobial dressing '
            '(moisture control + antimicrobial)\n'
            'Charcoal can be used for odour management',
        antibioticYes,
        ['Surgical debridement is strongly recommended'],
      ),
    };

    for (final MapEntry(key: type, value: e) in expected.entries) {
      test('Type $type', () {
        final m = WoundTypesDatabase.getManagement(type);
        expect(m.dressingMaterials, e.$1);
        expect(m.dressingNotes, e.$2);
        expect(m.antibioticRecommendation, e.$3);
        expect(m.surgicalProcedures, e.$4);
      });
    }
  });

  test('specialist confirmation is required for Types 3, 4 and 6 only', () {
    final flagged = [
      for (var t = 1; t <= 8; t++)
        if (WoundTypesDatabase.requiresSpecialistConfirmation(t)) t,
    ];
    expect(flagged, [3, 4, 6]);
  });

  group('unknown wound types are errors, never Type 1', () {
    test('type IDs outside 1–8', () {
      for (final bad in [0, 9, -1]) {
        expect(() => WoundTypesDatabase.getWoundTypeName(bad),
            throwsArgumentError, reason: '$bad');
        expect(() => WoundTypesDatabase.getManagement(bad),
            throwsArgumentError, reason: '$bad');
        expect(() => WoundTypesDatabase.requiresSpecialistConfirmation(bad),
            throwsArgumentError, reason: '$bad');
      }
    });

    test('unknown type names', () {
      for (final bad in ['Type_9', 'type_3', 'burn', '']) {
        expect(() => WoundTypesDatabase.getWoundTypeData(bad),
            throwsArgumentError, reason: bad);
      }
    });

    test('an assessment with no type has no display type', () {
      final a = WoundAssessment(
        id: 'a',
        patientId: 'p',
        imageUrl: '',
        assessmentDate: DateTime(2026, 10, 1),
      );
      expect(a.hasWoundType, isFalse);
      expect(a.displayWoundType, isNull);
      expect(a.displayWoundName, isNull);
    });
  });

  test('dressing notes survive a Firestore round trip', () {
    final m = WoundTypesDatabase.getManagement(4);
    final restored = WoundManagement.fromJson(m.toJson());
    expect(restored.dressingNotes, '*May require secondary dressing');
    // Records saved before this field existed still load
    final legacy = WoundManagement.fromJson({
      'dressingMaterials': <String>[],
      'antibioticRecommendation': 'No',
      'surgicalProcedures': <String>[],
    });
    expect(legacy.dressingNotes, isNull);
  });
}
