
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _buses =>
      _firestore.collection('buses');

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

  // Add Bus
  Future<String> addBus(Map<String, dynamic> data) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    final role = profile['role'];
    String schoolId;

    if (role == 'schoolAdmin') {
      schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }
    } else if (role == 'mainAdmin' || role == 'admin') {
      schoolId = data['schoolId']?.toString() ?? '';
    } else {
      throw Exception('You are not authorized to add buses.');
    }

    await _validateSchool(schoolId);

    final busData = Map<String, dynamic>.from(data);
    busData.remove('schoolId');

    final doc = await _buses.add({
      ...busData,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });

    return doc.id;
  }

  // Get Buses
  // Get Buses
Stream<List<Map<String, dynamic>>> getBuses() async* {
  final profile = await _getUserProfile();

  final role = profile['role'];
  Query query = _buses;

  if (role == 'schoolAdmin') {
    final schoolId = profile['schoolId']?.toString() ?? '';

    if (schoolId.isEmpty) {
      throw Exception('No school assigned to this account.');
    }

    query = query.where('schoolId', isEqualTo: schoolId);
  } else if (role != 'mainAdmin' && role != 'admin') {
    throw Exception('You are not authorized to view buses.');
  }

  yield* query.snapshots().map((snapshot) {
    final buses = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
    }).toList();

    buses.sort((a, b) =>
        (a['busId'] ?? '').toString().compareTo(
              (b['busId'] ?? '').toString(),
            ));

    return buses;
  });
}

  // Validate access to an existing bus
  Future<void> _validateBusAccess(
    String documentId,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'];

    if (role != 'mainAdmin' &&
        role != 'admin' &&
        role != 'schoolAdmin') {
      throw Exception('You are not authorized to access buses.');
    }

    final busDoc = await _buses.doc(documentId).get();

    if (!busDoc.exists) {
      throw Exception('Bus not found.');
    }

    if (role == 'schoolAdmin') {
      final assignedSchoolId =
          profile['schoolId']?.toString() ?? '';

      final busData = busDoc.data() as Map<String, dynamic>;

      if (assignedSchoolId.isEmpty ||
          busData['schoolId'] != assignedSchoolId) {
        throw Exception(
          'You cannot access buses from another school.',
        );
      }
    }
  }

  // Update Bus
  Future<void> updateBus(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    await _validateBusAccess(documentId, profile);

    final busData = Map<String, dynamic>.from(data);
    busData.remove('schoolId');

    await _buses.doc(documentId).update({
      ...busData,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }

  // Delete Bus
  Future<void> deleteBus(String documentId) async {
    final profile = await _getUserProfile();

    await _validateBusAccess(documentId, profile);

    await _buses.doc(documentId).delete();
  }
}
