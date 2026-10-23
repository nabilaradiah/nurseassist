import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import '../models/wound_types_database.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/vital_reading.dart';
import '../theme.dart';
import '../widgets/dispose_with.dart';
import '../widgets/vital_signs.dart';

class AnalysisResultsScreen extends StatefulWidget {
  final Patient patient;
  final WoundAssessment assessment;

  /// Database access. Defaults to the real Firestore service; tests pass
  /// a fake so screens can be exercised without Firebase.
  final FirestoreService? firestoreService;

  const AnalysisResultsScreen({
    super.key,
    required this.patient,
    required this.assessment,
    this.firestoreService,
  });

  @override
  State<AnalysisResultsScreen> createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _specialistConfirmed = false;
  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();
  late WoundAssessment _assessment;

  /// The patient's vital readings, kept locally so a new reading recorded
  /// from this screen shows straight away.
  late List<VitalReading> _vitals = widget.patient.vitalReadings;

  // Accordion expansion state
  final Map<int, bool> _sectionExpanded = {1: true, 2: true, 3: true};

  // Editable assessment fields
  final TextEditingController _woundNameController = TextEditingController();
  final TextEditingController _estimatedSizeController =
      TextEditingController();
  final TextEditingController _dressingController = TextEditingController();
  final TextEditingController _antibioticController = TextEditingController();
  final TextEditingController _surgicalController = TextEditingController();
  final TextEditingController _managementNotesController =
      TextEditingController();
  String _severity = 'Moderate';

  /// Severity labels are hidden until the nursing team confirms what each
  /// wound type should be called — the Wound Care Quick Reference algorithm
  /// doesn't define severity. Set to true to show the badge and edit field.
  static const _showSeverity = false;

  @override
  void initState() {
    super.initState();
    _assessment = widget.assessment;
    _notesController.text = _assessment.additionalNotes ?? '';
    _specialistConfirmed = _assessment.specialistConfirmed ?? false;
    _initEditableFields();
  }

  Future<void> _saveAssessment() async {
    try {
      final updatedAssessment = _buildUpdatedAssessment(
        analysisResult: _assessment.analysisResult,
        notes: _notesController.text,
        specialistConfirmed: _specialistConfirmed,
      );

      await _firestoreService.updateWoundAssessment(updatedAssessment);

      setState(() {
        _assessment = updatedAssessment;
      });

      if (mounted) {
        showSuccessSnack(context, 'Assessment saved successfully');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, 'Error saving: $e');
      }
    }
  }

  /// Records new vitals: added to the patient's history and linked to this
  /// assessment.
  Future<void> _recordVitals() async {
    final reading = await showRecordVitalsSheet(context);
    if (reading == null) return;
    try {
      await _firestoreService.recordAssessmentVitals(
        patientId: widget.patient.id,
        assessmentId: _assessment.id,
        reading: reading,
      );
      if (!mounted) return;
      setState(() {
        _vitals = [..._vitals, reading];
        _assessment = _assessment.copyWith(vitals: reading);
      });
      showSuccessSnack(context, 'Vital signs saved to this assessment');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Could not save vital signs: $e');
    }
  }

  /// Links the patient's latest reading to this assessment without
  /// re-entering it (only offered while the reading is recent).
  Future<void> _useLatestVitals(VitalReading reading) async {
    try {
      await _firestoreService.saveAssessmentVitals(_assessment.id, reading);
      if (!mounted) return;
      setState(() => _assessment = _assessment.copyWith(vitals: reading));
      showSuccessSnack(context, 'Latest vital signs linked to this assessment');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Could not save vital signs: $e');
    }
  }

  VitalReading? get _latestPatientVitals => _vitals.isEmpty
      ? null
      : _vitals.reduce((a, b) => b.takenAt.isAfter(a.takenAt) ? b : a);

  /// Vital signs taken for this wound assessment. Before any are linked, the
  /// patient's latest reading is offered (if recent) or a new one requested.
  Widget _buildAssessmentVitals() {
    final own = _assessment.vitals;
    final latest = _latestPatientVitals;
    final latestIsRecent =
        latest != null &&
        DateTime.now().difference(latest.takenAt) <= kVitalsStaleAfter;

    Widget header(Widget? action) => Row(
      children: [
        const Icon(Icons.monitor_heart_outlined, size: 18, color: kPrimary),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Vital Signs',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk2,
            ),
          ),
        ),
        ?action,
      ],
    );

    Widget note(String text, {Color color = kMuted1, IconData? icon}) =>
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ),
            ],
          ),
        );

    final List<Widget> body;
    if (own != null) {
      // ── Vitals already linked to this assessment ──
      body = [
        header(
          TextButton(
            onPressed: _recordVitals,
            style: TextButton.styleFrom(
              foregroundColor: kMuted1,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Replace', style: TextStyle(fontSize: 12)),
          ),
        ),
        note(
          'For this assessment · ${formatVitalsTimestamp(own.takenAt)}'
          '${own.takenByName != null ? ' · ${own.takenByName}' : ''}',
          icon: Icons.link_rounded,
        ),
        VitalTiles(reading: own, compact: true),
      ];
    } else if (latest != null) {
      // ── Nothing linked yet; offer the latest reading on file ──
      body = [
        header(null),
        note(
          latestIsRecent
              ? 'Not linked to this assessment yet. Latest on file was taken '
                    '${formatVitalsAge(latest.takenAt).toLowerCase()}.'
              : 'Not linked to this assessment yet. Latest on file is from '
                    '${formatVitalsAge(latest.takenAt).toLowerCase()}, so record new ones.',
          color: kWarning,
          icon: Icons.info_outline_rounded,
        ),
        Opacity(
          opacity: latestIsRecent ? 1 : 0.55,
          child: VitalTiles(reading: latest, compact: true),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (latestIsRecent) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _useLatestVitals(latest),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                  ),
                  child: const Text('Use these'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _recordVitals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Record new'),
              ),
            ),
          ],
        ),
      ];
    } else {
      // ── No vitals anywhere yet ──
      body = [
        header(
          TextButton.icon(
            onPressed: _recordVitals,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Record', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        note('No vital signs recorded for this assessment.'),
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: body,
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (_normalizeSeverity(severity).toLowerCase()) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'moderate':
        return const Color(0xFFE65100);
      case 'mild':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getSeverityBgColor(String severity) {
    switch (_normalizeSeverity(severity).toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFEBEB);
      case 'moderate':
        return const Color(0xFFFFF3E0);
      case 'mild':
        return const Color(0xFFE8F5E9);
      default:
        return Colors.grey.shade100;
    }
  }

  /// Maps any AI-generated severity string to one of the 3 valid dropdown values.
  /// e.g. "Moderate to Critical", "CRITICAL RISK", "moderately severe" → 'Critical'/'Moderate'/'Mild'
  String _normalizeSeverity(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('critical')) return 'Critical';
    if (lower.contains('mild')) return 'Mild';
    if (lower.contains('moderate')) return 'Moderate';
    return 'Moderate'; // safe fallback
  }

  void _initEditableFields() {
    final result = _assessment.analysisResult;
    if (result == null) return;

    _severity = result.severity;
    _woundNameController.text = result.woundName;
    _estimatedSizeController.text =
        result.estimatedSize?.toStringAsFixed(1) ?? '';
    _dressingController.text = result.management.dressingMaterials.join(', ');
    _antibioticController.text = result.management.antibioticRecommendation;
    _surgicalController.text = result.management.surgicalProcedures.join(', ');
    _managementNotesController.text = result.management.additionalNotes ?? '';
  }

  /// Rebuilds the assessment preserving ALL fields — including the immutable
  /// AI prediction snapshot and any existing clinician correction.
  /// Uses copyWith so correction fields are never accidentally cleared.
  WoundAssessment _buildUpdatedAssessment({
    WoundAnalysisResult? analysisResult,
    String? notes,
    bool? specialistConfirmed,
  }) {
    return _assessment.copyWith(
      analysisResult: analysisResult,
      additionalNotes: notes,
      specialistConfirmed: specialistConfirmed,
    );
  }

  Future<void> _openEditAssessment() async {
    final current = _assessment.analysisResult;
    if (current == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No analysis data to edit')));
      return;
    }

    // Local copies so changes only apply on Save
    String localSeverity = _normalizeSeverity(_severity); // guard AI free-text
    final localNameCtrl = TextEditingController(
      text: _woundNameController.text,
    );
    final localSizeCtrl = TextEditingController(
      text: _estimatedSizeController.text,
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ────────────────────────────────
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Header ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue.shade700,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit Assessment',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade500),
                          onPressed: () => Navigator.of(context).pop(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade200),

                  // ── Form body ──────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Wound Name
                            _editLabel('Wound Name'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: localNameCtrl,
                              decoration: _editInputDecoration(
                                'e.g. Diabetic Foot Ulcer',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Wound name is required'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // Severity (wound type comes from the TIME
                            // assessment, so it isn't edited here)
                            if (_showSeverity) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _editLabel('Severity'),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: localSeverity,
                                          decoration: _editInputDecoration(
                                            null,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Critical',
                                              child: Text('Critical'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Moderate',
                                              child: Text('Moderate'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Mild',
                                              child: Text('Mild'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(
                                                () => localSeverity = val,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                            ],

                            // Estimated Size
                            _editLabel('Estimated Size (cm²)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: localSizeCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _editInputDecoration('e.g. 15.0'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final d = double.tryParse(v.trim());
                                if (d == null || d <= 0) {
                                  return 'Enter a valid positive number';
                                }
                                return null;
                              },
                            ),

                            // Info note — management auto-updates
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Wound type is set by the TIME assessment. Use Assess under Wound Characteristics to change it.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final updatedResult = WoundAnalysisResult(
                                    confidenceScore: current.confidenceScore,
                                    // AI-predicted type is never edited here
                                    woundType: current.woundType,
                                    woundName: localNameCtrl.text.trim(),
                                    severity: localSeverity,
                                    estimatedSize:
                                        localSizeCtrl.text.trim().isEmpty
                                        ? null
                                        : double.tryParse(
                                            localSizeCtrl.text.trim(),
                                          ),
                                    characteristics: current.characteristics,
                                    management: current.management,
                                    segmentationMapUrl:
                                        current.segmentationMapUrl,
                                    // Preserve softmax probabilities so the
                                    // correction sheet still shows bars after edit
                                    allClassProbabilities:
                                        current.allClassProbabilities,
                                  );

                                  final updatedAssessment =
                                      _buildUpdatedAssessment(
                                        analysisResult: updatedResult,
                                        notes: _notesController.text,
                                        specialistConfirmed:
                                            _specialistConfirmed,
                                      );

                                  // Capture before async gap
                                  final nav = Navigator.of(context);

                                  await _firestoreService.updateWoundAssessment(
                                    updatedAssessment,
                                  );

                                  if (mounted) {
                                    setState(() {
                                      _assessment = updatedAssessment;
                                      _severity = localSeverity;
                                      _woundNameController.text =
                                          localNameCtrl.text;
                                      _estimatedSizeController.text =
                                          localSizeCtrl.text;
                                    });
                                    nav.pop();
                                    showSuccessSnack(
                                      context,
                                      'Assessment updated',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Edit sheet helpers ─────────────────────────────────────────
  Widget _editLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
      letterSpacing: 0.3,
    ),
  );

  InputDecoration _editInputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.blue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Null when the AI was unavailable; the TIME assessment sets the type
    final result = _assessment.analysisResult;

    // Management follows the type currently shown (supervisor > clinician >
    // AI); null until the wound has a type
    final woundType = _assessment.displayWoundType;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Results',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              '${widget.patient.name}  •  ${widget.patient.age}y ${widget.patient.gender}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openEditAssessment,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. AI Confidence Banner ───────────────────────────
            result != null
                ? _buildConfidenceBanner(result)
                : _buildAiUnavailableBanner(),

            // ── 1b. Clinician Verification Card ──────────────────
            _buildVerificationCard(result),

            // ── 2. Wound Photo ────────────────────────────────────
            _buildWoundPhoto(),

            // ── 3. Classification + Severity + Patient ────────────
            _buildInfoRow(result),

            // ── 3b. Vital signs for this assessment ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildAssessmentVitals(),
            ),

            const SizedBox(height: 14),

            // ── 4. Wound Characteristics ──────────────────────────
            _buildAccordionSection(
              number: 1,
              title: 'Wound Characteristics',
              child: _buildCharacteristicsContent(result),
            ),

            const SizedBox(height: 10),

            // ── 5. Wound Management ───────────────────────────────
            _buildAccordionSection(
              number: 2,
              title: 'Wound Management',
              child: woundType != null
                  ? _buildWoundManagementContent(woundType)
                  : _buildManagementPending(),
            ),

            const SizedBox(height: 10),

            // ── 6. Clinical Notes ─────────────────────────────────
            _buildAccordionSection(
              number: 3,
              title: 'Clinical Notes',
              child: _buildClinicalNotesContent(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  AI CONFIDENCE BANNER
  // ════════════════════════════════════════════════════════════════
  /// Shown in place of the confidence banner when the AI couldn't analyse
  /// the photo.
  Widget _buildAiUnavailableBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: Colors.grey.shade600, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI analysis unavailable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInk2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The wound type comes from your TIME assessment.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Management advice needs a wound type; until the TIME assessment is
  /// recorded there's nothing safe to recommend.
  Widget _buildManagementPending() {
    return Row(
      children: [
        Icon(
          Icons.pending_actions_outlined,
          size: 20,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Complete the TIME assessment to see dressing, antibiotic and '
            'surgical advice.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBanner(WoundAnalysisResult result) {
    final pct = (result.confidenceScore * 100).toInt();
    final Color barColor = pct >= 90
        ? const Color(0xFF00C853)
        : pct >= 70
        ? Colors.orange
        : Colors.red;
    final String label = pct >= 90
        ? 'High Confidence'
        : pct >= 70
        ? 'Moderate Confidence'
        : 'Low Confidence';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Label + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Analysis Confidence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.confidenceScore,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Based on wound image analysis',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Large percentage
          Column(
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'score',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  WOUND PHOTO
  // ════════════════════════════════════════════════════════════════
  /// Shown when the wound photo can't be loaded (no connection, file
  /// missing, or storage refusing the request) instead of a raw error.
  Widget _imageUnavailable() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 44,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Check your connection and try again later.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWoundPhoto() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: _assessment.imageUrl.startsWith('http')
                  ? Image.network(
                      _assessment.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _imageUnavailable(),
                    )
                  : Image.file(
                      File(_assessment.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _imageUnavailable(),
                    ),
            ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            // Full Resolution button
            Positioned(
              bottom: 10,
              left: 12,
              child: GestureDetector(
                onTap: () => _showImageDialog(context, _assessment.imageUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_out_map_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Full Resolution',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  CLINICIAN VERIFICATION CARD
  // ════════════════════════════════════════════════════════════════
  Widget _buildVerificationCard(WoundAnalysisResult? result) {
    final pct = result == null ? null : (result.confidenceScore * 100).toInt();
    final noAi = _assessment.aiWoundType == null;
    final timeType = _assessment.timeAssessment?.woundType;

    // ── Wound type confirmed by a TIME assessment ──────────────────
    if (timeType != null) {
      final differences = _assessment.timeDifferencesFromAi;
      final agreed = differences.isEmpty;
      final color = agreed ? Colors.green : Colors.orange;

      final String reviewStatus;
      if (_assessment.supervisorCorrectedType != null) {
        reviewStatus =
            'Lecturer set Type ${_assessment.supervisorCorrectedType}';
      } else if (_assessment.approvedForTraining) {
        reviewStatus = 'Approved by lecturer';
      } else if (_assessment.rejectedForTraining) {
        reviewStatus = 'Reviewed by lecturer';
      } else {
        reviewStatus = 'Awaiting lecturer review';
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          children: [
            Icon(
              agreed ? Icons.check_circle : Icons.compare_arrows_rounded,
              color: color.shade700,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noAi
                        ? 'Wound type set by TIME: Type $timeType'
                        : agreed
                        ? 'TIME assessment confirms Type $timeType'
                        : 'TIME assessment gives Type $timeType',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color.shade800,
                    ),
                  ),
                  if (!agreed)
                    Text(
                      'AI predicted Type ${_assessment.aiWoundType} ($pct%). '
                      'Differs on: ${differences.join(', ')}.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  Text(
                    agreed
                        ? 'Assessed by ${_assessment.timeAssessment!.assessedByDisplay}'
                        : reviewStatus,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openTimeAssessmentSheet,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Edit TIME', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // ── Legacy: type corrected manually before TIME scoring existed ──
    if (_assessment.isClinicianVerified) {
      final agreed = _assessment.modelWasCorrect;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: agreed ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: agreed ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              agreed ? Icons.check_circle : Icons.swap_horiz,
              color: agreed ? Colors.green.shade700 : Colors.orange.shade700,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agreed
                        ? 'AI result confirmed by clinician'
                        : 'Corrected to Type ${_assessment.clinicianCorrectedType}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: agreed
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                  Text(
                    'Record a TIME assessment to confirm the wound type.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openTimeAssessmentSheet,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Assess', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // ── Not yet verified — ask for the TIME assessment ─────────────
    final isLowConf = pct != null && pct < 70;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLowConf ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowConf ? Colors.red.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLowConf ? Icons.warning_rounded : Icons.info_outline,
            color: isLowConf ? Colors.red.shade700 : Colors.amber.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pct == null
                  ? 'No AI result. Record the TIME assessment to set the wound type.'
                  : isLowConf
                  ? 'Low confidence ($pct%). Record the TIME assessment to confirm the wound type.'
                  : 'Record the TIME assessment to confirm the wound type.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isLowConf ? Colors.red.shade800 : Colors.amber.shade900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openTimeAssessmentSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLowConf
                  ? Colors.red.shade700
                  : Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Assess', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  CLASSIFICATION + SEVERITY + PATIENT ROW
  // ════════════════════════════════════════════════════════════════
  Widget _buildInfoRow(WoundAnalysisResult? result) {
    final severity = result?.severity ?? 'Moderate';
    final severityBg = _getSeverityBgColor(severity);
    final severityFg = _getSeverityColor(severity);
    final classified = _assessment.hasWoundType;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Classification — plain text, no border (matches reference)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLASSIFICATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  classified
                      ? 'Wound Type ${_assessment.displayWoundType}'
                      : 'Not yet classified',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  classified
                      ? _assessment.displayWoundName!
                      : 'Complete the TIME assessment',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Severity — hidden for now (see _showSeverity); the measured
          // size still shows on its own
          if (!_showSeverity && result?.estimatedSize != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kBlue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIZE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${result!.estimatedSize!.toStringAsFixed(1)} cm²',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),
          if (_showSeverity)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: severityBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEVERITY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: severityFg.withValues(alpha: 0.75),
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    severity,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: severityFg,
                    ),
                  ),
                  if (result?.estimatedSize != null)
                    Text(
                      '${result!.estimatedSize!.toStringAsFixed(1)} cm²',
                      style: TextStyle(
                        fontSize: 11,
                        color: severityFg.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ACCORDION WRAPPER
  // ════════════════════════════════════════════════════════════════
  Widget _buildAccordionSection({
    required int number,
    required String title,
    required Widget child,
  }) {
    final isExpanded = _sectionExpanded[number] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered circle
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  InkWell(
                    borderRadius: isExpanded
                        ? const BorderRadius.vertical(top: Radius.circular(12))
                        : BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _sectionExpanded[number] = !isExpanded;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100,
                    ),
                    Padding(padding: const EdgeInsets.all(16), child: child),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SECTION 1 — WOUND CHARACTERISTICS
  // ════════════════════════════════════════════════════════════════
  /// TIME(S) order from the HKL wound assessment chart. Shows the nurse's
  /// recorded findings when present; otherwise shows what the AI's predicted
  /// type implies for T, I and M, marked as suggestions, and leaves Edges /
  /// Surrounding skin as "Not assessed" rather than inventing a value.
  Widget _buildCharacteristicsContent(WoundAnalysisResult? result) {
    final ta = _assessment.timeAssessment;
    // No AI view of T/I/M when the AI was unavailable
    final aiType = _assessment.aiWoundType ?? result?.woundType;
    final aiFactors = aiType == null ? null : TimFactors.fromWoundType(aiType);
    final aiProbs = TimProbabilities.fromClassProbabilities(
      result?.allClassProbabilities,
    );
    final nurseFactors = ta?.factors;
    const nurseColor = kPrimaryDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeStatusBanner(ta),
        const SizedBox(height: 14),

        // T — Tissue
        _buildCharRow(
          letter: 'T',
          label: 'Tissue',
          score: nurseFactors?.tissueScore,
          child: ta != null && ta.hasTissue
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Necrotic and slough are only highlighted when together
                    // they're over 25% — the point where they add to the
                    // wound score — so a red chip never sits next to "+0"
                    if (ta.necroticPct != null)
                      _buildChip(
                        'Necrotic ${ta.necroticPct}%',
                        _tissueOver25(ta) && ta.necroticPct! > 0
                            ? Colors.red.shade600
                            : nurseColor,
                      ),
                    if (ta.sloughPct != null)
                      _buildChip(
                        'Slough ${ta.sloughPct}%',
                        _tissueOver25(ta) && ta.sloughPct! > 0
                            ? Colors.orange.shade700
                            : nurseColor,
                      ),
                    if (ta.granulationPct != null)
                      _buildChip(
                        'Granulation ${ta.granulationPct}%',
                        nurseColor,
                      ),
                    if (ta.epithelialPct != null)
                      _buildChip('Epithelial ${ta.epithelialPct}%', nurseColor),
                  ],
                )
              : aiFactors == null
              ? _buildNotAssessed()
              : _buildAiValue(
                  _tissueLabel(aiFactors.over25),
                  aiProbs == null
                      ? null
                      : _factorConfidence(aiProbs.over25, aiFactors.over25),
                ),
        ),
        const SizedBox(height: 10),

        // I — Infection / Inflammation
        _buildCharRow(
          letter: 'I',
          label: 'Infection',
          score: nurseFactors?.infectionScore,
          child: ta?.infection != null
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildChip(
                      'Infection: ${ta!.infection}',
                      ta.infection == 'Nil'
                          ? Colors.green.shade700
                          : Colors.red.shade600,
                    ),
                    if (ta.inflammation != null)
                      _buildChip(
                        'Inflammation: ${ta.inflammation}',
                        ta.inflammation == 'Nil'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                  ],
                )
              : aiFactors == null
              ? _buildNotAssessed()
              : _buildAiValue(
                  aiFactors.infected
                      ? 'Signs of infection'
                      : 'No signs of infection',
                  aiProbs == null
                      ? null
                      : _factorConfidence(aiProbs.infected, aiFactors.infected),
                ),
        ),
        const SizedBox(height: 10),

        // M — Moisture
        _buildCharRow(
          letter: 'M',
          label: 'Moisture',
          score: nurseFactors?.moistureScore,
          child: ta?.moisture != null
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildChip(ta!.moisture!, nurseColor),
                    if (ta.heavyExudate)
                      _buildChip('Heavy exudate', Colors.orange.shade700),
                  ],
                )
              : aiFactors == null
              ? _buildNotAssessed()
              : _buildAiValue(
                  aiFactors.wet
                      ? TimeAssessment.moistureWet
                      : TimeAssessment.moistureDry,
                  aiProbs == null
                      ? null
                      : _factorConfidence(aiProbs.wet, aiFactors.wet),
                ),
        ),
        const SizedBox(height: 10),

        // E — Edges (the AI does not assess edges; not scored)
        _buildCharRow(
          letter: 'E',
          label: 'Edges',
          child: ta?.edges != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChip(ta!.edges!, nurseColor),
                    if ((ta.edgeDetails ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ta.edgeDetails!,
                        style: const TextStyle(fontSize: 12, color: kMuted1),
                      ),
                    ],
                  ],
                )
              : _buildNotAssessed(),
        ),
        const SizedBox(height: 10),

        // S — Surrounding skin (the AI does not assess it; not scored)
        _buildCharRow(
          letter: 'S',
          label: 'Surrounding skin',
          child:
              ta != null &&
                  (ta.surroundingSkin.isNotEmpty ||
                      (ta.surroundingSkinNotes ?? '').isNotEmpty)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ta.surroundingSkin.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ta.surroundingSkin
                            .map(
                              (s) => _buildChip(
                                s,
                                s == 'Intact'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            )
                            .toList(),
                      ),
                    if ((ta.surroundingSkinNotes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ta.surroundingSkinNotes!,
                        style: const TextStyle(fontSize: 12, color: kMuted1),
                      ),
                    ],
                  ],
                )
              : _buildNotAssessed(),
        ),

        // Wound score = T + I + M
        if (nurseFactors != null) ...[
          const SizedBox(height: 12),
          _buildScoreSummary(nurseFactors),
        ],
      ],
    );
  }

  /// Whether necrotic tissue + slough scored as over 25%. Uses the nurse's
  /// answer when recorded (it decides the exactly-25% case), otherwise the
  /// percentages.
  bool _tissueOver25(TimeAssessment ta) =>
      ta.necroticSloughOver25 ?? ta.necroticSloughPct > 25;

  String _tissueLabel(bool over25) =>
      over25 ? 'Necrotic / slough over 25%' : 'Necrotic / slough under 25%';

  /// How sure the model is about the factor it predicted, e.g. "82%".
  String _factorConfidence(double probabilityTrue, bool predictedTrue) {
    final p = predictedTrue ? probabilityTrue : 1 - probabilityTrue;
    return '${(p * 100).round()}%';
  }

  /// "T 4 + I 2 + M 2 = 8 → Type 8", in the Wound Care Quick Reference form.
  Widget _buildScoreSummary(TimFactors f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kBlue50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Wound score  T ${f.tissueScore} + I ${f.infectionScore} + M ${f.moistureScore} = ${f.woundType}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kPrimaryDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Type ${f.woundType}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tells the nurse whether the rows below are their own findings or the
  /// AI's suggestions, with the action to record / edit the assessment.
  Widget _buildTimeStatusBanner(TimeAssessment? ta) {
    final assessed = ta != null;
    final color = assessed ? kSuccess : kWarning;
    final dateStr = ta?.assessedAt != null
        ? ' · ${_formatShortDate(ta!.assessedAt!)}'
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            assessed ? Icons.verified_outlined : Icons.smart_toy_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              assessed
                  ? 'Assessed by ${ta.assessedByDisplay}$dateStr'
                  : _assessment.analysisResult == null
                  ? 'No AI result. Record what you see on this wound.'
                  : 'AI suggestions only. Record what you see on this wound.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _openTimeAssessmentSheet,
            style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(assessed ? 'Edit' : 'Assess'),
          ),
        ],
      ),
    );
  }

  // ── TIME help text, shown in small tap-to-open tooltips ─────────
  static const _timeHelp = {
    'T':
        'Tissue type. Estimate the % of the wound bed for each tissue. '
        'Necrotic tissue + slough under 25% scores 0, over 25% scores 4.',
    'I':
        'Infection. Look for redness, warmth, swelling, pus, odour or '
        'increasing pain. No = 0, Yes = 2.',
    'M':
        'Moisture / exudate. Dry or minimal scores 1, moderate or wet '
        'scores 2.',
    'E':
        'Edges. Attached, not attached, rolled or undermined. Recorded '
        'for monitoring; not part of the wound score.',
    'S':
        'Surrounding (periwound) skin. Recorded for monitoring; not part '
        'of the wound score.',
  };

  Widget _timeInfoIcon(String letter) {
    return Tooltip(
      message: _timeHelp[letter] ?? '',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      preferBelow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      textStyle: const TextStyle(
        fontSize: 11.5,
        color: Colors.white,
        height: 1.35,
      ),
      decoration: BoxDecoration(
        color: kInk2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildCharRow({
    required String letter,
    required String label,
    required Widget child,
    int? score,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kBlue50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 132,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            // The ⓘ flows after the last word, so it stays next to the
            // label even when a long one ("Surrounding skin") wraps
            child: Text.rich(
              TextSpan(
                text: label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _timeInfoIcon(letter),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2),
            child: Text(
              '+$score',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kMuted1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }

  /// An AI observation shown before the nurse has recorded their own.
  Widget _buildAiValue(String text, String? confidence) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildAiTag(),
        Text(
          confidence == null ? text : '$text ($confidence)',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAiTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 11, color: Colors.grey.shade600),
          const SizedBox(width: 3),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotAssessed() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Not assessed',
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
      ),
    );
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Necrotic tissue + slough of exactly 25% sits on the algorithm's
  /// boundary, so the nurse decides which side it falls on.
  Future<bool?> _askAbout25Percent(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exactly 25%',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        // The two answers are stacked full-width so they fit small phones
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Necrotic tissue and slough add up to exactly 25%. The wound '
              'care algorithm splits at 25%. Based on what you see, is it '
              'closer to under or over 25%?',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Under 25%'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Over 25%'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  TIME(S) ASSESSMENT SHEET — nurse records what they observe
  // ════════════════════════════════════════════════════════════════
  Future<void> _openTimeAssessmentSheet() async {
    final result = _assessment.analysisResult;
    final existing = _assessment.timeAssessment;
    // Null when the AI was unavailable: no hints or comparison then
    final aiType = _assessment.aiWoundType ?? result?.woundType;
    final aiFactors = aiType == null ? null : TimFactors.fromWoundType(aiType);
    final aiProbs = TimProbabilities.fromClassProbabilities(
      result?.allClassProbabilities,
    );

    String pctText(int? v) => v?.toString() ?? '';
    final necroticCtrl = TextEditingController(
      text: pctText(existing?.necroticPct),
    );
    final sloughCtrl = TextEditingController(
      text: pctText(existing?.sloughPct),
    );
    final granulationCtrl = TextEditingController(
      text: pctText(existing?.granulationPct),
    );
    final epithelialCtrl = TextEditingController(
      text: pctText(existing?.epithelialPct),
    );
    final edgeDetailsCtrl = TextEditingController(
      text: existing?.edgeDetails ?? '',
    );
    final skinNotesCtrl = TextEditingController(
      text: existing?.surroundingSkinNotes ?? '',
    );

    String? infection = existing?.infection;
    String? inflammation = existing?.inflammation;
    String? moisture = existing?.moisture;
    bool heavyExudate = existing?.heavyExudate ?? false;
    String? edges = existing?.edges;
    final skin = <String>{...?existing?.surroundingSkin};
    // The nurse's earlier answer at exactly 25%, reused while it still applies
    bool? boundaryAnswer = existing != null && existing.necroticSloughPct == 25
        ? existing.necroticSloughOver25
        : null;
    String? error;
    bool saving = false;

    int? parsePct(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : int.tryParse(t);
    }

    String aiHintFor(String label, double? p, bool predicted) =>
        p == null ? label : '$label (${_factorConfidence(p, predicted)})';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Controllers are disposed once the sheet has fully closed
      builder: (ctx) => DisposeWith(
        notifiers: [
          necroticCtrl,
          sloughCtrl,
          granulationCtrl,
          epithelialCtrl,
          edgeDetailsCtrl,
          skinNotesCtrl,
        ],
        child: StatefulBuilder(
          builder: (context, setSheet) {
            final pcts = [
              necroticCtrl,
              sloughCtrl,
              granulationCtrl,
              epithelialCtrl,
            ].map(parsePct).toList();
            final total = pcts.fold<int>(0, (sum, v) => sum + (v ?? 0));
            final necroticSlough = (pcts[0] ?? 0) + (pcts[1] ?? 0);
            final anyTissue = pcts.any((v) => v != null);
            final showEdgeDetails =
                edges == 'Not attached' || edges == 'Undermining';

            // Live score preview, once T, I and M are all answerable
            final bool? over25 = !anyTissue
                ? null
                : necroticSlough == 25
                ? boundaryAnswer
                : necroticSlough > 25;
            final previewFactors =
                over25 != null && infection != null && moisture != null
                ? TimFactors(
                    over25: over25,
                    infected: infection != 'Nil',
                    wet: moisture == TimeAssessment.moistureWet,
                  )
                : null;

            Future<void> save() async {
              final invalidPct =
                  [
                    necroticCtrl,
                    sloughCtrl,
                    granulationCtrl,
                    epithelialCtrl,
                  ].any((c) {
                    final t = c.text.trim();
                    if (t.isEmpty) return false;
                    final v = int.tryParse(t);
                    return v == null || v < 0 || v > 100;
                  });
              String? problem;
              if (invalidPct) {
                problem =
                    'Tissue percentages must be whole numbers from 0 to 100.';
              } else if (!anyTissue) {
                problem = 'Enter at least one tissue percentage.';
              } else if (total > 100) {
                problem =
                    'Tissue percentages add up to $total%. They cannot exceed 100%.';
              } else if (infection == null) {
                problem = 'Select an infection finding.';
              } else if (moisture == null) {
                problem = 'Select the wound moisture.';
              } else if (edges == null) {
                problem = 'Select the wound edges.';
              }
              if (problem != null) {
                setSheet(() => error = problem);
                return;
              }

              // Exactly 25% is on the boundary — ask which side it falls on
              bool resolvedOver25;
              if (necroticSlough == 25) {
                final answer = await _askAbout25Percent(context);
                if (answer == null || !context.mounted) return;
                boundaryAnswer = answer;
                resolvedOver25 = answer;
              } else {
                resolvedOver25 = necroticSlough > 25;
              }

              final staff = AuthService().loggedInStaff;
              final ta = TimeAssessment(
                necroticPct: pcts[0],
                sloughPct: pcts[1],
                granulationPct: pcts[2],
                epithelialPct: pcts[3],
                necroticSloughOver25: resolvedOver25,
                infection: infection,
                inflammation: inflammation,
                moisture: moisture,
                heavyExudate:
                    moisture == TimeAssessment.moistureWet && heavyExudate,
                edges: edges,
                edgeDetails:
                    showEdgeDetails && edgeDetailsCtrl.text.trim().isNotEmpty
                    ? edgeDetailsCtrl.text.trim()
                    : null,
                surroundingSkin: TimeAssessment.surroundingSkinOptions
                    .where(skin.contains)
                    .toList(),
                surroundingSkinNotes: skinNotesCtrl.text.trim().isEmpty
                    ? null
                    : skinNotesCtrl.text.trim(),
                assessedBy:
                    staff?.staffId ??
                    AuthService().currentUser?.email
                        ?.split('@')[0]
                        .toUpperCase(),
                assessedByName: staff?.name,
                assessedAt: DateTime.now(),
              );
              final timeType = ta.woundType!;

              setSheet(() {
                saving = true;
                error = null;
              });
              final nav = Navigator.of(context);
              try {
                await _firestoreService.saveTimeAssessment(
                  assessmentId: _assessment.id,
                  timeAssessment: ta,
                  correctedBy: staff?.staffId ??
                      (throw Exception(
                    'Your staff profile is not loaded. Please log in again.')),
                );
                if (!mounted) return;
                setState(() {
                  _assessment = _assessment.copyWith(
                    timeAssessment: ta,
                    clinicianCorrectedType: timeType,
                    clinicianCorrectedName: WoundTypesDatabase.getWoundTypeName(
                      timeType,
                    ),
                    correctedBy: ta.assessedBy,
                    correctedAt: DateTime.now(),
                    approvedForTraining: false,
                  );
                });
                nav.pop();
                final differences = _assessment.timeDifferencesFromAi;
                if (aiType == null) {
                  showSuccessSnack(
                    this.context,
                    'TIME assessment saved. Wound type set to Type $timeType',
                  );
                } else if (differences.isEmpty) {
                  showSuccessSnack(
                    this.context,
                    'TIME assessment saved. Confirms AI result: Type $timeType',
                  );
                } else {
                  showWarningSnack(
                    this.context,
                    'TIME gives Type $timeType, AI predicted Type $aiType. Sent to lecturer for review.',
                  );
                }
              } catch (e) {
                setSheet(() {
                  saving = false;
                  error = 'Could not save: $e';
                });
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Wound Assessment (TIME)',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade500),
                          onPressed: () => Navigator.of(context).pop(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // T
                          _timeSectionHeader('T', 'Tissue', '% of wound bed'),
                          if (aiFactors != null)
                            _aiHint(
                              aiHintFor(
                                _tissueLabel(aiFactors.over25),
                                aiProbs?.over25,
                                aiFactors.over25,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _pctField(
                                  'Necrotic',
                                  necroticCtrl,
                                  setSheet,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _pctField(
                                  'Slough',
                                  sloughCtrl,
                                  setSheet,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _pctField(
                                  'Granulation',
                                  granulationCtrl,
                                  setSheet,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _pctField(
                                  'Epithelial',
                                  epithelialCtrl,
                                  setSheet,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            anyTissue
                                ? 'Necrotic + slough: $necroticSlough%  ·  Total: $total%'
                                : 'Total: $total%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: total > 100 ? kDanger : kMuted1,
                            ),
                          ),

                          const SizedBox(height: 18),
                          // I
                          _timeSectionHeader(
                            'I',
                            'Infection / Inflammation',
                            null,
                          ),
                          if (aiFactors != null)
                            _aiHint(
                              aiHintFor(
                                aiFactors.infected
                                    ? 'Signs of infection'
                                    : 'No signs of infection',
                                aiProbs?.infected,
                                aiFactors.infected,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _editLabel('Infection'),
                          const SizedBox(height: 6),
                          _choiceChips(
                            TimeAssessment.infectionOptions,
                            infection,
                            (v) => setSheet(() => infection = v),
                          ),
                          const SizedBox(height: 10),
                          _editLabel('Inflammation (not scored)'),
                          const SizedBox(height: 6),
                          _choiceChips(
                            TimeAssessment.inflammationOptions,
                            inflammation,
                            (v) => setSheet(() => inflammation = v),
                          ),

                          const SizedBox(height: 18),
                          // M
                          _timeSectionHeader('M', 'Moisture / exudate', null),
                          if (aiFactors != null)
                            _aiHint(
                              aiHintFor(
                                aiFactors.wet
                                    ? TimeAssessment.moistureWet
                                    : TimeAssessment.moistureDry,
                                aiProbs?.wet,
                                aiFactors.wet,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _choiceChips(
                            TimeAssessment.moistureOptions,
                            moisture,
                            (v) => setSheet(() => moisture = v),
                          ),
                          if (moisture == TimeAssessment.moistureWet) ...[
                            const SizedBox(height: 8),
                            FilterChip(
                              label: const Text('Heavy exudate'),
                              selected: heavyExudate,
                              showCheckmark: true,
                              onSelected: (on) =>
                                  setSheet(() => heavyExudate = on),
                              selectedColor: kBlue50,
                              backgroundColor: Colors.white,
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kMuted1,
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ],

                          const SizedBox(height: 18),
                          // E
                          _timeSectionHeader('E', 'Edges', 'Not scored'),
                          const SizedBox(height: 8),
                          _choiceChips(
                            TimeAssessment.edgeOptions,
                            edges,
                            (v) => setSheet(() => edges = v),
                          ),
                          if (showEdgeDetails) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: edgeDetailsCtrl,
                              decoration: _editInputDecoration(
                                "Position and depth, e.g. 12–3 o'clock, 2 cm",
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),
                          // S
                          _timeSectionHeader(
                            'S',
                            'Surrounding skin',
                            'Not scored',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: TimeAssessment.surroundingSkinOptions.map((
                              o,
                            ) {
                              final selected = skin.contains(o);
                              return FilterChip(
                                label: Text(o),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (on) => setSheet(() {
                                  if (on) {
                                    // "Intact" and abnormal findings are exclusive
                                    if (o == 'Intact') {
                                      skin.clear();
                                    } else {
                                      skin.remove('Intact');
                                    }
                                    skin.add(o);
                                  } else {
                                    skin.remove(o);
                                  }
                                }),
                                selectedColor: kPrimary,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : kMuted1,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? kPrimary
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: skinNotesCtrl,
                            decoration: _editInputDecoration(
                              'Other findings, e.g. HPSC-2A, desiccation',
                            ),
                          ),

                          // Live score
                          const SizedBox(height: 16),
                          if (previewFactors != null)
                            _buildScorePreview(previewFactors, aiType)
                          else if (anyTissue &&
                              necroticSlough == 25 &&
                              infection != null &&
                              moisture != null)
                            _scoreNote(
                              'Necrotic + slough is exactly 25%. '
                              "You'll be asked which side it falls on when you save.",
                            )
                          else
                            _scoreNote(
                              'Complete T, I and M to see the wound type.',
                            ),

                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: kDanger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saving ? null : save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                saving ? 'Saving…' : 'Save TIME Assessment',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Score preview inside the sheet, with a note when it differs from the AI.
  Widget _buildScorePreview(TimFactors f, int? aiType) {
    if (aiType == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreSummary(f),
          const SizedBox(height: 6),
          _scoreNote('No AI result to compare. Saving sets the wound type.'),
        ],
      );
    }
    final differences = f.differencesFrom(TimFactors.fromWoundType(aiType));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreSummary(f),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              differences.isEmpty
                  ? Icons.check_circle_outline_rounded
                  : Icons.compare_arrows_rounded,
              size: 14,
              color: differences.isEmpty ? kSuccess : kWarning,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                differences.isEmpty
                    ? 'Matches the AI result (Type $aiType).'
                    : 'AI predicted Type $aiType. Differs on ${differences.join(', ').toLowerCase()}. '
                          'Saving sends this to a lecturer for review.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: differences.isEmpty ? kSuccess : kWarning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreNote(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }

  Widget _timeSectionHeader(String letter, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kInk2,
          ),
        ),
        _timeInfoIcon(letter),
        if (subtitle != null) ...[
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ],
    );
  }

  /// Shows the AI's view of this factor as a reference only — nothing is
  /// pre-selected, so the nurse records their own finding.
  Widget _aiHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 32),
      child: Text(
        'AI suggested: $text',
        style: TextStyle(
          fontSize: 11.5,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _pctField(
    String label,
    TextEditingController controller,
    StateSetter setSheet,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => setSheet(() {}),
      decoration: _editInputDecoration(
        null,
      ).copyWith(labelText: label, suffixText: '%'),
    );
  }

  Widget _choiceChips(
    List<String> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
        final isSelected = selected == o;
        return ChoiceChip(
          label: Text(o),
          selected: isSelected,
          showCheckmark: false,
          // Tapping the selected chip again clears it
          onSelected: (_) => onChanged(isSelected ? null : o),
          selectedColor: kPrimary,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : kMuted1,
          ),
          side: BorderSide(color: isSelected ? kPrimary : Colors.grey.shade300),
        );
      }).toList(),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SECTION 2 — WOUND MANAGEMENT
  // ════════════════════════════════════════════════════════════════
  Widget _buildWoundManagementContent(int woundType) {
    final mgmt = WoundTypesDatabase.getManagement(woundType);
    final dressing = mgmt.dressingMaterials;
    final dressingNotes = mgmt.dressingNotes;
    final antibiotic = mgmt.antibioticRecommendation;
    final surgical = mgmt.surgicalProcedures;
    final requiresConfirmation =
        WoundTypesDatabase.requiresSpecialistConfirmation(woundType);

    final antibioticIsYes = antibiotic.toLowerCase().startsWith('yes');
    final antibioticIsMaybe = antibiotic.toLowerCase().startsWith('may');
    final antibioticColor = antibioticIsYes
        ? Colors.red.shade700
        : antibioticIsMaybe
        ? Colors.orange.shade700
        : Colors.green.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Allergies — shown before any recommendation so it's read first
        _buildAllergyBanner(dressing),
        const SizedBox(height: 12),

        // Dressing
        _buildMgmtHeader(
          Icons.medical_services_outlined,
          'Dressing Recommended',
          Colors.blue.shade700,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: dressing
              .map(
                (d) => _dressingMatchesAllergy(d)
                    ? _buildAllergyChip(d)
                    : _buildChip(d, Colors.blue.shade700),
              )
              .toList(),
        ),
        if (dressingNotes != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              dressingNotes,
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),
        Divider(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 14),

        // Antibiotics + Surgical
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Antibiotics column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMgmtHeader(
                    Icons.medication_outlined,
                    'Antibiotics',
                    antibioticColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    antibioticIsYes
                        ? 'Required: Yes'
                        : antibioticIsMaybe
                        ? 'May be required'
                        : 'Not required',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: antibioticColor,
                    ),
                  ),
                  if (antibioticIsYes || antibioticIsMaybe) ...[
                    const SizedBox(height: 4),
                    Text(
                      antibiotic.contains(',')
                          ? antibiotic
                                .substring(antibiotic.indexOf(',') + 1)
                                .trim()
                          : antibiotic,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Surgical column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMgmtHeader(
                    Icons.local_hospital_outlined,
                    'Surgical',
                    Colors.purple.shade700,
                  ),
                  const SizedBox(height: 6),
                  ...surgical.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Specialist confirmation checkbox (types 3, 4, 6)
        if (requiresConfirmation) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () =>
                setState(() => _specialistConfirmed = !_specialistConfirmed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _specialistConfirmed,
                    onChanged: (value) =>
                        setState(() => _specialistConfirmed = value ?? false),
                    activeColor: Colors.blue,
                    side: BorderSide(color: Colors.grey.shade400),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Confirm Specialist Notified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              'Required before saving — specialist must confirm debridement is needed',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ],
    );
  }

  /// Allergen words a nurse might record → the dressing name they affect.
  /// Kept to known dressing allergens so unrelated words never flag a dressing.
  static const _allergenToDressing = {
    'iodine': 'iodine',
    'povidone': 'iodine',
    'betadine': 'iodine',
    'silver': 'silver',
    'sulfadiazine': 'silver',
    'honey': 'honey',
    'bee': 'honey',
    'seaweed': 'alginate',
    'alginate': 'alginate',
    'charcoal': 'charcoal',
    'hydrocolloid': 'hydrocolloid',
    'pectin': 'hydrocolloid',
    'gelatin': 'hydrocolloid',
    'adhesive': 'island',
    'plaster': 'island',
  };

  /// Dressing keywords that conflict with the patient's recorded allergies
  /// (e.g. "Povidone-iodine" → {'iodine'}).
  Set<String> get _conflictingDressingWords {
    if (!widget.patient.hasKnownAllergies) return const {};
    final words = widget.patient.allergies!.toLowerCase().split(
      RegExp(r'[^a-z]+'),
    );
    return {
      for (final w in words)
        if (_allergenToDressing.containsKey(w)) _allergenToDressing[w]!,
    };
  }

  bool _dressingMatchesAllergy(String dressing) {
    final conflicts = _conflictingDressingWords;
    if (conflicts.isEmpty) return false;
    final lower = dressing.toLowerCase();
    return conflicts.any(lower.contains);
  }

  Widget _buildAllergyBanner(List<String> dressing) {
    final patient = widget.patient;
    if (!patient.hasKnownAllergies) {
      final recorded = (patient.allergies ?? '').trim().isNotEmpty;
      return Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              recorded
                  ? 'No known allergies recorded'
                  : 'Allergies not recorded. Check with the patient before applying a dressing.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }

    final flagged = dressing.where(_dressingMatchesAllergy).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kDanger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: kDanger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allergies: ${patient.allergies!.trim()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kDanger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  flagged.isEmpty
                      ? 'Check dressings and antibiotics against these allergies.'
                      : 'May conflict with: ${flagged.map((d) => d.replaceAll('*', '')).join(', ')}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDanger.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: kDanger),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kDanger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMgmtHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SECTION 3 — CLINICAL NOTES
  // ════════════════════════════════════════════════════════════════
  Widget _buildClinicalNotesContent() {
    return TextField(
      controller: _notesController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Other observations, e.g. odour, pain during dressing change',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BOTTOM ACTION BAR
  // ════════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    // Follow the wound type currently shown (e.g. after a TIME assessment
    // changes it), not only the AI's original type at capture time
    final woundType = _assessment.displayWoundType;
    final needsGating =
        _assessment.requiresSpecialistConfirmation ||
        (woundType != null &&
            WoundTypesDatabase.requiresSpecialistConfirmation(woundType));
    final isSaveBlocked = needsGating && !_specialistConfirmed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (needsGating)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWarningBg,
              borderRadius: BorderRadius.circular(kRadiusLg),
              border: Border.all(color: kWarning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 22,
                      color: kWarning,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Specialist confirmation required',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kWarning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please notify a specialist before saving this assessment.',
                  style: TextStyle(fontSize: 13, color: kInk2),
                ),
                const SizedBox(height: 4),
                // Own Material so the tile's tap ripple shows on the
                // coloured warning box
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: _specialistConfirmed,
                    onChanged: (v) =>
                        setState(() => _specialistConfirmed = v ?? false),
                    title: const Text(
                      'I have notified the specialist',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: kWarning,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isSaveBlocked ? null : _saveAssessment,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.7,
                    ),
                    disabledBackgroundColor: kPrimary.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  FULL RESOLUTION IMAGE DIALOG
  // ════════════════════════════════════════════════════════════════
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        errorBuilder: (context, error, stackTrace) =>
                            SizedBox(height: 300, child: _imageUnavailable()),
                      )
                    : Image.file(
                        File(imageUrl),
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 300,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error, size: 100),
                        ),
                      ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _woundNameController.dispose();
    _estimatedSizeController.dispose();
    _dressingController.dispose();
    _antibioticController.dispose();
    _surgicalController.dispose();
    _managementNotesController.dispose();
    super.dispose();
  }
}
