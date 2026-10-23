import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/load_error_view.dart';
import '../widgets/patient_avatar.dart';
import '../widgets/primary_fab.dart';
import '../models/patient.dart';
import '../models/staff.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'patient_profile_screen.dart';
import 'add_edit_patient_screen.dart';

class PatientListScreen extends StatefulWidget {
  final String? initialPatientId;

  const PatientListScreen({super.key, this.initialPatientId});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  Staff? _currentStaff;
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    // Jump to the requested patient only after the list has loaded —
    // before that there are no patients to find
    _loadPatients().then((_) {
      final id = widget.initialPatientId;
      if (id != null && mounted) _navigateToPatient(id);
    });
  }

  Future<void> _loadPatients() async {
    try {
      final currentStaff = await _authService.getCurrentStaff();
      print('👤 Patient list - Current staff: ${currentStaff?.name} (${currentStaff?.staffId})');

      List<Patient> patients = [];

      if (currentStaff != null) {
        patients = await _firestoreService.getPatientsByStaffId(currentStaff.staffId);
        print('👥 Patient list - Loaded ${patients.length} shared patients');
      }

      setState(() {
        _currentStaff = currentStaff;
        _allPatients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading patients: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadPatients();
  }

  void _filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _allPatients;
      } else {
        _filteredPatients = _allPatients.where((patient) {
          return patient.name.toLowerCase().contains(query.toLowerCase()) ||
              patient.mrn.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _navigateToPatient(String patientId) {
    final matches = _allPatients.where((p) => p.id == patientId);
    if (matches.isEmpty) return;
    final patient = matches.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientProfileScreen(patient: patient),
      ),
    ).then((_) => _loadPatients());
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
          'Patient List',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome and search section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    gradient: kHeroGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kBlue600.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentStaff?.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _filterPatients,
                  decoration: InputDecoration(
                    hintText: 'Search by name or MRN',
                    hintStyle: const TextStyle(
                      color: kMuted3,
                      fontSize: 14,
                    ),
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: kMuted1),
                    filled: true,
                    fillColor: kBgInput,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBlue200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBlue200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kBlue400, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people_alt_rounded,
                    count: _allPatients.length,
                    label: 'Patients',
                    color: kBlue600,
                    bgColor: kBlue100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.assignment_rounded,
                    count: _allPatients.fold<int>(
                      0,
                      (sum, p) => sum + p.woundAssessmentIds.length,
                    ),
                    label: 'Assessments',
                    color: kTeal600,
                    bgColor: kTeal50,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Patient List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Patient List',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kInk2,
                  ),
                ),
                PrimaryFAB(
                  label: 'Add Patient',
                  onPressed: () async {
                    final added = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const AddEditPatientScreen(),
                      ),
                    );
                    if (added == true) _loadPatients();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Patient List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? LoadErrorView(
                    what: 'patients',
                    error: _loadError!,
                    onRetry: _retryLoad,
                  )
                : _filteredPatients.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                size: 34,
                                color: kMuted1,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No patients found',
                                style: TextStyle(
                                  color: kInk2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try a different search keyword or add a new patient.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              leading: PatientAvatar(name: patient.name, size: 50),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      patient.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Color(0xFF1F2B3A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kBgCanvas,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${patient.woundAssessmentIds.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5E6D81),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${patient.mrn} • ${patient.age}y • ${patient.gender}',
                                  style: const TextStyle(
                                    color: Color(0xFF768497),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF728398),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PatientProfileScreen(
                                      patient: patient,
                                    ),
                                  ),
                                ).then((_) => _loadPatients());
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kInk2,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kMuted1,
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
    _searchController.dispose();
    super.dispose();
  }
}
