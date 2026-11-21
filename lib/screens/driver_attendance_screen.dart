
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/attendance_service.dart';

class DriverAttendanceScreen extends StatefulWidget {
  const DriverAttendanceScreen({super.key});

  @override
  State<DriverAttendanceScreen> createState() =>
      _DriverAttendanceScreenState();
}

class _DriverAttendanceScreenState
    extends State<DriverAttendanceScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final AttendanceService _attendanceService =
      AttendanceService();

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  List<Map<String, dynamic>> _routes = [];

  String? _schoolId;
  String? _selectedRouteId;

  String _journey = 'morning';
  String _event = 'pickup';

  bool _isLoading = true;
  bool _isBulkSaving = false;

  final Set<String> _savingStudents = {};

  Stream<List<Map<String, dynamic>>>? _attendanceStream;

  // Keep the students stream persistent across screen rebuilds.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentsStream;

  DateTime get _today => DateTime.now();

  String get _eventField => '${_event}Status';

  List<Map<String, dynamic>> get _journeyRoutes {
    return _routes.where((route) {
      return route['journeyType'] == _journey;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAssignedRoutes();
  }

  void _updateAttendanceStream() {
    if (_selectedRouteId == null) {
      _attendanceStream = null;
      return;
    }

    _attendanceStream = _attendanceService.getRouteAttendance(
      routeId: _selectedRouteId!,
      journey: _journey,
      attendanceDate: _today,
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _loadAssignedRoutes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User is not logged in.');
      }

      final profileDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDoc.exists) {
        throw Exception('User profile not found.');
      }

      final profile = profileDoc.data()!;

      if (profile['isActive'] != true) {
        throw Exception('Your account is inactive.');
      }

      final role = profile['role']?.toString() ?? '';

      if (role != 'driver' && role != 'assistant') {
        throw Exception(
          'Only drivers and assistants can access attendance.',
        );
      }

      final staffId = profile[
              role == 'driver' ? 'driverId' : 'assistantId']
          ?.toString() ?? '';

      if (staffId.isEmpty) {
        throw Exception(
          'Your account is not linked to a staff record.',
        );
      }

      final collection =
          role == 'driver' ? 'drivers' : 'assistants';

      final staffDoc = await _firestore
          .collection(collection)
          .doc(staffId)
          .get();

      if (!staffDoc.exists) {
        throw Exception('Your staff record was not found.');
      }

      final staff = staffDoc.data()!;

      if (staff['isActive'] == false) {
        throw Exception('Your staff record is inactive.');
      }

      final schoolId = staff['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('Your school assignment is missing.');
      }

      final routeField =
          role == 'driver' ? 'driverId' : 'assistantId';

      final routeSnapshot = await _firestore
          .collection('routes')
          .where(routeField, isEqualTo: staffId)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final routes = routeSnapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'id': doc.id,
        };
      }).where((route) {
        return route['isActive'] == true;
      }).toList();

      routes.sort((a, b) {
        return (a['routeCode'] ?? '')
            .toString()
            .compareTo((b['routeCode'] ?? '').toString());
      });

      if (!mounted) return;

      setState(() {
        _schoolId = schoolId;
        _routes = routes;
        _isLoading = false;

        // Create the students stream only once.
        _studentsStream = _firestore
            .collection('students')
            .where('schoolId', isEqualTo: schoolId)
            .snapshots();

        final availableRoutes = routes.where((route) {
          return route['journeyType'] == _journey;
        }).toList();

        _selectedRouteId = availableRoutes.isNotEmpty
            ? availableRoutes.first['id'].toString()
            : null;

        _updateAttendanceStream();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage(
        'Unable to load assigned routes: $e',
        isError: true,
      );
    }
  }

  void _changeJourney(String? value) {
    if (value == null) return;

    final availableRoutes = _routes.where((route) {
      return route['journeyType'] == value;
    }).toList();

    setState(() {
      _journey = value;
      _event = value == 'morning' ? 'pickup' : 'boarding';

      _selectedRouteId = availableRoutes.isNotEmpty
          ? availableRoutes.first['id'].toString()
          : null;

      _updateAttendanceStream();
    });
  }

  void _changeRoute(String? value) {
    if (value == null) return;

    setState(() {
      _selectedRouteId = value;
      _updateAttendanceStream();
    });
  }

  void _changeEvent(String? value) {
    if (value == null) return;

    setState(() => _event = value);
  }

  Future<void> _markStudent({
    required String studentDocumentId,
    required String status,
  }) async {
    if (_selectedRouteId == null ||
        _schoolId == null ||
        _savingStudents.contains(studentDocumentId)) {
      return;
    }

    setState(() {
      _savingStudents.add(studentDocumentId);
    });

    try {
      await _attendanceService.markAttendance(
        studentDocumentId: studentDocumentId,
        routeId: _selectedRouteId!,
        journey: _journey,
        event: _event,
        status: status,
        attendanceDate: _today,
      );

      _showMessage(
        status == 'present'
            ? 'Student marked present.'
            : 'Student marked absent.',
      );
    } catch (e) {
      _showMessage(
        'Unable to save attendance: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingStudents.remove(studentDocumentId);
        });
      }
    }
  }

  Future<void> _markAllPresent(
    List<Map<String, dynamic>> students,
  ) async {
    if (_selectedRouteId == null ||
        students.isEmpty ||
        _isBulkSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark All Present?'),
          content: Text(
            'This will mark all ${students.length} students '
            'as present for the selected attendance event. '
            'Existing attendance for this event will be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBulkSaving = true);

    try {
      for (final student in students) {
        if (!mounted) return;

        final studentId = student['id'].toString();

        setState(() {
          _savingStudents.add(studentId);
        });

        try {
          await _attendanceService.markAttendance(
            studentDocumentId: studentId,
            routeId: _selectedRouteId!,
            journey: _journey,
            event: _event,
            status: 'present',
            attendanceDate: _today,
          );
        } finally {
          if (mounted) {
            setState(() {
              _savingStudents.remove(studentId);
            });
          }
        }
      }

      _showMessage('All students marked present successfully.');
    } catch (e) {
      _showMessage(
        'Some attendance records could not be saved: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isBulkSaving = false);
      }
    }
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 6,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 7),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    Map<String, dynamic>? attendance,
  ) {
    final studentId = student['id'].toString();

    final status =
        attendance?[_eventField]?.toString() ?? 'notMarked';

    final isSaving = _savingStudents.contains(studentId);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'present') {
      statusColor = Colors.green;
      statusLabel = 'Present';
      statusIcon = Icons.check_circle;
    } else if (status == 'absent') {
      statusColor = Colors.red;
      statusLabel = 'Absent';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusLabel = 'Not Marked';
      statusIcon = Icons.pending_actions;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['fullName']?.toString() ?? 'Student',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Student ID: ${student['studentId'] ?? '-'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            _markStudent(
                              studentDocumentId: studentId,
                              status: 'present',
                            );
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Present'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            _markStudent(
                              studentDocumentId: studentId,
                              status: 'absent',
                            );
                          },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Absent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceContent() {
    final selectedRoutes = _journeyRoutes;

    if (selectedRoutes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No active routes are assigned to your account for this journey.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selectedRoute = selectedRoutes.firstWhere(
      (route) => route['id'].toString() == _selectedRouteId,
      orElse: () => selectedRoutes.first,
    );

    final routeId = selectedRoute['id'].toString();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _journey,
                decoration: const InputDecoration(
                  labelText: 'Select Journey',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'morning',
                    child: Text('Morning Journey'),
                  ),
                  DropdownMenuItem(
                    value: 'afternoon',
                    child: Text('Afternoon Journey'),
                  ),
                ],
                onChanged: _changeJourney,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: routeId,
                decoration: const InputDecoration(
                  labelText: 'Select Assigned Route',
                  border: OutlineInputBorder(),
                ),
                items: selectedRoutes.map((route) {
                  return DropdownMenuItem<String>(
                    value: route['id'].toString(),
                    child: Text(
                      '${route['routeName'] ?? 'Route'} '
                      '(${route['routeCode'] ?? ''})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _changeRoute,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _event,
                decoration: const InputDecoration(
                  labelText: 'Attendance Event',
                  border: OutlineInputBorder(),
                ),
                items: _journey == 'morning'
                    ? const [
                        DropdownMenuItem(
                          value: 'pickup',
                          child: Text('Morning Pickup'),
                        ),
                        DropdownMenuItem(
                          value: 'schoolArrival',
                          child: Text('School Arrival'),
                        ),
                      ]
                    : const [
                        DropdownMenuItem(
                          value: 'boarding',
                          child: Text('Afternoon Boarding'),
                        ),
                        DropdownMenuItem(
                          value: 'dropoff',
                          child: Text('Afternoon Drop-off'),
                        ),
                      ],
                onChanged: _changeEvent,
              ),
            ],
          ),
        ),
        Expanded(
          child: _studentsStream == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _studentsStream,
                  builder: (context, studentSnapshot) {
                    if (studentSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading students: ${studentSnapshot.error}',
                        ),
                      );
                    }

                    if (studentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final students =
                        studentSnapshot.data!.docs.where((doc) {
                      final data = doc.data();

                      final assignments =
                          data['routeAssignments']
                              as Map<String, dynamic>? ?? {};

                      final journeyAssignment =
                          assignments[_journey]
                              as Map<String, dynamic>? ?? {};

                      return data['isActive'] == true &&
                          journeyAssignment['routeId'] == routeId &&
                          journeyAssignment['busId'] ==
                              selectedRoute['busId'];
                    }).map((doc) {
                      return {
                        ...doc.data(),
                        'id': doc.id,
                      };
                    }).toList();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _attendanceStream,
                      builder: (context, attendanceSnapshot) {
                        if (attendanceSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading attendance: '
                              '${attendanceSnapshot.error}',
                            ),
                          );
                        }

                        if (attendanceSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final attendanceRecords =
                            attendanceSnapshot.data ?? [];

                        final attendanceByStudent = {
                          for (final record in attendanceRecords)
                            record['studentDocumentId'].toString(): record,
                        };

                        int present = 0;
                        int absent = 0;

                        for (final student in students) {
                          final record = attendanceByStudent[
                              student['id'].toString()];

                          final status =
                              record?[_eventField]?.toString();

                          if (status == 'present') {
                            present++;
                          } else if (status == 'absent') {
                            absent++;
                          }
                        }

                        final notMarked =
                            students.length - present - absent;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16, 12, 16, 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Students (${students.length})',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: students.isEmpty ||
                                            _isBulkSaving
                                        ? null
                                        : () => _markAllPresent(students),
                                    icon: _isBulkSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.done_all,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _isBulkSaving
                                          ? 'Saving...'
                                          : 'Mark All Present',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  _buildSummaryCard(
                                    'Total',
                                    students.length,
                                    primaryBlue,
                                    Icons.people,
                                  ),
                                  _buildSummaryCard(
                                    'Present',
                                    present,
                                    Colors.green,
                                    Icons.check_circle,
                                  ),
                                  _buildSummaryCard(
                                    'Absent',
                                    absent,
                                    Colors.red,
                                    Icons.cancel,
                                  ),
                                  _buildSummaryCard(
                                    'Not Marked',
                                    notMarked,
                                    Colors.orange,
                                    Icons.pending_actions,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: students.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No active students are assigned '
                                        'to this route.',
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: students.length,
                                      itemBuilder: (context, index) {
                                        final student = students[index];

                                        final record =
                                            attendanceByStudent[
                                                student['id'].toString()];

                                        return _buildStudentCard(
                                          student,
                                          record,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          title: const Text('Student Attendance'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _schoolId == null
                ? const Center(
                    child: Text(
                      'Unable to load your school assignment.',
                    ),
                  )
                : _buildAttendanceContent(),
      ),
    );
  }
}
