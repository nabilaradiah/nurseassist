import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/chronic_condition.dart';

void main() {
  group('ChronicCondition.toJson / fromJson', () {
    test('round-trips an exact-date condition', () {
      final condition = ChronicCondition(
        id: 'abc-123',
        name: 'Type 2 Diabetes',
        diagnosedDate: DateTime(2019, 3, 1),
        isApproximate: false,
      );

      final json = condition.toJson();
      final restored = ChronicCondition.fromJson(json);

      expect(restored.id, 'abc-123');
      expect(restored.name, 'Type 2 Diabetes');
      expect(restored.diagnosedDate, DateTime(2019, 3, 1));
      expect(restored.isApproximate, false);
    });

    test('round-trips an approximate condition', () {
      final condition = ChronicCondition(
        id: 'xyz-789',
        name: 'Hypertension',
        diagnosedDate: DateTime(2020, 6, 1),
        isApproximate: true,
      );

      final restored = ChronicCondition.fromJson(condition.toJson());

      expect(restored.diagnosedDate, DateTime(2020, 6, 1));
      expect(restored.isApproximate, true);
    });

    test('fromJson handles a null diagnosedDate (legacy/unknown)', () {
      final restored = ChronicCondition.fromJson({
        'id': 'id-1',
        'name': 'Asthma',
        'diagnosedDate': null,
        'isApproximate': false,
      });

      expect(restored.diagnosedDate, isNull);
      expect(restored.name, 'Asthma');
    });

    test('fromJson defaults missing id/isApproximate rather than throwing', () {
      final restored = ChronicCondition.fromJson({'name': 'Osteoarthritis'});

      expect(restored.id, isNotEmpty);
      expect(restored.name, 'Osteoarthritis');
      expect(restored.isApproximate, false);
    });
  });

  group('ChronicCondition.durationLabel', () {
    test('reports unknown duration when diagnosedDate is null', () {
      const condition = ChronicCondition(id: '1', name: 'X');
      expect(condition.durationLabel(), 'Duration unknown');
    });

    test('formats whole years with no remainder month', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2020, 3, 1));
      expect(condition.durationLabel(asOf: DateTime(2026, 3, 9)), '6 yrs');
    });

    test('formats years and months', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2019, 3, 1));
      expect(
          condition.durationLabel(asOf: DateTime(2026, 8, 9)), '7 yrs 5 mo');
    });

    test('formats sub-year durations as months only', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2026, 2, 1));
      expect(condition.durationLabel(asOf: DateTime(2026, 8, 9)), '6 mo');
    });

    test('formats sub-month durations as "< 1 mo"', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2026, 8, 1));
      expect(condition.durationLabel(asOf: DateTime(2026, 8, 9)), '< 1 mo');
    });

    test('prefixes approximate durations with ~', () {
      final condition = ChronicCondition(
        id: '1',
        name: 'X',
        diagnosedDate: DateTime(2023, 8, 1),
        isApproximate: true,
      );
      expect(condition.durationLabel(asOf: DateTime(2026, 8, 9)), '~3 yrs');
    });

    test('uses singular "yr" for exactly one year', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2025, 8, 1));
      expect(condition.durationLabel(asOf: DateTime(2026, 8, 9)), '1 yr');
    });
  });

  group('ChronicCondition.diagnosedLabel', () {
    test('formats a known date as "MMM yyyy"', () {
      final condition = ChronicCondition(
          id: '1', name: 'X', diagnosedDate: DateTime(2019, 3, 1));
      expect(condition.diagnosedLabel, 'Mar 2019');
    });

    test('returns a dash for an unknown date', () {
      const condition = ChronicCondition(id: '1', name: 'X');
      expect(condition.diagnosedLabel, '—');
    });
  });

  group('ChronicCondition.listFromLegacyString', () {
    test('splits a comma-separated legacy string into separate conditions',
        () {
      final conditions =
          ChronicCondition.listFromLegacyString('Hypertension, Type 2 Diabetes');

      expect(conditions.length, 2);
      expect(conditions[0].name, 'Hypertension');
      expect(conditions[1].name, 'Type 2 Diabetes');
      expect(conditions.every((c) => c.diagnosedDate == null), true);
    });

    test('drops empty entries and trims whitespace', () {
      final conditions =
          ChronicCondition.listFromLegacyString('Asthma,  , COPD ,');
      expect(conditions.map((c) => c.name).toList(), ['Asthma', 'COPD']);
    });

    test('returns an empty list for null or blank input', () {
      expect(ChronicCondition.listFromLegacyString(null), isEmpty);
      expect(ChronicCondition.listFromLegacyString(''), isEmpty);
      expect(ChronicCondition.listFromLegacyString('   '), isEmpty);
    });
  });
}
