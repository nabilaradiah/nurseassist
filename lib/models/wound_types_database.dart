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

  /// Returns the 1-based integer ID for a type name (e.g. 'Type_3' → 3).
  /// Returns 1 if the name is not recognised.
  static int getWoundTypeId(String typeName) {
    final idx = getAllWoundTypes().indexOf(typeName);
    return idx >= 0 ? idx + 1 : 1;
  }

  /// Returns the type name for a 1-based integer ID (e.g. 3 → 'Type_3').
  /// Clamps out-of-range values to Type_1.
  static String getWoundTypeName(int typeId) {
    if (typeId < 1 || typeId > 8) return 'Type_1';
    return 'Type_$typeId';
  }

  /// Returns true for types that require a clinician/specialist to verify the
  /// prediction before acting on the management plan.
  static bool requiresSpecialistConfirmation(String typeName) {
    return typeName == 'Type_3' || typeName == 'Type_4' || typeName == 'Type_6';
  }

  /// Maps raw TFLite output strings to the canonical Type_N format.
  /// Safe to call with any string.
  static String normalizeClassName(String rawClass) {
    final s = rawClass.trim();

    // Already in canonical form
    if (RegExp(r'^Type_[1-8]$').hasMatch(s)) return s;

    // Lower-case variant — e.g. 'type_3'
    final lower = s.toLowerCase();
    final lowerMatch = RegExp(r'^type_([1-8])$').firstMatch(lower);
    if (lowerMatch != null) return 'Type_${lowerMatch.group(1)}';

    // Numeric only — e.g. model returns '3'
    final numMatch = RegExp(r'^([1-8])$').firstMatch(s);
    if (numMatch != null) return 'Type_${numMatch.group(1)}';

    // Common alternative class name strings → canonical Type_N
    const roboflowMap = <String, String>{
      'normal':          'Type_1', // healed / normal skin → healing category
      'abrasion':        'Type_2',
      'abrasions':       'Type_2',
      'cut':             'Type_2',
      'cuts':            'Type_2',
      'bruise':          'Type_2',
      'bruises':         'Type_2',
      'surgical_wound':  'Type_2',
      'surgical_wounds': 'Type_2',
      'surgical':        'Type_2',
      'burn':            'Type_3',
      'burns':           'Type_3',
      'laceration':      'Type_3',
      'lacerations':     'Type_3',
      'laseration':      'Type_3',
      'venous_wound':    'Type_3',
      'venous_wounds':   'Type_3',
      'venous':          'Type_3',
      'diabetic_wound':  'Type_5',
      'diabetic_wounds': 'Type_5',
      'diabetic':        'Type_5',
      'pressure_wound':  'Type_4',
      'pressure_wounds': 'Type_4',
      'pressure_ulcer':  'Type_4',
    };

    return roboflowMap[lower] ?? 'Type_1';
  }

  /// Returns full clinical data for the requested wound type.
  /// Falls back to Type_1 for unrecognised names.
  static Map<String, dynamic> getWoundTypeData(String woundType) {
    // Normalise before lookup so 'type_3', '3', legacy names all work
    final key = RegExp(r'^Type_[1-8]$').hasMatch(woundType)
        ? woundType
        : normalizeClassName(woundType);
    return _woundDatabase[key] ?? _woundDatabase['Type_1']!;
  }

  // ─────────────────────────────────────────────
  // Clinical database
  // ─────────────────────────────────────────────

  static final Map<String, Map<String, dynamic>> _woundDatabase = {

    // ── Type 1 ── <25% necrotic/slough · no infection · dry ──────────────
    'Type_1': {
      'displayName': 'Type 1',
      'severity': 'Mild (Recovering)',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Dry / minimal exudates',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Non-adherent silicone contact layer (e.g. Mepitel)',
          'Foam dressing (light absorbency)',
          'Hydrocolloid (to support epithelialisation)',
          'Transparent film dressing (for shallow wounds)',
        ],
        'antibioticRecommendation':
            'Not required — maintain moist wound environment only',
        'surgicalProcedures': [
          'Ready for secondary wound closure',
          'Gentle cleansing with normal saline — avoid trauma to fragile tissue',
          'Apply non-adherent dressing to protect granulation tissue',
          'Change dressing every 3–5 days (minimise disruption)',
          'Protect from pressure, friction and trauma',
          'Monitor for signs of regression (new slough or exudate increase)',
        ],
        'additionalNotes':
            'Good progress — continue current wound care plan.  Ensure adequate '
            'nutrition (protein and vitamin C) to sustain healing.  '
            'Sun protection for new epithelium; scar management once fully closed.',
      },
      'estimatedHealingTime': '1–4 weeks (to complete closure)',
    },

    // ── Type 2 ── <25% necrotic/slough · no infection · wet ──────────────
    'Type_2': {
      'displayName': 'Type 2',
      'severity': 'Mild',
      // Wording from the Wound Care Quick Reference slide for this type
      'characteristics': {
        'necroticTissue': 'Necrotic tissue / slough <25%',
        'infection': 'No signs of infection',
        'exudateLevel': 'Moderate exudates / wet',
        'tissueClassification': <String>[],
      },
      'management': {
        'dressingMaterials': [
          'Foam dressing',
          'Polymeric membrane',
          'Island dressing',
          'Non-adherent dressing',
        ],
        'antibioticRecommendation':
            'May or may not be required, based on underlying cause',
        'surgicalProcedures': [
          'Find underlying cause',
          'Treat underlying cause if necessary',
          'Cleanse with normal saline or clean water',
          'Apply non-adherent dressing; change every 1–3 days or when soiled',
        ],
        'additionalNotes':
            'Heals within 5–10 days with proper hygiene.  Monitor for '
            'erythema, warmth or increased pain that may signal early infection.',
      },
      'estimatedHealingTime': '5–14 days',
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
          'Tulle* (may require secondary dressing)',
          'Hydrogel* (may require secondary dressing)',
          'Hydrocolloid* (may require secondary dressing)',
          'Silver dressing* (antimicrobial)',
          'Iodine-based dressing* (e.g. Betadine tulle)',
          'Any secondary dressing** (Gamgee, gauze, foam, island dressing)',
        ],
        'antibioticRecommendation':
            'Yes, based on C&S report of infected tissue — topical antiseptic first; '
            'systemic antibiotics if no improvement within 48 hours',
        'surgicalProcedures': [
          'Debridement may be needed',
          'Wound swab for culture and sensitivity (C&S)',
          'Thorough irrigation with normal saline',
          'Apply silver/antimicrobial dressing; change daily or every 2 days',
          'Review in 48 hours — refer to clinician if worsening',
        ],
        'additionalNotes':
            '⚠ Clinician verification required.  Cellulitis, lymphangitis or '
            'systemic fever warrants urgent medical review.  Document exudate '
            'colour, odour and wound margin changes at every dressing change.',
      },
      'estimatedHealingTime': '2–6 weeks (infection-dependent)',
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
          'Alginate* (may require secondary dressing)',
          'Foam dressing',
          'Silver dressing* (antimicrobial)',
          'Hydrofiber* (e.g. Aquacel Ag)',
          'Polymeric membrane',
          'Iodine-based dressing* (antimicrobial)',
        ],
        'antibioticRecommendation':
            'Yes, based on C&S report of infected tissue',
        'surgicalProcedures': [
          'Debridement may be needed',
          'Irrigate wound bed with normal saline',
          'Mechanical or enzymatic debridement of slough',
          'Wound swab for C&S',
          'Change dressing every 1–2 days depending on exudate',
        ],
        'additionalNotes':
            '⚠ Clinician verification required.  Persistent slough despite '
            'debridement should prompt review for underlying osteomyelitis or '
            'vascular insufficiency.  Protect periwound skin with skin barrier cream.',
      },
      'estimatedHealingTime': '4–12 weeks',
    },

    // ── Type 5 ── >25% necrotic/slough · no infection · dry ──────────────
    'Type_5': {
      'displayName': 'Type 5',
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
          'Hydrogel* (to rehydrate and soften eschar)',
          'Hydrocolloid (after eschar loosens)',
          'Polymeric membrane',
          'Composite medical grade honey* (autolytic debridement)',
        ],
        'antibioticRecommendation':
            'No — not required unless infection signs emerge after debridement',
        'surgicalProcedures': [
          'Debridement is needed',
          'Moisturise eschar with hydrogel to facilitate autolytic debridement',
          'Do NOT forcibly remove hard eschar on heels without vascular assessment',
          'Sharp/surgical debridement by qualified clinician',
          'Assess peripheral vascular status before debridement',
        ],
        'additionalNotes':
            'Hard heel eschar may act as a protective barrier — consult vascular '
            'team before debriding.  Ensure adequate nutrition and hydration to '
            'support healing.',
      },
      'estimatedHealingTime': '4–12 weeks',
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
          'Alginate* (may require secondary dressing)',
          'Foam dressing',
          'Polymeric membrane',
          'Hydrofiber* (e.g. Aquacel)',
        ],
        'antibioticRecommendation':
            'May or may not be required, based on underlying cause',
        'surgicalProcedures': [
          'Surgical/mechanical debridement is recommended',
          'May need repeated debridement',
          'Irrigate cavity thoroughly with saline',
          'Pack wound cavity loosely with alginate or hydrofiber',
          'Measure cavity depth and width at each dressing change',
        ],
        'additionalNotes':
            '⚠ Clinician verification required.  Track wound dimensions to '
            'monitor progress.  Consider Negative Pressure Wound Therapy (NPWT) '
            'for deep cavities.  Escalate if spreading infection or systemic signs.',
      },
      'estimatedHealingTime': '6–16 weeks (debridement-dependent)',
    },

    // ── Type 7 ── >25% necrotic/slough · infection · dry ─────────────────
    'Type_7': {
      'displayName': 'Type 7',
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
          'Silver dressing* (antimicrobial cover)',
          'Hydrogel* (moisture balance)',
          'Hydrocolloid',
          'Iodine-based dressing*',
          'Polymeric membrane',
          'Composite medical grade honey*',
        ],
        'antibioticRecommendation':
            'Yes, based on C&S report of infected tissue — IV broad-spectrum '
            'empirical cover while awaiting results',
        'surgicalProcedures': [
          'Surgical debridement is strongly recommended',
          'Urgent wound swab for C&S',
          'Consider IV antibiotics if systemic signs present',
          'Daily wound assessment post-operatively',
          'Refer to surgical team if spreading infection or gas in tissue',
        ],
        'additionalNotes':
            'Escalate immediately if the patient shows fever, tachycardia, '
            'hypotension or confusion — these suggest systemic sepsis.  Document '
            'neurovascular status of affected limb at every assessment.',
      },
      'estimatedHealingTime': '3–6 months (surgery-dependent)',
    },

    // ── Type 8 ── >25% necrotic/slough · infection · wet ─────────────────
    'Type_8': {
      'displayName': 'Type 8',
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
          'Alginate* (exudate control)',
          'Hydrofiber* (high absorbency)',
          'Foam* (secondary layer)',
          'Polymeric membrane*',
          'Iodine-based dressing* (antimicrobial)',
          'Silver dressing* (antimicrobial)',
          'Charcoal dressing* (odour management)',
        ],
        'antibioticRecommendation':
            'Yes, based on C&S report of infected tissue — combination or '
            'composite antimicrobial dressings required (exudate control + '
            'antimicrobial).  Charcoal can be used for odour management.',
        'surgicalProcedures': [
          'Surgical debridement is strongly recommended',
          'URGENT surgical review — do not delay',
          'Radical surgical debridement or amputation may be required',
          'ICU admission if haemodynamic instability',
          'IV fluid resuscitation and sepsis management',
          'Reconstructive surgery (flap/graft) once infection controlled',
        ],
        'additionalNotes':
            'URGENT — Refer immediately to surgeon/emergency department.  '
            'Risk of limb loss and life-threatening sepsis.  Involve '
            'multidisciplinary team: surgeon, infectious disease, vascular, '
            'intensivist.  Document every assessment with time-stamp.',
      },
      'estimatedHealingTime': 'Months to > 1 year (if limb salvaged)',
    },
  };
}
