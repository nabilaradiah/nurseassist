import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models/chronic_condition.dart';
import '../models/chronic_conditions_database.dart';
import '../models/patient.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/vital_signs.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;
  /// Database access. Defaults to the real Firestore service; tests pass
  /// a fake so screens can be exercised without Firebase.
  final FirestoreService? firestoreService;

  const AddEditPatientScreen({super.key, this.patient, this.firestoreService});

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen>
    with SingleTickerProviderStateMixin {
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  /// Index of the optional vital-signs step.
  static const _vitalsStep = 2;
  static const _lastStep = 3;

  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();
  final _nameController = TextEditingController();
  final _mrnController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressRoomController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  List<ChronicCondition> _chronicConditions = [];
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactRelationshipController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _vitalInputs = VitalInputs();

  String _gender = 'Female';
  bool _isSaving = false;
  int _currentStep = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();

    if (widget.patient != null) {
      final p = widget.patient!;
      _nameController.text = p.name;
      _mrnController.text = p.mrn;
      _ageController.text = p.age.toString();
      _contactController.text = p.contact;
      _gender = p.gender;
      _addressRoomController.text = p.addressRoom ?? '';
      _allergiesController.text = p.allergies ?? '';
      _medicationsController.text = p.medications ?? '';
      _chronicConditions = List<ChronicCondition>.from(p.chronicConditions);
      _emergencyContactNameController.text = p.emergencyContactName ?? '';
      _emergencyContactRelationshipController.text =
          p.emergencyContactRelationship ?? '';
      _emergencyContactPhoneController.text = p.emergencyContactPhone ?? '';
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _mrnController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    _addressRoomController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactRelationshipController.dispose();
    _emergencyContactPhoneController.dispose();
    _vitalInputs.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _animController.forward(from: 0);
  }

  void _nextStep() {
    if (!_formKeys[_currentStep].currentState!.validate()) return;
    if (_currentStep == _vitalsStep) {
      final problem = _vitalInputs.validate();
      if (problem != null) {
        showErrorSnack(context, problem);
        return;
      }
    }
    if (_currentStep < _lastStep) _goToStep(_currentStep + 1);
  }

  void _prevStep() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  Future<void> _save() async {
    if (!_formKeys[_currentStep].currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final currentStaff = await AuthService().getCurrentStaff();
      final staffId = currentStaff?.staffId ?? '';
      final id = widget.patient?.id ?? const Uuid().v4();
      // Vitals are optional; a filled step adds one new dated reading
      final newReading =
          _vitalInputs.isEmpty ? null : _vitalInputs.toReading();

      final patient = Patient(
        id: id,
        mrn: _mrnController.text.trim(),
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _gender,
        contact: _contactController.text.trim(),
        registeredDate: widget.patient?.registeredDate ?? DateTime.now(),
        woundAssessmentIds: widget.patient?.woundAssessmentIds ?? const [],
        staffIdAssignedTo: widget.patient?.staffIdAssignedTo ?? staffId,
        addressRoom: _addressRoomController.text.trim().isEmpty
            ? null
            : _addressRoomController.text.trim(),
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        medications: _medicationsController.text.trim().isEmpty
            ? null
            : _medicationsController.text.trim(),
        chronicConditions: _chronicConditions,
        vitalReadings: [
          ...?widget.patient?.vitalReadings,
          if (newReading != null) newReading,
        ],
        emergencyContactName:
            _emergencyContactNameController.text.trim().isEmpty
                ? null
                : _emergencyContactNameController.text.trim(),
        emergencyContactRelationship:
            _emergencyContactRelationshipController.text.trim().isEmpty
                ? null
                : _emergencyContactRelationshipController.text.trim(),
        emergencyContactPhone:
            _emergencyContactPhoneController.text.trim().isEmpty
                ? null
                : _emergencyContactPhoneController.text.trim(),
      );

      if (widget.patient == null) {
        await _firestoreService.addPatient(patient);
      } else {
        await _firestoreService.updatePatient(patient);
        if (newReading != null) {
          await _firestoreService.addVitalReading(id, newReading);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save patient: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.patient != null;

    return Scaffold(
      backgroundColor: kBgCanvas,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(isEdit),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStepBar(),
                      const SizedBox(height: 24),
                      SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Form(
                            key: _formKeys[_currentStep],
                            child: _buildCurrentStepCard(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky bottom bar ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(isEdit),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(bool isEdit) {
    const stepTitles = [
      'Personal Details',
      'Medical History',
      'Vital Signs',
      'Emergency Contact',
    ];
    const stepSubtitles = [
      'Name, MRN, age and contact information.',
      'Allergies, medications and chronic conditions.',
      "Optional. Record today's observations if taken.",
      'Who to contact in case of emergency.',
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(kRadius3xl),
          bottomRight: Radius.circular(kRadius3xl),
        ),
        boxShadow: kShadowHero,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Glass back button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Eyebrows row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'EDIT PATIENT · MANUAL ENTRY' : 'NEW PATIENT · MANUAL ENTRY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'STEP ${_currentStep + 1} OF ${_lastStep + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                stepTitles[_currentStep],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                stepSubtitles[_currentStep],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              // Progress bar — one segment per step
              Row(
                children: List.generate(_lastStep + 1, (i) {
                  final filled = i < _currentStep + 1;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < _lastStep ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step bar ─────────────────────────────────────────────────────────────

  Widget _buildStepBar() {
    const labels = ['PERSONAL', 'HISTORY', 'VITALS', 'EMERGENCY'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIndex = i ~/ 2;
          final isComplete = _currentStep > stepIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: isComplete ? kPrimary : kLine,
            ),
          );
        }
        // Circle step
        final step = i ~/ 2;
        final isActive = _currentStep == step;
        final isDone = _currentStep > step;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isActive || isDone) ? kPrimary : Colors.white,
                border: Border.all(
                  color: (isActive || isDone) ? kPrimary : kLine,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.28),
                          blurRadius: 0,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : Center(
                      child: Text(
                        '${step + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : kMuted3,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              labels[step],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: (isActive || isDone) ? kPrimary : kMuted3,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Step Cards ─────────────────────────────────────────────────
  Widget _buildCurrentStepCard() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildHistoryStep();
      case _vitalsStep:
        return _buildVitalsStep();
      case _lastStep:
        return _buildClinicalStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: kShadowMd,
      ),
      child: child,
    );
  }

  // Step 1 — Personal Details
  Widget _buildPersonalStep() {
    return _buildStepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('FULL PATIENT NAME'),
          _buildField(
            controller: _nameController,
            hint: 'e.g. Robert J. Sterling',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          _buildLabel('PATIENT ID / MRN'),
          _buildField(
            controller: _mrnController,
            hint: 'e.g. MRN-001237',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'MRN is required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('AGE'),
                    _buildField(
                      controller: _ageController,
                      hint: 'Years',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final age = int.tryParse(v.trim());
                        if (age == null || age <= 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('GENDER'),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: _inputDecoration('Select'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('CONTACT NUMBER'),
          _buildField(
            controller: _contactController,
            hint: 'e.g. +60 12-345 6789',
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Contact is required' : null,
          ),
          const SizedBox(height: 16),
          _buildLabel('ADDRESS / ROOM'),
          _buildField(
            controller: _addressRoomController,
            hint: 'Room number or ward address',
          ),
        ],
      ),
    );
  }

  // Step 2 — Medical History
  Widget _buildHistoryStep() {
    return _buildStepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('ALLERGIES'),
          _buildField(
            controller: _allergiesController,
            hint: 'List any known allergies',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildLabel('CURRENT MEDICATIONS'),
          _buildField(
            controller: _medicationsController,
            hint: 'Active prescriptions or supplements',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildLabel('CHRONIC CONDITIONS'),
          _buildChronicConditionsSection(),
          const SizedBox(height: 16),
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBlue100,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kBlue200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: kPrimary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optional — but recommended for bedside reference.',
                    style: TextStyle(
                      fontSize: 12,
                      color: kPrimaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chronic conditions ───────────────────────────────────────────
  Widget _buildChronicConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _chronicConditions) _conditionChip(c),
            _addConditionChip(),
          ],
        ),
        if (_chronicConditions.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._chronicConditions.map(_conditionDetailRow),
        ],
      ],
    );
  }

  Widget _conditionChip(ChronicCondition c) {
    return GestureDetector(
      onTap: () => _showAddConditionSheet(editing: c),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
        decoration: BoxDecoration(
          color: kBlue100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.name,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kPrimaryDark,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(
                  () => _chronicConditions.removeWhere((x) => x.id == c.id)),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: kPrimaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addConditionChip() {
    return GestureDetector(
      onTap: () => _showAddConditionSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlue400, width: 1.3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: kPrimary),
            SizedBox(width: 4),
            Text(
              'Add condition',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionDetailRow(ChronicCondition c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _showAddConditionSheet(editing: c),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 4, color: kMuted3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.diagnosedDate == null
                    ? '${c.name} · start date unknown'
                    : '${c.name} · ${c.diagnosedLabel} — ${c.durationLabel()}',
                style: const TextStyle(fontSize: 12.5, color: kMuted1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddConditionSheet({ChronicCondition? editing}) async {
    final result = await showModalBottomSheet<ChronicCondition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      builder: (ctx) => _AddConditionSheet(existing: editing),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (editing != null) {
        final i = _chronicConditions.indexWhere((x) => x.id == editing.id);
        if (i != -1) {
          _chronicConditions[i] = result;
        } else {
          _chronicConditions.add(result);
        }
      } else {
        _chronicConditions.add(result);
      }
    });
  }

  // Step 3 — Vital Signs (optional)
  Widget _buildVitalsStep() {
    final isEdit = widget.patient != null;
    return _buildStepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit
                ? "Adds a new reading with today's date and time. Earlier "
                    "readings stay in the patient's history. Leave blank to skip."
                : "Saved with today's date and time. Leave blank anything you "
                    "didn't measure, or skip this step.",
            style: const TextStyle(fontSize: 12.5, color: kMuted1, height: 1.4),
          ),
          const SizedBox(height: 16),
          VitalSignsFields(inputs: _vitalInputs),
        ],
      ),
    );
  }

  // Step 4 — Emergency Contact
  Widget _buildClinicalStep() {
    return _buildStepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('CONTACT NAME'),
          _buildField(
            controller: _emergencyContactNameController,
            hint: 'Full name of emergency contact',
          ),
          const SizedBox(height: 16),
          _buildLabel('RELATIONSHIP'),
          _buildField(
            controller: _emergencyContactRelationshipController,
            hint: 'e.g. Spouse, Parent, Sibling',
          ),
          const SizedBox(height: 16),
          _buildLabel('PHONE NUMBER'),
          _buildField(
            controller: _emergencyContactPhoneController,
            hint: 'Emergency contact phone',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isEdit) {
    final isLastStep = _currentStep == _lastStep;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kLine, width: 1)),
      ),
      child: Row(
        children: [
          // Cancel / Back
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : (_currentStep == 0
                      ? () => Navigator.of(context).pop()
                      : _prevStep),
              style: OutlinedButton.styleFrom(
                foregroundColor: kInk2,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: kLine, width: 1.5),
              ),
              child: Text(
                _currentStep == 0 ? 'Cancel' : 'Back',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Continue / Save
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : (isLastStep ? _save : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kPrimary.withValues(alpha: 0.45),
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.7),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    )
                  : Icon(
                      isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                isLastStep
                    ? (isEdit ? 'Save changes' : 'Save patient')
                    : 'Continue',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kMuted2,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(hint),
      validator: validator,
    );
  }
}

// Shared by the form fields above and _AddConditionSheet below, so both
// keep the same input styling without duplicating it.
InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kMuted3, fontSize: 14),
    filled: true,
    fillColor: kBgInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBlue400, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kDanger),
    ),
  );
}

// ── Add / edit condition bottom sheet ─────────────────────────────────────
//
// Two steps: "pick" a condition name (search the common list, or "Other"
// free text), then "onset" — either an exact month/year, or a quick range
// when the exact date isn't known.
enum _DateMode { unknown, exact, range }

class _AddConditionSheet extends StatefulWidget {
  final ChronicCondition? existing;

  const _AddConditionSheet({this.existing});

  @override
  State<_AddConditionSheet> createState() => _AddConditionSheetState();
}

class _AddConditionSheetState extends State<_AddConditionSheet> {
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _rangeLabels = ['< 1 yr', '1–5 yrs', '5–10 yrs', '10+ yrs'];

  late String _step; // 'pick' or 'onset'
  final _searchController = TextEditingController();
  final _otherController = TextEditingController();
  bool _showOtherField = false;
  String? _selectedName;

  late int _pickedMonth;
  late int _pickedYear;
  late final List<int> _years;
  late final FixedExtentScrollController _monthScrollController;
  late final FixedExtentScrollController _yearScrollController;

  /// How the start date is given. New conditions start as [_DateMode.unknown]
  /// so a date is only saved when the nurse actively picks one — never the
  /// current month by default.
  _DateMode _dateMode = _DateMode.unknown;
  int? _selectedRangeIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _years = List.generate(101, (i) => now.year - i);

    final existing = widget.existing;
    if (existing != null) {
      _step = 'onset';
      _selectedName = existing.name;
      final d = existing.diagnosedDate ?? now;
      _pickedMonth = d.month;
      _pickedYear = d.year;
      _dateMode = existing.diagnosedDate == null
          ? _DateMode.unknown
          : existing.isApproximate
              ? _DateMode.range
              : _DateMode.exact;
    } else {
      _step = 'pick';
      _pickedMonth = now.month;
      _pickedYear = now.year;
    }

    final yearIndex = _years.indexOf(_pickedYear);
    _monthScrollController =
        FixedExtentScrollController(initialItem: _pickedMonth - 1);
    _yearScrollController =
        FixedExtentScrollController(initialItem: yearIndex >= 0 ? yearIndex : 0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _otherController.dispose();
    _monthScrollController.dispose();
    _yearScrollController.dispose();
    super.dispose();
  }

  List<String> get _filteredConditions {
    final query = _searchController.text.trim().toLowerCase();
    final all = ChronicConditionsDatabase.getAllConditions();
    if (query.isEmpty) return all;
    return all.where((c) => c.toLowerCase().contains(query)).toList();
  }

  void _pickName(String name) {
    setState(() {
      _selectedName = name;
      _step = 'onset';
    });
  }

  void _confirmOther() {
    final text = _otherController.text.trim();
    if (text.isEmpty) return;
    _pickName(text);
  }

  DateTime _rangeMidpoint(int index) {
    final now = DateTime.now();
    switch (index) {
      case 0: // < 1 yr
        return DateTime(now.year, now.month - 6, 1);
      case 1: // 1–5 yrs
        return DateTime(now.year - 3, now.month, 1);
      case 2: // 5–10 yrs
        return DateTime(now.year - 7, now.month - 6, 1);
      default: // 10+ yrs — open-ended, anchor at 15 years back
        return DateTime(now.year - 15, now.month, 1);
    }
  }

  void _confirm() {
    if (_selectedName == null) return;

    final DateTime? diagnosedDate;
    final bool isApproximate;
    switch (_dateMode) {
      case _DateMode.unknown:
        diagnosedDate = null;
        isApproximate = false;
      case _DateMode.range:
        if (_selectedRangeIndex == null) return;
        diagnosedDate = _rangeMidpoint(_selectedRangeIndex!);
        isApproximate = true;
      case _DateMode.exact:
        diagnosedDate = DateTime(_pickedYear, _pickedMonth, 1);
        isApproximate = false;
    }

    Navigator.of(context).pop(ChronicCondition(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _selectedName!,
      diagnosedDate: diagnosedDate,
      isApproximate: isApproximate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: _step == 'pick' ? _buildPickStep() : _buildOnsetStep(),
        ),
      ),
    );
  }

  Widget _buildPickStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add condition',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kInk2),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: _inputDecoration('Search condition…'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final name in _filteredConditions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(name, style: const TextStyle(fontSize: 14, color: kInk2)),
                  onTap: () => _pickName(name),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        if (!_showOtherField)
          TextButton.icon(
            onPressed: () => setState(() => _showOtherField = true),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Other — type it in'),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otherController,
                  autofocus: true,
                  decoration: _inputDecoration('Condition name'),
                  onSubmitted: (_) => _confirmOther(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirmOther,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use this'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOnsetStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When did $_selectedName start?',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kInk2),
        ),
        const SizedBox(height: 4),
        const Text(
          "Optional. Skip it if you don't know.",
          style: TextStyle(fontSize: 12.5, color: kMuted1),
        ),
        const SizedBox(height: 16),
        if (_dateMode == _DateMode.unknown) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBgInput,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLine),
            ),
            child: Column(
              children: [
                const Text(
                  'No start date set',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kInk2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _dateMode = _DateMode.exact),
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: const Text('Pick month & year'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _dateMode = _DateMode.range),
                      icon: const Icon(Icons.timelapse_rounded, size: 16),
                      label: const Text('Roughly how long'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (_dateMode == _DateMode.exact) ...[
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _monthScrollController,
                    itemExtent: 36,
                    onSelectedItemChanged: (i) => _pickedMonth = i + 1,
                    children: _monthNames
                        .map((m) => Center(child: Text(m)))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _yearScrollController,
                    itemExtent: 36,
                    onSelectedItemChanged: (i) => _pickedYear = _years[i],
                    children: _years
                        .map((y) => Center(child: Text('$y')))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _dateMode = _DateMode.range),
              child: const Text('Not sure — use a range instead'),
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_rangeLabels.length, (i) {
              final selected = _selectedRangeIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedRangeIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? kPrimary : kBgInput,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _rangeLabels[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : kMuted1,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _dateMode = _DateMode.exact),
              child: const Text('Use exact date instead'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_dateMode == _DateMode.range &&
                    _selectedRangeIndex == null)
                ? null
                : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _dateMode == _DateMode.unknown
                  ? (widget.existing != null
                      ? 'Save without date'
                      : 'Add without date')
                  : (widget.existing != null ? 'Save changes' : 'Add condition'),
            ),
          ),
        ),
        if (_dateMode != _DateMode.unknown)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _dateMode = _DateMode.unknown),
              child: const Text("Skip — I don't know the date",
                  style: TextStyle(color: kMuted1)),
            ),
          ),
      ],
    );
  }
}
