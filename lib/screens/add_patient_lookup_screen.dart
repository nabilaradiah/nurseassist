import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AddPatientLookupScreen extends StatefulWidget {
  const AddPatientLookupScreen({super.key});

  @override
  State<AddPatientLookupScreen> createState() => _AddPatientLookupScreenState();
}

class _AddPatientLookupScreenState extends State<AddPatientLookupScreen> {
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  bool _isSearching = false;
  bool _isAdding = false;
  bool _notFound = false;
  Map<String, String>? _foundRecord;

  // Simulated hospital master data (replace with real API/DB later)
  final List<Map<String, String>> _hospitalRecords = [
    {
      'mrn': 'MRN-001237',
      'name': 'Tengku Mazlina',
      'nric': '801124-14-5532',
      'age': '45',
      'gender': 'Female',
      'phone': '0174067606',
      'location': 'Bandar Botanik, Klang',
      'allergies': 'Aspirin',
      'medications': 'Omeprazole 20mg',
      'chronicDiseases': 'GERD',
      'emergencyName': 'Mohammad Hafruizal',
      'emergencyRelationship': 'Husband',
      'emergencyPhone': '0125646427',
    },
    {
      'mrn': 'MRN-001235',
      'name': 'Abdul Wahab',
      'nric': '670102-02-4431',
      'age': '67',
      'gender': 'Male',
      'phone': '0123456789',
      'location': 'Batu Pahat, Johor',
      'allergies': 'None',
      'medications': 'Metformin, Atorvastatin',
      'chronicDiseases': 'Diabetes, Hyperlipidemia',
      'emergencyName': 'Ramlah Musa',
      'emergencyRelationship': 'Wife',
      'emergencyPhone': '0138876543',
    },
    {
      'mrn': 'MRN-001240',
      'name': 'Sabrina Elyana',
      'nric': '900701-10-2234',
      'age': '35',
      'gender': 'Female',
      'phone': '0192233445',
      'location': 'Petaling Jaya, Selangor',
      'allergies': 'Penicillin',
      'medications': 'Lisinopril',
      'chronicDiseases': 'Hypertension',
      'emergencyName': 'Hakim Iskandar',
      'emergencyRelationship': 'Brother',
      'emergencyPhone': '0189988776',
    },
    {
      'mrn': 'MRN-012',
      'name': 'Noraini Binti Kassim',
      'nric': '750412-08-2231',
      'age': '50',
      'gender': 'Female',
      'phone': '0112233445',
      'location': 'Seremban, Negeri Sembilan',
      'allergies': 'Seafood',
      'medications': 'Amlodipine 5mg',
      'chronicDiseases': 'Hypertension',
      'emergencyName': 'Kassim Bin Omar',
      'emergencyRelationship': 'Husband',
      'emergencyPhone': '0129988776',
    },
    {
      'mrn': 'MRN-013',
      'name': 'Faizul Rahman',
      'nric': '820601-05-4412',
      'age': '43',
      'gender': 'Male',
      'phone': '0195566778',
      'location': 'Shah Alam, Selangor',
      'allergies': 'None',
      'medications': 'Metformin 500mg',
      'chronicDiseases': 'Type 2 Diabetes',
      'emergencyName': 'Nur Farah',
      'emergencyRelationship': 'Wife',
      'emergencyPhone': '0134455667',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a patient name or MRN to search')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _notFound = false;
      _foundRecord = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final lower = query.toLowerCase();
    final match = _hospitalRecords.firstWhere(
      (r) => r['mrn']!.toLowerCase() == lower || r['name']!.toLowerCase().contains(lower),
      orElse: () => {},
    );

    setState(() {
      _isSearching = false;
      if (match.isEmpty) {
        _notFound = true;
      } else {
        _foundRecord = match;
      }
    });
  }

  Future<void> _addPatient() async {
    if (_foundRecord == null || _isAdding) return;

    setState(() => _isAdding = true);

    try {
      final staff = await _authService.getCurrentStaff();
      if (staff == null) {
        throw Exception('No staff session found');
      }

      final mrn = _foundRecord!['mrn'] ?? '';
      final existing = await _firestoreService.getPatientByMrn(mrn);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient already exists in NurseAssist')),
          );
        }
        return;
      }

      final id = const Uuid().v4();
      final age = int.tryParse(_foundRecord!['age'] ?? '') ?? 0;
      final patient = Patient(
        id: id,
        mrn: mrn,
        name: _foundRecord!['name'] ?? 'Unknown',
        age: age,
        gender: _foundRecord!['gender'] ?? 'N/A',
        contact: _foundRecord!['phone'] ?? 'N/A',
        registeredDate: DateTime.now(),
        staffIdAssignedTo: staff.staffId,
        phone: _foundRecord!['phone'],
        addressRoom: _foundRecord!['location'],
        allergies: _foundRecord!['allergies'],
        medications: _foundRecord!['medications'],
        chronicDiseases: _foundRecord!['chronicDiseases'],
        emergencyContactName: _foundRecord!['emergencyName'],
        emergencyContactRelationship: _foundRecord!['emergencyRelationship'],
        emergencyContactPhone: _foundRecord!['emergencyPhone'],
      );

      await _firestoreService.addPatient(patient);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added to NurseAssist')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add patient: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _foundRecord = null;
      _notFound = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'New Patient',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Register a new patient',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient ID / MRN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Enter MRN or patient name',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: _isSearching ? null : _search,
                            child: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the patient\'s hospital ID to fetch their information',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),

            if (_notFound) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: const [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('No patient found. Check the MRN or try another search.'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_foundRecord != null) ...[
              const SizedBox(height: 16),
              _buildFoundCard(),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isAdding ? null : _addPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Add'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isAdding ? null : _resetSearch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text('Search Another Patient'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFoundCard() {
    final r = _foundRecord!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Patient Found',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle('Personal Information'),
            _infoRow('Full Name', r['name']),
            _infoRow('NRIC No', r['nric']),
            _infoRow('Age', r['age']),
            _infoRow('Gender', r['gender']),
            _infoRow('MRN', r['mrn']),
            const SizedBox(height: 12),

            _sectionTitle('Contact Information'),
            _infoRow('Phone', r['phone']),
            _infoRow('Location', r['location']),
            const SizedBox(height: 12),

            _sectionTitle('Medical Information'),
            _infoRow('Allergies', r['allergies']),
            _infoRow('Medications', r['medications']),
            _infoRow('Chronic Disease', r['chronicDiseases']),
            const SizedBox(height: 12),

            _sectionTitle('Emergency Contact'),
            _infoRow('Name', r['emergencyName']),
            _infoRow('Relationship', r['emergencyRelationship']),
            _infoRow('Phone', r['emergencyPhone']),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value?.isNotEmpty == true ? value! : '-')),
        ],
      ),
    );
  }
}
