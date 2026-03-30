import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import '../services/firestore_service.dart';

class AnalysisResultsScreen extends StatefulWidget {
  final Patient patient;
  final WoundAssessment assessment;

  const AnalysisResultsScreen({
    super.key,
    required this.patient,
    required this.assessment,
  });

  @override
  State<AnalysisResultsScreen> createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _specialistConfirmed = false;
  final FirestoreService _firestoreService = FirestoreService();
  late WoundAssessment _assessment;

  // Editable assessment fields
  final TextEditingController _woundNameController = TextEditingController();
  final TextEditingController _estimatedSizeController = TextEditingController();
  final TextEditingController _dressingController = TextEditingController();
  final TextEditingController _antibioticController = TextEditingController();
  final TextEditingController _surgicalController = TextEditingController();
  final TextEditingController _managementNotesController = TextEditingController();
  int _woundType = 1;
  String _severity = 'Moderate';

  @override
  void initState() {
    super.initState();
    _assessment = widget.assessment;
    _notesController.text = _assessment.additionalNotes ?? '';
    _specialistConfirmed = _assessment.specialistConfirmed ?? false;
    _initEditableFields();
  }

  Future<void> _saveAssessment() async {
    // Only require specialist confirmation if the wound type requires it (types 3, 4, 6)
    if (_assessment.requiresSpecialistConfirmation && !_specialistConfirmed) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Confirmation Required',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Please tick the "Specialist Confirmation Required" checkbox before saving the assessment.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _initEditableFields() {
    final result = _assessment.analysisResult;
    if (result == null) return;

    _woundType = result.woundType;
    _severity = result.severity;
    _woundNameController.text = result.woundName;
    _estimatedSizeController.text = result.estimatedSize.toStringAsFixed(1);
    _dressingController.text = result.management.dressingMaterials.join(', ');
    _antibioticController.text = result.management.antibioticRecommendation;
    _surgicalController.text = result.management.surgicalProcedures.join(', ');
    _managementNotesController.text = result.management.additionalNotes ?? '';
  }

  WoundAssessment _buildUpdatedAssessment({
    WoundAnalysisResult? analysisResult,
    String? notes,
    bool? specialistConfirmed,
  }) {
    return WoundAssessment(
      id: _assessment.id,
      patientId: _assessment.patientId,
      imageUrl: _assessment.imageUrl,
      assessmentDate: _assessment.assessmentDate,
      analysisResult: analysisResult ?? _assessment.analysisResult,
      additionalNotes: notes ?? _assessment.additionalNotes,
      requiresSpecialistConfirmation: _assessment.requiresSpecialistConfirmation,
      specialistConfirmed: specialistConfirmed ?? _assessment.specialistConfirmed,
    );
  }

  List<String> _parseList(String value, List<String> fallback) {
    final parts = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? fallback : parts;
  }

  Future<void> _openEditAssessment() async {
    final current = _assessment.analysisResult;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analysis data to edit')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Assessment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _woundNameController,
                        decoration: const InputDecoration(
                          labelText: 'Wound Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Wound name is required'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _woundType,
                              decoration: const InputDecoration(
                                labelText: 'Wound Type',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(
                                8,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('Type ${index + 1}'),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => _woundType = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _severity,
                              decoration: const InputDecoration(
                                labelText: 'Severity',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                                DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                                DropdownMenuItem(value: 'Mild', child: Text('Mild')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => _severity = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _estimatedSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Size (cm²)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Estimated size is required';
                          }
                          final d = double.tryParse(v.trim());
                          if (d == null || d <= 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _dressingController,
                        decoration: const InputDecoration(
                          labelText: 'Dressing Materials (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _antibioticController,
                        decoration: const InputDecoration(
                          labelText: 'Antibiotic Recommendation',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _surgicalController,
                        decoration: const InputDecoration(
                          labelText: 'Surgical Procedures (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _managementNotesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Management Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final updatedResult = WoundAnalysisResult(
                              confidenceScore: current.confidenceScore,
                              woundType: _woundType,
                              woundName: _woundNameController.text.trim(),
                              severity: _severity,
                              estimatedSize:
                                  double.tryParse(_estimatedSizeController.text.trim()) ??
                                      current.estimatedSize,
                              characteristics: current.characteristics,
                              management: WoundManagement(
                                dressingMaterials: _parseList(
                                  _dressingController.text,
                                  current.management.dressingMaterials,
                                ),
                                antibioticRecommendation: _antibioticController.text.trim().isEmpty
                                    ? current.management.antibioticRecommendation
                                    : _antibioticController.text.trim(),
                                surgicalProcedures: _parseList(
                                  _surgicalController.text,
                                  current.management.surgicalProcedures,
                                ),
                                additionalNotes: _managementNotesController.text.trim().isEmpty
                                    ? null
                                    : _managementNotesController.text.trim(),
                              ),
                              segmentationMapUrl: current.segmentationMapUrl,
                            );

                            final updatedAssessment = _buildUpdatedAssessment(
                              analysisResult: updatedResult,
                              notes: _notesController.text,
                              specialistConfirmed: _specialistConfirmed,
                            );

                            await _firestoreService.updateWoundAssessment(updatedAssessment);

                            if (mounted) {
                              setState(() {
                                _assessment = updatedAssessment;
                              });
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Assessment updated')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _assessment.analysisResult;
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis Results')),
        body: const Center(child: Text('No analysis result available')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Analysis Results',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
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
            // Patient Info
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patient.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.patient.age} years • ${widget.patient.gender}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // AI Analysis Confidence
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Analysis Confidence',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Accuracy is based on the assessment',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(result.confidenceScore * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Original Photo
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Original Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _showImageDialog(context, _assessment.imageUrl);
                        },
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('Zoom'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _assessment.imageUrl.startsWith('http')
                          ? Image.network(
                              _assessment.imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_assessment.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.error, size: 100),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Wound Characteristics Dashboard
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wound Characteristics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Necrotic Tissue Progress
                  _buildCharacteristicProgress(
                    icon: Icons.info_outline,
                    label: 'Necrotic Tissue / Slough',
                    value: result.characteristics.necroticTissue,
                    color: result.characteristics.necroticTissue.contains('> 25%')
                        ? Colors.red
                        : Colors.orange,
                  ),
                  const SizedBox(height: 16),

                  // Infection Status
                  _buildInfectionStatus(
                    label: 'Infection Status',
                    infection: result.characteristics.infection,
                  ),
                  const SizedBox(height: 16),

                  // Exudate Level Progress
                  _buildExudateLevel(
                    label: 'Exudate Level',
                    exudateLevel: result.characteristics.exudateLevel,
                  ),
                  const SizedBox(height: 16),

                  // Tissue Classification Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tissue Classification',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: result.characteristics.tissueClassification
                            .map((tissue) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    tissue,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confidence Score Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confidence Score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(result.confidenceScore * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: result.confidenceScore,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Indicators: ${result.characteristics.tissueClassification.join(", ")}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Wound Classification
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wound Classification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Type ${result.woundType}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Wound Name', result.woundName),
                  const Divider(height: 24),
                  const Text(
                    'Wound Characteristics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCharacteristicRow(
                    'Necrotic Tissue / Slough',
                    result.characteristics.necroticTissue,
                  ),
                  _buildCharacteristicRow(
                    'Infection',
                    result.characteristics.infection,
                  ),
                  _buildCharacteristicRow(
                    'Exudate Level',
                    result.characteristics.exudateLevel,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Severity', result.severity,
                      valueColor: _getSeverityColor(result.severity)),
                  _buildInfoRow(
                      'Estimated Size', '${result.estimatedSize.toStringAsFixed(1)} cm²'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Wound Management
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wound Management (Type ${result.woundType})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Dressing Materials
                  _buildManagementSection(
                    icon: Icons.medical_services,
                    title: 'Dressing Materials',
                    items: result.management.dressingMaterials,
                    color: Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Antibiotic
                  _buildManagementSection(
                    icon: Icons.medication,
                    title: 'Antibiotic',
                    items: [result.management.antibioticRecommendation],
                    color: result.management.antibioticRecommendation.toLowerCase().contains('yes')
                        ? Colors.red
                        : Colors.green,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Surgical Procedures
                  _buildManagementSection(
                    icon: Icons.local_hospital,
                    title: 'Surgical Procedures',
                    items: result.management.surgicalProcedures,
                    color: Colors.orange,
                  ),

                  // Additional Notes
                  if (result.management.additionalNotes != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                  color: Colors.amber.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Additional Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.management.additionalNotes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Specialist Confirmation (for types 3, 4, 6)
            if (_assessment.requiresSpecialistConfirmation) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Specialist Confirmation Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'For wound types requiring debridement, a specialist must be consulted before proceeding.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _specialistConfirmed,
                      onChanged: (value) {
                        setState(() => _specialistConfirmed = value ?? false);
                      },
                      title: const Text(
                        'I confirm a specialist has been consulted regarding the debridement procedure',
                        style: TextStyle(fontSize: 14),
                      ),
                      activeColor: Colors.orange,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Additional Notes Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add any additional observations or notes...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                      onPressed: _saveAssessment,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Assessment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicProgress({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.contains('> 25%') ? 0.7 : 0.25,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInfectionStatus({
    required String label,
    required String infection,
  }) {
    final hasInfection = infection.toLowerCase().contains('presence');
    final color = hasInfection ? Colors.red : Colors.green;
    final icon = hasInfection ? Icons.warning_rounded : Icons.check_circle_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Infection Status',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  infection,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExudateLevel({
    required String label,
    required String exudateLevel,
  }) {
    final isDry = exudateLevel.toLowerCase().contains('dry');
    final color = isDry ? Colors.green : Colors.orange;
    final value = isDry ? 0.2 : 0.65;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.water_drop_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                exudateLevel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Dry',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Wet',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

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
                    ? Image.network(imageUrl)
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
