
import 'package:flutter/material.dart';

class RouteDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> routeData;

  const RouteDetailsScreen({
    super.key,
    required this.routeData,
  });

  static const Color primaryBlue = Color(0xFF2563EB);

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : '-',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStops(List stops) {
    if (stops.isEmpty) {
      return const Text('No stops added to this route.');
    }

    return Column(
      children: List.generate(stops.length, (index) {
        final stop = Map<String, dynamic>.from(stops[index] as Map);

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: primaryBlue,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (index != stops.length - 1)
                    Container(
                      width: 2,
                      height: 65,
                      color: Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop['stopName']?.toString() ?? 'Unnamed Stop',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stop['address']?.toString() ?? '-',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: primaryBlue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stop['pickupTime']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if ((stop['notes'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Notes: ${stop['notes']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = routeData['stops'] as List? ?? [];
    final isActive = routeData['isActive'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Route Details'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _infoCard('Route Information', [
                _infoRow('Route Name', routeData['routeName']),
                _infoRow('Route Code', routeData['routeCode']),
                _infoRow('Journey', routeData['journeyType']),
                _infoRow('School', routeData['schoolName'] ?? routeData['schoolId']),
                _infoRow('Status', isActive ? 'Active' : 'Inactive'),
              ]),
              _infoCard('Assigned Vehicle and Staff', [
                _infoRow('Bus', routeData['busName']),
                _infoRow('Bus ID', routeData['busId']),
                _infoRow('Driver', routeData['driverName']),
                _infoRow('Driver ID', routeData['driverId']),
                _infoRow('Assistant', routeData['assistantName']),
                _infoRow('Assistant ID', routeData['assistantId']),
              ]),
              _infoCard('Route Stops (${stops.length})', [
                _buildStops(stops),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
