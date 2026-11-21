
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception('User record not found.');
      }

      final data = userDoc.data()!;

      final role = data['role'];
      final isActive = data['isActive'] == true;

      if (!isActive) {
        await _auth.signOut();
        throw Exception('Your account is inactive.');
      }

      const allowedRoles = [
        'admin',
        'mainAdmin',
        'schoolAdmin',
        'driver',
        'assistant',
      ];

      if (!allowedRoles.contains(role)) {
        await _auth.signOut();
        throw Exception('Access denied. Invalid user role.');
      }

      // School Admin must belong to an active school.
      if (role == 'schoolAdmin') {
        final schoolId = data['schoolId'];

        if (schoolId == null || schoolId.toString().isEmpty) {
          await _auth.signOut();
          throw Exception('No school assigned to this account.');
        }

        final schoolDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .get();

        if (!schoolDoc.exists ||
            schoolDoc.data()?['isActive'] != true) {
          await _auth.signOut();
          throw Exception(
            'Assigned school is inactive or unavailable.',
          );
        }
      }

      // Driver and Assistant must have a linked staff record.
      if (role == 'driver' || role == 'assistant') {
        final schoolId = data['schoolId'];

        final staffId = role == 'driver'
            ? data['driverId']
            : data['assistantId'];

        if (schoolId == null ||
            schoolId.toString().isEmpty ||
            staffId == null ||
            staffId.toString().isEmpty) {
          await _auth.signOut();
          throw Exception(
            'Staff account is missing its school or staff assignment.',
          );
        }

        final collection = role == 'driver'
            ? 'drivers'
            : 'assistants';

        final staffDoc = await _firestore
            .collection(collection)
            .doc(staffId)
            .get();

        if (!staffDoc.exists) {
          await _auth.signOut();
          throw Exception('Linked staff record not found.');
        }

        final staffData = staffDoc.data()!;

        if (staffData['schoolId'] != schoolId ||
            staffData['isActive'] != true) {
          await _auth.signOut();
          throw Exception(
            'Staff record is inactive or belongs to another school.',
          );
        }
      }

      return {
        ...data,
        'uid': uid,
        'role': role,
        'schoolId': data['schoolId'],
      };
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed.');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
