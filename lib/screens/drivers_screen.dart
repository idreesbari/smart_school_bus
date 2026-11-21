
import 'package:flutter/material.dart';

import '../services/driver_service.dart';
import 'add_driver_screen.dart';
import 'edit_driver_screen.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final DriverService _driverService = DriverService();
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addDriver() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDriverScreen(),
      ),
    );
  }

  Future<void> _editDriver(
    Map<String, dynamic> driver,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDriverScreen(
          documentId: driver['id'],
          driverData: driver,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterDrivers(
    List<Map<String, dynamic>> drivers,
  ) {
    if (_searchQuery.isEmpty) return drivers;

    final query = _searchQuery.toLowerCase();

    return drivers.where((driver) {
      return [
        driver['driverId'],
        driver['fullName'],
        driver['email'],
        driver['phone'],
        driver['nationality'],
        driver['busId'],
        driver['schoolName'],
        driver['schoolId'],
      ].any(
        (value) =>
            value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Widget _driverCard(Map<String, dynamic> driver) {
    final isActive = driver['isActive'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withValues(alpha: 0.1),
          child: const Icon(
            Icons.directions_bus_outlined,
            color: primaryBlue,
          ),
        ),
        title: Text(
          driver['fullName'] ?? 'Unknown Driver',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Driver ID: ${driver['driverId'] ?? '-'}'),
              Text('Phone: ${driver['phone'] ?? '-'}'),
              Text('Nationality: ${driver['nationality'] ?? '-'}'),
              Text(
                'Assigned School: ${driver['schoolName'] ?? driver['schoolId'] ?? '-'}',
              ),
              Text('Assigned Bus: ${driver['busId'] ?? '-'}'),
              const SizedBox(height: 6),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit Driver',
              icon: const Icon(
                Icons.edit_outlined,
                color: primaryBlue,
              ),
              onPressed: () => _editDriver(driver),
            ),
            IconButton(
              tooltip: 'Delete Driver',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: () => _deleteDriver(driver),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDriver(
    Map<String, dynamic> driver,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text(
          'Are you sure you want to delete ${driver['fullName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _driverService.deleteDriver(driver['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 55,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No drivers found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Drivers will appear here once added.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search drivers...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _addButton({bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: _addDriver,
        icon: const Icon(Icons.add),
        label: const Text('Add Driver'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Drivers Management'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drivers',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage registered drivers in the Smart Bus system.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 550) {
                  return Column(
                    children: [
                      _searchField(),
                      const SizedBox(height: 12),
                      _addButton(fullWidth: true),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 12),
                    _addButton(),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _driverService.getDrivers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading drivers:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final allDrivers = snapshot.data ?? [];
                    final drivers = _filterDrivers(allDrivers);

                    if (drivers.isEmpty) {
                      return _emptyState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Drivers: ${allDrivers.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Expanded(
                          child: ListView.builder(
                            itemCount: drivers.length,
                            itemBuilder: (context, index) {
                              return _driverCard(drivers[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
