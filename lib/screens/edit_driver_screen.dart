
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/driver_service.dart';

class EditDriverScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> driverData;

  const EditDriverScreen({
    super.key,
    required this.documentId,
    required this.driverData,
  });

  @override
  State<EditDriverScreen> createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
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
  final _schoolName = TextEditingController();

  DateTime? _licenceExpiry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.driverData;

    _driverId.text = data['driverId']?.toString() ?? '';
    _name.text = data['fullName']?.toString() ?? '';
    _email.text = data['email']?.toString() ?? '';
    _phone.text = data['phone']?.toString() ?? '';
    _nationality.text = data['nationality']?.toString() ?? '';
    _cnic.text = data['cnic']?.toString() ?? '';
    _licence.text = data['licenceNumber']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    _busId.text = data['busId']?.toString() ?? '';

    _schoolName.text =
        data['schoolName']?.toString() ??
        data['schoolId']?.toString() ??
        '';

    final expiry = data['licenceExpiry'];

    if (expiry is Timestamp) {
      _licenceExpiry = expiry.toDate();
    } else if (expiry is DateTime) {
      _licenceExpiry = expiry;
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

  Future<void> _updateDriver() async {
    if (!_formKey.currentState!.validate()) return;

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
      await _driverService.updateDriver(
        widget.documentId,
        {
          'fullName': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'nationality': _nationality.text.trim(),
          'cnic': _cnic.text.trim(),
          'licenceNumber': _licence.text.trim(),
          'licenceExpiry': Timestamp.fromDate(_licenceExpiry!),
          'address': _address.text.trim(),
          'busId': _busId.text.trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver updated successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool numericOnly = false,
    bool emailValidation = false,
    bool optional = false,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: numericOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: readOnly,
          fillColor: readOnly
              ? const Color(0xFFF1F5F9)
              : null,
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline)
              : null,
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
    _schoolName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Edit Driver'),
        backgroundColor: Colors.white,
      ),
      body: Center(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Driver Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_schoolName.text.isNotEmpty)
                    _field(
                      'Assigned School',
                      _schoolName,
                      readOnly: true,
                    ),

                  _field(
                    'Driver ID',
                    _driverId,
                    readOnly: true,
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

                  _field('Driving Licence Number', _licence),

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
                        return InkWell(
                          onTap: () async {
                            await _pickExpiryDate();
                            field.didChange(_licenceExpiry);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Licence Expiry Date',
                              border: const OutlineInputBorder(),
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
                      onPressed: _isLoading ? null : _updateDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('UPDATE DRIVER'),
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
