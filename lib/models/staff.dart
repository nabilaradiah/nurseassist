class Staff {
  final String id;
  final String staffId;
  final String name;
  final String department;

  /// Real email address supplied at registration.
  /// Null only for legacy accounts created before this field existed.
  final String? email;

  /// Role controls what the user can see/do in the app.
  ///   'nurse'      — default for all new registrations
  ///   'supervisor' — can approve images for model retraining
  ///   'admin'      — full access
  final String role;

  Staff({
    required this.id,
    required this.staffId,
    required this.name,
    required this.department,
    this.email,
    this.role = 'nurse',
  });

  // Accepts both 'supervisor' and legacy 'lecturer' until migration is complete
  bool get isLecturer => role == 'supervisor' || role == 'lecturer' || role == 'admin';
  bool get isAdmin    => role == 'admin';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'name': name,
      'department': department,
      'email': email,
      'role': role,
    };
  }

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      staffId: json['staffId'] as String,
      name: json['name'] as String,
      department: json['department'] as String,
      email: json['email'] as String?,
      role: (json['role'] as String?) ?? 'nurse',
    );
  }
}
