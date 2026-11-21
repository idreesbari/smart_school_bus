
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssistantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _assistants =>
      _firestore.collection('assistants');

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

  // Add Assistant
  Future<String> addAssistant(Map<String, dynamic> data) async {
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
      throw Exception('You are not authorized to add assistants.');
    }

    await _validateSchool(schoolId);

    final assistantData = Map<String, dynamic>.from(data);
    assistantData.remove('schoolId');

    final doc = await _assistants.add({
      ...assistantData,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });

    return doc.id;
  }

  // Get Assistants
  Stream<List<Map<String, dynamic>>> getAssistants() async* {
    final profile = await _getUserProfile();

    final role = profile['role'];
    Query query = _assistants;

    if (role == 'schoolAdmin') {
      final schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }

      query = query.where('schoolId', isEqualTo: schoolId);
    } else if (role != 'mainAdmin' && role != 'admin') {
      throw Exception('You are not authorized to view assistants.');
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

  // Validate access to an existing assistant
  Future<void> _validateAssistantAccess(
    String documentId,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'];

    if (role != 'mainAdmin' &&
        role != 'admin' &&
        role != 'schoolAdmin') {
      throw Exception('You are not authorized to access assistants.');
    }

    final assistantDoc = await _assistants.doc(documentId).get();

    if (!assistantDoc.exists) {
      throw Exception('Assistant not found.');
    }

    if (role == 'schoolAdmin') {
      final assignedSchoolId =
          profile['schoolId']?.toString() ?? '';

      final assistantData =
          assistantDoc.data() as Map<String, dynamic>;

      if (assignedSchoolId.isEmpty ||
          assistantData['schoolId'] != assignedSchoolId) {
        throw Exception(
          'You cannot access assistants from another school.',
        );
      }
    }
  }

  // Update Assistant
  Future<void> updateAssistant(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    await _validateAssistantAccess(documentId, profile);

    final assistantData = Map<String, dynamic>.from(data);
    assistantData.remove('schoolId');

    await _assistants.doc(documentId).update({
      ...assistantData,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }

  // Delete Assistant
  Future<void> deleteAssistant(String documentId) async {
    final profile = await _getUserProfile();

    await _validateAssistantAccess(documentId, profile);

    await _assistants.doc(documentId).delete();
  }
}
