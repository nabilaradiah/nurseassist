import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/wound_assessment.dart';

void main() {
  final base = {
    'id': 'a1',
    'patientId': 'p1',
    'imageUrl': '',
    'assessmentDate': '2026-10-01T09:00:00.000',
  };

  test('audit dates written with serverTimestamp() load as DateTime', () {
    final at = DateTime.utc(2026, 10, 2, 8, 30);
    final a = WoundAssessment.fromJson({
      ...base,
      'correctedAt': Timestamp.fromDate(at),
      'approvedAt': Timestamp.fromDate(at),
      'rejectedAt': Timestamp.fromDate(at),
      'supervisorFeedbackAt': Timestamp.fromDate(at),
    });
    expect(a.correctedAt!.toUtc(), at);
    expect(a.approvedAt!.toUtc(), at);
    expect(a.rejectedAt!.toUtc(), at);
    expect(a.supervisorFeedbackAt!.toUtc(), at);
  });

  test('older records with ISO-8601 strings still load', () {
    final a = WoundAssessment.fromJson({
      ...base,
      'correctedAt': '2026-10-02T08:30:00.000',
      'approvedAt': null,
    });
    expect(a.assessmentDate, DateTime(2026, 10, 1, 9));
    expect(a.correctedAt, DateTime(2026, 10, 2, 8, 30));
    expect(a.approvedAt, isNull);
  });
}
