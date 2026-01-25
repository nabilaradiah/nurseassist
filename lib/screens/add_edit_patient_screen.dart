import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;

  const AddEditPatientScreen({super.key, this.patient});

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _mrnController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressRoomController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _chronicDiseasesController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactRelationshipController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  String _gender = 'Female';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _nameController.text = widget.patient!.name;
      _mrnController.text = widget.patient!.mrn;
      _ageController.text = widget.patient!.age.toString();
      _contactController.text = widget.patient!.contact;
      _gender = widget.patient!.gender;
      _addressRoomController.text = widget.patient!.addressRoom ?? '';
      _allergiesController.text = widget.patient!.allergies ?? '';
      _medicationsController.text = widget.patient!.medications ?? '';
      _chronicDiseasesController.text = widget.patient!.chronicDiseases ?? '';
      _emergencyContactNameController.text = widget.patient!.emergencyContactName ?? '';
      _emergencyContactRelationshipController.text = widget.patient!.emergencyContactRelationship ?? '';
      _emergencyContactPhoneController.text = widget.patient!.emergencyContactPhone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrnController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    _addressRoomController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _chronicDiseasesController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactRelationshipController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get current staff to assign patient
      final currentStaff = await AuthService().getCurrentStaff();
      final staffId = currentStaff?.staffId ?? '';
      
      final id = widget.patient?.id ?? const Uuid().v4();
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
        addressRoom: _addressRoomController.text.trim().isEmpty ? null : _addressRoomController.text.trim(),
        allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
        medications: _medicationsController.text.trim().isEmpty ? null : _medicationsController.text.trim(),
        chronicDiseases: _chronicDiseasesController.text.trim().isEmpty ? null : _chronicDiseasesController.text.trim(),
        emergencyContactName: _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
        emergencyContactRelationship: _emergencyContactRelationshipController.text.trim().isEmpty ? null : _emergencyContactRelationshipController.text.trim(),
        emergencyContactPhone: _emergencyContactPhoneController.text.trim().isEmpty ? null : _emergencyContactPhoneController.text.trim(),
      );

      if (widget.patient == null) {
        await _firestoreService.addPatient(patient);
      } else {
        await _firestoreService.updatePatient(patient);
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
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEdit ? 'Edit Patient' : 'New Patient',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Register or update patient details',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              _buildLabel('Full Name'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Enter full name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              _buildLabel('Patient ID / MRN'),
              TextFormField(
                controller: _mrnController,
                decoration: _inputDecoration('e.g. MRN-001237'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'MRN is required'
                    : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Age'),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Years'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Age is required';
                            }
                            final age = int.tryParse(value.trim());
                            if (age == null || age <= 0) {
                              return 'Enter a valid age';
                            }
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
                        _buildLabel('Gender'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _gender,
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _gender = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildLabel('Contact Number'),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Enter phone number'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Contact is required'
                    : null,
              ),
              const SizedBox(height: 12),

              _buildLabel('Address / Room'),
              TextFormField(
                controller: _addressRoomController,
                decoration: _inputDecoration('Room number or address'),
              ),
              const SizedBox(height: 12),

              _buildLabel('Allergies'),
              TextFormField(
                controller: _allergiesController,
                maxLines: 2,
                decoration: _inputDecoration('List any allergies'),
              ),
              const SizedBox(height: 12),

              _buildLabel('Medications'),
              TextFormField(
                controller: _medicationsController,
                maxLines: 2,
                decoration: _inputDecoration('Current medications'),
              ),
              const SizedBox(height: 12),

              _buildLabel('Chronic Diseases'),
              TextFormField(
                controller: _chronicDiseasesController,
                maxLines: 2,
                decoration: _inputDecoration('Any chronic conditions'),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Emergency Contact Section
              const Text(
                'Emergency Contact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Name'),
              TextFormField(
                controller: _emergencyContactNameController,
                decoration: _inputDecoration('Emergency contact name'),
              ),
              const SizedBox(height: 12),

              _buildLabel('Relationship'),
              TextFormField(
                controller: _emergencyContactRelationshipController,
                decoration: _inputDecoration('e.g. Spouse, Parent, Sibling'),
              ),
              const SizedBox(height: 12),

              _buildLabel('Phone'),
              TextFormField(
                controller: _emergencyContactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Emergency contact phone'),
              ),

              const SizedBox(height: 24),

              // Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(isEdit ? 'Save Changes' : 'Add Patient'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
