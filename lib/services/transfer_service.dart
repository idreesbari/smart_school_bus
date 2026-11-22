
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('transferRequests');

  static const Map<String, String> _entityCollections = {
    'student': 'students',
    'driver': 'drivers',
    'assistant': 'assistants',
    'bus': 'buses',
  };

  // --------------------------------------------------
  // CURRENT USER PROFILE
  // --------------------------------------------------

  Future<Map<String, dynamic>> _getUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final snapshot =
        await _firestore.collection('users').doc(user.uid).get();

    if (!snapshot.exists) {
      throw Exception('User profile was not found.');
    }

    final data = snapshot.data()!;

    if (data['isActive'] != true) {
      throw Exception('Your account is inactive.');
    }

    return data;
  }

  Future<String> _getSchoolAdminSchoolId() async {
    final profile = await _getUserProfile();

    if (profile['role'] != 'schoolAdmin') {
      throw Exception('Only School Admin can perform this operation.');
    }

    final schoolId = profile['schoolId'];

    if (schoolId is! String || schoolId.isEmpty) {
      throw Exception('School ID is missing from your profile.');
    }

    return schoolId;
  }

  // --------------------------------------------------
  // CREATE TRANSFER REQUEST
  // --------------------------------------------------

  Future<String> createTransferRequest({
    required String entityType,
    required String entityId,
    required String targetSchoolId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    if (!_entityCollections.containsKey(entityType)) {
      throw Exception('Invalid transfer record type.');
    }

    if (entityId.trim().isEmpty) {
      throw Exception('Record ID is required.');
    }

    if (targetSchoolId.trim().isEmpty) {
      throw Exception('Receiving school is required.');
    }

    final profile = await _getUserProfile();

    if (profile['role'] != 'schoolAdmin') {
      throw Exception('Only School Admin can request transfers.');
    }

    final sourceSchoolId = profile['schoolId'];

    if (sourceSchoolId is! String || sourceSchoolId.isEmpty) {
      throw Exception('Your school ID is missing.');
    }

    if (sourceSchoolId == targetSchoolId) {
      throw Exception('Source and receiving schools cannot be the same.');
    }

    // Verify receiving school.
    final targetSchool = await _firestore
        .collection('schools')
        .doc(targetSchoolId)
        .get();

    if (!targetSchool.exists ||
        targetSchool.data()?['isActive'] != true) {
      throw Exception('Receiving school does not exist or is inactive.');
    }

    // Verify that the record belongs to the sending school.
    final collectionName = _entityCollections[entityType]!;

    final entity = await _firestore
        .collection(collectionName)
        .doc(entityId)
        .get();

    if (!entity.exists) {
      throw Exception('The selected record was not found.');
    }

    if (entity.data()?['schoolId'] != sourceSchoolId) {
      throw Exception('This record does not belong to your school.');
    }

    // Create request.
    final requestDocument = _requests.doc();

    await requestDocument.set({
      'entityType': entityType,
      'entityId': entityId,
      'sourceSchoolId': sourceSchoolId,
      'targetSchoolId': targetSchoolId,
      'status': 'pending',
      'requestedBy': user.uid,
      'requestedAt': FieldValue.serverTimestamp(),
    });

    return requestDocument.id;
  }

  // --------------------------------------------------
  // REQUESTS SENT BY CURRENT SCHOOL
  // --------------------------------------------------

  Future<Stream<QuerySnapshot<Map<String, dynamic>>>>
      getSentRequests() async {
    final schoolId = await _getSchoolAdminSchoolId();

    return _requests
        .where('sourceSchoolId', isEqualTo: schoolId)
        .snapshots();
  }

  // --------------------------------------------------
  // REQUESTS RECEIVED BY CURRENT SCHOOL
  // --------------------------------------------------

  Future<Stream<QuerySnapshot<Map<String, dynamic>>>>
      getIncomingRequests() async {
    final schoolId = await _getSchoolAdminSchoolId();

    return _requests
        .where('targetSchoolId', isEqualTo: schoolId)
        .snapshots();
  }

  // --------------------------------------------------
  // ALL REQUESTS - MAIN ADMIN
  // --------------------------------------------------

  Future<Stream<QuerySnapshot<Map<String, dynamic>>>>
      getAllRequests() async {
    final profile = await _getUserProfile();

    if (!['admin', 'mainAdmin'].contains(profile['role'])) {
      throw Exception('Only Main Admin can view all transfer requests.');
    }

    return _requests.snapshots();
  }

  // --------------------------------------------------
  // APPROVE OR REJECT TRANSFER REQUEST
  // --------------------------------------------------

  Future<void> reviewTransferRequest({
    required String requestId,
    required String decision,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    if (!['approved', 'rejected'].contains(decision)) {
      throw Exception('Invalid transfer decision.');
    }

    final schoolId = await _getSchoolAdminSchoolId();

    final requestDocument = _requests.doc(requestId);

    final requestSnapshot = await requestDocument.get();

    if (!requestSnapshot.exists) {
      throw Exception('Transfer request was not found.');
    }

    final requestData = requestSnapshot.data()!;

    if (requestData['targetSchoolId'] != schoolId) {
      throw Exception('This request is not addressed to your school.');
    }

    if (requestData['status'] != 'pending') {
      throw Exception('This request has already been reviewed.');
    }

    await requestDocument.update({
      'status': decision,
      'reviewedBy': user.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
