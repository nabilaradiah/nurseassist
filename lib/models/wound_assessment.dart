class WoundAssessment {
  final String id;
  final String patientId;
  final String imageUrl;
  final DateTime assessmentDate;
  final WoundAnalysisResult? analysisResult;
  final String? additionalNotes;
  final bool requiresSpecialistConfirmation;
  final bool? specialistConfirmed;

  WoundAssessment({
    required this.id,
    required this.patientId,
    required this.imageUrl,
    required this.assessmentDate,
    this.analysisResult,
    this.additionalNotes,
    this.requiresSpecialistConfirmation = false,
    this.specialistConfirmed,
  });

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
    };
  }

  factory WoundAssessment.fromJson(Map<String, dynamic> json) {
    return WoundAssessment(
      id: json['id'],
      patientId: json['patientId'],
      imageUrl: json['imageUrl'],
      assessmentDate: DateTime.parse(json['assessmentDate']),
      analysisResult: json['analysisResult'] != null
          ? WoundAnalysisResult.fromJson(json['analysisResult'])
          : null,
      additionalNotes: json['additionalNotes'],
      requiresSpecialistConfirmation:
          json['requiresSpecialistConfirmation'] ?? false,
      specialistConfirmed: json['specialistConfirmed'],
    );
  }
}

class WoundAnalysisResult {
  final double confidenceScore;
  final int woundType; // 1-8
  final String woundName;
  final String severity;
  final double estimatedSize; // in cm²
  final WoundCharacteristics characteristics;
  final WoundManagement management;
  final String? segmentationMapUrl;

  WoundAnalysisResult({
    required this.confidenceScore,
    required this.woundType,
    required this.woundName,
    required this.severity,
    required this.estimatedSize,
    required this.characteristics,
    required this.management,
    this.segmentationMapUrl,
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
    };
  }

  factory WoundAnalysisResult.fromJson(Map<String, dynamic> json) {
    return WoundAnalysisResult(
      confidenceScore: json['confidenceScore'].toDouble(),
      woundType: json['woundType'],
      woundName: json['woundName'],
      severity: json['severity'],
      estimatedSize: json['estimatedSize'].toDouble(),
      characteristics:
          WoundCharacteristics.fromJson(json['characteristics']),
      management: WoundManagement.fromJson(json['management']),
      segmentationMapUrl: json['segmentationMapUrl'],
    );
  }
}

class WoundCharacteristics {
  final String necroticTissue; // e.g., "< 25%" or "> 25%"
  final String infection; // "No infection" or "Presence of infection"
  final String exudateLevel; // "Dry/Minimal" or "Moderate/Wet"
  final List<String> tissueClassification; // e.g., ["slough", "granulation tissue"]

  WoundCharacteristics({
    required this.necroticTissue,
    required this.infection,
    required this.exudateLevel,
    required this.tissueClassification,
  });

  Map<String, dynamic> toJson() {
    return {
      'necroticTissue': necroticTissue,
      'infection': infection,
      'exudateLevel': exudateLevel,
      'tissueClassification': tissueClassification,
    };
  }

  factory WoundCharacteristics.fromJson(Map<String, dynamic> json) {
    return WoundCharacteristics(
      necroticTissue: json['necroticTissue'],
      infection: json['infection'],
      exudateLevel: json['exudateLevel'],
      tissueClassification:
          List<String>.from(json['tissueClassification']),
    );
  }
}

class WoundManagement {
  final List<String> dressingMaterials;
  final String antibioticRecommendation;
  final List<String> surgicalProcedures;
  final String? additionalNotes;

  WoundManagement({
    required this.dressingMaterials,
    required this.antibioticRecommendation,
    required this.surgicalProcedures,
    this.additionalNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'dressingMaterials': dressingMaterials,
      'antibioticRecommendation': antibioticRecommendation,
      'surgicalProcedures': surgicalProcedures,
      'additionalNotes': additionalNotes,
    };
  }

  factory WoundManagement.fromJson(Map<String, dynamic> json) {
    return WoundManagement(
      dressingMaterials: List<String>.from(json['dressingMaterials']),
      antibioticRecommendation: json['antibioticRecommendation'],
      surgicalProcedures: List<String>.from(json['surgicalProcedures']),
      additionalNotes: json['additionalNotes'],
    );
  }
}
