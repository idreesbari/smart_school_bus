
import 'package:flutter/material.dart';

import '../services/bus_service.dart';
import 'add_bus_screen.dart';
import 'edit_bus_screen.dart';

class BusesScreen extends StatefulWidget {
  const BusesScreen({super.key});

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final BusService _busService = BusService();
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addBus() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddBusScreen(),
      ),
    );
  }

  Future<void> _editBus(Map<String, dynamic> bus) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBusScreen(
          documentId: bus['id'],
          busData: bus,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterBuses(
    List<Map<String, dynamic>> buses,
  ) {
    if (_searchQuery.isEmpty) return buses;

    final query = _searchQuery.toLowerCase();

    return buses.where((bus) {
      return [
        bus['busId'],
        bus['registrationNumber'],
        bus['manufacturer'],
        bus['model'],
        bus['driverName'],
        bus['driverId'],
        bus['assistantName'],
        bus['assistantId'],
        bus['schoolName'],
        bus['schoolId'],
      ].any(
        (value) =>
            value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Future<void> _deleteBus(Map<String, dynamic> bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text(
          'Are you sure you want to delete bus ${bus['busId']}?',
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
      await _busService.deleteBus(bus['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Widget _busCard(Map<String, dynamic> bus) {
    final isActive = bus['isActive'] == true;

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
          '${bus['busId'] ?? '-'} - ${bus['registrationNumber'] ?? '-'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model: ${bus['manufacturer'] ?? ''} ${bus['model'] ?? ''}',
              ),
              Text(
                'School: ${bus['schoolName'] ?? bus['schoolId'] ?? '-'}',
              ),
              Text('Driver: ${bus['driverName'] ?? 'Not assigned'}'),
              Text(
                'Assistant: ${bus['assistantName'] ?? 'Not assigned'}',
              ),
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
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit Bus',
              icon: const Icon(
                Icons.edit_outlined,
                color: primaryBlue,
              ),
              onPressed: () => _editBus(bus),
            ),
            IconButton(
              tooltip: 'Delete Bus',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: () => _deleteBus(bus),
            ),
          ],
        ),
      ),
    );
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
            'No buses found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Buses will appear here once added.',
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
        hintText: 'Search buses...',
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
        onPressed: _addBus,
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
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
        title: const Text('Bus Management'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buses',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage buses registered in the Smart Bus system.',
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
                  stream: _busService.getBuses(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading buses:\n${snapshot.error}',
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

                    final allBuses = snapshot.data ?? [];
                    final buses = _filterBuses(allBuses);

                    if (buses.isEmpty) {
                      return _emptyState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Buses: ${allBuses.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Expanded(
                          child: ListView.builder(
                            itemCount: buses.length,
                            itemBuilder: (context, index) {
                              return _busCard(buses[index]);
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
