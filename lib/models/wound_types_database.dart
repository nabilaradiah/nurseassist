/// Database of wound types with their characteristics and management protocols
/// 
/// Currently supports 10 wound types for Roboflow classification:
/// - Abrasion, Bruise, Burn, Cut, Diabetic Wound, Laceration, 
///   Normal, Pressure Wound, Surgical Wound, Venous Wound
class WoundTypesDatabase {
  
  /// Get all available wound type names
  static List<String> getAllWoundTypes() {
    return [
      'Abrasion',
      'Bruise',
      'Burn',
      'Cut',
      'Diabetic Wound',
      'Laceration',
      'Normal',
      'Pressure Wound',
      'Surgical Wound',
      'Venous Wound',
    ];
  }

  /// Map Roboflow class names to standardized wound type names
  static String normalizeClassName(String roboflowClass) {
    final normalized = roboflowClass.toLowerCase().trim();
    
    final mapping = {
      'abrasions': 'Abrasion',
      'abrasion': 'Abrasion',
      'bruises': 'Bruise',
      'bruise': 'Bruise',
      'burns': 'Burn',
      'burn': 'Burn',
      'cut': 'Cut',
      'cuts': 'Cut',
      'diabetic_wounds': 'Diabetic Wound',
      'diabetic_wound': 'Diabetic Wound',
      'diabetic': 'Diabetic Wound',
      'laseration': 'Laceration',
      'laceration': 'Laceration',
      'lacerations': 'Laceration',
      'normal': 'Normal',
      'pressure_wounds': 'Pressure Wound',
      'pressure_wound': 'Pressure Wound',
      'pressure_ulcer': 'Pressure Wound',
      'surgical_wounds': 'Surgical Wound',
      'surgical_wound': 'Surgical Wound',
      'surgical': 'Surgical Wound',
      'venous_wounds': 'Venous Wound',
      'venous_wound': 'Venous Wound',
      'venous': 'Venous Wound',
    };
    
    return mapping[normalized] ?? roboflowClass;
  }

  /// Get detailed data for a specific wound type
  static Map<String, dynamic> getWoundTypeData(String woundType) {
    return _woundDatabase[woundType] ?? _woundDatabase['Normal']!;
  }

  /// Complete wound database with characteristics and management
  static final Map<String, Map<String, dynamic>> _woundDatabase = {
    'Abrasion': {
      'severity': 'Mild',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'No infection',
        'exudateLevel': 'Dry/Minimal',
        'tissueClassification': ['Superficial dermis', 'Raw surface', 'Minor bleeding'],
      },
      'management': {
        'dressingMaterials': [
          'Non-adherent dressing',
          'Hydrocolloid thin film',
          'Transparent film dressing',
          'Antibiotic ointment (if needed)',
        ],
        'antibioticRecommendation': 'Not typically required unless signs of infection',
        'surgicalProcedures': [
          'Clean wound with saline or water',
          'Remove debris or foreign material',
          'No suturing typically required',
          'Change dressing daily or when soiled',
        ],
        'additionalNotes': 'Usually heals within 5-7 days without scarring if kept clean.',
      },
      'estimatedHealingTime': '5-7 days',
    },

    'Bruise': {
      'severity': 'Mild',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'No infection',
        'exudateLevel': 'Dry/Minimal',
        'tissueClassification': ['Intact skin', 'Subcutaneous bleeding', 'Discoloration'],
      },
      'management': {
        'dressingMaterials': [
          'Cold compress (first 24-48 hours)',
          'Warm compress (after 48 hours)',
          'No dressing typically required',
        ],
        'antibioticRecommendation': 'No',
        'surgicalProcedures': [
          'Rest and elevation',
          'Ice application (15-20 min intervals)',
          'Monitor for expansion or pain increase',
          'No surgical intervention unless severe hematoma',
        ],
        'additionalNotes': 'Bruising color changes from red/purple to yellow/green as it heals.',
      },
      'estimatedHealingTime': '2-4 weeks',
    },

    'Burn': {
      'severity': 'Moderate to Critical',
      'characteristics': {
        'necroticTissue': 'Varies (< 25% to > 25% depending on degree)',
        'infection': 'High risk of infection',
        'exudateLevel': 'Moderate/Wet',
        'tissueClassification': ['Damaged epidermis', 'Possible dermis involvement', 'Blistering'],
      },
      'management': {
        'dressingMaterials': [
          'Silver sulfadiazine cream',
          'Hydrogel (for cooling and moisture)',
          'Non-adherent dressing',
          'Silver dressing',
          'Foam dressing for exudate absorption',
        ],
        'antibioticRecommendation': 'Yes, topical initially; systemic if infected',
        'surgicalProcedures': [
          'Cool burn with running water (not ice)',
          'Debride broken blisters if infected',
          'Skin grafting for deep burns (third-degree)',
          'Daily dressing changes',
          'Monitor for infection signs',
        ],
        'additionalNotes': 'First-degree: 7-10 days. Second-degree: 2-3 weeks. Third-degree: requires grafting.',
      },
      'estimatedHealingTime': '7 days to several months',
    },

    'Cut': {
      'severity': 'Mild to Moderate',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'Low risk if clean',
        'exudateLevel': 'Minimal to Moderate',
        'tissueClassification': ['Clean edges', 'Dermis involvement', 'Possible bleeding'],
      },
      'management': {
        'dressingMaterials': [
          'Sterile gauze',
          'Non-stick pad',
          'Adhesive bandage (for small cuts)',
          'Transparent film dressing',
        ],
        'antibioticRecommendation': 'Only if contaminated or signs of infection',
        'surgicalProcedures': [
          'Clean with saline solution',
          'Apply direct pressure to stop bleeding',
          'Suture or Steri-Strips if deep (> 0.5 cm)',
          'Tetanus shot if needed',
          'Change dressing daily',
        ],
        'additionalNotes': 'Small cuts heal in 7-10 days. Deep cuts may take 2-3 weeks.',
      },
      'estimatedHealingTime': '7-21 days',
    },

    'Diabetic Wound': {
      'severity': 'Moderate to Critical',
      'characteristics': {
        'necroticTissue': '> 25% (often)',
        'infection': 'High risk of infection',
        'exudateLevel': 'Varies (Dry to Moderate)',
        'tissueClassification': ['Poor vascularization', 'Necrotic tissue', 'Slow granulation'],
      },
      'management': {
        'dressingMaterials': [
          'Hydrogel (for debridement)',
          'Alginate (for exudate)',
          'Hydrofiber',
          'Silver dressing',
          'Foam dressing',
          'Collagen dressing',
        ],
        'antibioticRecommendation': 'Yes, broad-spectrum based on C&S',
        'surgicalProcedures': [
          'Debride necrotic tissue regularly',
          'Offload pressure (specialized footwear)',
          'Monitor blood glucose strictly',
          'Assess vascular status',
          'Consider hyperbaric oxygen therapy',
          'Amputation if gangrene develops',
        ],
        'additionalNotes': 'Requires multidisciplinary care: endocrinologist, vascular surgeon, podiatrist.',
      },
      'estimatedHealingTime': '4-12 weeks or longer',
    },

    'Laceration': {
      'severity': 'Moderate',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'Moderate risk',
        'exudateLevel': 'Moderate',
        'tissueClassification': ['Irregular edges', 'Deeper tissue involvement', 'Bleeding'],
      },
      'management': {
        'dressingMaterials': [
          'Sterile gauze',
          'Non-adherent dressing',
          'Foam dressing',
          'Island dressing',
        ],
        'antibioticRecommendation': 'Consider if contaminated or high infection risk',
        'surgicalProcedures': [
          'Irrigate thoroughly with saline',
          'Suture primary closure if < 12 hours old',
          'Delayed closure if contaminated',
          'Tetanus prophylaxis',
          'Remove sutures in 7-14 days',
        ],
        'additionalNotes': 'Face lacerations: 5-7 days. Body: 10-14 days. Lower extremity: 14-21 days.',
      },
      'estimatedHealingTime': '10-21 days',
    },

    'Normal': {
      'severity': 'None',
      'characteristics': {
        'necroticTissue': '0%',
        'infection': 'No infection',
        'exudateLevel': 'None',
        'tissueClassification': ['Intact skin', 'Normal coloration', 'No damage'],
      },
      'management': {
        'dressingMaterials': ['No dressing required'],
        'antibioticRecommendation': 'No',
        'surgicalProcedures': ['No treatment needed', 'Routine skin care'],
        'additionalNotes': 'No wound detected. Normal healthy skin.',
      },
      'estimatedHealingTime': 'N/A',
    },

    'Pressure Wound': {
      'severity': 'Moderate to Critical',
      'characteristics': {
        'necroticTissue': '< 25% to > 25% (depends on stage)',
        'infection': 'Moderate to high risk',
        'exudateLevel': 'Varies by stage',
        'tissueClassification': ['Tissue necrosis', 'Undermining', 'Possible bone exposure'],
      },
      'management': {
        'dressingMaterials': [
          'Hydrocolloid (Stage I-II)',
          'Foam dressing',
          'Alginate (exuding wounds)',
          'Hydrogel (dry necrotic tissue)',
          'Silver dressing (infected)',
        ],
        'antibioticRecommendation': 'Yes if infected or deep',
        'surgicalProcedures': [
          'Debridement of necrotic tissue',
          'Pressure redistribution (repositioning every 2 hours)',
          'Specialized mattress/cushion',
          'Nutritional support',
          'Surgical flap closure for Stage III-IV',
        ],
        'additionalNotes': 'Prevention is key: turn/reposition frequently, manage moisture, nutrition.',
      },
      'estimatedHealingTime': 'Weeks to months (stage dependent)',
    },

    'Surgical Wound': {
      'severity': 'Mild to Moderate',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'Low risk if clean',
        'exudateLevel': 'Minimal to Moderate',
        'tissueClassification': ['Clean incision', 'Sutured/stapled', 'Controlled edges'],
      },
      'management': {
        'dressingMaterials': [
          'Sterile gauze',
          'Transparent film dressing',
          'Foam dressing',
          'Island dressing',
          'Non-adherent pad',
        ],
        'antibioticRecommendation': 'Prophylactic perioperative antibiotics',
        'surgicalProcedures': [
          'Keep incision clean and dry',
          'Change dressing per surgeon instructions',
          'Monitor for dehiscence or infection',
          'Remove sutures/staples per schedule (7-14 days)',
          'Avoid stress on incision',
        ],
        'additionalNotes': 'Most heal uneventfully in 2-3 weeks. Report redness, warmth, or drainage.',
      },
      'estimatedHealingTime': '2-3 weeks',
    },

    'Venous Wound': {
      'severity': 'Moderate',
      'characteristics': {
        'necroticTissue': '< 25%',
        'infection': 'Moderate risk',
        'exudateLevel': 'Moderate/Wet',
        'tissueClassification': ['Irregular borders', 'Shallow', 'Hemosiderin staining'],
      },
      'management': {
        'dressingMaterials': [
          'Foam dressing (high exudate)',
          'Alginate',
          'Hydrofiber',
          'Compression bandages (essential)',
          'Zinc paste bandages',
        ],
        'antibioticRecommendation': 'Only if signs of infection',
        'surgicalProcedures': [
          'Compression therapy (20-30 mmHg)',
          'Leg elevation when resting',
          'Debride slough if present',
          'Exercise to improve venous return',
          'Treat underlying venous insufficiency',
        ],
        'additionalNotes': 'Compression is the cornerstone of treatment. Address venous hypertension.',
      },
      'estimatedHealingTime': '3-6 months',
    },
  };
}
