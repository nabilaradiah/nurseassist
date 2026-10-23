import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/wound_assessment.dart';
import '../models/wound_types_database.dart';
import '../widgets/vital_signs.dart';

class LecturerApprovalScreen extends StatefulWidget {
  /// Database access. Defaults to the real Firestore service; tests pass
  /// a fake so screens can be exercised without Firebase.
  final FirestoreService? firestoreService;

  const LecturerApprovalScreen({super.key, this.firestoreService});

  @override
  State<LecturerApprovalScreen> createState() =>
      _LecturerApprovalScreenState();
}

class _LecturerApprovalScreenState extends State<LecturerApprovalScreen> {
  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();

  List<WoundAssessment> _assessments = [];
  bool _isLoading = true;
  final Set<String> _approving = {};
  final Set<String> _rejecting = {};

  // ── Reassign type / feedback (per-card, collapsed by default) ───────────
  final Set<String> _expanded = {};
  final Map<String, int?> _typeOverride = {};
  final Map<String, TextEditingController> _feedbackControllers = {};

  TextEditingController _feedbackControllerFor(String assessmentId) {
    return _feedbackControllers.putIfAbsent(
        assessmentId, () => TextEditingController());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.getPendingApprovalAssessments();
      // Nurse-vs-AI disagreements need a lecturer decision, so list them first
      list.sort((a, b) {
        final byDisagreement = (b.timeDisagreesWithAi ? 1 : 0)
            .compareTo(a.timeDisagreesWithAi ? 1 : 0);
        if (byDisagreement != 0) return byDisagreement;
        return (b.correctedAt ?? b.assessmentDate)
            .compareTo(a.correctedAt ?? a.assessmentDate);
      });
      if (mounted) {
        setState(() {
          _assessments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(WoundAssessment assessment) async {
    setState(() => _approving.add(assessment.id));
    try {
      final staffId = AuthService().loggedInStaff?.staffId ?? 'unknown';
      final feedback = _feedbackControllers[assessment.id]?.text.trim();
      await _firestoreService.approveForTraining(
        assessmentId: assessment.id,
        approvedBy: staffId,
        supervisorCorrectedType: _typeOverride[assessment.id],
        supervisorFeedback: (feedback == null || feedback.isEmpty) ? null : feedback,
      );
      if (mounted) {
        setState(() {
          _assessments.removeWhere((a) => a.id == assessment.id);
          _approving.remove(assessment.id);
          _expanded.remove(assessment.id);
          _typeOverride.remove(assessment.id);
          _feedbackControllers.remove(assessment.id)?.dispose();
        });
        showSuccessSnack(context, 'Approved for model training.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _approving.remove(assessment.id));
        showErrorSnack(
          context,
          'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _reject(WoundAssessment assessment) async {
    final feedback = _feedbackControllers[assessment.id]?.text.trim() ?? '';
    if (feedback.isEmpty) {
      setState(() => _expanded.add(assessment.id));
      showErrorSnack(context, 'Add feedback for the nurse before rejecting.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reject Image?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This image will be removed from the training queue and will not be used to improve the model.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _rejecting.add(assessment.id));
    try {
      final staffId = AuthService().loggedInStaff?.staffId ?? 'unknown';
      await _firestoreService.rejectFromTraining(
        assessmentId: assessment.id,
        rejectedBy: staffId,
        supervisorFeedback: feedback,
        supervisorCorrectedType: _typeOverride[assessment.id],
      );
      if (mounted) {
        setState(() {
          _assessments.removeWhere((a) => a.id == assessment.id);
          _rejecting.remove(assessment.id);
          _expanded.remove(assessment.id);
          _typeOverride.remove(assessment.id);
          _feedbackControllers.remove(assessment.id)?.dispose();
        });
        showWarningSnack(context, 'Image removed from training queue.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rejecting.remove(assessment.id));
        showErrorSnack(
          context,
          'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        );
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
          'Pending Approvals',
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
          // Lecturer role badge + count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPurple600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kPurple600.withValues(alpha: 0.30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 13, color: kPurple600),
                      SizedBox(width: 5),
                      Text(
                        'Lecturer Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kPurple600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading) ...[
                  const Spacer(),
                  Text(
                    '${_assessments.length} wound${_assessments.length == 1 ? '' : 's'} awaiting review',
                    style: const TextStyle(fontSize: 12, color: kMuted1),
                  ),
                ],
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _assessments.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _assessments.length,
                          itemBuilder: (_, i) => _buildCard(_assessments[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── assessment card ────────────────────────────────────────────────────────

  Widget _buildCard(WoundAssessment a) {
    final correctedAt = a.correctedAt;
    final correctedDateStr = correctedAt != null
        ? '${correctedAt.day}/${correctedAt.month}/${correctedAt.year}'
        : '—';
    final assessedDateStr =
        '${a.assessmentDate.day}/${a.assessmentDate.month}/${a.assessmentDate.year}';

    final aiType = a.modelPredictedType ?? a.analysisResult?.woundType;
    final clinType = a.clinicianCorrectedType;
    final isSameType =
        aiType != null && clinType != null && aiType == clinType;

    final isApproving = _approving.contains(a.id);
    final isRejecting = _rejecting.contains(a.id);
    final isBusy = isApproving || isRejecting;

    final confidencePct = a.modelConfidence != null
        ? '${(a.modelConfidence! * 100).toStringAsFixed(0)}%'
        : (a.analysisResult?.confidenceScore != null
            ? '${(a.analysisResult!.confidenceScore * 100).toStringAsFixed(0)}%'
            : null);

    return Container(
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
          // ── Wound image ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _openFullImage(a),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Hero(
                  tag: 'assessment-image-${a.id}',
                  child: _woundImage(a, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Patient ID + assessment date ───────────────────────
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Patient ID: ${a.patientId}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text(
                      assessedDateStr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── AI prediction vs Clinician correction ──────────────
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  children: [
                    _typeChip(
                      label: confidencePct != null
                          ? 'AI: Type ${aiType ?? '—'}  ($confidencePct)'
                          : 'AI: Type ${aiType ?? '—'}',
                      bg: kBgLifted,
                      fg: kPrimary,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: Colors.grey),
                    ),
                    _typeChip(
                      label: a.timeAssessment?.woundType != null
                          ? 'Nurse TIME: Type ${clinType ?? '—'}'
                          : 'Corrected: Type ${clinType ?? '—'}',
                      bg: isSameType ? kSevMildBg : kSevModerateBg,
                      fg: isSameType ? kSevMild : kSevModerate,
                    ),
                    if (_typeOverride[a.id] != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 16, color: Colors.grey),
                      ),
                      _typeChip(
                        label: 'Supervisor: Type ${_typeOverride[a.id]}',
                        bg: kPurple600.withValues(alpha: 0.10),
                        fg: kPurple600,
                      ),
                    ],
                  ],
                ),

                if (isSameType) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 13, color: kSuccess),
                      SizedBox(width: 4),
                      Text(
                        'Clinician confirmed the AI result',
                        style: TextStyle(
                            fontSize: 11, color: kSuccess),
                      ),
                    ],
                  ),
                ],

                // ── Nurse TIME breakdown + where it differs from the AI ─
                if (a.timeAssessment?.factors != null) ...[
                  const SizedBox(height: 10),
                  _timeBreakdown(a),
                ],

                // ── Vital signs taken for this assessment ──────────────
                if (a.vitals != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Vitals · ${formatVitalsTimestamp(a.vitals!.takenAt)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  VitalTiles(reading: a.vitals!, compact: true),
                ],

                const SizedBox(height: 10),

                // ── Corrected by + date ────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'By ${a.correctedBy ?? 'unknown'}  •  $correctedDateStr',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),

                // ── Nurse notes ────────────────────────────────────────
                if (a.additionalNotes != null &&
                    a.additionalNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a.additionalNotes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // ── Reassign type / feedback toggle ─────────────────────
                InkWell(
                  onTap: () => setState(() {
                    if (_expanded.contains(a.id)) {
                      _expanded.remove(a.id);
                    } else {
                      _expanded.add(a.id);
                    }
                  }),
                  child: Row(
                    children: [
                      Icon(
                        _expanded.contains(a.id)
                            ? Icons.expand_less_rounded
                            : Icons.rate_review_outlined,
                        size: 16,
                        color: kPurple600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expanded.contains(a.id)
                            ? 'Hide reassign / feedback'
                            : 'Reassign type / Add feedback',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPurple600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_expanded.contains(a.id)) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Reassign wound type (optional)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _typeOverride[a.id],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No change — keep Type ${clinType ?? '—'}'),
                      ),
                      ...List.generate(
                        8,
                        (i) => DropdownMenuItem<int?>(
                          value: i + 1,
                          child: Text(
                              WoundTypesDatabase.getWoundTypeName(i + 1)),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _typeOverride[a.id] = val),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Feedback for nurse',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _feedbackControllerFor(a.id),
                    maxLines: 3,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Add a comment for the nurse (required to reject)',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Reject / Approve buttons ───────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : () => _reject(a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kDanger,
                          disabledForegroundColor: kDanger.withValues(alpha: 0.4),
                          side: BorderSide(
                            color: isBusy
                                ? kDanger.withValues(alpha: 0.25)
                                : kDanger.withValues(alpha: 0.55),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isRejecting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kDanger.withValues(alpha: 0.5),
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 16),
                        label: Text(
                          isRejecting ? 'Rejecting…' : 'Reject',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isBusy ? null : () => _approve(a),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccess,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: kSuccess.withValues(alpha: 0.4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: isApproving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                              ),
                        label: Text(
                          isApproving
                              ? 'Approving…'
                              : 'Approve for Training',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Widget _woundImage(WoundAssessment a, {required BoxFit fit}) {
    final bool isNetworkImage = a.imageUrl.startsWith('http');
    return isNetworkImage
        ? Image.network(
            a.imageUrl,
            fit: fit,
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          )
        : Image.file(
            File(a.imageUrl),
            fit: fit,
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          );
  }

  void _openFullImage(WoundAssessment a) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          heroTag: 'assessment-image-${a.id}',
          child: _woundImage(a, fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// The nurse's scored T/I/M findings side by side with what the AI's type
  /// implies, highlighting the factors they disagree on.
  Widget _timeBreakdown(WoundAssessment a) {
    final ta = a.timeAssessment!;
    final nurse = ta.factors!;
    final aiType = a.aiWoundType;
    final ai = aiType != null ? TimFactors.fromWoundType(aiType) : null;
    final differences = a.timeDifferencesFromAi;

    Widget row(String letter, String nurseText, int score, String? aiText,
        bool differs) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Text(letter,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kPrimary)),
            ),
            Expanded(
              child: Text(
                '$nurseText  (+$score)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: differs ? FontWeight.w700 : FontWeight.w500,
                  color: differs ? kSevModerate : kInk2,
                ),
              ),
            ),
            if (aiText != null)
              Text(
                'AI: $aiText',
                style: TextStyle(
                  fontSize: 11,
                  color: differs ? kSevModerate : Colors.grey.shade500,
                ),
              ),
          ],
        ),
      );
    }

    String tissue(bool over25) => over25 ? 'Necrotic/slough >25%' : 'Necrotic/slough <25%';
    String infection(bool infected) => infected ? 'Infection' : 'No infection';
    String moisture(bool wet) => wet ? 'Moderate / wet' : 'Dry / minimal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: differences.isEmpty ? kBgLifted : kSevModerateBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('T', '${tissue(nurse.over25)} (${ta.necroticSloughPct}%)',
              nurse.tissueScore, ai == null ? null : tissue(ai.over25),
              differences.contains('Tissue')),
          row('I', infection(nurse.infected), nurse.infectionScore,
              ai == null ? null : infection(ai.infected),
              differences.contains('Infection')),
          row('M', moisture(nurse.wet), nurse.moistureScore,
              ai == null ? null : moisture(ai.wet),
              differences.contains('Moisture')),
          if (differences.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.gavel_rounded, size: 13, color: kSevModerate),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Nurse and AI differ on ${differences.join(', ').toLowerCase()}. '
                    'Your decision is needed: approve the nurse\'s type or reassign.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSevModerate,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
              'No wound assessments are pending\nyour review right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── full-screen image viewer ──────────────────────────────────────────────────

class _FullScreenImageViewer extends StatelessWidget {
  final String heroTag;
  final Widget child;

  const _FullScreenImageViewer({required this.heroTag, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
