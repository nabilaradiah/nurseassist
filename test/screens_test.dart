// Widget tests for the screens changed in the TIME / vitals / allergy work.
// They run each screen with fake data (no Firebase) at phone and tablet
// sizes, tap through the new flows, and check what would be saved.
// Any layout overflow fails the test automatically.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseassist/models/patient.dart';
import 'package:nurseassist/models/staff.dart';
import 'package:nurseassist/models/vital_reading.dart';
import 'package:nurseassist/models/wound_assessment.dart';
import 'package:nurseassist/models/wound_types_database.dart';
import 'package:nurseassist/screens/add_edit_patient_screen.dart';
import 'package:nurseassist/screens/analysis_results_screen.dart';
import 'package:nurseassist/screens/lecturer_approval_screen.dart';
import 'package:nurseassist/screens/patient_profile_screen.dart';
import 'package:nurseassist/services/auth_service.dart';
import 'package:nurseassist/theme.dart';

import 'helpers/fake_firestore_service.dart';

// ── Test data ────────────────────────────────────────────────────────────────

Patient _patient({String? allergies, List<VitalReading> vitals = const []}) =>
    Patient(
      id: 'p1',
      mrn: 'MRN-TEST',
      name: 'Test Patient',
      age: 62,
      gender: 'Female',
      contact: '0123456789',
      registeredDate: DateTime(2026, 9, 1),
      staffIdAssignedTo: 'WRN-TEST',
      allergies: allergies,
      medications: 'Metformin 500mg',
      vitalReadings: vitals,
    );

WoundAnalysisResult _aiResult(int type) {
  final data = WoundTypesDatabase.getWoundTypeData('Type_$type');
  final c = data['characteristics'] as Map<String, dynamic>;
  return WoundAnalysisResult(
    confidenceScore: 0.7,
    woundType: type,
    woundName: 'Type_$type',
    severity: data['severity'] as String,
    characteristics: WoundCharacteristics(
      necroticTissue: c['necroticTissue'],
      infection: c['infection'],
      exudateLevel: c['exudateLevel'],
      tissueClassification: const [],
    ),
    management: WoundManagement(
      dressingMaterials: const [],
      antibioticRecommendation: '',
      surgicalProcedures: const [],
    ),
    // Type 6 most likely; some weight on 8
    allClassProbabilities: const [0, 0, 0, 0, 0.1, 0.7, 0.05, 0.15],
  );
}

WoundAssessment _assessment({
  String id = 'a1',
  int aiType = 6,
  TimeAssessment? time,
  VitalReading? vitals,
}) =>
    WoundAssessment(
      id: id,
      patientId: 'p1',
      imageUrl: 'missing-test-image.jpg',
      assessmentDate: DateTime(2026, 10, 3, 9),
      analysisResult: _aiResult(aiType),
      modelPredictedType: aiType,
      modelConfidence: 0.7,
      timeAssessment: time,
      clinicianCorrectedType: time?.woundType,
      vitals: vitals,
    );

// ── Helpers ──────────────────────────────────────────────────────────────────

const _sizes = {
  'small phone 360x780': Size(360, 780),
  'tablet 800x1280': Size(800, 1280),
};

void _setSize(WidgetTester tester, Size logical) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = logical * 3;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: kNurseAssistTheme, home: screen));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets snackbars and tooltips time out so no timers are left running.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);
Finder _field(String hintOrLabel) => find.widgetWithText(TextField, hintOrLabel);

void main() {
  setUp(() {
    AuthService().loggedInStaffForTest = Staff(
      id: 's1',
      staffId: 'WRN-TEST',
      name: 'Test Nurse',
      department: 'Ward 1',
    );
  });
  tearDown(() => AuthService().loggedInStaffForTest = null);

  // ════════════════════════════════════════════════════════════════════════
  //  Analysis results screen
  // ════════════════════════════════════════════════════════════════════════
  for (final entry in _sizes.entries) {
    group('Results screen · ${entry.key}', () {
      testWidgets('before assessment: AI suggestions, no fake findings, '
          'severity hidden', (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(),
            firestoreService: fake,
          ),
        );

        expect(find.textContaining('AI suggestions only'), findsOneWidget);
        expect(find.textContaining('Record the TIME assessment'), findsOneWidget);
        // T / I / M show the AI's view of Type 6 with factor confidence
        expect(find.textContaining('Necrotic / slough over 25%'), findsOneWidget);
        expect(find.textContaining('No signs of infection'), findsOneWidget);
        // Edges and surrounding skin are never invented
        expect(find.text('Not assessed'), findsNWidgets(2));
        expect(find.text('No specific edge findings recorded'), findsNothing);
        // Severity and tissue description chips are gone
        expect(find.text('SEVERITY'), findsNothing);
        expect(find.text('Tissue description'), findsNothing);
        // Vitals prompt
        expect(find.text('No vital signs recorded for this assessment.'),
            findsOneWidget);
        await _drain(tester);
      });

      testWidgets('TIME assessment scores to Type 8 and flags the '
          'disagreement with the AI', (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(aiType: 6),
            firestoreService: fake,
          ),
        );

        await _tap(tester, find.widgetWithText(ElevatedButton, 'Assess'));
        expect(find.text('Wound Assessment (TIME)'), findsOneWidget);
        expect(find.text('Complete T, I and M to see the wound type.'),
            findsOneWidget);

        await tester.enterText(_field('Necrotic'), '30');
        await tester.enterText(_field('Slough'), '20');
        await tester.enterText(_field('Granulation'), '50');
        await tester.pump();
        await _tap(tester, _chip('Local signs'));
        await _tap(tester, _chip(TimeAssessment.moistureWet));
        await _tap(tester, _chip('Undermining'));
        await tester.enterText(
            _field("Position and depth, e.g. 12–3 o'clock, 2 cm"),
            "12–3 o'clock, 2 cm");
        await tester.pump();

        // Live score preview
        expect(find.textContaining('T 4 + I 2 + M 2 = 8'), findsOneWidget);
        expect(find.textContaining('Differs on infection'), findsOneWidget);

        await _tap(tester, find.text('Save TIME Assessment'));

        final saved = fake.savedTimeAssessments['a1']!;
        expect(saved.woundType, 8);
        expect(saved.necroticSloughOver25, isTrue);
        expect(saved.edgeDetails, "12–3 o'clock, 2 cm");
        expect(saved.assessedBy, 'WRN-TEST');

        // Screen now shows the nurse's findings and the disagreement
        expect(find.text('TIME assessment gives Type 8'), findsOneWidget);
        expect(find.textContaining('Differs on: Infection'), findsOneWidget);
        expect(find.text('Awaiting lecturer review'), findsOneWidget);
        expect(find.text('Wound Type 8'), findsOneWidget);
        expect(find.textContaining('Assessed by Test Nurse (WRN-TEST)'),
            findsOneWidget);
        await _drain(tester);
      });

      testWidgets('exactly 25% asks the nurse which side it falls on',
          (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(),
            firestoreService: fake,
          ),
        );

        await _tap(tester, find.widgetWithText(ElevatedButton, 'Assess'));
        await tester.enterText(_field('Necrotic'), '15');
        await tester.enterText(_field('Slough'), '10');
        await tester.pump();
        await _tap(tester, _chip('Nil').first);
        await _tap(tester, _chip(TimeAssessment.moistureDry));
        await _tap(tester, _chip('Attached'));
        expect(find.textContaining('exactly 25%'), findsOneWidget);

        await _tap(tester, find.text('Save TIME Assessment'));
        expect(find.text('Exactly 25%'), findsOneWidget);
        await _tap(tester, find.text('Over 25%'));

        final saved = fake.savedTimeAssessments['a1']!;
        expect(saved.necroticSloughOver25, isTrue);
        expect(saved.woundType, 5); // 4 + 0 + 1
        await _drain(tester);
      });

      testWidgets('rejects tissue percentages over 100%', (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(),
            firestoreService: fake,
          ),
        );

        await _tap(tester, find.widgetWithText(ElevatedButton, 'Assess'));
        await tester.enterText(_field('Necrotic'), '80');
        await tester.enterText(_field('Granulation'), '40');
        await tester.pump();
        await _tap(tester, find.text('Save TIME Assessment'));

        expect(find.textContaining('add up to 120%'), findsOneWidget);
        expect(fake.savedTimeAssessments, isEmpty);
        await _drain(tester);
      });

      testWidgets('tooltip explains a TIME factor', (tester) async {
        _setSize(tester, entry.value);
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(),
            firestoreService: FakeFirestoreService(patient: _patient()),
          ),
        );

        await _tap(tester, find.byIcon(Icons.info_outline_rounded).first);
        expect(find.textContaining('Necrotic tissue + slough under 25% scores 0'),
            findsOneWidget);
        await _drain(tester);
      });

      testWidgets('records vitals for this assessment and flags a fever',
          (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(),
            firestoreService: fake,
          ),
        );

        await _tap(tester, find.text('Record'));
        expect(find.text('Record Vital Signs'), findsOneWidget);
        await tester.enterText(_field('Systolic'), '120');
        await tester.enterText(_field('Diastolic'), '80');
        await tester.enterText(_field('e.g. 37.0'), '38.2');
        await tester.pump();
        expect(find.text('↑ High'), findsOneWidget);
        await _tap(tester, find.widgetWithText(ChoiceChip, '3'));
        await _tap(tester, find.text('Save Vital Signs'));

        expect(fake.addedVitalReadings['p1'], hasLength(1));
        final linked = fake.savedAssessmentVitals['a1']!;
        expect(linked.temperature, 38.2);
        expect(linked.painScore, 3);
        expect(linked.takenByName, 'Test Nurse');
        expect(find.textContaining('For this assessment'), findsOneWidget);
        expect(find.text('38.2 ↑'), findsOneWidget);
        await _drain(tester);
      });

      testWidgets('offers the latest reading only while it is recent',
          (tester) async {
        _setSize(tester, entry.value);
        final recent = VitalReading(
          heartRate: 88,
          takenAt: DateTime.now().subtract(const Duration(hours: 2)),
        );
        final fake = FakeFirestoreService(patient: _patient(vitals: [recent]));
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(vitals: [recent]),
            assessment: _assessment(),
            firestoreService: fake,
          ),
        );

        await _tap(tester, find.text('Use these'));
        expect(fake.savedAssessmentVitals['a1']!.heartRate, 88);
        expect(find.textContaining('For this assessment'), findsOneWidget);
        await _drain(tester);
      });

      testWidgets('stale vitals must be re-recorded', (tester) async {
        _setSize(tester, entry.value);
        final old = VitalReading(
          heartRate: 88,
          takenAt: DateTime.now().subtract(const Duration(days: 3)),
        );
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(vitals: [old]),
            assessment: _assessment(),
            firestoreService: FakeFirestoreService(),
          ),
        );

        expect(find.text('Use these'), findsNothing);
        expect(find.textContaining('record new ones'), findsOneWidget);
        expect(find.text('Record new'), findsOneWidget);
        await _drain(tester);
      });

      testWidgets('allergy warning flags a conflicting dressing',
          (tester) async {
        _setSize(tester, entry.value);
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(allergies: 'Seaweed (alginate)'),
            assessment: _assessment(aiType: 6), // Type 6 includes Alginate*
            firestoreService: FakeFirestoreService(),
          ),
        );

        expect(find.text('Allergies: Seaweed (alginate)'), findsOneWidget);
        expect(find.textContaining('May conflict with: Alginate'), findsOneWidget);
        await _drain(tester);
      });

      testWidgets('without an AI result, TIME sets the wound type',
          (tester) async {
        _setSize(tester, entry.value);
        final fake = FakeFirestoreService(patient: _patient());
        final noAi = WoundAssessment(
          id: 'a-noai',
          patientId: 'p1',
          imageUrl: 'missing-test-image.jpg',
          assessmentDate: DateTime(2026, 10, 4, 9),
        );
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: noAi,
            firestoreService: fake,
          ),
        );

        // Nothing is guessed while there's no AI result and no TIME
        expect(find.text('AI analysis unavailable'), findsOneWidget);
        expect(find.text('Not yet classified'), findsOneWidget);
        expect(find.textContaining('No AI result. Record the TIME'),
            findsOneWidget);
        expect(find.textContaining('Complete the TIME assessment to see'),
            findsOneWidget);
        expect(find.textContaining('AI suggested'), findsNothing);
        expect(find.text('Not assessed'), findsNWidgets(5));

        // TIME form has no AI hints and nothing to compare against
        await _tap(tester, find.widgetWithText(ElevatedButton, 'Assess'));
        expect(find.textContaining('AI suggested'), findsNothing);
        await tester.enterText(_field('Necrotic'), '40');
        await tester.pump();
        await _tap(tester, _chip('Local signs'));
        await _tap(tester, _chip(TimeAssessment.moistureWet));
        await _tap(tester, _chip('Attached'));
        expect(find.textContaining('No AI result to compare'), findsOneWidget);
        await _tap(tester, find.text('Save TIME Assessment'));

        expect(fake.savedTimeAssessments['a-noai']!.woundType, 8);
        expect(find.text('Wound type set by TIME: Type 8'), findsOneWidget);
        expect(find.text('Wound Type 8'), findsOneWidget);
        expect(find.text('Dressing Recommended'), findsOneWidget);
        await _drain(tester);
      });

      testWidgets('necrotic/slough are highlighted only when over 25%',
          (tester) async {
        _setSize(tester, entry.value);
        Color colorOf(String text) =>
            tester.widget<Text>(find.text(text)).style!.color!;

        // Exactly 25%, nurse chose "under" → scores +0, no red/orange
        const under = TimeAssessment(
          necroticPct: 15,
          sloughPct: 10,
          necroticSloughOver25: false,
          infection: 'Local signs',
          moisture: TimeAssessment.moistureWet,
          edges: 'Attached',
        );
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(aiType: 4, time: under),
            firestoreService: FakeFirestoreService(),
          ),
        );
        expect(colorOf('Necrotic 15%'), kPrimaryDark);
        expect(colorOf('Slough 10%'), kPrimaryDark);
        await _drain(tester);

        // Over 25% → scores +4, highlighted
        const over = TimeAssessment(
          necroticPct: 30,
          sloughPct: 20,
          necroticSloughOver25: true,
          infection: 'Local signs',
          moisture: TimeAssessment.moistureWet,
          edges: 'Attached',
        );
        await _open(
          tester,
          AnalysisResultsScreen(
            key: UniqueKey(),
            patient: _patient(),
            assessment: _assessment(aiType: 8, time: over),
            firestoreService: FakeFirestoreService(),
          ),
        );
        expect(colorOf('Necrotic 30%'), Colors.red.shade600);
        expect(colorOf('Slough 20%'), Colors.orange.shade700);
        await _drain(tester);
      });

      testWidgets('agreeing TIME assessment confirms the AI', (tester) async {
        _setSize(tester, entry.value);
        const time = TimeAssessment(
          necroticPct: 40,
          necroticSloughOver25: true,
          infection: 'Nil',
          moisture: TimeAssessment.moistureWet,
          edges: 'Attached',
          surroundingSkin: ['Maceration'],
          assessedBy: 'WRN-TEST',
          assessedByName: 'Test Nurse',
        );
        await _open(
          tester,
          AnalysisResultsScreen(
            patient: _patient(),
            assessment: _assessment(aiType: 6, time: time),
            firestoreService: FakeFirestoreService(),
          ),
        );

        expect(find.text('TIME assessment confirms Type 6'), findsOneWidget);
        expect(find.textContaining('T 4 + I 0 + M 2 = 6'), findsOneWidget);
        expect(find.text('Maceration'), findsOneWidget);
        expect(find.text('Not assessed'), findsNothing);
        await _drain(tester);
      });
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Patient profile
  // ════════════════════════════════════════════════════════════════════════
  for (final entry in _sizes.entries) {
    testWidgets('Profile · ${entry.key}: allergies, medications and vitals',
        (tester) async {
      _setSize(tester, entry.value);
      final patient = _patient(allergies: 'Povidone-iodine');
      final fake = FakeFirestoreService(
        patient: patient,
        assessments: [_assessment()],
      );
      await _open(
        tester,
        PatientProfileScreen(patient: patient, firestoreService: fake),
      );

      expect(find.text('Povidone-iodine'), findsOneWidget);
      expect(find.text('Metformin 500mg'), findsOneWidget);
      expect(find.text('No vital signs recorded yet.'), findsOneWidget);

      await _tap(tester, find.text('Record'));
      await tester.enterText(_field('e.g. 98'), '93');
      await tester.pump();
      expect(find.text('↓ Low'), findsOneWidget);
      await _tap(tester, find.text('Save Vital Signs'));

      expect(fake.addedVitalReadings['p1']!.single.spo2, 93);
      expect(find.text('93 ↓'), findsOneWidget);
      expect(find.textContaining('by Test Nurse'), findsOneWidget);
      await _drain(tester);
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Lecturer approval queue
  // ════════════════════════════════════════════════════════════════════════
  for (final entry in _sizes.entries) {
    testWidgets('Lecturer queue · ${entry.key}: disagreements first, '
        'with TIME breakdown and vitals', (tester) async {
      _setSize(tester, entry.value);
      const agree = TimeAssessment(
        necroticPct: 10,
        necroticSloughOver25: false,
        infection: 'Nil',
        moisture: TimeAssessment.moistureDry,
        edges: 'Attached',
      ); // Type 1
      const disagree = TimeAssessment(
        necroticPct: 40,
        necroticSloughOver25: true,
        infection: 'Local signs',
        moisture: TimeAssessment.moistureWet,
        edges: 'Attached',
      ); // Type 8
      final fake = FakeFirestoreService(assessments: [
        _assessment(id: 'agree', aiType: 1, time: agree),
        _assessment(
          id: 'disagree',
          aiType: 6,
          time: disagree,
          vitals: VitalReading(temperature: 38.4, takenAt: DateTime(2026, 10, 3, 9)),
        ),
      ]);
      await _open(tester, LecturerApprovalScreen(firestoreService: fake));

      expect(find.text('2 wounds awaiting review'), findsOneWidget);
      final disagreeChip = find.text('Nurse TIME: Type 8');
      final agreeChip = find.text('Nurse TIME: Type 1');
      expect(disagreeChip, findsOneWidget);
      expect(tester.getTopLeft(disagreeChip).dy,
          lessThan(tester.getTopLeft(agreeChip).dy),
          reason: 'disagreement should be listed first');
      expect(find.textContaining('Nurse and AI differ on infection'),
          findsOneWidget);
      expect(find.text('38.4 ↑'), findsOneWidget);
      await _drain(tester);
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Add patient form
  // ════════════════════════════════════════════════════════════════════════
  for (final entry in _sizes.entries) {
    testWidgets('Add patient · ${entry.key}: undated condition and '
        'optional vitals step', (tester) async {
      _setSize(tester, entry.value);
      await _open(
        tester,
        AddEditPatientScreen(firestoreService: FakeFirestoreService()),
      );

      // Step 1
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      await tester.enterText(_field('e.g. Robert J. Sterling'), 'Test Patient');
      await tester.enterText(_field('e.g. MRN-001237'), 'MRN-TEST');
      await tester.enterText(_field('Years'), '62');
      await tester.enterText(_field('e.g. +60 12-345 6789'), '0123456789');
      await tester.pump();
      await _tap(tester, find.text('Continue'));

      // Step 2 — add a condition without a date
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      await _tap(tester, find.text('Add condition'));
      await _tap(tester, find.text('Hypertension'));
      expect(find.text('No start date set'), findsOneWidget);
      await _tap(tester, find.text('Add without date'));
      expect(find.textContaining('start date unknown'), findsOneWidget);
      await _tap(tester, find.text('Continue'));

      // Step 3 — vitals: a typo blocks Continue, a fix lets it through
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      await tester.enterText(_field('e.g. 98'), '980');
      await tester.pump();
      await _tap(tester, find.text('Continue'));
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.textContaining('SpO₂ should be between'), findsOneWidget);
      await _drain(tester);
      await tester.enterText(_field('e.g. 98'), '98');
      await tester.pump();
      await _tap(tester, find.text('Continue'));

      // Step 4
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('Save patient'), findsOneWidget);
      await _drain(tester);
    });
  }
}
