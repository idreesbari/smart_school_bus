
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState
    extends State<AttendanceReportsScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF4F7FC);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String? _schoolId;

  bool _isLoading = true;
  bool _isExporting = false;

  DateTime _selectedDate = DateTime.now();

  String _journey = 'morning';
  String _event = 'pickup';
  String _selectedRouteId = 'all';

  List<Map<String, dynamic>> _routes = [];

  Map<String, Map<String, dynamic>> _students = {};

  Stream<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;

  String get _dateKey {
    final year = _selectedDate.year.toString().padLeft(4, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String get _eventField => '${_event}Status';

  String get _eventTitle {
    switch (_event) {
      case 'pickup':
        return 'Morning Pickup';
      case 'schoolArrival':
        return 'School Arrival';
      case 'boarding':
        return 'Afternoon Boarding';
      case 'dropoff':
        return 'Afternoon Drop-off';
      default:
        return 'Attendance';
    }
  }

  List<Map<String, dynamic>> get _journeyRoutes {
    return _routes.where((route) {
      return route['journeyType'] == _journey;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    try {
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

      if (profile['isActive'] != true) {
        throw Exception('Your account is inactive.');
      }

      if (profile['role'] != 'schoolAdmin') {
        throw Exception(
          'Only School Admin can access this report.',
        );
      }

      final schoolId = profile['schoolId']?.toString() ?? '';

      if (schoolId.isEmpty) {
        throw Exception('School assignment not found.');
      }

      final routeSnapshot = await _firestore
          .collection('routes')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final routes = routeSnapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'id': doc.id,
        };
      }).toList();

      routes.sort((a, b) {
        return (a['routeCode'] ?? '')
            .toString()
            .compareTo((b['routeCode'] ?? '').toString());
      });

      final studentSnapshot = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final students = <String, Map<String, dynamic>>{};

      for (final doc in studentSnapshot.docs) {
        students[doc.id] = {
          ...doc.data(),
          'id': doc.id,
        };
      }

      if (!mounted) return;

      setState(() {
        _schoolId = schoolId;
        _routes = routes;
        _students = students;
        _isLoading = false;
        _updateAttendanceStream();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateAttendanceStream() {
    if (_schoolId == null) {
      _attendanceStream = null;
      return;
    }

    _attendanceStream = _firestore
        .collection('attendance')
        .where('schoolId', isEqualTo: _schoolId)
        .where('date', isEqualTo: _dateKey)
        .where('journey', isEqualTo: _journey)
        .snapshots();
  }

  void _changeJourney(String? value) {
    if (value == null) return;

    setState(() {
      _journey = value;
      _event = value == 'morning' ? 'pickup' : 'boarding';
      _selectedRouteId = 'all';

      _updateAttendanceStream();
    });
  }

  void _changeEvent(String? value) {
    if (value == null) return;

    setState(() {
      _event = value;
    });
  }

  void _changeRoute(String? value) {
    if (value == null) return;

    setState(() {
      _selectedRouteId = value;
    });
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = selected;
      _updateAttendanceStream();
    });
  }

  // ------------------------------------------
  // EXPORT ATTENDANCE TO EXCEL
  // ------------------------------------------

  Future<void> _exportToExcel() async {
    if (_schoolId == null || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Get attendance records for selected date and journey.
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('schoolId', isEqualTo: _schoolId)
          .where('date', isEqualTo: _dateKey)
          .where('journey', isEqualTo: _journey)
          .get();

      final attendanceByStudent =
          <String, Map<String, dynamic>>{};

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();

        if (_selectedRouteId != 'all' &&
            data['routeId'] != _selectedRouteId) {
          continue;
        }

        final studentId =
            data['studentDocumentId']?.toString() ?? '';

        if (studentId.isNotEmpty) {
          attendanceByStudent[studentId] = data;
        }
      }

      // Find students assigned to the selected journey and route.
      final assignedStudents = _students.values.where((student) {
        if (student['isActive'] != true) return false;

        final assignments =
            student['routeAssignments'] as Map<String, dynamic>? ?? {};

        final journeyAssignment =
            assignments[_journey] as Map<String, dynamic>? ?? {};

        if (_selectedRouteId != 'all') {
          return journeyAssignment['routeId'] == _selectedRouteId;
        }

        return journeyAssignment['routeId'] != null;
      }).toList();

      assignedStudents.sort((a, b) {
        return (a['fullName'] ?? '')
            .toString()
            .compareTo((b['fullName'] ?? '').toString());
      });

      int present = 0;
      int absent = 0;
      int notMarked = 0;

      // Create Excel workbook.
      final excel = Excel.createExcel();

      final sheet = excel['Attendance Report'];

      // Report heading.
      sheet.appendRow([
        TextCellValue('DAILY ATTENDANCE REPORT'),
      ]);

      sheet.appendRow([
        TextCellValue('School ID'),
        TextCellValue(_schoolId ?? ''),
      ]);

      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue(_dateKey),
      ]);

      sheet.appendRow([
        TextCellValue('Journey'),
        TextCellValue(
          _journey == 'morning' ? 'Morning' : 'Afternoon',
        ),
      ]);

      sheet.appendRow([
        TextCellValue('Event'),
        TextCellValue(_eventTitle),
      ]);

      String routeName = 'All Routes';

      if (_selectedRouteId != 'all') {
        final selectedRoute = _routes.firstWhere(
          (route) => route['id'] == _selectedRouteId,
          orElse: () => {},
        );

        routeName =
            '${selectedRoute['routeName'] ?? 'Selected Route'} '
            '(${selectedRoute['routeCode'] ?? ''})';
      }

      sheet.appendRow([
        TextCellValue('Route'),
        TextCellValue(routeName),
      ]);

      sheet.appendRow([
        TextCellValue(''),
      ]);

      // Student table headings.
      sheet.appendRow([
        TextCellValue('No.'),
        TextCellValue('Student Name'),
        TextCellValue('Student ID'),
        TextCellValue('Route'),
        TextCellValue('Attendance Status'),
      ]);

      // Student attendance records.
      int serialNumber = 1;

      for (final student in assignedStudents) {
        final studentId = student['id'].toString();

        final attendance = attendanceByStudent[studentId];

        final status =
            attendance?[_eventField]?.toString() ?? 'notMarked';

        String statusLabel;

        if (status == 'present') {
          present++;
          statusLabel = 'Present';
        } else if (status == 'absent') {
          absent++;
          statusLabel = 'Absent';
        } else {
          notMarked++;
          statusLabel = 'Not Marked';
        }

        final assignments =
            student['routeAssignments'] as Map<String, dynamic>? ?? {};

        final journeyAssignment =
            assignments[_journey] as Map<String, dynamic>? ?? {};

        final studentRouteName =
            journeyAssignment['routeName']?.toString() ?? '-';

        sheet.appendRow([
          IntCellValue(serialNumber),
          TextCellValue(
            student['fullName']?.toString() ?? 'Unknown Student',
          ),
          TextCellValue(
            student['studentId']?.toString() ?? '-',
          ),
          TextCellValue(studentRouteName),
          TextCellValue(statusLabel),
        ]);

        serialNumber++;
      }

      // Summary section.
      sheet.appendRow([
        TextCellValue(''),
      ]);

      sheet.appendRow([
        TextCellValue('ATTENDANCE SUMMARY'),
      ]);

      sheet.appendRow([
        TextCellValue('Total Students'),
        IntCellValue(assignedStudents.length),
      ]);

      sheet.appendRow([
        TextCellValue('Present'),
        IntCellValue(present),
      ]);

      sheet.appendRow([
        TextCellValue('Absent'),
        IntCellValue(absent),
      ]);

      sheet.appendRow([
        TextCellValue('Not Marked'),
        IntCellValue(notMarked),
      ]);

      // Save workbook to temporary directory.
      final bytes = excel.save();

      if (bytes == null) {
        throw Exception('Unable to generate Excel file.');
      }

      final directory = await getTemporaryDirectory();

      final safeDate = _dateKey.replaceAll('-', '');

      final fileName =
          'Attendance_${_journey}_${safeDate}.xlsx';

      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      // Open system sharing options.
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report - $_dateKey - $_eventTitle',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
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
            vertical: 16,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(
    Map<String, dynamic> attendance,
  ) {
    final studentId =
        attendance['studentDocumentId']?.toString() ?? '';

    final student = _students[studentId];

    final status =
        attendance[_eventField]?.toString() ?? 'notMarked';

    final isPresent = status == 'present';
    final isAbsent = status == 'absent';

    final statusColor = isPresent
        ? Colors.green
        : isAbsent
            ? Colors.red
            : Colors.orange;

    final statusLabel = isPresent
        ? 'Present'
        : isAbsent
            ? 'Absent'
            : 'Not Marked';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withValues(alpha: 0.1),
          child: const Icon(
            Icons.person,
            color: primaryBlue,
          ),
        ),
        title: Text(
          student?['fullName']?.toString() ?? 'Unknown Student',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Student ID: ${student?['studentId'] ?? '-'}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load attendance: ${snapshot.error}',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final records = snapshot.data?.docs ?? [];

        final filteredRecords = records.where((doc) {
          if (_selectedRouteId == 'all') return true;

          return doc.data()['routeId'] == _selectedRouteId;
        }).toList();

        final attendanceByStudent =
            <String, Map<String, dynamic>>{};

        for (final doc in filteredRecords) {
          final data = doc.data();
          final studentId =
              data['studentDocumentId']?.toString() ?? '';

          if (studentId.isNotEmpty) {
            attendanceByStudent[studentId] = data;
          }
        }

        final assignedStudents = _students.values.where((student) {
          if (student['isActive'] != true) return false;

          final assignments =
              student['routeAssignments'] as Map<String, dynamic>? ?? {};

          final journeyAssignment =
              assignments[_journey] as Map<String, dynamic>? ?? {};

          if (_selectedRouteId != 'all') {
            return journeyAssignment['routeId'] == _selectedRouteId;
          }

          return journeyAssignment['routeId'] != null;
        }).toList();

        int present = 0;
        int absent = 0;

        for (final student in assignedStudents) {
          final record = attendanceByStudent[student['id']];

          final status = record?[_eventField]?.toString();

          if (status == 'present') {
            present++;
          } else if (status == 'absent') {
            absent++;
          }
        }

        final notMarked =
            assignedStudents.length - present - absent;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Total',
                    assignedStudents.length,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Student Attendance (${assignedStudents.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${((present + absent) / (assignedStudents.isEmpty ? 1 : assignedStudents.length) * 100).round()}% Marked',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: assignedStudents.isEmpty
                  ? const Center(
                      child: Text(
                        'No students are assigned to this route.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: assignedStudents.length,
                      itemBuilder: (context, index) {
                        final student = assignedStudents[index];

                        final attendance =
                            attendanceByStudent[student['id']];

                        return _buildStudentRow(
                          attendance ??
                              {
                                'studentDocumentId': student['id'],
                                _eventField: 'notMarked',
                              },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = _journeyRoutes;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Daily Attendance Report'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            onPressed: _isLoading || _isExporting
                ? null
                : _exportToExcel,
            icon: _isExporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.file_download,
                    color: primaryBlue,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _schoolId == null
              ? const Center(
                  child: Text('School assignment not found.'),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Report Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_month),
                              ),
                              child: Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                                '${_selectedDate.year}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _journey,
                            decoration: const InputDecoration(
                              labelText: 'Journey',
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
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedRouteId,
                            decoration: const InputDecoration(
                              labelText: 'Route',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All Routes'),
                              ),
                              ...routes.map((route) {
                                return DropdownMenuItem<String>(
                                  value: route['id'].toString(),
                                  child: Text(
                                    '${route['routeName'] ?? 'Route'} '
                                    '(${route['routeCode'] ?? ''})',
                                  ),
                                );
                              }),
                            ],
                            onChanged: _changeRoute,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildReportContent(),
                    ),
                  ],
                ),
    );
  }
}
