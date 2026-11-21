
import 'package:flutter/material.dart';

class StudentRouteDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> studentData;

  const StudentRouteDetailsScreen({
    super.key,
    required this.studentData,
  });

  static const Color primaryBlue = Color(0xFF2563EB);

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : '-',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyCard({
    required String title,
    required Map<String, dynamic>? assignment,
    required IconData icon,
  }) {
    if (assignment == null || assignment.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text('$title route has not been assigned yet.'),
        ),
      );
    }

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
            Row(
              children: [
                Icon(icon, color: primaryBlue),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),

            const Text(
              'Route Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _detailRow('Route Name', assignment['routeName']),
            _detailRow('Route Code', assignment['routeCode']),

            const Divider(height: 25),

            const Text(
              'Transport Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _detailRow('Bus', assignment['busName']),
            _detailRow('Driver', assignment['driverName']),
            _detailRow('Assistant', assignment['assistantName']),

            const Divider(height: 25),

            const Text(
              'Pickup Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _detailRow('Pickup Stop', assignment['pickupStopName']),
            _detailRow('Address', assignment['pickupAddress']),
            _detailRow('Pickup Time', assignment['pickupTime']),

            const Divider(height: 25),

            const Text(
              'Drop-off Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _detailRow('Drop-off Stop', assignment['dropoffStopName']),
            _detailRow('Address', assignment['dropoffAddress']),
            _detailRow('Drop-off Time', assignment['dropoffTime']),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignments =
        studentData['routeAssignments'] as Map<String, dynamic>? ?? {};

    final morning =
        assignments['morning'] as Map<String, dynamic>? ?? {};

    final afternoon =
        assignments['afternoon'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Student Route Details'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                studentData['fullName'] ?? 'Student',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Student ID: ${studentData['studentId'] ?? '-'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 22),

              _journeyCard(
                title: 'Morning Journey',
                assignment: morning,
                icon: Icons.wb_sunny_outlined,
              ),

              _journeyCard(
                title: 'Afternoon Journey',
                assignment: afternoon,
                icon: Icons.wb_twilight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
