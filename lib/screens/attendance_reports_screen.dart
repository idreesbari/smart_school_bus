
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

  String _reportType = 'daily';

  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _journey = 'morning';
  String _event = 'pickup';
  String _selectedRouteId = 'all';

  List<Map<String, dynamic>> _routes = [];

  Map<String, Map<String, dynamic>> _students = {};

  Stream<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;

  Future<Map<String, dynamic>>? _monthlyReportFuture;

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String get _dailyDateKey => _dateKey(_selectedDate);
/*
  String get _firstMonthDateKey =>
      _dateKey(DateTime(_selectedMonth.year, _selectedMonth.month, 1));

  String get _lastMonthDateKey =>
      _dateKey(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));
*/
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

  String get _monthTitle {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
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
        _refreshMonthlyReport();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load report: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _updateAttendanceStream() {
    if (_schoolId == null) {
      _attendanceStream = null;
      return;
    }

    _attendanceStream = _firestore
        .collection('attendance')
        .where('schoolId', isEqualTo: _schoolId)
        .where('date', isEqualTo: _dailyDateKey)
        .where('journey', isEqualTo: _journey)
        .snapshots();
  }

  void _refreshMonthlyReport() {
    if (_schoolId == null) {
      _monthlyReportFuture = null;
      return;
    }

    _monthlyReportFuture = _fetchMonthlyReport();
  }

  void _changeReportType(String value) {
    setState(() {
      _reportType = value;
      _refreshMonthlyReport();
    });
  }

  void _changeJourney(String? value) {
    if (value == null) return;

    setState(() {
      _journey = value;
      _event = value == 'morning' ? 'pickup' : 'boarding';
      _selectedRouteId = 'all';

      _updateAttendanceStream();
      _refreshMonthlyReport();
    });
  }

  void _changeEvent(String? value) {
    if (value == null) return;

    setState(() {
      _event = value;
      _refreshMonthlyReport();
    });
  }

  void _changeRoute(String? value) {
    if (value == null) return;

    setState(() {
      _selectedRouteId = value;
      _refreshMonthlyReport();
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

  Future<void> _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select a date in the required month',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedMonth = DateTime(selected.year, selected.month);
      _refreshMonthlyReport();
    });
  }

  // ------------------------------------------
  // STUDENT ASSIGNMENT FILTER
  // ------------------------------------------

  List<Map<String, dynamic>> _getAssignedStudents() {
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

    return assignedStudents;
  }

  // ------------------------------------------
  // MONTHLY REPORT CALCULATION
  // ------------------------------------------

  Future<Map<String, dynamic>> _fetchMonthlyReport() async {
    if (_schoolId == null) {
      throw Exception('School assignment not found.');
    }

    final firstDate =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);

    final lastDate =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final firstKey = _dateKey(firstDate);
    final lastKey = _dateKey(lastDate);

    final calendarSnapshot = await _firestore
        .collection('schoolCalendar')
        .where('schoolId', isEqualTo: _schoolId)
        .where('date', isGreaterThanOrEqualTo: firstKey)
        .where('date', isLessThanOrEqualTo: lastKey)
        .get();

    final calendarOverrides = <String, String>{};

    for (final doc in calendarSnapshot.docs) {
      final data = doc.data();
      final date = data['date']?.toString();
      final dayType = data['dayType']?.toString();

      if (date != null && dayType != null) {
        calendarOverrides[date] = dayType;
      }
    }

    // Friday and Saturday are non-working by default.
    // School Calendar entries can override this.
    final workingDates = <String>[];

    for (int day = 1; day <= lastDate.day; day++) {
      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        day,
      );

      final key = _dateKey(date);
      final override = calendarOverrides[key];

      if (override == 'holiday' || override == 'closed') {
        continue;
      }

      if (override == 'working') {
        workingDates.add(key);
        continue;
      }

      if (date.weekday != DateTime.friday &&
          date.weekday != DateTime.saturday) {
        workingDates.add(key);
      }
    }

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('schoolId', isEqualTo: _schoolId)
        .where('date', isGreaterThanOrEqualTo: firstKey)
        .where('date', isLessThanOrEqualTo: lastKey)
        .where('journey', isEqualTo: _journey)
        .get();

    // Key format: date_studentDocumentId
    final attendanceByDateAndStudent =
        <String, Map<String, dynamic>>{};

    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();

      if (_selectedRouteId != 'all' &&
          data['routeId'] != _selectedRouteId) {
        continue;
      }

      final date = data['date']?.toString() ?? '';
      final studentId =
          data['studentDocumentId']?.toString() ?? '';

      if (date.isNotEmpty && studentId.isNotEmpty) {
        attendanceByDateAndStudent['${date}_$studentId'] = data;
      }
    }

    final assignedStudents = _getAssignedStudents();

    final studentSummaries = <Map<String, dynamic>>[];

    int totalPresent = 0;
    int totalAbsent = 0;
    int totalNotMarked = 0;

    for (final student in assignedStudents) {
      final studentId = student['id'].toString();

      int present = 0;
      int absent = 0;

      for (final date in workingDates) {
        final attendance =
            attendanceByDateAndStudent['${date}_$studentId'];

        final status = attendance?[_eventField]?.toString();

        if (status == 'present') {
          present++;
        } else if (status == 'absent') {
          absent++;
        }
      }

      final notMarked =
          workingDates.length - present - absent;

      final percentage = workingDates.isEmpty
          ? 0.0
          : (present / workingDates.length) * 100;

      totalPresent += present;
      totalAbsent += absent;
      totalNotMarked += notMarked;

      studentSummaries.add({
        ...student,
        'present': present,
        'absent': absent,
        'notMarked': notMarked,
        'percentage': percentage,
      });
    }

    return {
      'workingDates': workingDates,
      'workingDays': workingDates.length,
      'students': studentSummaries,
      'totalStudents': assignedStudents.length,
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalNotMarked': totalNotMarked,
    };
  }

  // ------------------------------------------
  // EXCEL EXPORT
  // ------------------------------------------

  Future<void> _exportToExcel() async {
    if (_schoolId == null || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      if (_reportType == 'monthly') {
        await _exportMonthlyToExcel();
      } else {
        await _exportDailyToExcel();
      }
    } catch (e) {
      _showMessage('Excel export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportDailyToExcel() async {
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('schoolId', isEqualTo: _schoolId)
        .where('date', isEqualTo: _dailyDateKey)
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

    final assignedStudents = _getAssignedStudents();

    int present = 0;
    int absent = 0;
    int notMarked = 0;

    final excel = Excel.createExcel();
    final sheet = excel['Attendance Report'];

    sheet.appendRow([
      TextCellValue('DAILY ATTENDANCE REPORT'),
    ]);

    sheet.appendRow([
      TextCellValue('School ID'),
      TextCellValue(_schoolId ?? ''),
    ]);

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue(_dailyDateKey),
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

    sheet.appendRow([
      TextCellValue('Route'),
      TextCellValue(_selectedRouteName()),
    ]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('No.'),
      TextCellValue('Student Name'),
      TextCellValue('Student ID'),
      TextCellValue('Route'),
      TextCellValue('Attendance Status'),
    ]);

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

      sheet.appendRow([
        IntCellValue(serialNumber),
        TextCellValue(
          student['fullName']?.toString() ?? 'Unknown Student',
        ),
        TextCellValue(student['studentId']?.toString() ?? '-'),
        TextCellValue(
          journeyAssignment['routeName']?.toString() ?? '-',
        ),
        TextCellValue(statusLabel),
      ]);

      serialNumber++;
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('ATTENDANCE SUMMARY')]);

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

    await _saveAndShareExcel(
      excel,
      'Attendance_${_journey}_${_dailyDateKey.replaceAll('-', '')}.xlsx',
      'Attendance Report - $_dailyDateKey - $_eventTitle',
    );
  }

  Future<void> _exportMonthlyToExcel() async {
    final report = await _fetchMonthlyReport();

    final students =
        report['students'] as List<Map<String, dynamic>>;

    final excel = Excel.createExcel();
    final sheet = excel['Monthly Attendance'];

    sheet.appendRow([
      TextCellValue('MONTHLY ATTENDANCE REPORT'),
    ]);

    sheet.appendRow([
      TextCellValue('School ID'),
      TextCellValue(_schoolId ?? ''),
    ]);

    sheet.appendRow([
      TextCellValue('Month'),
      TextCellValue(_monthTitle),
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

    sheet.appendRow([
      TextCellValue('Route'),
      TextCellValue(_selectedRouteName()),
    ]);

    sheet.appendRow([
      TextCellValue('Working Days'),
      IntCellValue(report['workingDays'] as int),
    ]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('No.'),
      TextCellValue('Student Name'),
      TextCellValue('Student ID'),
      TextCellValue('Route'),
      TextCellValue('Present'),
      TextCellValue('Absent'),
      TextCellValue('Not Marked'),
      TextCellValue('Attendance %'),
    ]);

    int serialNumber = 1;

    for (final student in students) {
      final assignments =
          student['routeAssignments'] as Map<String, dynamic>? ?? {};

      final journeyAssignment =
          assignments[_journey] as Map<String, dynamic>? ?? {};

      sheet.appendRow([
        IntCellValue(serialNumber),
        TextCellValue(
          student['fullName']?.toString() ?? 'Unknown Student',
        ),
        TextCellValue(student['studentId']?.toString() ?? '-'),
        TextCellValue(
          journeyAssignment['routeName']?.toString() ?? '-',
        ),
        IntCellValue(student['present'] as int),
        IntCellValue(student['absent'] as int),
        IntCellValue(student['notMarked'] as int),
        TextCellValue(
          '${(student['percentage'] as double).toStringAsFixed(1)}%',
        ),
      ]);

      serialNumber++;
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('MONTHLY SUMMARY')]);

    sheet.appendRow([
      TextCellValue('Total Students'),
      IntCellValue(report['totalStudents'] as int),
    ]);

    sheet.appendRow([
      TextCellValue('Working Days'),
      IntCellValue(report['workingDays'] as int),
    ]);

    sheet.appendRow([
      TextCellValue('Present'),
      IntCellValue(report['totalPresent'] as int),
    ]);

    sheet.appendRow([
      TextCellValue('Absent'),
      IntCellValue(report['totalAbsent'] as int),
    ]);

    sheet.appendRow([
      TextCellValue('Not Marked'),
      IntCellValue(report['totalNotMarked'] as int),
    ]);

    await _saveAndShareExcel(
      excel,
      'Monthly_Attendance_${_journey}_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.xlsx',
      'Monthly Attendance Report - $_monthTitle - $_eventTitle',
    );
  }

  String _selectedRouteName() {
    if (_selectedRouteId == 'all') {
      return 'All Routes';
    }

    final selectedRoute = _routes.firstWhere(
      (route) => route['id'] == _selectedRouteId,
      orElse: () => {},
    );

    return '${selectedRoute['routeName'] ?? 'Selected Route'} '
        '(${selectedRoute['routeCode'] ?? ''})';
  }

  Future<void> _saveAndShareExcel(
    Excel excel,
    String fileName,
    String shareText,
  ) async {
    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('Unable to generate Excel file.');
    }

    final directory = await getTemporaryDirectory();

    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
    );
  }

  // ------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------

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

  Widget _buildStudentRow(Map<String, dynamic> attendance) {
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

  // ------------------------------------------
  // DAILY REPORT CONTENT
  // ------------------------------------------

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

        final assignedStudents = _getAssignedStudents();

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

        final markedPercentage = assignedStudents.isEmpty
            ? 0
            : ((present + absent) / assignedStudents.length * 100)
                .round();

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
                    '$markedPercentage% Marked',
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

  // ------------------------------------------
  // MONTHLY REPORT CONTENT
  // ------------------------------------------

  Widget _buildMonthlyReportContent() {
    if (_monthlyReportFuture == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _monthlyReportFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load monthly report: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final report = snapshot.data!;

        final students =
            report['students'] as List<Map<String, dynamic>>;

        final workingDays = report['workingDays'] as int;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Students',
                              report['totalStudents'] as int,
                              primaryBlue,
                              Icons.people,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryCard(
                              'Working Days',
                              workingDays,
                              Colors.blue,
                              Icons.calendar_month,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Present',
                              report['totalPresent'] as int,
                              Colors.green,
                              Icons.check_circle,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryCard(
                              'Absent',
                              report['totalAbsent'] as int,
                              Colors.red,
                              Icons.cancel,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryCard(
                              'Not Marked',
                              report['totalNotMarked'] as int,
                              Colors.orange,
                              Icons.pending_actions,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Student Monthly Summary (${students.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: students.isEmpty
                  ? const Center(
                      child: Text(
                        'No students are assigned to this route.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];

                        final percentage =
                            student['percentage'] as double;

                        final assignments =
                            student['routeAssignments']
                                as Map<String, dynamic>? ?? {};

                        final assignment =
                            assignments[_journey]
                                as Map<String, dynamic>? ?? {};

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['fullName']
                                                    ?.toString() ??
                                                'Unknown Student',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Student ID: ${student['studentId'] ?? '-'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: percentage >= 75
                                            ? Colors.green
                                            : percentage >= 50
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _monthlyCount(
                                      'Present',
                                      student['present'] as int,
                                      Colors.green,
                                    ),
                                    _monthlyCount(
                                      'Absent',
                                      student['absent'] as int,
                                      Colors.red,
                                    ),
                                    _monthlyCount(
                                      'Not Marked',
                                      student['notMarked'] as int,
                                      Colors.orange,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Route: ${assignment['routeName'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    minHeight: 7,
                                    backgroundColor:
                                        Colors.grey.shade200,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      percentage >= 75
                                          ? Colors.green
                                          : percentage >= 50
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _monthlyCount(
    String title,
    int count,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // FILTERS
  // ------------------------------------------

  Widget _buildFilters(List<Map<String, dynamic>> routes) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _changeReportType('daily'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _reportType == 'daily'
                        ? primaryBlue
                        : Colors.white,
                    foregroundColor: _reportType == 'daily'
                        ? Colors.white
                        : primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Daily Report'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _changeReportType('monthly'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _reportType == 'monthly'
                        ? primaryBlue
                        : Colors.white,
                    foregroundColor: _reportType == 'monthly'
                        ? Colors.white
                        : primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Monthly Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _reportType == 'daily'
                ? _selectDate
                : _selectMonth,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: _reportType == 'daily'
                    ? 'Report Date'
                    : 'Report Month',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_month),
              ),
              child: Text(
                _reportType == 'daily'
                    ? '${_selectedDate.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate.year}'
                    : _monthTitle,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = _journeyRoutes;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _reportType == 'daily'
              ? 'Daily Attendance Report'
              : 'Monthly Attendance Report',
        ),
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
                    _buildFilters(routes),
                    Expanded(
                      child: _reportType == 'daily'
                          ? _buildReportContent()
                          : _buildMonthlyReportContent(),
                    ),
                  ],
                ),
    );
  }
}
