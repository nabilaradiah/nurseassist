import 'chronic_condition.dart';
import 'vital_reading.dart';

class Patient {
  final String id;
  final String mrn;
  final String name;
  final int age;
  final String gender;
  final String contact;
  final DateTime registeredDate;
  final List<String> woundAssessmentIds;
  final String staffIdAssignedTo; // Assigned to specific nurse
  
  // Additional patient information
  final String? phone;
  final String? addressRoom;
  final String? allergies;
  final String? medications;
  final List<ChronicCondition> chronicConditions;
  /// Dated vital-sign readings, oldest first. See [latestVitals].
  final List<VitalReading> vitalReadings;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;

  Patient({
    required this.id,
    required this.mrn,
    required this.name,
    required this.age,
    required this.gender,
    required this.contact,
    required this.registeredDate,
    required this.staffIdAssignedTo,
    this.woundAssessmentIds = const [],
    this.phone,
    this.addressRoom,
    this.allergies,
    this.medications,
    this.chronicConditions = const [],
    this.vitalReadings = const [],
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
  });

  /// True when [allergies] names a real allergy rather than being blank or a
  /// "none" placeholder (e.g. "None", "Nil", "NKDA", "No known allergies").
  bool get hasKnownAllergies {
    final text = allergies?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return false;
    const noneValues = {
      'none', 'nil', 'no', 'nka', 'nkda', 'nkfa', 'nkfda', 'nkmi', 'n/a',
      'na', '-', 'no allergy', 'no allergies', 'not known', 'unknown',
      'no known allergies', 'no known allergy', 'no known drug allergies',
      'no known drug allergy', 'no known medical illness',
    };
    // Ignore trailing punctuation, e.g. "NKDA." or "nil,"
    final normalised = text.replaceAll(RegExp(r'[.,;:!]+$'), '').trim();
    return !noneValues.contains(normalised);
  }

  /// The most recent vital-sign reading, or null if none were recorded.
  VitalReading? get latestVitals {
    if (vitalReadings.isEmpty) return null;
    return vitalReadings.reduce(
        (a, b) => b.takenAt.isAfter(a.takenAt) ? b : a);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mrn': mrn,
      'name': name,
      'age': age,
      'gender': gender,
      'contact': contact,
      'registeredDate': registeredDate.toIso8601String(),
      'woundAssessmentIds': woundAssessmentIds,
      'staffIdAssignedTo': staffIdAssignedTo,
      'phone': phone,
      'addressRoom': addressRoom,
      'allergies': allergies,
      'medications': medications,
      'chronicConditions': chronicConditions.map((c) => c.toJson()).toList(),
      'vitalReadings': vitalReadings.map((v) => v.toJson()).toList(),
      'emergencyContactName': emergencyContactName,
      'emergencyContactRelationship': emergencyContactRelationship,
      'emergencyContactPhone': emergencyContactPhone,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    // Handle registeredDate - it can be either String (ISO format) or Timestamp (from Firebase)
    DateTime parsedDate;
    final dateValue = json['registeredDate'];
    
    if (dateValue is String) {
      parsedDate = DateTime.parse(dateValue);
    } else if (dateValue != null) {
      // Handle Firestore Timestamp object
      try {
        parsedDate = (dateValue as dynamic).toDate();
      } catch (e) {
        print('⚠️ Could not parse date: $dateValue, using current date');
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }
    
    // Handle age - it can be int or String
    int parsedAge = 0;
    final ageValue = json['age'];
    if (ageValue is int) {
      parsedAge = ageValue;
    } else if (ageValue is String) {
      parsedAge = int.tryParse(ageValue) ?? 0;
    }
    
    try {
      return Patient(
        id: json['id'] ?? '',
        mrn: json['mrn'] ?? 'N/A',
        name: json['name'] ?? 'Unknown',
        age: parsedAge,
        gender: json['gender'] ?? 'N/A',
        contact: json['contact'] ?? 'N/A',
        registeredDate: parsedDate,
        woundAssessmentIds: List<String>.from(json['woundAssessmentIds'] ?? []),
        staffIdAssignedTo: json['staffIdAssignedTo'] ?? '',
        phone: json['phone'],
        addressRoom: json['addressRoom'],
        allergies: json['allergies'],
        medications: json['medications'],
        chronicConditions: _parseChronicConditions(json),
        vitalReadings: _parseVitalReadings(json),
        emergencyContactName: json['emergencyContactName'],
        emergencyContactRelationship: json['emergencyContactRelationship'],
        emergencyContactPhone: json['emergencyContactPhone'],
      );
    } catch (e) {
      print('❌ Error parsing patient: $e');
      print('   Patient data: $json');
      rethrow;
    }
  }

  static List<VitalReading> _parseVitalReadings(Map<String, dynamic> json) {
    final readings = json['vitalReadings'];
    if (readings is! List) return const [];
    return readings
        .map((e) => VitalReading.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  }

  // Prefers the new structured 'chronicConditions' list; falls back to
  // splitting the legacy free-text 'chronicDiseases' string (pre-migration
  // records) so old documents still load instead of losing their data.
  static List<ChronicCondition> _parseChronicConditions(
      Map<String, dynamic> json) {
    final conditions = json['chronicConditions'];
    if (conditions is List) {
      return conditions
          .map((e) => ChronicCondition.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final legacy = json['chronicDiseases'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return ChronicCondition.listFromLegacyString(legacy);
    }

    return const [];
  }
}
