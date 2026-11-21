
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _routes =>
      _firestore.collection('routes');

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

  Future<String> _getSchoolId(
    Map<String, dynamic> profile,
    Map<String, dynamic> data,
  ) async {
    final role = profile['role'];

    String schoolId;

    if (role == 'schoolAdmin') {
      schoolId = profile['schoolId']?.toString() ?? '';
    } else if (role == 'mainAdmin' || role == 'admin') {
      schoolId = data['schoolId']?.toString() ?? '';
    } else {
      throw Exception('You are not authorized to manage routes.');
    }

    if (schoolId.isEmpty) {
      throw Exception('Please select a school.');
    }

    final schoolDoc =
        await _firestore.collection('schools').doc(schoolId).get();

    if (!schoolDoc.exists ||
        schoolDoc.data()?['isActive'] != true) {
      throw Exception('Selected school is inactive or unavailable.');
    }

    return schoolId;
  }

  Future<void> _validateAssignments({
    required String schoolId,
    required String busId,
    required String driverId,
    required String assistantId,
  }) async {
    await _validateAssignment(
      collection: 'buses',
      documentId: busId,
      schoolId: schoolId,
      label: 'Bus',
    );

    await _validateAssignment(
      collection: 'drivers',
      documentId: driverId,
      schoolId: schoolId,
      label: 'Driver',
    );

    await _validateAssignment(
      collection: 'assistants',
      documentId: assistantId,
      schoolId: schoolId,
      label: 'Assistant',
    );
  }

  Future<void> _validateAssignment({
    required String collection,
    required String documentId,
    required String schoolId,
    required String label,
  }) async {
    if (documentId.isEmpty) {
      throw Exception('Please select a $label.');
    }

    final doc = await _firestore
        .collection(collection)
        .doc(documentId)
        .get();

    if (!doc.exists) {
      throw Exception('$label not found.');
    }

    final data = doc.data();

    if (data == null || data['schoolId'] != schoolId) {
      throw Exception('$label does not belong to the selected school.');
    }

    if (data['isActive'] == false) {
      throw Exception('$label is inactive.');
    }
  }

  List<Map<String, dynamic>> _prepareStops(dynamic stops) {
    if (stops is! List || stops.isEmpty) {
      throw Exception('Please add at least one route stop.');
    }

    final preparedStops = <Map<String, dynamic>>[];

    for (var i = 0; i < stops.length; i++) {
      if (stops[i] is! Map) {
        throw Exception('Invalid route stop.');
      }

      final stop = Map<String, dynamic>.from(stops[i]);

      final stopName = stop['stopName']?.toString().trim() ?? '';
      final address = stop['address']?.toString().trim() ?? '';
      final pickupTime = stop['pickupTime']?.toString().trim() ?? '';

      if (stopName.isEmpty) {
        throw Exception('Stop ${i + 1}: Stop name is required.');
      }

      if (address.isEmpty) {
        throw Exception('Stop ${i + 1}: Address is required.');
      }

      if (pickupTime.isEmpty) {
        throw Exception('Stop ${i + 1}: Pickup time is required.');
      }

      preparedStops.add({
        'stopName': stopName,
        'address': address,
        'sequence': i + 1,
        'pickupTime': pickupTime,
        'notes': stop['notes']?.toString() ?? '',
      });
    }

    return preparedStops;
  }

  void _validateRouteDetails(Map<String, dynamic> data) {
    final routeName = data['routeName']?.toString().trim() ?? '';
    final routeCode = data['routeCode']?.toString().trim() ?? '';
    final journeyType = data['journeyType']?.toString() ?? '';

    if (routeName.isEmpty) {
      throw Exception('Route name is required.');
    }

    if (routeCode.isEmpty) {
      throw Exception('Route code is required.');
    }

    if (!['morning', 'afternoon'].contains(journeyType)) {
      throw Exception('Please select morning or afternoon journey.');
    }
  }

  // Add Route
  Future<String> addRoute(Map<String, dynamic> data) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    _validateRouteDetails(data);

    final schoolId = await _getSchoolId(profile, data);

    await _validateAssignments(
      schoolId: schoolId,
      busId: data['busId']?.toString() ?? '',
      driverId: data['driverId']?.toString() ?? '',
      assistantId: data['assistantId']?.toString() ?? '',
    );

    final stops = _prepareStops(data['stops']);

    final routeCode = data['routeCode'].toString().trim();

    final existingRoute = await _routes
        .where('schoolId', isEqualTo: schoolId)
        .where('routeCode', isEqualTo: routeCode)
        .limit(1)
        .get();

    if (existingRoute.docs.isNotEmpty) {
      throw Exception('Route code already exists in this school.');
    }

    final routeData = Map<String, dynamic>.from(data);

    routeData.remove('schoolId');
    routeData.remove('stops');

    final doc = await _routes.add({
      ...routeData,
      'routeName': data['routeName'].toString().trim(),
      'routeCode': routeCode,
      'journeyType': data['journeyType'],
      'schoolId': schoolId,
      'stops': stops,
      'isActive': data['isActive'] ?? true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });

    return doc.id;
  }

  // Get Routes
  Stream<List<Map<String, dynamic>>> getRoutes() async* {
    final profile = await _getUserProfile();

    final role = profile['role'];
    Query query = _routes;

    if (role == 'schoolAdmin') {
      final schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('No school assigned to this account.');
      }

      query = query.where('schoolId', isEqualTo: schoolId);
    } else if (role != 'mainAdmin' && role != 'admin') {
      throw Exception('You are not authorized to view routes.');
    }

    yield* query.snapshots().map((snapshot) {
      final routes = snapshot.docs.map((doc) {
        return {
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        };
      }).toList();

      routes.sort((a, b) =>
          (a['routeCode'] ?? '').toString().compareTo(
                (b['routeCode'] ?? '').toString(),
              ));

      return routes;
    });
  }

  // Validate access to an existing route
  Future<Map<String, dynamic>> _validateRouteAccess(
    String documentId,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'];

    if (role != 'mainAdmin' &&
        role != 'admin' &&
        role != 'schoolAdmin') {
      throw Exception('You are not authorized to access routes.');
    }

    final routeDoc = await _routes.doc(documentId).get();

    if (!routeDoc.exists) {
      throw Exception('Route not found.');
    }

    final routeData = routeDoc.data() as Map<String, dynamic>;

    if (role == 'schoolAdmin') {
      final assignedSchoolId =
          profile['schoolId']?.toString() ?? '';

      if (assignedSchoolId.isEmpty ||
          routeData['schoolId'] != assignedSchoolId) {
        throw Exception(
          'You cannot access routes from another school.',
        );
      }
    }

    return routeData;
  }

  // Update Route
  Future<void> updateRoute(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final uid = _currentUid;
    final profile = await _getUserProfile();

    final existingRoute =
        await _validateRouteAccess(documentId, profile);

    final schoolId = existingRoute['schoolId']?.toString() ?? '';

    final updatedData = Map<String, dynamic>.from(data);

    _validateRouteDetails(updatedData);

    await _validateAssignments(
      schoolId: schoolId,
      busId: updatedData['busId']?.toString() ?? '',
      driverId: updatedData['driverId']?.toString() ?? '',
      assistantId: updatedData['assistantId']?.toString() ?? '',
    );

    final stops = _prepareStops(updatedData['stops']);

    final routeCode = updatedData['routeCode'].toString().trim();

    final duplicateRoute = await _routes
        .where('schoolId', isEqualTo: schoolId)
        .where('routeCode', isEqualTo: routeCode)
        .get();

    if (duplicateRoute.docs.any((doc) => doc.id != documentId)) {
      throw Exception('Route code already exists in this school.');
    }

    updatedData.remove('schoolId');
    updatedData.remove('stops');

    await _routes.doc(documentId).update({
      ...updatedData,
      'routeName': updatedData['routeName'].toString().trim(),
      'routeCode': routeCode,
      'stops': stops,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': uid,
    });
  }

  // Delete Route
  Future<void> deleteRoute(String documentId) async {
    final profile = await _getUserProfile();

    await _validateRouteAccess(documentId, profile);

    await _routes.doc(documentId).delete();
  }
}
