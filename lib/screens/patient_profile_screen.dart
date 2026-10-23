import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/patient_avatar.dart';
import '../widgets/primary_fab.dart';
import '../widgets/vital_signs.dart';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'capture_wound_screen.dart';
import 'analysis_results_screen.dart';
import 'add_edit_patient_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final Patient patient;

  /// Database access. Defaults to the real Firestore service; tests pass
  /// a fake so screens can be exercised without Firebase.
  final FirestoreService? firestoreService;

  const PatientProfileScreen({
    super.key,
    required this.patient,
    this.firestoreService,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();
  List<WoundAssessment> _assessments = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  late Patient _patient;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    try {
      final assessments = await _firestoreService.getWoundAssessments(
        _patient.id,
      );
      setState(() {
        _assessments = assessments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading assessments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAssessment(WoundAssessment assessment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete assessment?'),
          content: const Text('This will remove the assessment permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteWoundAssessment(
        assessmentId: assessment.id,
        patientId: _patient.id,
      );
      setState(() {
        _assessments.removeWhere((a) => a.id == assessment.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assessment deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _confirmDeletePatient() async {
    if (_isDeleting) return;

    final staff = AuthService().loggedInStaff;
    if (staff?.isLecturer != true) {
      showWarningSnack(
        context,
        'Only a lecturer/senior nurse can delete a patient.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Remove patient?', style: kH3),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: kInk2, height: 1.5),
              children: [
                const TextSpan(text: 'This will permanently delete '),
                TextSpan(
                  text: _patient.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text:
                      ' and all their wound assessments. This cannot be undone.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: kMuted1),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _firestoreService.deletePatientAndAssessments(_patient.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient removed from NurseAssist')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove patient: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _navigateToCaptureWound() {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => CaptureWoundScreen(patient: _patient),
          ),
        )
        .then((result) {
          if (result == true) {
            _loadAssessments();
          }
        });
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Patient Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          _buildTopActionButton(
            icon: Icons.edit,
            color: kMuted1,
            onTap: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddEditPatientScreen(patient: _patient),
                ),
              );

              if (updated == true) {
                final refreshed = await _firestoreService.getPatient(
                  _patient.id,
                );
                if (refreshed != null && mounted) {
                  setState(() {
                    _patient = refreshed;
                  });
                }
              }
            },
          ),
          const SizedBox(width: 6),
          _buildTopActionButton(
            icon: Icons.delete_outline,
            color: kDanger,
            onTap: _confirmDeletePatient,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _buildPatientHeroCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildPatientDetailsCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VitalSignsCard(
                readings: _patient.vitalReadings,
                onRecord: _recordVitals,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Wound Assessments',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: kInk2,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDDE4EC),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _assessments.length.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5D6C7D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _assessments.isEmpty
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'No wound assessments yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _assessments.length,
                    itemBuilder: (context, index) {
                      final assessment = _assessments[index];
                      return _buildAssessmentTile(assessment);
                    },
                  ),
            const SizedBox(height: 108),
          ],
        ),
      ),
      floatingActionButton: PrimaryFAB(
        label: 'Capture New Wound',
        icon: Icons.camera_alt_rounded,
        onPressed: _navigateToCaptureWound,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F3F8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }

  Widget _buildPatientHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kShadowHero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PatientAvatar(name: _patient.name, size: 40, onGradient: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _patient.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_patient.age} years | ${_patient.gender}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEE, d MMM').format(_patient.registeredDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordVitals() async {
    final reading = await showRecordVitalsSheet(context);
    if (reading == null) return;
    try {
      await _firestoreService.addVitalReading(_patient.id, reading);
      final refreshed = await _firestoreService.getPatient(_patient.id);
      if (!mounted) return;
      if (refreshed != null) setState(() => _patient = refreshed);
      showSuccessSnack(context, 'Vital signs saved');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Could not save vital signs: $e');
    }
  }

  Widget _buildPatientDetailsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2EB)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.badge_outlined, 'Medical Record #', _patient.mrn),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.call_outlined, 'Contact', _patient.contact),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Registered',
            _formatDate(_patient.registeredDate),
          ),
          const SizedBox(height: 10),
          _buildAllergyRow(),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.medication_outlined,
            'Current Medications',
            (_patient.medications ?? '').trim().isEmpty
                ? 'Not recorded'
                : _patient.medications!.trim(),
          ),
        ],
      ),
    );
  }

  /// Allergies get their own row so they're never buried in free text —
  /// highlighted red when a real allergy is recorded, since some recommended
  /// dressings (iodine, silver, honey) are common allergens.
  Widget _buildAllergyRow() {
    final hasAllergy = _patient.hasKnownAllergies;
    final raw = (_patient.allergies ?? '').trim();
    final value = hasAllergy
        ? raw
        : raw.isEmpty
        ? 'Not recorded'
        : 'No known allergies';

    if (!hasAllergy) {
      return _buildInfoRow(Icons.warning_amber_rounded, 'Allergies', value);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kDanger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: kDanger,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allergies',
                  style: TextStyle(
                    fontSize: 13,
                    color: kDanger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2A38),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentTile(WoundAssessment assessment) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // Opens even without an AI result, so the nurse can record the
        // TIME assessment that sets the wound type
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => AnalysisResultsScreen(
                  patient: _patient,
                  assessment: assessment,
                ),
              ),
            )
            .then((_) => _loadAssessments());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                color: const Color(0xFFE6EBF2),
                child: assessment.imageUrl.startsWith('http')
                    ? Image.network(
                        assessment.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_outlined,
                              size: 26,
                              color: Color(0xFF617287),
                            ),
                      )
                    : Image.file(
                        File(assessment.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_outlined,
                              size: 26,
                              color: Color(0xFF617287),
                            ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: assessment.hasWoundType
                              ? const Color(0xFFF2A317)
                              : Colors.grey.shade500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          assessment.hasWoundType
                              ? 'Type ${assessment.displayWoundType}'
                              : 'No type',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          assessment.hasWoundType
                              ? assessment.displayWoundName
                              : 'TIME assessment needed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2B3A),
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDateTime(assessment.assessmentDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A8696),
                    ),
                  ),
                  if (assessment.hasSupervisorFeedback) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kPurple600.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kPurple600.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.feedback_outlined,
                            size: 13,
                            color: kPurple600,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              assessment.supervisorCorrectedType != null
                                  ? 'Reassigned to Type ${assessment.supervisorCorrectedType}'
                                        '${assessment.supervisorFeedback != null ? ' — ${assessment.supervisorFeedback}' : ''}'
                                  : (assessment.supervisorFeedback ??
                                        'Supervisor left feedback'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: kPurple600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Deleting an assessment is lecturer/admin-only (firestore.rules)
                if (AuthService().loggedInStaff?.isLecturer == true)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: kDanger),
                    onPressed: () => _confirmDeleteAssessment(assessment),
                  ),
                const Icon(Icons.chevron_right, color: Color(0xFF778698)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE6ECF6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: kPrimary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8894A4)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2A38),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
