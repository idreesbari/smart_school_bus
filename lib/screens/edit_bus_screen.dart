
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/bus_service.dart';
import '../services/driver_service.dart';
import '../services/assistant_service.dart';

class EditBusScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> busData;

  const EditBusScreen({
    super.key,
    required this.documentId,
    required this.busData,
  });

  @override
  State<EditBusScreen> createState() => _EditBusScreenState();
}

class _EditBusScreenState extends State<EditBusScreen> {
  final _formKey = GlobalKey<FormState>();

  final _busIdController = TextEditingController();
  final _registrationController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();

  final BusService _busService = BusService();
  final DriverService _driverService = DriverService();
  final AssistantService _assistantService = AssistantService();

  String? _schoolId;
  String? _schoolName;

  String? _selectedDriverId;
  String? _selectedAssistantId;
  String? _selectedDriverName;
  String? _selectedAssistantName;

  DateTime? _insuranceExpiry;
  DateTime? _fitnessExpiry;

  bool _isActive = true;
  bool _isSaving = false;

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  void initState() {
    super.initState();

    final bus = widget.busData;

    _schoolId = bus['schoolId']?.toString();
    _schoolName = bus['schoolName']?.toString();

    _busIdController.text = bus['busId']?.toString() ?? '';
    _registrationController.text =
        bus['registrationNumber']?.toString() ?? '';
    _manufacturerController.text =
        bus['manufacturer']?.toString() ?? '';
    _modelController.text = bus['model']?.toString() ?? '';
    _capacityController.text =
        bus['seatingCapacity']?.toString() ?? '';

    _selectedDriverId = bus['driverId']?.toString();
    _selectedAssistantId = bus['assistantId']?.toString();

    _selectedDriverName = bus['driverName']?.toString();
    _selectedAssistantName = bus['assistantName']?.toString();

    _insuranceExpiry = _readDate(bus['insuranceExpiry']);
    _fitnessExpiry = _readDate(bus['fitnessExpiry']);

    _isActive = bus['isActive'] == true;

    if ((_schoolName == null || _schoolName!.isEmpty) &&
        _schoolId != null) {
      _loadSchoolName();
    }
  }

  Future<void> _loadSchoolName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .get();

      if (mounted && doc.exists) {
        setState(() {
          _schoolName = doc.data()?['schoolName']?.toString();
        });
      }
    } catch (_) {
      // Keep the school ID visible if the school name cannot be loaded.
    }
  }

  Future<void> _selectDate(bool isInsurance) async {
    final currentDate =
        isInsurance ? _insuranceExpiry : _fitnessExpiry;

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
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

  Future<void> _updateBus() async {
    if (!_formKey.currentState!.validate()) return;

    if (_schoolId == null || _schoolId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This bus has no school assigned.'),
        ),
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
      await _busService.updateBus(widget.documentId, {
        'busId': _busIdController.text.trim(),
        'registrationNumber': _registrationController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'model': _modelController.text.trim(),
        'seatingCapacity': int.parse(
          _capacityController.text.trim(),
        ),
        'driverId': _selectedDriverId,
        'driverName': _selectedDriverName,
        'assistantId': _selectedAssistantId,
        'assistantName': _selectedAssistantName,
        'insuranceExpiry': Timestamp.fromDate(_insuranceExpiry!),
        'fitnessExpiry': Timestamp.fromDate(_fitnessExpiry!),
        'isActive': _isActive,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus updated successfully.'),
        ),
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
          'Edit Bus',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: SingleChildScrollView(
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

                    _schoolField(),

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

                    StreamBuilder<List<Map<String, dynamic>>>(
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
                                d['schoolId'] == _schoolId &&
                                (d['isActive'] == true ||
                                    d['id'] == _selectedDriverId))
                            .toList();

                        final selectedExists = drivers.any(
                          (d) => d['id'] == _selectedDriverId,
                        );

                        return DropdownButtonFormField<String>(
                          value: selectedExists
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
                            final selected = drivers.firstWhere(
                              (d) => d['id'] == value,
                            );

                            setState(() {
                              _selectedDriverId = value;
                              _selectedDriverName =
                                  selected['fullName']?.toString();
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Select a driver' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Bus Assistant',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    StreamBuilder<List<Map<String, dynamic>>>(
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
                                a['schoolId'] == _schoolId &&
                                (a['isActive'] == true ||
                                    a['id'] == _selectedAssistantId))
                            .toList();

                        final selectedExists = assistants.any(
                          (a) => a['id'] == _selectedAssistantId,
                        );

                        return DropdownButtonFormField<String>(
                          value: selectedExists
                              ? _selectedAssistantId
                              : null,
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
                              ? 'Select an assistant'
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
                        onPressed: _isSaving ? null : _updateBus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Update Bus'),
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

  Widget _schoolField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(_schoolName),
        initialValue: _schoolName?.isNotEmpty == true
            ? _schoolName
            : (_schoolId ?? 'School not assigned'),
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
