import 'wound_assessment.dart' show WoundManagement;

/// Database of wound types with their characteristics and management protocols
///
/// Wound types are labelled Type_1 through Type_8 to match the TFLite model
/// output classes.  Severity ASCENDS with the type number — Type 1 is the
/// mildest/best outcome and Type 8 is the most critical:
///
///   Type_1 — Healing / Granulating Wound          (Mild-Recovering)
///   Type_2 — Clean Wound                          (Mild)
///   Type_3 — Infected Wound                       (Moderate)        ← specialist
///   Type_4 — Infected Wound with Slough           (Moderate-Severe) ← specialist
///   Type_5 — Dry Necrotic Wound                   (Moderate-Severe)
///   Type_6 — Cavity / Undermining Wound           (Severe)          ← specialist
///   Type_7 — Severely Infected Necrotic Wound     (Severe-Critical)
///   Type_8 — Critical Wound                       (Critical)
class WoundTypesDatabase {

  // ─────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────

  /// Returns the ordered list of type names that matches the TFLite model
  /// class indices (index 0 → 'Type_1', index 7 → 'Type_8').
  static List<String> getAllWoundTypes() {
    return [
      'Type_1',
      'Type_2',
      'Type_3',
      'Type_4',
      'Type_5',
      'Type_6',
      'Type_7',
      'Type_8',
    ];
  }

  /// True for a valid 1-based wound type ID (1–8).
  static bool isValidTypeId(int typeId) => typeId >= 1 && typeId <= 8;

  /// Returns the type name for a 1-based integer ID (e.g. 3 → 'Type_3').
  ///
  /// Throws [ArgumentError] for an ID outside 1–8. There is deliberately no
  /// fallback: silently showing an unknown wound as Type 1 (the mildest)
  /// would hide a bug behind the least alarming advice.
  static String getWoundTypeName(int typeId) {
    if (!isValidTypeId(typeId)) {
      throw ArgumentError.value(typeId, 'typeId', 'Wound type must be 1–8');
    }
    return 'Type_$typeId';
  }

  /// Returns true for types that require a clinician/specialist to verify the
  /// prediction before acting on the management plan.
  static bool requiresSpecialistConfirmation(int typeId) =>
      _entry(getWoundTypeName(typeId))['specialistRequired'] as bool;

  /// The Wound Care Quick Reference management plan for [typeId] — the one
  /// source for both what the results screen shows and what is saved with an
  /// AI result.
  static WoundManagement getManagement(int typeId) {
    final m = _entry(getWoundTypeName(typeId))['management']
        as Map<String, dynamic>;
    return WoundManagement(
      dressingMaterials: List<String>.from(m['dressingMaterials']),
      dressingNotes: m['dressingNotes'] as String?,
      antibioticRecommendation: m['antibioticRecommendation'] as String,
      surgicalProcedures: List<String>.from(m['surgicalProcedures']),
    );
  }

  /// Returns full clinical data for [woundType] ('Type_1' … 'Type_8').
  /// Throws [ArgumentError] for any other name.
  static Map<String, dynamic> getWoundTypeData(String woundType) =>
      _entry(woundType);

  static Map<String, dynamic> _entry(String woundType) {
    final data = _woundDatabase[woundType];
    if (data == null) {
      throw ArgumentError.value(woundType, 'woundType', 'Unknown wound type');
    }
    return data;
  }

  // ─────────────────────────────────────────────
  // Clinical database
  // ─────────────────────────────────────────────

  static final Map<String, Map<String, dynamic>> _woundDatabase = {

    // ── Type 1 ── <25% necrotic/slough · no infection · dry ──────────────
    'Type_1': {
      'displayName': 'Type 1',
      'specialistRequired': false,
      'severity': 'Mild (Recovering)',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Dry / minimal exudates',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': ['Foam', 'Polymeric membrane', 'Island dressing'],
        'dressingNotes': null,
        'antibioticRecommendation': 'No',
        'surgicalProcedures': [
          'Ready for secondary wound closure',
          'If wound is small, continue dressing till wound heals by secondary intention',
          'Frequency of dressing varies depending on wound type and dressing material used',
        ],
      },
    },

    // ── Type 2 ── <25% necrotic/slough · no infection · wet ──────────────
    'Type_2': {
      'displayName': 'Type 2',
      'specialistRequired': false,
      'severity': 'Mild',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Moderate exudates / wet',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': ['Foam', 'Alginate', 'Hydrofiber', 'Polymeric membrane'],
        'dressingNotes': null,
        'antibioticRecommendation':
            'May or may not, based on tissue C&S result or other infectious disease, and current guidelines',
        'surgicalProcedures': [
          'Find underlying cause',
          'Treat underlying cause if necessary',
        ],
      },
    },

    // ── Type 3 ── <25% necrotic/slough · infection · dry ─────────────────
    'Type_3': {
      'displayName': 'Type 3',
      'severity': 'Moderate',
      'specialistRequired': true,
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'Presence of infection',
        'exudateLevel': 'Dry / minimal exudates',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Tulle*',
          'Hydrogel*',
          'Hydrocolloid*',
          'Silver dressing*',
          'Iodine base dressing*',
          'Any secondary dressing**',
        ],
        'dressingNotes':
            '*May require secondary dressing\n**Options: Gamgee, gauze, foam, island dressing, etc.',
        'antibioticRecommendation':
            'Yes, based on tissue C&S result and current guidelines',
        'surgicalProcedures': ['Debridement may be needed'],
      },
    },

    // ── Type 4 ── <25% necrotic/slough · infection · wet ─────────────────
    'Type_4': {
      'displayName': 'Type 4',
      'severity': 'Moderate-Severe',
      'specialistRequired': true,
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'Presence of infection',
        'exudateLevel': 'Moderate exudates / wet',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Alginate*',
          'Foam',
          'Silver*',
          'Hydrofiber*',
          'Polymeric membrane',
          'Iodine base dressing*',
        ],
        'dressingNotes': '*May require secondary dressing',
        'antibioticRecommendation':
            'Yes, based on tissue C&S result and current guidelines',
        'surgicalProcedures': ['Debridement may be needed'],
      },
    },

    // ── Type 5 ── >25% necrotic/slough · no infection · dry ──────────────
    'Type_5': {
      'displayName': 'Type 5',
      'specialistRequired': false,
      'severity': 'Moderate-Severe',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough >25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Dry / minimal exudates',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Hydrogel*',
          'Hydrocolloid',
          'Polymeric membrane',
          'Composite medical grade honey*',
        ],
        'dressingNotes': '*May require secondary dressing',
        'antibioticRecommendation': 'No',
        'surgicalProcedures': ['Debridement is needed'],
      },
    },

    // ── Type 6 ── >25% necrotic/slough · no infection · wet ──────────────
    'Type_6': {
      'displayName': 'Type 6',
      'severity': 'Severe',
      'specialistRequired': true,
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough >25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Moderate exudates / wet',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Alginate*',
          'Foam',
          'Polymeric membrane',
          'Hydrofiber*',
        ],
        'dressingNotes': '*May require secondary dressing',
        'antibioticRecommendation':
            'May or may not, based on tissue C&S result or other infectious disease, and current guidelines',
        'surgicalProcedures': [
          'Surgical/mechanical debridement is recommended',
          'May need repeated debridement',
        ],
      },
    },

    // ── Type 7 ── >25% necrotic/slough · infection · dry ─────────────────
    'Type_7': {
      'displayName': 'Type 7',
      'specialistRequired': false,
      'severity': 'Severe-Critical',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough >25%',
        'infection': 'Presence of infection',
        'exudateLevel': 'Dry / minimal exudates',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Silver*',
          'Hydrogel*',
          'Hydrocolloid',
          'Iodine based dressing*',
          'Polymeric membrane',
          'Composite medical grade honey*',
        ],
        'dressingNotes': null,
        'antibioticRecommendation':
            'Yes, based on tissue C&S result and current guidelines',
        'surgicalProcedures': ['Surgical debridement is strongly recommended'],
      },
    },

    // ── Type 8 ── >25% necrotic/slough · infection · wet ─────────────────
    'Type_8': {
      'displayName': 'Type 8',
      'specialistRequired': false,
      'severity': 'Critical',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough >25%',
        'infection': 'Presence of infection',
        'exudateLevel': 'Moderate exudates / wet',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Alginate*',
          'Hydrofiber*',
          'Foam*',
          'Polymeric membrane*',
          'Iodine base dressing*',
          'Silver*',
          'Charcoal*',
        ],
        'dressingNotes':
            '*Require combination or composite antimicrobial dressing (moisture control + antimicrobial)\nCharcoal can be used for odour management',
        'antibioticRecommendation':
            'Yes, based on tissue C&S result and current guidelines',
        'surgicalProcedures': ['Surgical debridement is strongly recommended'],
      },
    },
  };
}
