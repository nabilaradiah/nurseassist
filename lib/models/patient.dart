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
  final String? chronicDiseases;
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
    this.chronicDiseases,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
  });

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
      'chronicDiseases': chronicDiseases,
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
        chronicDiseases: json['chronicDiseases'],
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
}
