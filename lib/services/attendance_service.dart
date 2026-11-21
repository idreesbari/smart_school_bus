
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _attendance =>
      _firestore.collection('attendance');

  CollectionReference get _users =>
      _firestore.collection('users');

  String get _currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  Future<Map<String, dynamic>> _getUserProfile() async {
    final doc = await _users.doc(_currentUid).get();

    if (!doc.exists) {
      throw Exception('User profile not found.');
    }

    final profile = doc.data() as Map<String, dynamic>;

    if (profile['isActive'] != true) {
      throw Exception('Your account is inactive.');
    }

    if (!['driver', 'assistant'].contains(profile['role'])) {
      throw Exception(
        'Only drivers and assistants can mark attendance.',
      );
    }

    return profile;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _attendanceDocumentId({
    required String studentId,
    required String journey,
    required String date,
  }) {
    return '${date}_${journey}_$studentId';
  }

  String _eventField(String journey, String event) {
    const allowedEvents = {
      'morning': ['pickup', 'schoolArrival'],
      'afternoon': ['boarding', 'dropoff'],
    };

    if (!allowedEvents.containsKey(journey) ||
        !allowedEvents[journey]!.contains(event)) {
      throw Exception('Invalid attendance event.');
    }

    return '${event}Status';
  }

  Future<Map<String, dynamic>> _validateAssignment({
    required Map<String, dynamic> profile,
    required String routeId,
    required String journey,
  }) async {
    final role = profile['role']?.toString();

    final linkedDocumentId =
        profile[role == 'driver' ? 'driverId' : 'assistantId']
                ?.toString() ??
            '';

    if (linkedDocumentId.isEmpty) {
      throw Exception(
        'Your account is not linked to a driver or assistant record.',
      );
    }

    final collection = role == 'driver' ? 'drivers' : 'assistants';

    final personDoc = await _firestore
        .collection(collection)
        .doc(linkedDocumentId)
        .get();

    if (!personDoc.exists) {
      throw Exception('Your assigned staff record was not found.');
    }

    final personData = personDoc.data() as Map<String, dynamic>;

    if (personData['isActive'] == false) {
      throw Exception('Your staff record is inactive.');
    }

    final schoolId = personData['schoolId']?.toString() ?? '';

    if (schoolId.isEmpty) {
      throw Exception('Your school assignment is missing.');
    }

    final schoolDoc =
        await _firestore.collection('schools').doc(schoolId).get();

    if (!schoolDoc.exists ||
        schoolDoc.data()?['isActive'] != true) {
      throw Exception('Your school is inactive or unavailable.');
    }

    final routeDoc = await _firestore
        .collection('routes')
        .doc(routeId)
        .get();

    if (!routeDoc.exists) {
      throw Exception('Route not found.');
    }

    final route = routeDoc.data() as Map<String, dynamic>;

    if (route['isActive'] != true) {
      throw Exception('This route is inactive.');
    }

    if (route['schoolId'] != schoolId ||
        route['journeyType'] != journey) {
      throw Exception(
        'This route does not belong to your assigned journey and school.',
      );
    }

    final busId = route['busId']?.toString() ?? '';

    if (busId.isEmpty) {
      throw Exception('Route bus assignment is missing.');
    }

    final assignedStaffId =
        route[role == 'driver' ? 'driverId' : 'assistantId']
                ?.toString() ??
            '';

    if (assignedStaffId != linkedDocumentId) {
      throw Exception('You are not assigned to this route.');
    }

    final busDoc =
        await _firestore.collection('buses').doc(busId).get();

    if (!busDoc.exists) {
      throw Exception('Assigned bus not found.');
    }

    final bus = busDoc.data() as Map<String, dynamic>;

    if (bus['isActive'] != true ||
        bus['schoolId'] != schoolId) {
      throw Exception('Assigned bus is inactive or unavailable.');
    }

    if (bus['driverId'] != route['driverId'] ||
        bus['assistantId'] != route['assistantId']) {
      throw Exception(
        'Bus staff assignments do not match the route.',
      );
    }

    if (bus['driverId'] !=
            (role == 'driver' ? linkedDocumentId : route['driverId']) ||
        bus['assistantId'] !=
            (role == 'assistant' ? linkedDocumentId : route['assistantId'])) {
      throw Exception('You are not assigned to this bus.');
    }

    return {
      'schoolId': schoolId,
      'busId': busId,
      'route': route,
    };
  }

  Future<void> markAttendance({
    required String studentDocumentId,
    required String routeId,
    required String journey,
    required String event,
    required String status,
    required DateTime attendanceDate,
  }) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    if (!['morning', 'afternoon'].contains(journey)) {
      throw Exception('Invalid journey type.');
    }

    if (!['present', 'absent'].contains(status)) {
      throw Exception('Invalid attendance status.');
    }

    if (studentDocumentId.isEmpty || routeId.isEmpty) {
      throw Exception('Attendance information is incomplete.');
    }

    final eventField = _eventField(journey, event);

    final assignment = await _validateAssignment(
      profile: profile,
      routeId: routeId,
      journey: journey,
    );

    final schoolId = assignment['schoolId'] as String;
    final busId = assignment['busId'] as String;
    final route = assignment['route'] as Map<String, dynamic>;

    final studentDoc = await _firestore
        .collection('students')
        .doc(studentDocumentId)
        .get();

    if (!studentDoc.exists) {
      throw Exception('Student not found.');
    }

    final student = studentDoc.data() as Map<String, dynamic>;

    if (student['schoolId'] != schoolId) {
      throw Exception('Student belongs to another school.');
    }

    final assignments =
        student['routeAssignments'] as Map<String, dynamic>? ?? {};

    final journeyAssignment =
        assignments[journey] as Map<String, dynamic>? ?? {};

    if (journeyAssignment['routeId'] != routeId ||
        journeyAssignment['busId'] != busId ||
        journeyAssignment['driverId'] != route['driverId'] ||
        journeyAssignment['assistantId'] != route['assistantId']) {
      throw Exception(
        'Student is not assigned to this route and bus for this journey.',
      );
    }

    final date = _dateKey(attendanceDate);

    final attendanceId = _attendanceDocumentId(
      studentId: studentDocumentId,
      journey: journey,
      date: date,
    );

    await _attendance.doc(attendanceId).set({
      'studentDocumentId': studentDocumentId,
      'schoolId': schoolId,
      'routeId': routeId,
      'busId': busId,
      'journey': journey,
      'date': date,
      eventField: status,
      '${event}MarkedBy': uid,
      '${event}MarkedByRole': profile['role'],
      '${event}MarkedAt': FieldValue.serverTimestamp(),
      'modifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> getRouteAttendance({
    required String routeId,
    required String journey,
    required DateTime attendanceDate,
  }) {
    return _getRouteAttendanceStream(
      routeId: routeId,
      journey: journey,
      attendanceDate: attendanceDate,
    ).asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> _getRouteAttendanceStream({
    required String routeId,
    required String journey,
    required DateTime attendanceDate,
  }) async* {
    final profile = await _getUserProfile();

    if (!['morning', 'afternoon'].contains(journey)) {
      throw Exception('Invalid journey type.');
    }

    final assignment = await _validateAssignment(
      profile: profile,
      routeId: routeId,
      journey: journey,
    );

    final date = _dateKey(attendanceDate);

    yield* _attendance
        .where('schoolId', isEqualTo: assignment['schoolId'])
        .where('busId', isEqualTo: assignment['busId'])
        .where('routeId', isEqualTo: routeId)
        .where('journey', isEqualTo: journey)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        };
      }).toList();
    });
  }
}
