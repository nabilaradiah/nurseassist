import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// A single chronic condition on a patient's record, with its own onset
/// date so duration can be tracked per-condition rather than as one shared
/// value across every condition a patient has.
class ChronicCondition {
  final String id;
  final String name;

  /// Normalized to the 1st of the diagnosed month. Null when unknown
  /// (e.g. migrated from a legacy free-text record).
  final DateTime? diagnosedDate;

  /// True when [diagnosedDate] was set via the quick-range fallback
  /// (an estimated midpoint) rather than an exact month/year pick.
  final bool isApproximate;

  const ChronicCondition({
    required this.id,
    required this.name,
    this.diagnosedDate,
    this.isApproximate = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'diagnosedDate': diagnosedDate?.toIso8601String(),
      'isApproximate': isApproximate,
    };
  }

  factory ChronicCondition.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateValue = json['diagnosedDate'];
    if (dateValue is String && dateValue.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateValue);
    } else if (dateValue != null) {
      try {
        parsedDate = (dateValue as dynamic).toDate();
      } catch (_) {
        parsedDate = null;
      }
    }

    return ChronicCondition(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? '',
      diagnosedDate: parsedDate,
      isApproximate: json['isApproximate'] ?? false,
    );
  }

  /// "Mar 2019", or "—" when the diagnosis date is unknown.
  String get diagnosedLabel {
    if (diagnosedDate == null) return '—';
    return DateFormat('MMM yyyy').format(diagnosedDate!);
  }

  /// "6 yrs 5 mo", "~3 yrs" when approximate, or "Duration unknown".
  String durationLabel({DateTime? asOf}) {
    if (diagnosedDate == null) return 'Duration unknown';

    final now = asOf ?? DateTime.now();
    var totalMonths =
        (now.year - diagnosedDate!.year) * 12 + (now.month - diagnosedDate!.month);
    if (totalMonths < 0) totalMonths = 0;

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;

    String label;
    if (years == 0 && months == 0) {
      label = '< 1 mo';
    } else if (years == 0) {
      label = '$months mo';
    } else if (months == 0) {
      label = '$years yr${years == 1 ? '' : 's'}';
    } else {
      label = '$years yr${years == 1 ? '' : 's'} $months mo';
    }

    return isApproximate ? '~$label' : label;
  }

  /// Splits a legacy comma-separated free-text value (the old
  /// `chronicDiseases` string field) into individual conditions with
  /// unknown diagnosis dates, so old records still load correctly.
  static List<ChronicCondition> listFromLegacyString(String? legacy) {
    if (legacy == null || legacy.trim().isEmpty) return const [];
    return legacy
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((name) => ChronicCondition(id: const Uuid().v4(), name: name))
        .toList();
  }
}
