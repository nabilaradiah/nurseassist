/// One set of vital signs taken at a specific time.
///
/// Vitals change every visit, so they are stored as a dated history on the
/// patient instead of a single value, and the UI always shows when the
/// latest reading was taken. Every field is optional — a nurse may record
/// only some observations.
class VitalReading {
  final int? systolic; // mmHg
  final int? diastolic; // mmHg
  final int? heartRate; // bpm
  final int? spo2; // %
  final double? temperature; // °C
  final double? rbs; // random blood sugar, mmol/L
  final int? painScore; // 0–10

  final DateTime takenAt;
  final String? takenBy; // staff ID
  final String? takenByName;

  const VitalReading({
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.spo2,
    this.temperature,
    this.rbs,
    this.painScore,
    required this.takenAt,
    this.takenBy,
    this.takenByName,
  });

  bool get isEmpty =>
      systolic == null &&
      diastolic == null &&
      heartRate == null &&
      spo2 == null &&
      temperature == null &&
      rbs == null &&
      painScore == null;

  bool get hasBloodPressure => systolic != null && diastolic != null;

  /// True when any recorded value is outside its normal range.
  bool get hasAbnormal => VitalSign.values.any((s) => flagOf(s) != VitalFlag.normal);

  /// The value for [sign], or null if it wasn't recorded. BP returns the
  /// systolic value; use [flagOf] for the combined BP flag.
  num? valueOf(VitalSign sign) => switch (sign) {
        VitalSign.bp => systolic,
        VitalSign.hr => heartRate,
        VitalSign.spo2 => spo2,
        VitalSign.temp => temperature,
        VitalSign.rbs => rbs,
        VitalSign.pain => painScore,
      };

  /// Display text for [sign] without its unit, e.g. "120/80" or "37.2".
  String? displayOf(VitalSign sign) {
    if (sign == VitalSign.bp) {
      return hasBloodPressure ? '$systolic/$diastolic' : null;
    }
    final v = valueOf(sign);
    if (v == null) return null;
    return v is double ? v.toStringAsFixed(1) : v.toString();
  }

  /// Whether [sign] is low, high or normal. Unrecorded values are normal.
  VitalFlag flagOf(VitalSign sign) {
    if (sign == VitalSign.bp) {
      if (!hasBloodPressure) return VitalFlag.normal;
      final s = VitalRanges.systolic.flag(systolic!);
      final d = VitalRanges.diastolic.flag(diastolic!);
      if (s == VitalFlag.high || d == VitalFlag.high) return VitalFlag.high;
      if (s == VitalFlag.low || d == VitalFlag.low) return VitalFlag.low;
      return VitalFlag.normal;
    }
    final v = valueOf(sign);
    return v == null ? VitalFlag.normal : sign.range.flag(v);
  }

  Map<String, dynamic> toJson() => {
        'systolic': systolic,
        'diastolic': diastolic,
        'heartRate': heartRate,
        'spo2': spo2,
        'temperature': temperature,
        'rbs': rbs,
        'painScore': painScore,
        'takenAt': takenAt.toIso8601String(),
        'takenBy': takenBy,
        'takenByName': takenByName,
      };

  factory VitalReading.fromJson(Map<String, dynamic> json) => VitalReading(
        systolic: (json['systolic'] as num?)?.toInt(),
        diastolic: (json['diastolic'] as num?)?.toInt(),
        heartRate: (json['heartRate'] as num?)?.toInt(),
        spo2: (json['spo2'] as num?)?.toInt(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        rbs: (json['rbs'] as num?)?.toDouble(),
        painScore: (json['painScore'] as num?)?.toInt(),
        takenAt: DateTime.parse(json['takenAt']),
        takenBy: json['takenBy'],
        takenByName: json['takenByName'],
      );
}

enum VitalFlag { low, normal, high }

/// The six observations from the nurse's feedback, in display order.
enum VitalSign {
  bp('BP', 'mmHg'),
  hr('HR', 'bpm'),
  spo2('SpO₂', '%'),
  temp('Temp', '°C'),
  rbs('RBS', 'mmol/L'),
  pain('Pain', '/10');

  final String label;
  final String unit;
  const VitalSign(this.label, this.unit);

  VitalRange get range => switch (this) {
        VitalSign.bp => VitalRanges.systolic,
        VitalSign.hr => VitalRanges.heartRate,
        VitalSign.spo2 => VitalRanges.spo2,
        VitalSign.temp => VitalRanges.temperature,
        VitalSign.rbs => VitalRanges.rbs,
        VitalSign.pain => VitalRanges.pain,
      };
}

/// Normal range plus the limits of a plausible entry (to catch typos).
class VitalRange {
  final num? lowBelow; // flagged low when value < lowBelow
  final num? highFrom; // flagged high when value >= highFrom
  final num minValid;
  final num maxValid;

  const VitalRange({
    this.lowBelow,
    this.highFrom,
    required this.minValid,
    required this.maxValid,
  });

  VitalFlag flag(num v) {
    if (lowBelow != null && v < lowBelow!) return VitalFlag.low;
    if (highFrom != null && v >= highFrom!) return VitalFlag.high;
    return VitalFlag.normal;
  }

  bool isValid(num v) => v >= minValid && v <= maxValid;
}

/// Adult reference ranges used to flag readings.
///
/// These are common general-ward defaults and should be confirmed with the
/// nursing team (e.g. ward early-warning thresholds) before clinical use.
class VitalRanges {
  static const systolic = VitalRange(lowBelow: 90, highFrom: 140, minValid: 50, maxValid: 260);
  static const diastolic = VitalRange(lowBelow: 60, highFrom: 90, minValid: 20, maxValid: 160);
  static const heartRate = VitalRange(lowBelow: 60, highFrom: 101, minValid: 20, maxValid: 250);
  static const spo2 = VitalRange(lowBelow: 95, minValid: 50, maxValid: 100);
  static const temperature = VitalRange(lowBelow: 36.0, highFrom: 37.5, minValid: 30, maxValid: 45);
  static const rbs = VitalRange(lowBelow: 4.0, highFrom: 11.1, minValid: 1, maxValid: 40);
  static const pain = VitalRange(highFrom: 4, minValid: 0, maxValid: 10);
}
