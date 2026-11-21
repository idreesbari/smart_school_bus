
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
      UserCredential credential =
          await _auth.signInWithEmailAndPassword(
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

      final data = userDoc.data() as Map<String, dynamic>;

      final role = data['role'];
      final isActive = data['isActive'] == true;

      if (!isActive) {
        await _auth.signOut();
        throw Exception('Your account is inactive.');
      }

      if (role != 'admin' &&
          role != 'mainAdmin' &&
          role != 'schoolAdmin') {
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
          throw Exception('Assigned school is inactive or unavailable.');
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
