class Staff {
  final String id;
  final String staffId;
  final String name;
  final String department;

  Staff({
    required this.id,
    required this.staffId,
    required this.name,
    required this.department,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'name': name,
      'department': department,
    };
  }

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      staffId: json['staffId'],
      name: json['name'],
      department: json['department'],
    );
  }
}
