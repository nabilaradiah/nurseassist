import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'vital_reading.dart';

/// Reads a date stored either as an ISO-8601 string (older records and
/// client-written fields) or as a Firestore server timestamp.
DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

/// Data models for wound assessments.
///
/// Key design rule: the original AI prediction is stored once and NEVER
/// overwritten.  Clinician corrections are stored alongside in separate
/// fields so the full model-vs-clinician history is preserved for retraining.
class WoundAssessment {
  final String id;
  final String patientId;
  final String imageUrl;
  final DateTime assessmentDate;
  final WoundAnalysisResult? analysisResult;
  final String? additionalNotes;
  final bool requiresSpecialistConfirmation;
  final bool? specialistConfirmed;

  // ── Original AI prediction (set once on creation, never mutated) ────────
  /// The wound type integer (1–8) the TFLite model originally predicted.
  /// Null only for legacy assessments created before this field existed.
  final int? modelPredictedType;

  /// Softmax confidence the model reported for [modelPredictedType].
  final double? modelConfidence;

  // ── Clinician correction (set by nurse / lecturer after reviewing) ───────
  /// The wound type integer the clinician believes is correct.
  /// Null until a clinician explicitly verifies or corrects the result.
  final int? clinicianCorrectedType;

  /// Display name matching [clinicianCorrectedType] (e.g. 'Type_3').
  final String? clinicianCorrectedName;

  /// Staff / user ID of whoever performed the correction.
  final String? correctedBy;

  /// Timestamp of the clinician correction.
  final DateTime? correctedAt;

  // ── ML training approval (set by Lecturer / Admin only) ─────────────────
  /// True once a Lecturer or Admin has approved this image+label pair for
  /// inclusion in the next model training run.
  final bool approvedForTraining;

  /// User ID of the Lecturer/Admin who approved the image.
  final String? approvedBy;

  /// Timestamp of training approval.
  final DateTime? approvedAt;

  // ── ML training rejection (set by Lecturer / Admin only) ─────────────────
  /// True if a Lecturer or Admin has rejected this image from the training
  /// queue (e.g. poor quality, wrong angle).
  final bool rejectedForTraining;

  /// User ID of whoever rejected the image.
  final String? rejectedBy;

  /// Timestamp of rejection.
  final DateTime? rejectedAt;

  // ── Supervisor type reassignment (set by Supervisor / Admin only) ───────
  /// Wound type the supervisor believes is correct, overriding
  /// [clinicianCorrectedType] for display/training purposes only.
  /// Never overwrites the clinician's own record.
  final int? supervisorCorrectedType;

  /// Display name matching [supervisorCorrectedType] (e.g. 'Type_3').
  final String? supervisorCorrectedName;

  // ── Supervisor feedback (set by Supervisor / Admin only) ─────────────────
  /// Free-text comment left by the supervisor for the nurse to read.
  final String? supervisorFeedback;

  /// Staff / user ID of the supervisor who left the feedback.
  final String? supervisorFeedbackBy;

  /// Timestamp of the supervisor feedback.
  final DateTime? supervisorFeedbackAt;

  /// True whenever a supervisor has left a comment and/or reassigned the
  /// type. Denormalized so the nurse's "needs attention" badge can be
  /// queried with two cheap equality filters.
  final bool hasSupervisorFeedback;

  // ── Nurse TIME(S) assessment ────────────────────────────────────────────
  /// What the nurse observed on this wound (Tissue, Infection, Moisture,
  /// Edges, Surrounding skin). Null until a nurse records it; until then the
  /// AI's [WoundAnalysisResult.characteristics] are shown as suggestions only.
  final TimeAssessment? timeAssessment;

  /// Vital signs taken for this assessment (also kept in the patient's
  /// vitals history). Null until the nurse records or links a reading.
  final VitalReading? vitals;

  WoundAssessment({
    required this.id,
    required this.patientId,
    required this.imageUrl,
    required this.assessmentDate,
    this.analysisResult,
    this.additionalNotes,
    this.requiresSpecialistConfirmation = false,
    this.specialistConfirmed,
    // AI prediction snapshot
    this.modelPredictedType,
    this.modelConfidence,
    // Clinician correction
    this.clinicianCorrectedType,
    this.clinicianCorrectedName,
    this.correctedBy,
    this.correctedAt,
    // Training approval
    this.approvedForTraining = false,
    this.approvedBy,
    this.approvedAt,
    // Training rejection
    this.rejectedForTraining = false,
    this.rejectedBy,
    this.rejectedAt,
    // Supervisor type reassignment
    this.supervisorCorrectedType,
    this.supervisorCorrectedName,
    // Supervisor feedback
    this.supervisorFeedback,
    this.supervisorFeedbackBy,
    this.supervisorFeedbackAt,
    this.hasSupervisorFeedback = false,
    // Nurse TIME(S) assessment
    this.timeAssessment,
    this.vitals,
  });

  /// Returns the wound type to display in the UI.
  /// Prefers the supervisor reassignment, then the clinician correction.
  /// Null when there is no type yet (see [hasWoundType]) — never a guess.
  int? get displayWoundType =>
      supervisorCorrectedType ??
      clinicianCorrectedType ??
      analysisResult?.woundType;

  /// Returns the wound type name to display, or null when there is no type.
  String? get displayWoundName =>
      supervisorCorrectedName ??
      clinicianCorrectedName ??
      analysisResult?.woundName;

  /// True once the wound has a type from the lecturer, the nurse's TIME
  /// assessment or the AI. False only when the AI was unavailable and no
  /// TIME assessment has been recorded yet.
  bool get hasWoundType =>
      supervisorCorrectedType != null ||
      clinicianCorrectedType != null ||
      analysisResult != null;

  /// True when a clinician has reviewed and submitted a correction.
  bool get isClinicianVerified => clinicianCorrectedType != null;

  /// True when the clinician agreed with the model (no change needed).
  bool get modelWasCorrect =>
      isClinicianVerified &&
      clinicianCorrectedType == modelPredictedType;

  /// The type the AI originally predicted (immutable snapshot first).
  int? get aiWoundType => modelPredictedType ?? analysisResult?.woundType;

  /// TIME factors on which the nurse's assessment differs from the AI's
  /// predicted type, e.g. ['Infection']. Empty when they agree or when
  /// either side is missing.
  List<String> get timeDifferencesFromAi {
    final nurse = timeAssessment?.factors;
    final ai = aiWoundType;
    if (nurse == null || ai == null) return const [];
    return nurse.differencesFrom(TimFactors.fromWoundType(ai));
  }

  /// True when the nurse's TIME-derived type differs from the AI's type,
  /// which sends the assessment to a lecturer for a decision.
  bool get timeDisagreesWithAi => timeDifferencesFromAi.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'imageUrl': imageUrl,
      'assessmentDate': assessmentDate.toIso8601String(),
      'analysisResult': analysisResult?.toJson(),
      'additionalNotes': additionalNotes,
      'requiresSpecialistConfirmation': requiresSpecialistConfirmation,
      'specialistConfirmed': specialistConfirmed,
      // AI snapshot
      'modelPredictedType': modelPredictedType,
      'modelConfidence': modelConfidence,
      // Clinician correction
      'clinicianCorrectedType': clinicianCorrectedType,
      'clinicianCorrectedName': clinicianCorrectedName,
      'correctedBy': correctedBy,
      'correctedAt': correctedAt?.toIso8601String(),
      // Training approval
      'approvedForTraining': approvedForTraining,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      // Training rejection
      'rejectedForTraining': rejectedForTraining,
      'rejectedBy': rejectedBy,
      'rejectedAt': rejectedAt?.toIso8601String(),
      // Supervisor type reassignment
      'supervisorCorrectedType': supervisorCorrectedType,
      'supervisorCorrectedName': supervisorCorrectedName,
      // Supervisor feedback
      'supervisorFeedback': supervisorFeedback,
      'supervisorFeedbackBy': supervisorFeedbackBy,
      'supervisorFeedbackAt': supervisorFeedbackAt?.toIso8601String(),
      'hasSupervisorFeedback': hasSupervisorFeedback,
      // Nurse TIME(S) assessment
      'timeAssessment': timeAssessment?.toJson(),
      'vitals': vitals?.toJson(),
    };
  }

  factory WoundAssessment.fromJson(Map<String, dynamic> json) {
    return WoundAssessment(
      id: json['id'],
      patientId: json['patientId'],
      imageUrl: json['imageUrl'],
      assessmentDate: _parseDate(json['assessmentDate'])!,
      analysisResult: json['analysisResult'] != null
          ? WoundAnalysisResult.fromJson(json['analysisResult'])
          : null,
      additionalNotes: json['additionalNotes'],
      requiresSpecialistConfirmation:
          json['requiresSpecialistConfirmation'] ?? false,
      specialistConfirmed: json['specialistConfirmed'],
      // AI snapshot — null-safe for legacy documents
      modelPredictedType: json['modelPredictedType'],
      modelConfidence: (json['modelConfidence'] as num?)?.toDouble(),
      // Clinician correction
      clinicianCorrectedType: json['clinicianCorrectedType'],
      clinicianCorrectedName: json['clinicianCorrectedName'],
      correctedBy: json['correctedBy'],
      correctedAt: _parseDate(json['correctedAt']),
      // Training approval
      approvedForTraining: json['approvedForTraining'] ?? false,
      approvedBy: json['approvedBy'],
      approvedAt: _parseDate(json['approvedAt']),
      // Training rejection
      rejectedForTraining: json['rejectedForTraining'] ?? false,
      rejectedBy: json['rejectedBy'],
      rejectedAt: _parseDate(json['rejectedAt']),
      // Supervisor type reassignment
      supervisorCorrectedType: json['supervisorCorrectedType'],
      supervisorCorrectedName: json['supervisorCorrectedName'],
      // Supervisor feedback
      supervisorFeedback: json['supervisorFeedback'],
      supervisorFeedbackBy: json['supervisorFeedbackBy'],
      supervisorFeedbackAt: _parseDate(json['supervisorFeedbackAt']),
      hasSupervisorFeedback: json['hasSupervisorFeedback'] ?? false,
      // Nurse TIME(S) assessment — absent on legacy documents
      timeAssessment: json['timeAssessment'] != null
          ? TimeAssessment.fromJson(
              Map<String, dynamic>.from(json['timeAssessment']))
          : null,
      vitals: json['vitals'] != null
          ? VitalReading.fromJson(Map<String, dynamic>.from(json['vitals']))
          : null,
    );
  }

  WoundAssessment copyWith({
    String? additionalNotes,
    bool? specialistConfirmed,
    WoundAnalysisResult? analysisResult,
    int? clinicianCorrectedType,
    String? clinicianCorrectedName,
    String? correctedBy,
    DateTime? correctedAt,
    bool? approvedForTraining,
    String? approvedBy,
    DateTime? approvedAt,
    bool? rejectedForTraining,
    String? rejectedBy,
    DateTime? rejectedAt,
    int? supervisorCorrectedType,
    String? supervisorCorrectedName,
    String? supervisorFeedback,
    String? supervisorFeedbackBy,
    DateTime? supervisorFeedbackAt,
    bool? hasSupervisorFeedback,
    TimeAssessment? timeAssessment,
    VitalReading? vitals,
  }) {
    return WoundAssessment(
      id: id,
      patientId: patientId,
      imageUrl: imageUrl,
      assessmentDate: assessmentDate,
      analysisResult: analysisResult ?? this.analysisResult,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      requiresSpecialistConfirmation: requiresSpecialistConfirmation,
      specialistConfirmed: specialistConfirmed ?? this.specialistConfirmed,
      // AI snapshot is immutable — always carry original values through
      modelPredictedType: modelPredictedType,
      modelConfidence: modelConfidence,
      // Clinician correction
      clinicianCorrectedType:
          clinicianCorrectedType ?? this.clinicianCorrectedType,
      clinicianCorrectedName:
          clinicianCorrectedName ?? this.clinicianCorrectedName,
      correctedBy: correctedBy ?? this.correctedBy,
      correctedAt: correctedAt ?? this.correctedAt,
      // Training approval
      approvedForTraining: approvedForTraining ?? this.approvedForTraining,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      // Training rejection
      rejectedForTraining: rejectedForTraining ?? this.rejectedForTraining,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      // Supervisor type reassignment
      supervisorCorrectedType:
          supervisorCorrectedType ?? this.supervisorCorrectedType,
      supervisorCorrectedName:
          supervisorCorrectedName ?? this.supervisorCorrectedName,
      // Supervisor feedback
      supervisorFeedback: supervisorFeedback ?? this.supervisorFeedback,
      supervisorFeedbackBy: supervisorFeedbackBy ?? this.supervisorFeedbackBy,
      supervisorFeedbackAt: supervisorFeedbackAt ?? this.supervisorFeedbackAt,
      hasSupervisorFeedback:
          hasSupervisorFeedback ?? this.hasSupervisorFeedback,
      // Nurse TIME(S) assessment
      timeAssessment: timeAssessment ?? this.timeAssessment,
      vitals: vitals ?? this.vitals,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

/// The three scored TIME factors that define a wound type in the Wound Care
/// Quick Reference algorithm. Edges and surrounding skin are not scored.
class TimFactors {
  /// Necrotic tissue / slough over 25% of the wound bed (T score 4, else 0).
  final bool over25;

  /// Signs of infection present (I score 2, else 0).
  final bool infected;

  /// Moderate / wet exudate (M score 2); dry / minimal scores 1.
  final bool wet;

  const TimFactors({
    required this.over25,
    required this.infected,
    required this.wet,
  });

  int get tissueScore => over25 ? 4 : 0;
  int get infectionScore => infected ? 2 : 0;
  int get moistureScore => wet ? 2 : 1;

  /// Total wound score, which is also the wound type (1–8).
  int get woundType => tissueScore + infectionScore + moistureScore;

  /// Inverse of [woundType]: Types 5–8 are over 25%, Types 3, 4, 7, 8 are
  /// infected, even types are wet.
  factory TimFactors.fromWoundType(int type) {
    final t = type.clamp(1, 8);
    return TimFactors(
      over25: t >= 5,
      infected: const {3, 4, 7, 8}.contains(t),
      wet: t.isEven,
    );
  }

  /// Names of the factors that differ from [other], e.g. ['Infection'].
  List<String> differencesFrom(TimFactors other) => [
        if (over25 != other.over25) 'Tissue',
        if (infected != other.infected) 'Infection',
        if (wet != other.wet) 'Moisture',
      ];
}

/// Per-factor probabilities derived from the model's 8 class probabilities
/// (index 0 = Type 1 … index 7 = Type 8), so the UI can say which factor the
/// AI is unsure about.
class TimProbabilities {
  final double over25;
  final double infected;
  final double wet;

  const TimProbabilities(this.over25, this.infected, this.wet);

  /// Returns null unless all 8 class probabilities are available.
  static TimProbabilities? fromClassProbabilities(List<double>? probs) {
    if (probs == null || probs.length < 8) return null;
    double sumOf(List<int> types) =>
        types.fold(0.0, (sum, t) => sum + probs[t - 1]);
    return TimProbabilities(
      sumOf([5, 6, 7, 8]),
      sumOf([3, 4, 7, 8]),
      sumOf([2, 4, 6, 8]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

/// Nurse-recorded wound assessment in TIME(S) order, matching the HKL ward
/// wound assessment chart: Tissue, Infection/Inflammation, Moisture, Edges
/// and Surrounding skin. Every value is what the nurse saw on this wound on
/// this day — never copied from the AI or the wound-type reference table.
///
/// T, I and M are scored with the Wound Care Quick Reference algorithm to
/// give the wound type (see [factors] and [woundType]).
class TimeAssessment {
  // ── T — Tissue: % of wound bed (0–100), null when not recorded ──────────
  final int? necroticPct;
  final int? sloughPct;
  final int? granulationPct;
  final int? epithelialPct;

  /// Whether necrotic tissue + slough is over 25%. Derived from the
  /// percentages, except at exactly 25% where the nurse is asked to decide.
  final bool? necroticSloughOver25;

  // ── I — Infection / Inflammation ────────────────────────────────────────
  final String? infection; // one of [infectionOptions]
  final String? inflammation; // one of [inflammationOptions]

  // ── M — Moisture ────────────────────────────────────────────────────────
  final String? moisture; // one of [moistureOptions]
  /// Optional detail for a wet wound; does not change the score.
  final bool heavyExudate;

  // ── E — Edges ───────────────────────────────────────────────────────────
  final String? edges; // one of [edgeOptions]
  /// Free text for undermining/tunnelling, e.g. "12–3 o'clock, 2 cm".
  final String? edgeDetails;

  // ── S — Surrounding skin ────────────────────────────────────────────────
  final List<String> surroundingSkin; // any of [surroundingSkinOptions]
  final String? surroundingSkinNotes;

  // ── Who recorded it ─────────────────────────────────────────────────────
  final String? assessedBy; // staff ID
  final String? assessedByName;
  final DateTime? assessedAt;

  static const infectionOptions = ['Nil', 'Local signs', 'Spreading / systemic'];
  static const inflammationOptions = ['Nil', 'Present'];
  static const moistureDry = 'Dry / minimal';
  static const moistureWet = 'Moderate / wet';
  static const moistureOptions = [moistureDry, moistureWet];
  static const edgeOptions = [
    'Attached',
    'Not attached',
    'Rolled / epibole',
    'Undermining',
  ];
  static const surroundingSkinOptions = [
    'Intact',
    'Erythema',
    'Maceration',
    'Dry / desiccation',
    'Oedema',
    'Induration',
    'Excoriation',
  ];

  const TimeAssessment({
    this.necroticPct,
    this.sloughPct,
    this.granulationPct,
    this.epithelialPct,
    this.necroticSloughOver25,
    this.infection,
    this.inflammation,
    this.moisture,
    this.heavyExudate = false,
    this.edges,
    this.edgeDetails,
    this.surroundingSkin = const [],
    this.surroundingSkinNotes,
    this.assessedBy,
    this.assessedByName,
    this.assessedAt,
  });

  /// Sum of the recorded tissue percentages (unrecorded ones count as 0).
  int get tissueTotal =>
      (necroticPct ?? 0) +
      (sloughPct ?? 0) +
      (granulationPct ?? 0) +
      (epithelialPct ?? 0);

  /// Necrotic tissue + slough, the figure the T score is based on.
  int get necroticSloughPct => (necroticPct ?? 0) + (sloughPct ?? 0);

  bool get hasTissue =>
      necroticPct != null ||
      sloughPct != null ||
      granulationPct != null ||
      epithelialPct != null;

  /// The scored T/I/M factors, or null until all three are recorded.
  TimFactors? get factors {
    final over25 = necroticSloughOver25;
    if (over25 == null || infection == null || moisture == null) return null;
    return TimFactors(
      over25: over25,
      infected: infection != 'Nil',
      wet: moisture == moistureWet,
    );
  }

  /// Wound type (1–8) from the T + I + M score, or null if incomplete.
  int? get woundType => factors?.woundType;

  /// "Jane Tan (WRN-001)", falling back to whichever part is known.
  String get assessedByDisplay {
    if (assessedByName != null && assessedByName!.isNotEmpty) {
      return assessedBy != null
          ? '$assessedByName ($assessedBy)'
          : assessedByName!;
    }
    return assessedBy ?? 'nurse';
  }

  Map<String, dynamic> toJson() => {
        'necroticPct': necroticPct,
        'sloughPct': sloughPct,
        'granulationPct': granulationPct,
        'epithelialPct': epithelialPct,
        'necroticSloughOver25': necroticSloughOver25,
        'infection': infection,
        'inflammation': inflammation,
        'moisture': moisture,
        'heavyExudate': heavyExudate,
        'edges': edges,
        'edgeDetails': edgeDetails,
        'surroundingSkin': surroundingSkin,
        'surroundingSkinNotes': surroundingSkinNotes,
        'assessedBy': assessedBy,
        'assessedByName': assessedByName,
        'assessedAt': assessedAt?.toIso8601String(),
        // Stored for querying/reporting; always recomputed from the factors
        'woundType': woundType,
      };

  factory TimeAssessment.fromJson(Map<String, dynamic> json) {
    final necrotic = (json['necroticPct'] as num?)?.toInt();
    final slough = (json['sloughPct'] as num?)?.toInt();

    // Older records didn't store the over-25% answer; derive it when the
    // percentages make it unambiguous.
    bool? over25 = json['necroticSloughOver25'] as bool?;
    if (over25 == null && (necrotic != null || slough != null)) {
      final sum = (necrotic ?? 0) + (slough ?? 0);
      if (sum != 25) over25 = sum > 25;
    }

    // Older records used Dry / Moist / Wet plus a separate exudate amount.
    String? moisture = json['moisture'];
    final exudate = json['exudateAmount'] as String?;
    if (moisture != null && !moistureOptions.contains(moisture)) {
      final wet = moisture == 'Wet' ||
          (moisture == 'Moist' &&
              (exudate == 'Moderate' || exudate == 'Heavy'));
      moisture = wet ? moistureWet : moistureDry;
    }

    return TimeAssessment(
      necroticPct: necrotic,
      sloughPct: slough,
      granulationPct: (json['granulationPct'] as num?)?.toInt(),
      epithelialPct: (json['epithelialPct'] as num?)?.toInt(),
      necroticSloughOver25: over25,
      infection: json['infection'],
      inflammation: json['inflammation'],
      moisture: moisture,
      heavyExudate: json['heavyExudate'] ?? exudate == 'Heavy',
      edges: json['edges'],
      edgeDetails: json['edgeDetails'],
      surroundingSkin: json['surroundingSkin'] != null
          ? List<String>.from(json['surroundingSkin'])
          : const [],
      surroundingSkinNotes: json['surroundingSkinNotes'],
      assessedBy: json['assessedBy'],
      assessedByName: json['assessedByName'],
      assessedAt: json['assessedAt'] != null
          ? DateTime.parse(json['assessedAt'])
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class WoundAnalysisResult {
  final double confidenceScore;
  final int woundType; // 1-8
  final String woundName;
  final String severity;
  final double? estimatedSize; // in cm², null until nurse measures and enters it
  final WoundCharacteristics characteristics;
  final WoundManagement management;
  final String? segmentationMapUrl;

  /// Softmax probabilities for all 8 types from the TFLite model.
  /// Index 0 = Type_1 … index 7 = Type_8.
  /// Null when the cloud or mock backend was used.
  final List<double>? allClassProbabilities;

  WoundAnalysisResult({
    required this.confidenceScore,
    required this.woundType,
    required this.woundName,
    required this.severity,
    this.estimatedSize,
    required this.characteristics,
    required this.management,
    this.segmentationMapUrl,
    this.allClassProbabilities,
  });

  Map<String, dynamic> toJson() {
    return {
      'confidenceScore': confidenceScore,
      'woundType': woundType,
      'woundName': woundName,
      'severity': severity,
      'estimatedSize': estimatedSize,
      'characteristics': characteristics.toJson(),
      'management': management.toJson(),
      'segmentationMapUrl': segmentationMapUrl,
      'allClassProbabilities': allClassProbabilities,
    };
  }

  factory WoundAnalysisResult.fromJson(Map<String, dynamic> json) {
    return WoundAnalysisResult(
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      woundType: json['woundType'],
      woundName: json['woundName'],
      severity: json['severity'],
      estimatedSize: (json['estimatedSize'] as num?)?.toDouble(),
      characteristics:
          WoundCharacteristics.fromJson(json['characteristics']),
      management: WoundManagement.fromJson(json['management']),
      segmentationMapUrl: json['segmentationMapUrl'],
      allClassProbabilities: json['allClassProbabilities'] != null
          ? List<double>.from(
              (json['allClassProbabilities'] as List)
                  .map((e) => (e as num).toDouble()))
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class WoundCharacteristics {
  final String necroticTissue;
  final String infection;
  final String exudateLevel;
  final List<String> tissueClassification;

  WoundCharacteristics({
    required this.necroticTissue,
    required this.infection,
    required this.exudateLevel,
    required this.tissueClassification,
  });

  Map<String, dynamic> toJson() => {
        'necroticTissue': necroticTissue,
        'infection': infection,
        'exudateLevel': exudateLevel,
        'tissueClassification': tissueClassification,
      };

  factory WoundCharacteristics.fromJson(Map<String, dynamic> json) =>
      WoundCharacteristics(
        necroticTissue: json['necroticTissue'],
        infection: json['infection'],
        exudateLevel: json['exudateLevel'],
        tissueClassification:
            List<String>.from(json['tissueClassification']),
      );
}

// ──────────────────────────────────────────────────────────────────────────────

class WoundManagement {
  final List<String> dressingMaterials;
  /// Footnotes for the starred (*) dressings, from the Quick Reference slide.
  final String? dressingNotes;
  final String antibioticRecommendation;
  final List<String> surgicalProcedures;
  final String? additionalNotes;

  WoundManagement({
    required this.dressingMaterials,
    this.dressingNotes,
    required this.antibioticRecommendation,
    required this.surgicalProcedures,
    this.additionalNotes,
  });

  Map<String, dynamic> toJson() => {
        'dressingMaterials': dressingMaterials,
        'dressingNotes': dressingNotes,
        'antibioticRecommendation': antibioticRecommendation,
        'surgicalProcedures': surgicalProcedures,
        'additionalNotes': additionalNotes,
      };

  factory WoundManagement.fromJson(Map<String, dynamic> json) =>
      WoundManagement(
        dressingMaterials: List<String>.from(json['dressingMaterials']),
        dressingNotes: json['dressingNotes'],
        antibioticRecommendation: json['antibioticRecommendation'],
        surgicalProcedures: List<String>.from(json['surgicalProcedures']),
        additionalNotes: json['additionalNotes'],
      );
}
