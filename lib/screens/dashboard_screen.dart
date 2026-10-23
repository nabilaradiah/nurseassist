import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/load_error_view.dart';
import '../widgets/brand_logo.dart';
import '../widgets/patient_avatar.dart';
import '../widgets/primary_fab.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/staff.dart';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import 'patient_list_screen.dart';
import 'patient_profile_screen.dart';
import 'login_screen.dart';
import 'add_edit_patient_screen.dart';
import 'lecturer_approval_screen.dart';
import 'nurse_feedback_screen.dart';

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
  int _todayPatients = 0;
  int _todayAssessments = 0;
  int _pendingApprovals = 0;
  int _needsAttentionCount = 0;
  bool _isLoading = true;
  Object? _loadError;

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

      List<Patient> patients = [];
      if (staff != null) {
        patients =
            await _firestoreService.getPatientsByStaffId(staff.staffId);
        debugPrint('👥 Loaded ${patients.length} shared patients');
      }

      int assessmentCount = 0;
      for (var patient in patients) {
        assessmentCount += patient.woundAssessmentIds
            .where((id) => id.isNotEmpty)
            .length;
      }

      // Today's counts
      final today = DateTime.now();
      bool isToday(DateTime d) =>
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;

      final todayPatients =
          patients.where((p) => isToday(p.registeredDate)).length;

      int todayAssessmentCount = 0;
      if (patients.isNotEmpty) {
        final List<List<WoundAssessment>> allLists = await Future.wait(
          patients.map((p) => _firestoreService.getWoundAssessments(p.id)),
        );
        for (final list in allLists) {
          todayAssessmentCount +=
              list.where((a) => isToday(a.assessmentDate)).length;
        }
      }

      int pendingCount = 0;
      int needsAttentionCount = 0;
      if (staff != null && staff.isLecturer) {
        final pending =
            await _firestoreService.getPendingApprovalAssessments();
        pendingCount = pending.length;
      } else if (staff != null) {
        final needsAttention =
            await _firestoreService.getAssessmentsNeedingAttention(staff.staffId);
        needsAttentionCount = needsAttention.length;
      }

      setState(() {
        _currentStaff = staff;
        _patientsList = patients;
        _totalPatients = patients.length;
        _totalAssessments = assessmentCount;
        _todayPatients = todayPatients;
        _todayAssessments = todayAssessmentCount;
        _pendingApprovals = pendingCount;
        _needsAttentionCount = needsAttentionCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
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
    _loadData();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('End your shift?', style: kH3),
          content: const Text(
            "You'll need to sign in again to keep documenting.",
            style: TextStyle(fontSize: 14, color: kMuted1),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: kMuted1),
              child: const Text('Stay logged in'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('End shift'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(_loadError != null
                        ? [
                            const SizedBox(height: 24),
                            LoadErrorView(
                              what: 'your patients',
                              error: _loadError!,
                              onRetry: _retryLoad,
                            ),
                          ]
                        : [
                      const SizedBox(height: 24),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _TodayTotalStatCard(
                              icon: Icons.people_alt_rounded,
                              accent: kPrimaryDark,
                              accentBg: kBlue50,
                              todayCount: _todayPatients,
                              totalCount: _totalPatients,
                              label: 'Patients',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TodayTotalStatCard(
                              icon: Icons.assignment_rounded,
                              accent: kTeal600,
                              accentBg: kTeal50,
                              todayCount: _todayAssessments,
                              totalCount: _totalAssessments,
                              label: 'Assessments',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Lecturer-only: Pending Approvals card
                      if (_currentStaff?.isLecturer == true) ...[
                        _buildLecturerReviewCard(),
                        const SizedBox(height: 32),
                      ],

                      // Nurse-only: Needs Your Attention card
                      if (_currentStaff?.isLecturer == false &&
                          _needsAttentionCount > 0) ...[
                        _buildNeedsAttentionCard(),
                        const SizedBox(height: 32),
                      ],

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

      floatingActionButton: _isLoading
          ? null
          : PrimaryFAB(
              label: 'Add Patient',
              icon: Icons.add_rounded,
              onPressed: () {
                Navigator.of(context)
                    .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const AddEditPatientScreen(),
                  ),
                )
                    .then((added) {
                  if (added == true) _loadData();
                });
              },
            ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: kShadowHero,
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
                      const BrandLogo(size: 32, onGradient: true),
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.85),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_currentStaff != null) ...[
                            _buildRoleBadge(_currentStaff!.role),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            _getFormattedDate(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
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
                color: kPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Your Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kInk2,
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
            foregroundColor: kPrimary,
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
        boxShadow: kShadowSm,
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
                    builder: (_) => PatientProfileScreen(patient: patient),
                  ),
                )
                .then((_) => _loadData());
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                PatientAvatar(name: patient.name, size: 48),
                const SizedBox(width: 14),

                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: kInk2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${patient.mrn}  •  ${patient.age}y  •  ${patient.gender}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kMuted1,
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
                    color: kBlue50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$woundCount wound${woundCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: kMuted3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── role badge ─────────────────────────────────────────────────────────────

  Widget _buildRoleBadge(String role) {
    final (label, bg, border) = switch (role) {
      'admin'                  => ('Admin',      const Color(0x33FF5252), const Color(0x99FF5252)),
      'supervisor' || 'lecturer' => ('Supervisor', const Color(0x33FFD740), const Color(0x99FFD740)),
      _                        => ('Nurse',      const Color(0x33FFFFFF), const Color(0x66FFFFFF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── lecturer review card ───────────────────────────────────────────────────

  Widget _buildLecturerReviewCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                  builder: (_) => const LecturerApprovalScreen()),
            )
            .then((_) => _loadData());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: kLecturerGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kShadowLecturer,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.rate_review_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Approvals',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _pendingApprovals == 0
                        ? 'No assessments awaiting review'
                        : '$_pendingApprovals wound${_pendingApprovals == 1 ? '' : 's'} awaiting your approval',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  // ── needs attention card ───────────────────────────────────────────────────

  Widget _buildNeedsAttentionCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (_) => const NurseFeedbackScreen()),
            )
            .then((_) => _loadData());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWarning,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kWarning.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.feedback_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Needs Your Attention',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _needsAttentionCount == 1
                        ? '1 assessment has supervisor feedback'
                        : '$_needsAttentionCount assessments have supervisor feedback',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
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
        boxShadow: kShadowSm,
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 52, color: kMuted3),
          SizedBox(height: 16),
          Text(
            'No patients yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kMuted1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap "Add Patient" below to get started',
            style: TextStyle(
              fontSize: 13,
              color: kMuted3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today / Total split stat card ────────────────────────────────────────────

class _TodayTotalStatCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final int todayCount;
  final int totalCount;
  final String label;

  const _TodayTotalStatCard({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.todayCount,
    required this.totalCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: kShadowMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel — TODAY ─────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                color: accentBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: accent, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      todayCount.toString(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // One line, shrinking slightly on narrow phones so
                    // "Assessments" never wraps onto a second line
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          color: accent.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Divider ────────────────────────────────────────────────────
            const VerticalDivider(width: 1, thickness: 1, color: kLine),

            // ── Right panel — TOTAL ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: kMuted3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      totalCount.toString(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kInk2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '',                           // spacer — same height as label
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
