import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vital_reading.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'dispose_with.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ENTRY
// ════════════════════════════════════════════════════════════════════════════

/// Holds the text controllers for one vital-signs entry, so the same fields
/// can sit in the registration form and in the "Record vitals" sheet.
class VitalInputs {
  final systolic = TextEditingController();
  final diastolic = TextEditingController();
  final heartRate = TextEditingController();
  final spo2 = TextEditingController();
  final temperature = TextEditingController();
  final rbs = TextEditingController();
  int? painScore;

  List<TextEditingController> get _all => [
    systolic,
    diastolic,
    heartRate,
    spo2,
    temperature,
    rbs,
  ];

  bool get isEmpty =>
      _all.every((c) => c.text.trim().isEmpty) && painScore == null;

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _double(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// A first problem to show the nurse, or null when everything entered is
  /// a plausible value. Blank fields are allowed.
  String? validate() {
    String? check(
      TextEditingController c,
      String label,
      VitalRange r, {
      bool decimal = false,
    }) {
      final t = c.text.trim();
      if (t.isEmpty) return null;
      final num? v = decimal ? _double(c) : _int(c);
      if (v == null) return '$label must be a number.';
      if (!r.isValid(v)) {
        return '$label should be between ${r.minValid} and ${r.maxValid}.';
      }
      return null;
    }

    final bpParts = [
      systolic,
      diastolic,
    ].where((c) => c.text.trim().isNotEmpty);
    if (bpParts.length == 1) {
      return 'Enter both systolic and diastolic blood pressure.';
    }
    return check(systolic, 'Systolic BP', VitalRanges.systolic) ??
        check(diastolic, 'Diastolic BP', VitalRanges.diastolic) ??
        check(heartRate, 'Heart rate', VitalRanges.heartRate) ??
        check(spo2, 'SpO₂', VitalRanges.spo2) ??
        check(
          temperature,
          'Temperature',
          VitalRanges.temperature,
          decimal: true,
        ) ??
        check(rbs, 'RBS', VitalRanges.rbs, decimal: true) ??
        (_int(systolic) != null &&
                _int(diastolic) != null &&
                _int(diastolic)! >= _int(systolic)!
            ? 'Diastolic BP should be lower than systolic.'
            : null);
  }

  /// Builds a reading stamped with the logged-in staff member and the
  /// current time. Call [validate] first.
  VitalReading toReading() {
    final staff = AuthService().loggedInStaff;
    return VitalReading(
      systolic: _int(systolic),
      diastolic: _int(diastolic),
      heartRate: _int(heartRate),
      spo2: _int(spo2),
      temperature: _double(temperature),
      rbs: _double(rbs),
      painScore: painScore,
      takenAt: DateTime.now(),
      takenBy: staff?.staffId,
      takenByName: staff?.name,
    );
  }

  /// A preview reading (no staff stamp) used to flag values as they're typed.
  VitalReading get preview => VitalReading(
    systolic: _int(systolic),
    diastolic: _int(diastolic),
    heartRate: _int(heartRate),
    spo2: _int(spo2),
    temperature: _double(temperature),
    rbs: _double(rbs),
    painScore: painScore,
    takenAt: DateTime.now(),
  );

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

/// Number fields for the six observations, with abnormal values flagged as
/// they are typed. Every field is optional.
class VitalSignsFields extends StatefulWidget {
  final VitalInputs inputs;
  const VitalSignsFields({super.key, required this.inputs});

  @override
  State<VitalSignsFields> createState() => _VitalSignsFieldsState();
}

class _VitalSignsFieldsState extends State<VitalSignsFields> {
  VitalInputs get _in => widget.inputs;

  @override
  Widget build(BuildContext context) {
    final preview = _in.preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BP spans the full width: systolic / diastolic
        _label(VitalSign.bp, 'Blood pressure', preview),
        Row(
          children: [
            Expanded(child: _field(_in.systolic, 'Systolic')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: TextStyle(fontSize: 18, color: kMuted3)),
            ),
            Expanded(child: _field(_in.diastolic, 'Diastolic')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(VitalSign.hr, 'Heart rate', preview),
                  _field(_in.heartRate, 'e.g. 80'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(VitalSign.spo2, 'SpO₂', preview),
                  _field(_in.spo2, 'e.g. 98'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(VitalSign.temp, 'Temperature', preview),
                  _field(_in.temperature, 'e.g. 37.0', decimal: true),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(VitalSign.rbs, 'RBS', preview),
                  _field(_in.rbs, 'e.g. 6.5', decimal: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label(VitalSign.pain, 'Pain score', preview),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(11, (score) {
            final selected = _in.painScore == score;
            return ChoiceChip(
              label: Text('$score'),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) =>
                  setState(() => _in.painScore = selected ? null : score),
              selectedColor: kPrimary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : kMuted1,
              ),
              side: BorderSide(color: selected ? kPrimary : kLine),
              visualDensity: VisualDensity.compact,
            );
          }),
        ),
        const SizedBox(height: 4),
        const Text(
          '0 = no pain, 10 = worst pain',
          style: TextStyle(fontSize: 11, color: kMuted3),
        ),
      ],
    );
  }

  /// Field label with its unit, plus a Low / High tag once a value is typed.
  Widget _label(VitalSign sign, String text, VitalReading preview) {
    final flag = preview.flagOf(sign);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$text (${sign.unit})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: kMuted1,
            ),
          ),
          if (flag != VitalFlag.normal) ...[
            const SizedBox(width: 6),
            VitalFlagTag(flag: flag),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted3, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: kBgInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

/// Opens a sheet to record a new set of vitals. Returns the reading, or null
/// if the nurse cancelled. Saving is left to the caller.
Future<VitalReading?> showRecordVitalsSheet(BuildContext context) async {
  final inputs = VitalInputs();
  String? error;

  final reading = await showModalBottomSheet<VitalReading>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Inputs are disposed once the sheet has fully closed
    builder: (ctx) => DisposeWith(
      onDispose: inputs.dispose,
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Record Vital Signs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kInk2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kMuted3),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved with today\'s date and time. Leave blank anything you didn\'t measure.',
                    style: TextStyle(fontSize: 12, color: kMuted1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VitalSignsFields(inputs: inputs),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: kDanger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          final problem = inputs.isEmpty
                              ? 'Enter at least one vital sign.'
                              : inputs.validate();
                          if (problem != null) {
                            setSheet(() => error = problem);
                            return;
                          }
                          Navigator.of(ctx).pop(inputs.toReading());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Vital Signs',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return reading;
}

// ════════════════════════════════════════════════════════════════════════════
//  DISPLAY
// ════════════════════════════════════════════════════════════════════════════

/// "Just now", "45 min ago", "3 h ago", "2 days ago", or a date.
String formatVitalsAge(DateTime takenAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(takenAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7)
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${takenAt.day} ${months[takenAt.month - 1]} ${takenAt.year}';
}

/// "3 Oct 2026, 2:30 PM" — exact time a reading was taken.
String formatVitalsTimestamp(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.hour < 12 ? 'AM' : 'PM';
  return '${t.day} ${months[t.month - 1]} ${t.year}, $hour:$minute $period';
}

/// Readings older than this are shown as out of date.
const kVitalsStaleAfter = Duration(hours: 24);

/// Small "↑ High" / "↓ Low" tag. Normal values get no tag.
class VitalFlagTag extends StatelessWidget {
  final VitalFlag flag;
  const VitalFlagTag({super.key, required this.flag});

  @override
  Widget build(BuildContext context) {
    final high = flag == VitalFlag.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        high ? '↑ High' : '↓ Low',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kDanger,
        ),
      ),
    );
  }
}

/// Latest vitals with when they were taken. Values are neutral unless
/// outside the normal range, which shows red with ↑ / ↓.
class VitalSignsCard extends StatelessWidget {
  final List<VitalReading> readings; // oldest first
  final VoidCallback? onRecord;
  final bool compact;

  const VitalSignsCard({
    super.key,
    required this.readings,
    this.onRecord,
    this.compact = false,
  });

  VitalReading? get _latest => readings.isEmpty
      ? null
      : readings.reduce((a, b) => b.takenAt.isAfter(a.takenAt) ? b : a);

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final stale =
        latest != null &&
        DateTime.now().difference(latest.takenAt) > kVitalsStaleAfter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 18,
                color: kPrimary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Vital Signs',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kInk2,
                ),
              ),
              const Spacer(),
              if (readings.length > 1)
                TextButton(
                  onPressed: () => _showHistory(context),
                  style: TextButton.styleFrom(
                    foregroundColor: kMuted1,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('History', style: TextStyle(fontSize: 12)),
                ),
              if (onRecord != null)
                TextButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Record', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: kPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (latest == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No vital signs recorded yet.',
                style: TextStyle(fontSize: 13, color: kMuted1),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    stale ? Icons.history_rounded : Icons.schedule_rounded,
                    size: 13,
                    color: stale ? kWarning : kMuted3,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stale
                          ? 'Taken ${formatVitalsAge(latest.takenAt)} · may be out of date'
                          : 'Taken ${formatVitalsAge(latest.takenAt)}'
                                '${latest.takenByName != null ? ' by ${latest.takenByName}' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: stale ? kWarning : kMuted1,
                        fontWeight: stale ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            VitalTiles(reading: latest, compact: compact),
          ],
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final ordered = readings.reversed.toList(); // newest first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Vital Signs History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kInk2,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: ordered.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 20, color: kLine),
                itemBuilder: (_, i) {
                  final r = ordered[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatVitalsAge(r.takenAt)}'
                        '${r.takenByName != null ? ' · ${r.takenByName}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kMuted1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      VitalTiles(reading: r, compact: true),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tile per recorded observation; abnormal values in red with ↑ / ↓.
class VitalTiles extends StatelessWidget {
  final VitalReading reading;
  final bool compact;
  const VitalTiles({super.key, required this.reading, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final recorded = VitalSign.values
        .where((s) => reading.displayOf(s) != null)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recorded.map((s) {
        final flag = reading.flagOf(s);
        final abnormal = flag != VitalFlag.normal;
        final color = abnormal ? kDanger : kInk2;
        final arrow = flag == VitalFlag.high
            ? ' ↑'
            : flag == VitalFlag.low
            ? ' ↓'
            : '';
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: abnormal ? kDanger.withValues(alpha: 0.07) : kBgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: abnormal ? kDanger.withValues(alpha: 0.35) : kLine,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: abnormal ? kDanger : kMuted1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${reading.displayOf(s)}$arrow',
                    style: TextStyle(
                      fontSize: compact ? 13.5 : 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    s.unit,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: abnormal ? kDanger : kMuted3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
