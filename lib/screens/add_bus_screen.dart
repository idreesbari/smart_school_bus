
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/bus_service.dart';
import '../services/driver_service.dart';
import '../services/assistant_service.dart';

class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final _formKey = GlobalKey<FormState>();

  final _busIdController = TextEditingController();
  final _registrationController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();

  final BusService _busService = BusService();
  final DriverService _driverService = DriverService();
  final AssistantService _assistantService = AssistantService();

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  String? _selectedDriverId;
  String? _selectedAssistantId;
  String? _selectedDriverName;
  String? _selectedAssistantName;

  List<Map<String, dynamic>> _schools = [];

  DateTime? _insuranceExpiry;
  DateTime? _fitnessExpiry;

  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoadingSchools = true;
  bool _isSchoolAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndSchools();
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schools: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSchools = false);
      }
    }
  }

  Future<void> _selectDate(bool isInsurance) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        if (isInsurance) {
          _insuranceExpiry = picked;
        } else {
          _fitnessExpiry = picked;
        }
      });
    }
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school.')),
      );
      return;
    }

    if (_selectedDriverId == null ||
        _selectedAssistantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both driver and assistant.'),
        ),
      );
      return;
    }

    if (_insuranceExpiry == null || _fitnessExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both expiry dates.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _busService.addBus({
        'schoolId': _selectedSchoolId,
        'schoolName': _selectedSchoolName,
        'busId': _busIdController.text.trim(),
        'registrationNumber': _registrationController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'model': _modelController.text.trim(),
        'seatingCapacity': int.parse(_capacityController.text.trim()),
        'driverId': _selectedDriverId,
        'driverName': _selectedDriverName,
        'assistantId': _selectedAssistantId,
        'assistantName': _selectedAssistantName,
        'insuranceExpiry': Timestamp.fromDate(_insuranceExpiry!),
        'fitnessExpiry': Timestamp.fromDate(_fitnessExpiry!),
        'isActive': _isActive,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus added successfully.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _busIdController.dispose();
    _registrationController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Add New Bus',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: _isLoadingSchools
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
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
                            'Bus Information',
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

                          _textField(_busIdController, 'Bus ID'),
                          _textField(
                            _registrationController,
                            'Registration Number',
                          ),
                          _textField(
                            _manufacturerController,
                            'Manufacturer',
                          ),
                          _textField(_modelController, 'Bus Model'),
                          _textField(
                            _capacityController,
                            'Seating Capacity',
                            isNumber: true,
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Assigned Driver',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 8),

                          _selectedSchoolId == null
                              ? const Text('Select a school first.')
                              : StreamBuilder<List<Map<String, dynamic>>>(
                                  key: ValueKey(
                                    'drivers_$_selectedSchoolId',
                                  ),
                                  stream: _driverService.getDrivers(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                        'Unable to load drivers.',
                                      );
                                    }

                                    if (!snapshot.hasData) {
                                      return const LinearProgressIndicator();
                                    }

                                    final drivers = snapshot.data!
                                        .where((d) =>
                                            d['isActive'] == true &&
                                            d['schoolId'] ==
                                                _selectedSchoolId)
                                        .toList();

                                    if (drivers.isEmpty) {
                                      return const Text(
                                        'No active drivers found for this school.',
                                      );
                                    }

                                    return DropdownButtonFormField<String>(
                                      value: _selectedDriverId,
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
                                        final selected = drivers.firstWhere(
                                          (d) => d['id'] == value,
                                        );

                                        setState(() {
                                          _selectedDriverId = value;
                                          _selectedDriverName =
                                              selected['fullName']?.toString();
                                        });
                                      },
                                      validator: (value) => value == null
                                          ? 'Please select a driver'
                                          : null,
                                    );
                                  },
                                ),

                          const SizedBox(height: 18),

                          const Text(
                            'Bus Assistant',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 8),

                          _selectedSchoolId == null
                              ? const Text('Select a school first.')
                              : StreamBuilder<List<Map<String, dynamic>>>(
                                  key: ValueKey(
                                    'assistants_$_selectedSchoolId',
                                  ),
                                  stream: _assistantService.getAssistants(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                        'Unable to load assistants.',
                                      );
                                    }

                                    if (!snapshot.hasData) {
                                      return const LinearProgressIndicator();
                                    }

                                    final assistants = snapshot.data!
                                        .where((a) =>
                                            a['isActive'] == true &&
                                            a['schoolId'] ==
                                                _selectedSchoolId)
                                        .toList();

                                    if (assistants.isEmpty) {
                                      return const Text(
                                        'No active assistants found for this school.',
                                      );
                                    }

                                    return DropdownButtonFormField<String>(
                                      value: _selectedAssistantId,
                                      isExpanded: true,
                                      decoration: _decoration(
                                        'Select Bus Assistant',
                                      ),
                                      items: assistants.map((assistant) {
                                        return DropdownMenuItem<String>(
                                          value: assistant['id'] as String,
                                          child: Text(
                                            '${assistant['fullName']} (${assistant['assistantId']})',
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        final selected = assistants.firstWhere(
                                          (a) => a['id'] == value,
                                        );

                                        setState(() {
                                          _selectedAssistantId = value;
                                          _selectedAssistantName =
                                              selected['fullName']?.toString();
                                        });
                                      },
                                      validator: (value) => value == null
                                          ? 'Please select an assistant'
                                          : null,
                                    );
                                  },
                                ),

                          const SizedBox(height: 18),

                          _dateField(
                            'Insurance Expiry Date',
                            _insuranceExpiry,
                            () => _selectDate(true),
                          ),

                          _dateField(
                            'Fitness Certificate Expiry Date',
                            _fitnessExpiry,
                            () => _selectDate(false),
                          ),

                          const SizedBox(height: 16),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active Bus'),
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
                              onPressed: _isSaving || _schools.isEmpty
                                  ? null
                                  : _saveBus,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text('Save Bus'),
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
          final selected = _schools.firstWhere(
            (school) => school['id'] == value,
          );

          setState(() {
            _selectedSchoolId = value;
            _selectedSchoolName =
                selected['schoolName']?.toString();

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
    String label, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
        decoration: _decoration(label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }

          if (isNumber && int.tryParse(value.trim()) == null) {
            return 'Enter a valid number';
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

  Widget _dateField(
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _decoration(label),
          child: Text(
            date == null
                ? 'Select date'
                : '${date.day}/${date.month}/${date.year}',
          ),
        ),
      ),
    );
  }
}
