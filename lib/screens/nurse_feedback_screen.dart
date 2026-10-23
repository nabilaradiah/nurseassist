import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/load_error_view.dart';
import '../models/patient.dart';
import '../models/wound_assessment.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'patient_profile_screen.dart';

/// Read-only list of assessments a supervisor has left feedback on
/// (reassigned type and/or a comment), scoped to the logged-in nurse.
class NurseFeedbackScreen extends StatefulWidget {
  const NurseFeedbackScreen({super.key});

  @override
  State<NurseFeedbackScreen> createState() => _NurseFeedbackScreenState();
}

class _NurseFeedbackScreenState extends State<NurseFeedbackScreen> {
  final _firestoreService = FirestoreService();

  List<_FeedbackItem> _items = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final staffId = AuthService().loggedInStaff?.staffId ?? '';
      final assessments =
          await _firestoreService.getAssessmentsNeedingAttention(staffId);

      final patients = await Future.wait(
        assessments.map((a) => _firestoreService.getPatient(a.patientId)),
      );

      final items = <_FeedbackItem>[];
      for (var i = 0; i < assessments.length; i++) {
        final patient = patients[i];
        if (patient != null) {
          items.add(_FeedbackItem(assessment: assessments[i], patient: patient));
        }
      }
      items.sort((a, b) => (b.assessment.supervisorFeedbackAt ?? b.assessment.assessmentDate)
          .compareTo(a.assessment.supervisorFeedbackAt ?? a.assessment.assessmentDate));

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e;
        });
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCanvas,
      appBar: AppBar(
        title: const Text(
          'Supervisor Feedback',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kWarning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kWarning.withValues(alpha: 0.30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.feedback_outlined, size: 13, color: kWarning),
                      SizedBox(width: 5),
                      Text(
                        'Needs Your Attention',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kWarning,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading) ...[
                  const Spacer(),
                  Text(
                    '${_items.length} assessment${_items.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: kMuted1),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? LoadErrorView(
                        what: 'feedback',
                        error: _loadError!,
                        onRetry: _load,
                      )
                    : _items.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _buildCard(_items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── assessment card ────────────────────────────────────────────────────────

  Widget _buildCard(_FeedbackItem item) {
    final a = item.assessment;
    final bool isNetworkImage = a.imageUrl.startsWith('http');

    final feedbackAt = a.supervisorFeedbackAt;
    final feedbackDateStr = feedbackAt != null
        ? '${feedbackAt.day}/${feedbackAt.month}/${feedbackAt.year}'
        : '—';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => PatientProfileScreen(patient: item.patient),
              ),
            )
            .then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: isNetworkImage
                    ? Image.network(
                        a.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : Image.file(
                        File(a.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.patient.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2B3A),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        feedbackDateStr,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (a.supervisorCorrectedType != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _typeChip(
                            label: 'Corrected: Type ${a.clinicianCorrectedType ?? '—'}',
                            bg: kBgLifted,
                            fg: kPrimary,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.grey),
                          ),
                          _typeChip(
                            label: 'Supervisor: Type ${a.supervisorCorrectedType}',
                            bg: kPurple600.withValues(alpha: 0.10),
                            fg: kPurple600,
                          ),
                        ],
                      ),
                    ),
                  if (a.supervisorFeedback != null &&
                      a.supervisorFeedback!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kWarningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kWarning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.feedback_outlined,
                              size: 14, color: kWarning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a.supervisorFeedback!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A4A00),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Widget _typeChip({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 52,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 80, color: kSuccess),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No assessments need your attention\nright now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackItem {
  final WoundAssessment assessment;
  final Patient patient;

  _FeedbackItem({required this.assessment, required this.patient});
}
