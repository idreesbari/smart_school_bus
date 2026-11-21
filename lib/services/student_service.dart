
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _students =>
      _firestore.collection('students');

  String get _currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  Future<Map<String, dynamic>> _getUserProfile() async {
    final doc = await _firestore
        .collection('users')
        .doc(_currentUid)
        .get();

    if (!doc.exists) {
      throw Exception('User profile not found.');
    }

    final profile = doc.data()!;

    if (profile['isActive'] != true) {
      throw Exception('Your account is inactive.');
    }

    return profile;
  }

  Future<void> _validateSchool(String schoolId) async {
    if (schoolId.isEmpty) {
      throw Exception('Please select a school.');
    }

    final schoolDoc =
        await _firestore.collection('schools').doc(schoolId).get();

    if (!schoolDoc.exists ||
        schoolDoc.data()?['isActive'] != true) {
      throw Exception('Selected school is inactive or unavailable.');
    }
  }

  // Add Student
  Future<String> addStudent(
    Map<String, dynamic> studentData,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    final role = profile['role'];
    final studentId = studentData['studentId']?.toString().trim();

    if (studentId == null || studentId.isEmpty) {
      throw Exception('Student ID is required.');
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(studentId)) {
      throw Exception('Student ID must contain numbers only.');
    }

    String schoolId;

    if (role == 'schoolAdmin') {
      schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }
    } else if (role == 'mainAdmin' || role == 'admin') {
      schoolId = studentData['schoolId']?.toString() ?? '';
    } else {
      throw Exception('You are not authorized to add students.');
    }

    await _validateSchool(schoolId);

    final existingStudent = await _students
        .where('schoolId', isEqualTo: schoolId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      throw Exception('Student ID already exists in this school.');
    }

    final data = Map<String, dynamic>.from(studentData);
    data.remove('schoolId');

    final doc = await _students.add({
      ...data,
      'studentId': studentId,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });

    return doc.id;
  }

  // Get Students
  Stream<List<Map<String, dynamic>>> getStudents() async* {
    final profile = await _getUserProfile();

    final role = profile['role'];
    Query query = _students;

    if (role == 'schoolAdmin') {
      final schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }

      query = query.where('schoolId', isEqualTo: schoolId);
    } else if (role != 'mainAdmin' && role != 'admin') {
      throw Exception('You are not authorized to view students.');
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        };
      }).toList();
    });
  }

  // Validate access to an existing student
  Future<void> _validateStudentAccess(
    String documentId,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'];

    if (role != 'mainAdmin' &&
        role != 'admin' &&
        role != 'schoolAdmin') {
      throw Exception('You are not authorized to access students.');
    }

    final studentDoc = await _students.doc(documentId).get();

    if (!studentDoc.exists) {
      throw Exception('Student not found.');
    }

    if (role == 'schoolAdmin') {
      final assignedSchoolId =
          profile['schoolId']?.toString() ?? '';

      final studentData =
          studentDoc.data() as Map<String, dynamic>;

      if (assignedSchoolId.isEmpty ||
          studentData['schoolId'] != assignedSchoolId) {
        throw Exception(
          'You cannot access students from another school.',
        );
      }
    }
  }

  // Update Student
  Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> studentData,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    await _validateStudentAccess(studentId, profile);

    final data = Map<String, dynamic>.from(studentData);

    // School assignment can only be changed through transfer workflow.
    data.remove('schoolId');

    await _students.doc(studentId).update({
      ...data,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }

  // Delete Student
  Future<void> deleteStudent(String studentId) async {
    final profile = await _getUserProfile();

    await _validateStudentAccess(studentId, profile);

    await _students.doc(studentId).delete();
  }
    // Assign morning and afternoon routes to a student
  Future<void> assignStudentRoutes({
    required String studentDocumentId,
    required Map<String, dynamic> morningAssignment,
    required Map<String, dynamic> afternoonAssignment,
  }) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    await _validateStudentAccess(studentDocumentId, profile);

    final studentDoc =
        await _students.doc(studentDocumentId).get();

    final studentData =
        studentDoc.data() as Map<String, dynamic>;

    final schoolId = studentData['schoolId']?.toString() ?? '';

    if (schoolId.isEmpty) {
      throw Exception('Student school information is missing.');
    }

    await _validateSchool(schoolId);

    await _students.doc(studentDocumentId).update({
      'routeAssignments': {
        'morning': morningAssignment,
        'afternoon': afternoonAssignment,
      },
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }
}
