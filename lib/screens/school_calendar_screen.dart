
import 'package:flutter/material.dart';

import '../services/school_calendar_service.dart';

class SchoolCalendarScreen extends StatefulWidget {
  const SchoolCalendarScreen({super.key});

  @override
  State<SchoolCalendarScreen> createState() =>
      _SchoolCalendarScreenState();
}

class _SchoolCalendarScreenState extends State<SchoolCalendarScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF4F7FC);

  final SchoolCalendarService _calendarService =
      SchoolCalendarService();

  late DateTime _selectedMonth;
  late Future<Map<String, Map<String, dynamic>>> _calendarFuture;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    _loadCalendar();
  }

  void _loadCalendar() {
    _calendarFuture = _calendarService.getMonthCalendar(
      _selectedMonth.year,
      _selectedMonth.month,
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isError ? 'Error' : 'Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _changeMonth(int difference) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + difference,
      );

      _loadCalendar();
    });
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  bool _isDefaultWorkingDay(DateTime date) {
    return date.weekday != DateTime.friday &&
        date.weekday != DateTime.saturday;
  }

  String _dayType(
    DateTime date,
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final override = calendar[_dateKey(date)];

    if (override != null) {
      return override['dayType']?.toString() ?? 'default';
    }

    return 'default';
  }

  bool _isWorkingDay(
    DateTime date,
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final type = _dayType(date, calendar);

    if (type == 'holiday' || type == 'closed') {
      return false;
    }

    if (type == 'working') {
      return true;
    }

    return _isDefaultWorkingDay(date);
  }

  Future<void> _refreshCalendar() async {
    setState(_loadCalendar);

    try {
      await _calendarFuture;
    } catch (_) {
      // FutureBuilder displays the loading error.
    }
  }

  Future<void> _showDayDialog(
    DateTime date,
    Map<String, dynamic>? existing,
  ) async {
    String selectedType =
        existing?['dayType']?.toString() ?? 'holiday';

    final reasonController = TextEditingController(
      text: existing?['reason']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                '${date.day} ${_monthName(date.month)} ${date.year}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select day type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Holiday'),
                      value: 'holiday',
                      groupValue: selectedType,
                      activeColor: primaryBlue,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('School Closed'),
                      value: 'closed',
                      groupValue: selectedType,
                      activeColor: primaryBlue,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Special Working Day'),
                      value: 'working',
                      groupValue: selectedType,
                      activeColor: primaryBlue,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Enter reason (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      {
                        'dayType': selectedType,
                        'reason': reasonController.text.trim(),
                      },
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (result == null || !mounted) return;

    try {
      await _calendarService.saveCalendarDay(
        date: date,
        dayType: result['dayType']!,
        reason: result['reason'] ?? '',
      );

      if (!mounted) return;

      setState(_loadCalendar);

      _showMessage('School calendar updated successfully.');
    } catch (e) {
      _showMessage(
        'Unable to save calendar entry: $e',
        isError: true,
      );
    }
  }

  Future<void> _removeOverride(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Calendar Override'),
          content: const Text(
            'This will restore the default working-day setting for this date.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _calendarService.deleteCalendarDay(date);

      if (!mounted) return;

      setState(_loadCalendar);

      _showMessage('Calendar override removed.');
    } catch (e) {
      _showMessage(
        'Unable to remove calendar entry: $e',
        isError: true,
      );
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  Color _dayColor(
    DateTime date,
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final type = _dayType(date, calendar);

    switch (type) {
      case 'holiday':
        return Colors.orange.shade100;
      case 'closed':
        return Colors.red.shade100;
      case 'working':
        return Colors.green.shade100;
      default:
        return _isDefaultWorkingDay(date)
            ? Colors.white
            : Colors.grey.shade200;
    }
  }

  Color _dayTextColor(
    DateTime date,
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final type = _dayType(date, calendar);

    switch (type) {
      case 'holiday':
        return Colors.orange.shade900;
      case 'closed':
        return Colors.red.shade900;
      case 'working':
        return Colors.green.shade900;
      default:
        return _isDefaultWorkingDay(date)
            ? Colors.black87
            : Colors.grey.shade600;
    }
  }

  String _dayLabel(
    DateTime date,
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final type = _dayType(date, calendar);

    switch (type) {
      case 'holiday':
        return 'Holiday';
      case 'closed':
        return 'Closed';
      case 'working':
        return 'Working';
      default:
        return _isDefaultWorkingDay(date) ? '' : 'Weekend';
    }
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(
    Map<String, Map<String, dynamic>> calendar,
  ) {
    final firstDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );

    final startingOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    final totalCells =
        ((startingOffset + daysInMonth + 6) ~/ 7) * 7;

    int workingDays = 0;
    int holidays = 0;
    int closures = 0;
    int specialWorkingDays = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        day,
      );

      final type = _dayType(date, calendar);

      if (_isWorkingDay(date, calendar)) {
        workingDays++;
      }

      if (type == 'holiday') holidays++;
      if (type == 'closed') closures++;
      if (type == 'working') specialWorkingDays++;
    }

    return Column(
      children: [
        Row(
          children: [
            _buildSummaryCard(
              'Working Days',
              workingDays,
              Colors.green.shade700,
              Icons.calendar_today,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              'Holidays',
              holidays,
              Colors.orange.shade800,
              Icons.celebration,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              'Closures',
              closures,
              Colors.red.shade700,
              Icons.event_busy,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSummaryCard(
              'Special Working',
              specialWorkingDays,
              Colors.blue.shade700,
              Icons.event_available,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            'Sun',
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
          ].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - startingOffset + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              _selectedMonth.year,
              _selectedMonth.month,
              dayNumber,
            );

            final key = _dateKey(date);
            final existing = calendar[key];
            final type = _dayType(date, calendar);
            final isToday = _dateKey(DateTime.now()) == key;

            return InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _showDayDialog(date, existing),
              onLongPress: existing == null
                  ? null
                  : () => _removeOverride(date),
              child: Container(
                decoration: BoxDecoration(
                  color: _dayColor(date, calendar),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isToday
                        ? primaryBlue
                        : Colors.grey.shade300,
                    width: isToday ? 2 : 0.7,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _dayTextColor(date, calendar),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (type != 'default')
                      Icon(
                        type == 'holiday'
                            ? Icons.celebration
                            : type == 'closed'
                                ? Icons.event_busy
                                : Icons.event_available,
                        size: 13,
                        color: _dayTextColor(date, calendar),
                      )
                    else if (!_isDefaultWorkingDay(date))
                      Icon(
                        Icons.weekend,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _dayLabel(date, calendar),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        color: _dayTextColor(date, calendar),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            _buildLegend(Colors.white, 'Working'),
            _buildLegend(Colors.grey.shade200, 'Weekend'),
            _buildLegend(Colors.orange.shade100, 'Holiday'),
            _buildLegend(Colors.red.shade100, 'Closed'),
            _buildLegend(Colors.green.shade100, 'Special Working'),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Tap a date to add or edit an exception. Long-press a date with an override to remove it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'School Calendar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshCalendar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _calendarFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load school calendar.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(_loadCalendar);
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final calendar = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                        color: primaryBlue,
                      ),
                      Expanded(
                        child: Text(
                          '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                        color: primaryBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCalendar(calendar),
              ],
            ),
          );
        },
      ),
    );
  }
}
