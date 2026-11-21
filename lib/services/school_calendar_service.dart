
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SchoolCalendarService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _getSchoolAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final profileDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!profileDoc.exists) {
      throw Exception('User profile not found.');
    }

    final profile = profileDoc.data()!;

    if (profile['isActive'] != true ||
        profile['role'] != 'schoolAdmin') {
      throw Exception(
        'Only an active School Admin can manage the calendar.',
      );
    }

    final schoolId = profile['schoolId']?.toString() ?? '';

    if (schoolId.isEmpty) {
      throw Exception('School assignment not found.');
    }

    return {
      'uid': user.uid,
      'schoolId': schoolId,
    };
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<Map<String, Map<String, dynamic>>> getMonthCalendar(
    int year,
    int month,
  ) async {
    final profile = await _getSchoolAdminProfile();

    final schoolId = profile['schoolId'] as String;

    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month + 1, 0);

    final snapshot = await _firestore
        .collection('schoolCalendar')
        .where('schoolId', isEqualTo: schoolId)
        .where(
          'date',
          isGreaterThanOrEqualTo: _dateKey(firstDate),
        )
        .where(
          'date',
          isLessThanOrEqualTo: _dateKey(lastDate),
        )
        .get();

    final calendar = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      calendar[doc.data()['date'].toString()] = {
        ...doc.data(),
        'id': doc.id,
      };
    }

    return calendar;
  }

  Future<void> saveCalendarDay({
    required DateTime date,
    required String dayType,
    required String reason,
  }) async {
    if (!['holiday', 'closed', 'working'].contains(dayType)) {
      throw Exception('Invalid calendar day type.');
    }

    final profile = await _getSchoolAdminProfile();

    final schoolId = profile['schoolId'] as String;
    final uid = profile['uid'] as String;

    final dateKey = _dateKey(date);
    final documentId = '${schoolId}_$dateKey';

    final document = _firestore
        .collection('schoolCalendar')
        .doc(documentId);

    final existing = await document.get();

    if (existing.exists) {
      await document.update({
        'dayType': dayType,
        'reason': reason.trim(),
        'modifiedAt': FieldValue.serverTimestamp(),
        'modifiedBy': uid,
      });
    } else {
      await document.set({
        'schoolId': schoolId,
        'date': dateKey,
        'dayType': dayType,
        'reason': reason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });
    }
  }

  Future<void> deleteCalendarDay(DateTime date) async {
    final profile = await _getSchoolAdminProfile();

    final schoolId = profile['schoolId'] as String;
    final dateKey = _dateKey(date);

    final documentId = '${schoolId}_$dateKey';

    await _firestore
        .collection('schoolCalendar')
        .doc(documentId)
        .delete();
  }
}
