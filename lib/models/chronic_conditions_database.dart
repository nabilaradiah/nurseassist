/// Curated list of chronic conditions commonly relevant to wound-care
/// nursing (conditions with a documented impact on wound healing are
/// listed first). Used to populate the "add condition" search/pick step —
/// anything not on this list can still be entered via "Other".
class ChronicConditionsDatabase {
  static List<String> getAllConditions() {
    return [
      'Type 1 Diabetes',
      'Type 2 Diabetes',
      'Hypertension',
      'Chronic Kidney Disease',
      'Peripheral Vascular Disease',
      'Peripheral Artery Disease',
      'Chronic Obstructive Pulmonary Disease (COPD)',
      'Coronary Artery Disease',
      'Congestive Heart Failure',
      'Obesity',
      'Venous Insufficiency',
      'Deep Vein Thrombosis (history)',
      'Anemia',
      'Rheumatoid Arthritis',
      'Osteoporosis',
      'Asthma',
      'Chronic Liver Disease',
      'Immunosuppression',
      'HIV/AIDS',
      'Malnutrition',
    ];
  }
}
