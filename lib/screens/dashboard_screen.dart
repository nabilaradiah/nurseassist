import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/staff.dart';
import '../models/patient.dart';
import 'patient_list_screen.dart';
import 'login_screen.dart';
import 'add_patient_lookup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Staff? _currentStaff;
  List<Patient> _patientsList = [];
  int _totalPatients = 0;
  int _totalAssessments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed - reloading dashboard data');
      _loadData();
    }
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🔄 Dashboard widget updated - reloading data');
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final staff = await _authService.getCurrentStaff();
      debugPrint('👤 Current staff: ${staff?.name} (${staff?.staffId})');

      // Get only patients assigned to this staff member
      List<Patient> patients = [];
      if (staff != null) {
        patients =
            await _firestoreService.getPatientsByStaffId(staff.staffId);
        debugPrint(
            '👥 Loaded ${patients.length} patients for ${staff.name}');
      }

      int assessmentCount = 0;
      for (var patient in patients) {
        // Count only non-empty assessment IDs
        assessmentCount += patient.woundAssessmentIds
            .where((id) => id.isNotEmpty)
            .length;
      }

      setState(() {
        _currentStaff = staff;
        _patientsList = patients;
        _totalPatients = patients.length;
        _totalAssessments = assessmentCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.people_alt_rounded,
                              count: _totalPatients,
                              label: 'Patients',
                              color: Colors.blue.shade600,
                              bgColor: Colors.blue.shade50,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.assignment_rounded,
                              count: _totalAssessments,
                              label: 'Assessments',
                              color: Colors.teal.shade600,
                              bgColor: Colors.teal.shade50,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Section header
                      _buildSectionHeader(),

                      const SizedBox(height: 16),

                      // Patient list / empty state
                      _patientsList.isEmpty
                          ? _buildEmptyState()
                          : Column(
                              children: _patientsList
                                  .take(3)
                                  .map((patient) =>
                                      _buildPatientCard(patient))
                                  .toList(),
                            ),
                    ]),
                  ),
                ),
              ],
            ),

      // Add Patient FAB — same logic, better placement
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const AddPatientLookupScreen(),
                  ),
                )
                    .then((added) {
                  if (added == true) {
                    _loadData();
                  }
                });
              },
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Patient',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              elevation: 4,
            ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade500,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: brand + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'NurseAssist',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Greeting — Builder kept to preserve debugPrint log
              Builder(
                builder: (context) {
                  debugPrint(
                      '🎯 Dashboard displaying staff: ${_currentStaff?.name} (${_currentStaff?.staffId})');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentStaff?.name ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── stat card ──────────────────────────────────────────────────────────────

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Your Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const PatientListScreen(),
                  ),
                )
                .then((_) => _loadData());
          },
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('View All'),
          iconAlignment: IconAlignment.end,
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade600,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── patient card ───────────────────────────────────────────────────────────

  Widget _buildPatientCard(Patient patient) {
    final woundCount = patient.woundAssessmentIds
        .where((id) => id.isNotEmpty)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PatientListScreen(initialPatientId: patient.id),
                  ),
                )
                .then((_) => _loadData());
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    patient.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${patient.mrn}  •  ${patient.age}y  •  ${patient.gender}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Wound count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$woundCount wound${woundCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No patients yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add Patient" below to get started',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
