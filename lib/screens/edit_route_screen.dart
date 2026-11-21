
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/route_service.dart';
import '../services/bus_service.dart';
import '../services/driver_service.dart';
import '../services/assistant_service.dart';

class EditRouteScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> routeData;

  const EditRouteScreen({
    super.key,
    required this.documentId,
    required this.routeData,
  });

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final _formKey = GlobalKey<FormState>();

  final _routeNameController = TextEditingController();
  final _routeCodeController = TextEditingController();

  final RouteService _routeService = RouteService();
  final BusService _busService = BusService();
  final DriverService _driverService = DriverService();
  final AssistantService _assistantService = AssistantService();

  final List<Map<String, dynamic>> _stops = [];

  List<Map<String, dynamic>> _schools = [];

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  String? _selectedBusId;
  String? _selectedBusName;

  String? _selectedDriverId;
  String? _selectedDriverName;

  String? _selectedAssistantId;
  String? _selectedAssistantName;

  String _journeyType = 'morning';

  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isSchoolAdmin = false;

  @override
  void initState() {
    super.initState();

    _loadRouteDetails();
  }

  void _loadRouteDetails() {
    final data = widget.routeData;

    _routeNameController.text =
        data['routeName']?.toString() ?? '';

    _routeCodeController.text =
        data['routeCode']?.toString() ?? '';

    _selectedSchoolId = data['schoolId']?.toString();
    _selectedSchoolName = data['schoolName']?.toString();

    _selectedBusId = data['busId']?.toString();
    _selectedBusName = data['busName']?.toString();

    _selectedDriverId = data['driverId']?.toString();
    _selectedDriverName = data['driverName']?.toString();

    _selectedAssistantId = data['assistantId']?.toString();
    _selectedAssistantName = data['assistantName']?.toString();

    _journeyType = data['journeyType']?.toString() ?? 'morning';
    _isActive = data['isActive'] == true;

    final existingStops = data['stops'] as List? ?? [];

    for (final item in existingStops) {
      final stop = Map<String, dynamic>.from(item as Map);

      _stops.add({
        'name': TextEditingController(
          text: stop['stopName']?.toString() ?? '',
        ),
        'address': TextEditingController(
          text: stop['address']?.toString() ?? '',
        ),
        'notes': TextEditingController(
          text: stop['notes']?.toString() ?? '',
        ),
        'time': _parseTime(stop['pickupTime']?.toString()),
      });
    }

    if (_stops.isEmpty) {
      _addStop();
    }

    _loadUserAndSchools();
  }

  TimeOfDay _parseTime(String? value) {
    if (value == null || value.isEmpty) {
      return const TimeOfDay(hour: 7, minute: 0);
    }

    try {
      final parts = value.trim().split(' ');
      final timeParts = parts[0].split(':');

      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (parts.length > 1) {
        final period = parts[1].toUpperCase();

        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  Future<void> _loadUserAndSchools() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User is not logged in.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found.');
      }

      final userData = userDoc.data()!;

      if (userData['isActive'] != true) {
        throw Exception('Your account is inactive.');
      }

      final role = userData['role'];

      if (role != 'mainAdmin' &&
          role != 'admin' &&
          role != 'schoolAdmin') {
        throw Exception('You are not authorized.');
      }

      if (role == 'schoolAdmin') {
        _isSchoolAdmin = true;

        final schoolId = userData['schoolId']?.toString();

        if (schoolId == null || schoolId.isEmpty) {
          throw Exception('No school assigned to this account.');
        }

        if (schoolId != _selectedSchoolId) {
          throw Exception('You cannot edit another school\'s route.');
        }

        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();

        if (!schoolDoc.exists ||
            schoolDoc.data()?['isActive'] != true) {
          throw Exception('Assigned school is inactive or unavailable.');
        }

        _schools = [
          {
            'id': schoolDoc.id,
            ...schoolDoc.data()!,
          }
        ];

        _selectedSchoolId = schoolDoc.id;
        _selectedSchoolName =
            schoolDoc.data()?['schoolName']?.toString();
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('schools')
            .where('isActive', isEqualTo: true)
            .get();

        _schools = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        _schools.sort(
          (a, b) => (a['schoolName'] ?? '')
              .toString()
              .compareTo((b['schoolName'] ?? '').toString()),
        );

        final selectedSchool = _schools.where(
          (school) => school['id'] == _selectedSchoolId,
        );

        if (selectedSchool.isNotEmpty) {
          _selectedSchoolName =
              selectedSchool.first['schoolName']?.toString();
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error loading route: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addStop() {
    setState(() {
      _stops.add({
        'name': TextEditingController(),
        'address': TextEditingController(),
        'time': const TimeOfDay(hour: 7, minute: 0),
        'notes': TextEditingController(),
      });
    });
  }

  void _disposeStop(Map<String, dynamic> stop) {
    (stop['name'] as TextEditingController).dispose();
    (stop['address'] as TextEditingController).dispose();
    (stop['notes'] as TextEditingController).dispose();
  }

  void _removeStop(int index) {
    if (_stops.length <= 1) return;

    setState(() {
      final stop = _stops.removeAt(index);
      _disposeStop(stop);
    });
  }

  void _moveStop(int index, int direction) {
    final newIndex = index + direction;

    if (newIndex < 0 || newIndex >= _stops.length) return;

    setState(() {
      final stop = _stops.removeAt(index);
      _stops.insert(newIndex, stop);
    });
  }

  Future<void> _selectStopTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _stops[index]['time'] as TimeOfDay,
    );

    if (picked != null && mounted) {
      setState(() {
        _stops[index]['time'] = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<void> _updateRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSchoolId == null) {
      _showMessage('Please select a school.');
      return;
    }

    if (_selectedBusId == null ||
        _selectedDriverId == null ||
        _selectedAssistantId == null) {
      _showMessage('Please select bus, driver and assistant.');
      return;
    }

    final stops = <Map<String, dynamic>>[];

    for (int i = 0; i < _stops.length; i++) {
      final stop = _stops[i];

      final name =
          (stop['name'] as TextEditingController).text.trim();

      final address =
          (stop['address'] as TextEditingController).text.trim();

      if (name.isEmpty || address.isEmpty) {
        _showMessage('Please complete all stop details.');
        return;
      }

      stops.add({
        'stopName': name,
        'address': address,
        'pickupTime': _formatTime(stop['time'] as TimeOfDay),
        'notes':
            (stop['notes'] as TextEditingController).text.trim(),
        'sequence': i + 1,
      });
    }

    setState(() => _isSaving = true);

    try {
      await _routeService.updateRoute(
        widget.documentId,
        {
          'schoolId': _selectedSchoolId,
          'schoolName': _selectedSchoolName,
          'routeName': _routeNameController.text.trim(),
          'routeCode': _routeCodeController.text.trim(),
          'journeyType': _journeyType,
          'busId': _selectedBusId,
          'busName': _selectedBusName,
          'driverId': _selectedDriverId,
          'driverName': _selectedDriverName,
          'assistantId': _selectedAssistantId,
          'assistantName': _selectedAssistantName,
          'stops': stops,
          'isActive': _isActive,
        },
      );

      if (!mounted) return;

      _showMessage('Route updated successfully.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Update failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _routeCodeController.dispose();

    for (final stop in _stops) {
      _disposeStop(stop);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Edit Route',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Route Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_isSchoolAdmin)
                            _assignedSchoolField()
                          else
                            _schoolDropdown(),

                          _textField(
                            _routeNameController,
                            'Route Name',
                          ),

                          _textField(
                            _routeCodeController,
                            'Route Code',
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Journey Type',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          DropdownButtonFormField<String>(
                            value: _journeyType,
                            decoration: _decoration('Journey Type'),
                            items: const [
                              DropdownMenuItem(
                                value: 'morning',
                                child: Text('Morning - Home to School'),
                              ),
                              DropdownMenuItem(
                                value: 'afternoon',
                                child: Text('Afternoon - School to Home'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _journeyType = value);
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Bus Assignment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildBusDropdown(),

                          const SizedBox(height: 18),

                          const Text(
                            'Driver Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildDriverDropdown(),

                          const SizedBox(height: 18),

                          const Text(
                            'Assistant Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildAssistantDropdown(),

                          const SizedBox(height: 28),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Route Stops',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addStop,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Stop'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          ...List.generate(
                            _stops.length,
                            (index) => _stopCard(index),
                          ),

                          const SizedBox(height: 16),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active Route'),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ||
                                      _schools.isEmpty ||
                                      _selectedSchoolId == null
                                  ? null
                                  : _updateRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text('Update Route'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBusDropdown() {
    if (_selectedSchoolId == null) {
      return const Text('Select a school first.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('edit_route_buses_$_selectedSchoolId'),
      stream: _busService.getBuses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load buses.');
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final buses = snapshot.data!
            .where((b) =>
                b['isActive'] == true &&
                b['schoolId'] == _selectedSchoolId)
            .toList();

        return DropdownButtonFormField<String>(
          value: buses.any((b) => b['id'] == _selectedBusId)
              ? _selectedBusId
              : null,
          isExpanded: true,
          decoration: _decoration('Select Bus'),
          items: buses.map((bus) {
            return DropdownMenuItem<String>(
              value: bus['id'] as String,
              child: Text(
                '${bus['busId']} - ${bus['registrationNumber']}',
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            final selected =
                buses.firstWhere((b) => b['id'] == value);

            setState(() {
              _selectedBusId = value;
              _selectedBusName = selected['busId']?.toString();
            });
          },
          validator: (value) =>
              value == null ? 'Please select a bus' : null,
        );
      },
    );
  }

  Widget _buildDriverDropdown() {
    if (_selectedSchoolId == null) {
      return const Text('Select a school first.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('edit_route_drivers_$_selectedSchoolId'),
      stream: _driverService.getDrivers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load drivers.');
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final drivers = snapshot.data!
            .where((d) =>
                d['isActive'] == true &&
                d['schoolId'] == _selectedSchoolId)
            .toList();

        return DropdownButtonFormField<String>(
          value: drivers.any((d) => d['id'] == _selectedDriverId)
              ? _selectedDriverId
              : null,
          isExpanded: true,
          decoration: _decoration('Select Driver'),
          items: drivers.map((driver) {
            return DropdownMenuItem<String>(
              value: driver['id'] as String,
              child: Text(
                '${driver['fullName']} (${driver['driverId']})',
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            final selected =
                drivers.firstWhere((d) => d['id'] == value);

            setState(() {
              _selectedDriverId = value;
              _selectedDriverName =
                  selected['fullName']?.toString();
            });
          },
          validator: (value) =>
              value == null ? 'Please select a driver' : null,
        );
      },
    );
  }

  Widget _buildAssistantDropdown() {
    if (_selectedSchoolId == null) {
      return const Text('Select a school first.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('edit_route_assistants_$_selectedSchoolId'),
      stream: _assistantService.getAssistants(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load assistants.');
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final assistants = snapshot.data!
            .where((a) =>
                a['isActive'] == true &&
                a['schoolId'] == _selectedSchoolId)
            .toList();

        return DropdownButtonFormField<String>(
          value: assistants.any(
                  (a) => a['id'] == _selectedAssistantId)
              ? _selectedAssistantId
              : null,
          isExpanded: true,
          decoration: _decoration('Select Assistant'),
          items: assistants.map((assistant) {
            return DropdownMenuItem<String>(
              value: assistant['id'] as String,
              child: Text(
                '${assistant['fullName']} (${assistant['assistantId']})',
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            final selected =
                assistants.firstWhere((a) => a['id'] == value);

            setState(() {
              _selectedAssistantId = value;
              _selectedAssistantName =
                  selected['fullName']?.toString();
            });
          },
          validator: (value) =>
              value == null ? 'Please select an assistant' : null,
        );
      },
    );
  }

  Widget _stopCard(int index) {
    final stop = _stops[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stop ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: index == 0
                    ? null
                    : () => _moveStop(index, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: index == _stops.length - 1
                    ? null
                    : () => _moveStop(index, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              if (_stops.length > 1)
                IconButton(
                  tooltip: 'Remove stop',
                  onPressed: () => _removeStop(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          _textField(
            stop['name'] as TextEditingController,
            'Stop Name',
          ),

          _textField(
            stop['address'] as TextEditingController,
            'Stop Address',
          ),

          InkWell(
            onTap: () => _selectStopTime(index),
            child: InputDecorator(
              decoration: _decoration('Pickup Time'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(stop['time'] as TimeOfDay),
                  ),
                  const Icon(Icons.access_time),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: stop['notes'] as TextEditingController,
            decoration: _decoration('Notes (Optional)'),
          ),
        ],
      ),
    );
  }

  Widget _schoolDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedSchoolId,
        isExpanded: true,
        decoration: _decoration('Select School'),
        items: _schools.map((school) {
          return DropdownMenuItem<String>(
            value: school['id'] as String,
            child: Text(school['schoolName']?.toString() ?? ''),
          );
        }).toList(),
        onChanged: (value) {
          final selected =
              _schools.firstWhere((school) => school['id'] == value);

          setState(() {
            _selectedSchoolId = value;
            _selectedSchoolName =
                selected['schoolName']?.toString();

            _selectedBusId = null;
            _selectedBusName = null;

            _selectedDriverId = null;
            _selectedDriverName = null;

            _selectedAssistantId = null;
            _selectedAssistantName = null;
          });
        },
        validator: (value) =>
            value == null ? 'Please select a school' : null,
      ),
    );
  }

  Widget _assignedSchoolField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _selectedSchoolName ?? '',
        readOnly: true,
        decoration: _decoration('Assigned School').copyWith(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          suffixIcon: const Icon(Icons.lock_outline),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: _decoration(label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }

          return null;
        },
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }
}
