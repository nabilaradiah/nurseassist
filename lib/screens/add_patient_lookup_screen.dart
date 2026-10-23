import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chronic_condition.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/patient_avatar.dart';

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
        chronicConditions:
            ChronicCondition.listFromLegacyString(_foundRecord!['chronicDiseases']),
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
      backgroundColor: kBgCanvas,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gradient hero ─────────────────────────────────────────
                _buildHero(),

                // ── Body padding ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search bar
                      _buildSearchBar(),

                      // Not-found banner
                      if (_notFound) ...[
                        const SizedBox(height: 16),
                        _buildNotFoundBanner(),
                      ],

                      // Found result
                      if (_foundRecord != null) ...[
                        const SizedBox(height: 16),
                        _buildSuccessBanner(),
                        const SizedBox(height: 12),
                        _buildPatientHeroCard(),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          icon: Icons.phone_outlined,
                          title: 'Contact',
                          rows: [
                            ('Phone', _foundRecord!['phone']),
                            ('Location', _foundRecord!['location']),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildSectionCard(
                          icon: Icons.medical_information_outlined,
                          title: 'Medical',
                          rows: [
                            ('Allergies', _foundRecord!['allergies']),
                            ('Medications', _foundRecord!['medications']),
                            ('Chronic Disease', _foundRecord!['chronicDiseases']),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildSectionCard(
                          icon: Icons.emergency_outlined,
                          title: 'Emergency Contact',
                          rows: [
                            ('Name', _foundRecord!['emergencyName']),
                            ('Relationship', _foundRecord!['emergencyRelationship']),
                            ('Phone', _foundRecord!['emergencyPhone']),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky bottom bar (shown when found) ────────────────────────
          if (_foundRecord != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
              const SizedBox(height: 20),
              Text(
                'NEW PATIENT · HOSPITAL REGISTRY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find a patient',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by MRN or full name to pull from hospital records.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kShadowMd,
        border: Border.all(color: kBlue400, width: 1.5),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.search_rounded, color: kMuted3, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _isSearching ? null : _search(),
              style: const TextStyle(fontSize: 15, color: kInk2),
              decoration: const InputDecoration(
                hintText: 'Enter MRN or patient name…',
                hintStyle: TextStyle(color: kMuted3),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _isSearching ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                    : const Text('Search',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Not-found banner ──────────────────────────────────────────────────────

  Widget _buildNotFoundBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDangerBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: kDanger, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No patient found. Check the MRN or try another search.',
              style: TextStyle(fontSize: 14, color: kInk2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success banner ────────────────────────────────────────────────────────

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSuccessBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: kSuccess, size: 22),
          const SizedBox(width: 12),
          const Text(
            'Patient found in hospital records',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kSuccess,
            ),
          ),
        ],
      ),
    );
  }

  // ── Patient hero card ─────────────────────────────────────────────────────

  Widget _buildPatientHeroCard() {
    final r = _foundRecord!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: kShadowMd,
      ),
      child: Row(
        children: [
          PatientAvatar(name: r['name'] ?? '', size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kInk2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r['nric'] ?? '',
                  style: const TextStyle(fontSize: 13, color: kMuted1),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pill(r['mrn'] ?? ''),
                    _pill('${r['age']} y/o'),
                    _pill(r['gender'] ?? ''),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kBlue100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kPrimaryDark,
        ),
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<(String, String?)> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: kShadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: kBlue50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: kPrimary, size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kInk2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => _kvRow(row.$1, row.$2)),
        ],
      ),
    );
  }

  Widget _kvRow(String key, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: const TextStyle(fontSize: 13, color: kMuted1),
            ),
          ),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              style: const TextStyle(
                  fontSize: 13,
                  color: kInk2,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kLine, width: 1)),
        boxShadow: kShadowMd,
      ),
      child: Row(
        children: [
          // Search again
          Expanded(
            child: OutlinedButton(
              onPressed: _isAdding ? null : _resetSearch,
              style: OutlinedButton.styleFrom(
                foregroundColor: kInk2,
                side: const BorderSide(color: kLine, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Search again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          // Add to my patients
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isAdding ? null : _addPatient,
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
              icon: _isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                _isAdding ? 'Adding…' : 'Add to my patients',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
