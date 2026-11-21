
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/driver_service.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _driverService = DriverService();

  final _driverId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nationality = TextEditingController();
  final _cnic = TextEditingController();
  final _licence = TextEditingController();
  final _address = TextEditingController();
  final _busId = TextEditingController();

  List<Map<String, dynamic>> _schools = [];

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  DateTime? _licenceExpiry;

  bool _isLoading = false;
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
          throw Exception(
            'Assigned school is inactive or unavailable.',
          );
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
              .compareTo(
                (b['schoolName'] ?? '').toString(),
              ),
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

  Future<void> _pickExpiryDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _licenceExpiry ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (selectedDate != null) {
      setState(() {
        _licenceExpiry = selectedDate;
      });
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school.')),
      );
      return;
    }

    if (_licenceExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Licence expiry date is required.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final driverId = await _driverService.addDriver({
        'schoolId': _selectedSchoolId,
        'schoolName': _selectedSchoolName,
        'driverId': _driverId.text.trim(),
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'nationality': _nationality.text.trim(),
        'cnic': _cnic.text.trim(),
        'licenceNumber': _licence.text.trim(),
        'licenceExpiry': Timestamp.fromDate(_licenceExpiry!),
        'address': _address.text.trim(),
        'busId': _busId.text.trim(),
        'isActive': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver added: $driverId')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _schoolDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedSchoolId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Select School',
          border: OutlineInputBorder(),
        ),
        items: _schools.map((school) {
          return DropdownMenuItem<String>(
            value: school['id'] as String,
            child: Text(
              school['schoolName']?.toString() ?? '',
            ),
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
        decoration: const InputDecoration(
          labelText: 'Assigned School',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Color(0xFFF1F5F9),
          suffixIcon: Icon(Icons.lock_outline),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool numericOnly = false,
    bool emailValidation = false,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: numericOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return optional ? null : '$label is required';
          }

          if (numericOnly &&
              !RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
            return '$label must contain numbers only';
          }

          if (emailValidation &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(value.trim())) {
            return 'Enter a valid email address';
          }

          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _driverId.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _nationality.dispose();
    _cnic.dispose();
    _licence.dispose();
    _address.dispose();
    _busId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Add Driver'),
        backgroundColor: Colors.white,
      ),
      body: _isLoadingSchools
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 650),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Driver Information',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (_isSchoolAdmin)
                          _assignedSchoolField()
                        else
                          _schoolDropdown(),

                        _field(
                          'Driver ID',
                          _driverId,
                          keyboardType: TextInputType.number,
                          numericOnly: true,
                        ),

                        _field('Full Name', _name),

                        _field(
                          'Email',
                          _email,
                          keyboardType: TextInputType.emailAddress,
                          emailValidation: true,
                        ),

                        _field(
                          'Phone Number',
                          _phone,
                          keyboardType: TextInputType.phone,
                          numericOnly: true,
                        ),

                        _field('Nationality', _nationality),

                        _field('CNIC / National ID', _cnic),

                        _field(
                          'Driving Licence Number',
                          _licence,
                        ),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: FormField<DateTime>(
                            validator: (_) {
                              if (_licenceExpiry == null) {
                                return 'Licence expiry date is required';
                              }
                              return null;
                            },
                            builder: (field) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      await _pickExpiryDate();
                                      field.didChange(_licenceExpiry);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText:
                                            'Licence Expiry Date',
                                        border:
                                            const OutlineInputBorder(),
                                        errorText: field.errorText,
                                        suffixIcon: const Icon(
                                          Icons.calendar_month,
                                        ),
                                      ),
                                      child: Text(
                                        _licenceExpiry == null
                                            ? 'Select expiry date'
                                            : '${_licenceExpiry!.day.toString().padLeft(2, '0')}/'
                                                '${_licenceExpiry!.month.toString().padLeft(2, '0')}/'
                                                '${_licenceExpiry!.year}',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        _field('Address', _address),

                        _field(
                          'Assigned Bus ID (Optional)',
                          _busId,
                          optional: true,
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading || _schools.isEmpty
                                ? null
                                : _saveDriver,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text('SAVE DRIVER'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
