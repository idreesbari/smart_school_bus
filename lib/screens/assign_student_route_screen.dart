
import 'package:flutter/material.dart';

import '../services/student_service.dart';
import '../services/route_service.dart';

class AssignStudentRouteScreen extends StatefulWidget {
  final String studentDocumentId;
  final Map<String, dynamic> studentData;

  const AssignStudentRouteScreen({
    super.key,
    required this.studentDocumentId,
    required this.studentData,
  });

  @override
  State<AssignStudentRouteScreen> createState() =>
      _AssignStudentRouteScreenState();
}

class _AssignStudentRouteScreenState
    extends State<AssignStudentRouteScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final StudentService _studentService = StudentService();
  final RouteService _routeService = RouteService();

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String? _morningRouteId;
  String? _morningPickup;
  String? _morningDropoff;

  String? _afternoonRouteId;
  String? _afternoonPickup;
  String? _afternoonDropoff;

  bool _isSaving = false;

  void _showMessage(String message, {bool isError = false}) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final assignments =
        widget.studentData['routeAssignments']
            as Map<String, dynamic>? ?? {};

    final morning =
        assignments['morning'] as Map<String, dynamic>? ?? {};

    final afternoon =
        assignments['afternoon'] as Map<String, dynamic>? ?? {};

    _morningRouteId = morning['routeId']?.toString();
    _morningPickup = morning['pickupStop']?.toString();
    _morningDropoff = morning['dropoffStop']?.toString();

    _afternoonRouteId = afternoon['routeId']?.toString();
    _afternoonPickup = afternoon['pickupStop']?.toString();
    _afternoonDropoff = afternoon['dropoffStop']?.toString();
  }

  List<Map<String, dynamic>> _getStops(
    Map<String, dynamic>? route,
  ) {
    if (route == null) return [];

    final stops = route['stops'] as List? ?? [];

    return stops.map((stop) {
      return Map<String, dynamic>.from(stop as Map);
    }).toList();
  }

  String _stopValue(Map<String, dynamic> stop, int index) {
    return (stop['sequence'] ?? index + 1).toString();
  }

  String _stopLabel(Map<String, dynamic> stop, int index) {
    final name = stop['stopName'] ?? 'Unnamed Stop';
    final address = stop['address'] ?? '';

    return '${index + 1}. $name${address.toString().isNotEmpty ? ' - $address' : ''}';
  }

  Widget _routeDropdown({
    required String label,
    required List<Map<String, dynamic>> routes,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: routes.any(
        (r) => r['id']?.toString() == selectedValue,
      )
          ? selectedValue
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: routes.map((route) {
        final id = route['id'].toString();
        final name = route['routeName'] ?? 'Unnamed Route';
        final code = route['routeCode'] ?? '';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            '$name ($code)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _stopDropdown({
    required String label,
    required List<Map<String, dynamic>> stops,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = stops.any(
      (stop) =>
          _stopValue(stop, stops.indexOf(stop)) == selectedValue,
    )
        ? selectedValue
        : null;

    return DropdownButtonFormField<String>(
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: stops.asMap().entries.map((entry) {
        return DropdownMenuItem<String>(
          value: _stopValue(entry.value, entry.key),
          child: Text(
            _stopLabel(entry.value, entry.key),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: stops.isEmpty ? null : onChanged,
    );
  }

  Widget _assignmentSection({
    required String title,
    required List<Map<String, dynamic>> routes,
    required String? routeId,
    required String? pickup,
    required String? dropoff,
    required ValueChanged<String?> onRouteChanged,
    required ValueChanged<String?> onPickupChanged,
    required ValueChanged<String?> onDropoffChanged,
  }) {
    final selectedRoutes = routes.where(
      (route) => route['id']?.toString() == routeId,
    );

    final selectedRoute =
        selectedRoutes.isEmpty ? null : selectedRoutes.first;

    final stops = _getStops(selectedRoute);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 18),
            _routeDropdown(
              label: 'Select Route',
              routes: routes,
              selectedValue: routeId,
              onChanged: onRouteChanged,
            ),
            if (selectedRoute != null) ...[
              const SizedBox(height: 14),
              Text(
                'Bus: ${selectedRoute['busName'] ?? selectedRoute['busId'] ?? '-'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _stopDropdown(
                label: 'Pickup Stop',
                stops: stops,
                selectedValue: pickup,
                onChanged: onPickupChanged,
              ),
              const SizedBox(height: 14),
              _stopDropdown(
                label: 'Drop-off Stop',
                stops: stops,
                selectedValue: dropoff,
                onChanged: onDropoffChanged,
              ),
            ],
            if (routeId == null) ...[
              const SizedBox(height: 10),
              const Text(
                'Select a route to choose pickup and drop-off stops.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveAssignments() async {
    if (_isSaving) return;

    if (_morningRouteId == null ||
        _morningPickup == null ||
        _morningDropoff == null ||
        _afternoonRouteId == null ||
        _afternoonPickup == null ||
        _afternoonDropoff == null) {
      _showMessage(
        'Please complete both route assignments.',
        isError: true,
      );
      return;
    }

    if (_morningPickup == _morningDropoff ||
        _afternoonPickup == _afternoonDropoff) {
      _showMessage(
        'Pickup and drop-off stops must be different.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      debugPrint('Loading routes...');

      final routes = await _routeService.getRoutes().first;

      debugPrint('Routes loaded: ${routes.length}');

      final morningRoute = routes.firstWhere(
        (route) => route['id'].toString() == _morningRouteId,
      );

      final afternoonRoute = routes.firstWhere(
        (route) => route['id'].toString() == _afternoonRouteId,
      );

      Map<String, dynamic> buildAssignment(
        Map<String, dynamic> route,
        String pickup,
        String dropoff,
      ) {
        final stops = _getStops(route);

        final pickupIndex = stops.indexWhere(
          (stop) =>
              _stopValue(stop, stops.indexOf(stop)) == pickup,
        );

        final dropoffIndex = stops.indexWhere(
          (stop) =>
              _stopValue(stop, stops.indexOf(stop)) == dropoff,
        );

        if (pickupIndex == -1 || dropoffIndex == -1) {
          throw Exception(
            'Selected pickup or drop-off stop was not found.',
          );
        }

        final pickupStop = stops[pickupIndex];
        final dropoffStop = stops[dropoffIndex];

        return {
          'routeId': route['id'],
          'routeName': route['routeName'],
          'routeCode': route['routeCode'],
          'busId': route['busId'],
          'busName': route['busName'],
          'driverId': route['driverId'],
          'driverName': route['driverName'],
          'assistantId': route['assistantId'],
          'assistantName': route['assistantName'],
          'pickupStop': pickup,
          'pickupStopName': pickupStop['stopName'],
          'pickupAddress': pickupStop['address'],
          'pickupTime': pickupStop['pickupTime'],
          'dropoffStop': dropoff,
          'dropoffStopName': dropoffStop['stopName'],
          'dropoffAddress': dropoffStop['address'],
          'dropoffTime': dropoffStop['pickupTime'],
        };
      }

      debugPrint('Preparing student assignments...');

      final morningAssignment = buildAssignment(
        morningRoute,
        _morningPickup!,
        _morningDropoff!,
      );

      final afternoonAssignment = buildAssignment(
        afternoonRoute,
        _afternoonPickup!,
        _afternoonDropoff!,
      );

      debugPrint('Saving assignments to Firestore...');

      await _studentService.assignStudentRoutes(
        studentDocumentId: widget.studentDocumentId,
        morningAssignment: morningAssignment,
        afternoonAssignment: afternoonAssignment,
      );

      debugPrint('Assignments saved successfully.');

      if (!mounted) return;

      _showMessage('Student routes assigned successfully.');

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('Assignment failed: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage(
        'Assignment failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          title: const Text('Assign Student Routes'),
          backgroundColor: Colors.white,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _routeService.getRoutes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading routes:\n${snapshot.error}',
                ),
              );
            }

            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final routes = (snapshot.data ?? []).where((route) {
              return route['isActive'] == true;
            }).toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      widget.studentData['fullName'] ?? 'Student',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Student ID: ${widget.studentData['studentId'] ?? '-'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 22),
                    if (routes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No active routes are available. Please create a route first.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      _assignmentSection(
                        title: 'Morning Journey',
                        routes: routes,
                        routeId: _morningRouteId,
                        pickup: _morningPickup,
                        dropoff: _morningDropoff,
                        onRouteChanged: (value) {
                          setState(() {
                            _morningRouteId = value;
                            _morningPickup = null;
                            _morningDropoff = null;
                          });
                        },
                        onPickupChanged: (value) {
                          setState(() => _morningPickup = value);
                        },
                        onDropoffChanged: (value) {
                          setState(() => _morningDropoff = value);
                        },
                      ),
                      _assignmentSection(
                        title: 'Afternoon Journey',
                        routes: routes,
                        routeId: _afternoonRouteId,
                        pickup: _afternoonPickup,
                        dropoff: _afternoonDropoff,
                        onRouteChanged: (value) {
                          setState(() {
                            _afternoonRouteId = value;
                            _afternoonPickup = null;
                            _afternoonDropoff = null;
                          });
                        },
                        onPickupChanged: (value) {
                          setState(() => _afternoonPickup = value);
                        },
                        onDropoffChanged: (value) {
                          setState(() => _afternoonDropoff = value);
                        },
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSaving ? null : _saveAssignments,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : 'Save Assignments',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
