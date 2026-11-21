
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _drivers =>
      _firestore.collection('drivers');

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

  // Add Driver
  Future<String> addDriver(
    Map<String, dynamic> driverData,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    final role = profile['role'];
    final driverId = driverData['driverId']?.toString().trim();

    if (driverId == null || driverId.isEmpty) {
      throw Exception('Driver ID is required.');
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(driverId)) {
      throw Exception('Driver ID must contain numbers only.');
    }

    String schoolId;

    if (role == 'schoolAdmin') {
      schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }
    } else if (role == 'mainAdmin' || role == 'admin') {
      schoolId = driverData['schoolId']?.toString() ?? '';
    } else {
      throw Exception('You are not authorized to add drivers.');
    }

    await _validateSchool(schoolId);

    final existingDriver = await _drivers
        .where('schoolId', isEqualTo: schoolId)
        .where('driverId', isEqualTo: driverId)
        .limit(1)
        .get();

    if (existingDriver.docs.isNotEmpty) {
      throw Exception('Driver ID already exists in this school.');
    }

    final data = Map<String, dynamic>.from(driverData);
    data.remove('schoolId');

    final doc = await _drivers.add({
      ...data,
      'driverId': driverId,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });

    return doc.id;
  }

  // Get Drivers
  Stream<List<Map<String, dynamic>>> getDrivers() async* {
    final profile = await _getUserProfile();

    final role = profile['role'];
    Query query = _drivers;

    if (role == 'schoolAdmin') {
      final schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }

      query = query.where('schoolId', isEqualTo: schoolId);
    } else if (role != 'mainAdmin' && role != 'admin') {
      throw Exception('You are not authorized to view drivers.');
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

  // Validate access to an existing driver
  Future<void> _validateDriverAccess(
    String documentId,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'];

    if (role != 'mainAdmin' &&
        role != 'admin' &&
        role != 'schoolAdmin') {
      throw Exception('You are not authorized to access drivers.');
    }

    final driverDoc = await _drivers.doc(documentId).get();

    if (!driverDoc.exists) {
      throw Exception('Driver not found.');
    }

    if (role == 'schoolAdmin') {
      final assignedSchoolId =
          profile['schoolId']?.toString() ?? '';

      if (assignedSchoolId.isEmpty ||
          driverDoc.data() is! Map<String, dynamic> ||
          (driverDoc.data() as Map<String, dynamic>)['schoolId'] !=
              assignedSchoolId) {
        throw Exception(
          'You cannot access drivers from another school.',
        );
      }
    }
  }

  // Update Driver
  Future<void> updateDriver(
    String documentId,
    Map<String, dynamic> driverData,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    await _validateDriverAccess(documentId, profile);

    final data = Map<String, dynamic>.from(driverData);
    data.remove('schoolId');

    await _drivers.doc(documentId).update({
      ...data,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }

  // Delete Driver
  Future<void> deleteDriver(String documentId) async {
    final profile = await _getUserProfile();

    await _validateDriverAccess(documentId, profile);

    await _drivers.doc(documentId).delete();
  }
}
