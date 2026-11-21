
class Student {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String parentName;
  final String parentPhone;
  final String schoolName;
  final String grade;
  final String address;
  final String routeId;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final DateTime modifiedAt;
  final String modifiedBy;

  Student({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.parentName,
    required this.parentPhone,
    required this.schoolName,
    required this.grade,
    required this.address,
    required this.routeId,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    required this.modifiedAt,
    required this.modifiedBy,
  });
}
