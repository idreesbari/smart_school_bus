
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/assistant_service.dart';

class AddAssistantScreen extends StatefulWidget {
  const AddAssistantScreen({super.key});

  @override
  State<AddAssistantScreen> createState() => _AddAssistantScreenState();
}

class _AddAssistantScreenState extends State<AddAssistantScreen> {
  final _formKey = GlobalKey<FormState>();
  final AssistantService _assistantService = AssistantService();

  final _assistantIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();

  String? _role;
  String? _selectedSchoolId;
  List<Map<String, dynamic>> _schools = [];

  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  static const Color primaryBlue = Color(0xFF2563EB);

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

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!profile.exists) {
        throw Exception('User profile not found.');
      }

      final data = profile.data()!;
      final role = data['role']?.toString();

      if (role != 'mainAdmin' &&
          role != 'admin' &&
          role != 'schoolAdmin') {
        throw Exception('You are not authorized.');
      }

      List<Map<String, dynamic>> schools = [];
      String? selectedSchoolId;

      if (role == 'schoolAdmin') {
        selectedSchoolId = data['schoolId']?.toString();

        if (selectedSchoolId == null ||
            selectedSchoolId.isEmpty) {
          throw Exception('No school assigned to this account.');
        }

        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(selectedSchoolId)
            .get();

        if (!schoolDoc.exists ||
            schoolDoc.data()?['isActive'] != true) {
          throw Exception('Assigned school is inactive or unavailable.');
        }

        schools.add({
          'id': schoolDoc.id,
          ...schoolDoc.data()!,
        });
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('schools')
            .where('isActive', isEqualTo: true)
            .get();

        schools = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        schools.sort((a, b) =>
            (a['schoolName'] ?? '')
                .toString()
                .compareTo((b['schoolName'] ?? '').toString()));
      }

      if (!mounted) return;

      setState(() {
        _role = role;
        _schools = schools;
        _selectedSchoolId = selectedSchoolId;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading schools: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _onSchoolChanged(String? schoolId) {
    setState(() {
      _selectedSchoolId = schoolId;
    });
  }

  Future<void> _saveAssistant() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSchoolId == null ||
        _selectedSchoolId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _assistantService.addAssistant({
        'assistantId': _assistantIdController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'address': _addressController.text.trim(),
        'schoolId': _selectedSchoolId,
        'isActive': _isActive,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assistant added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSchoolDropdown() {
    if (_role == 'schoolAdmin') {
      final schoolName = _schools.isNotEmpty
          ? _schools.first['schoolName']?.toString() ?? ''
          : '';

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: schoolName,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Assigned School',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            suffixIcon: const Icon(Icons.lock_outline),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedSchoolId,
        decoration: InputDecoration(
          labelText: 'Select School',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        items: _schools.map((school) {
          return DropdownMenuItem<String>(
            value: school['id'].toString(),
            child: Text(
              school['schoolName']?.toString() ?? '',
            ),
          );
        }).toList(),
        onChanged: _onSchoolChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a school';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: primaryBlue,
              width: 2,
            ),
          ),
        ),
        validator: (value) {
          if (requiredField &&
              (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _assistantIdController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Add Bus Assistant'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoadingProfile
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assistant Information',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildSchoolDropdown(),

                            _buildTextField(
                              label: 'Assistant ID',
                              controller: _assistantIdController,
                              keyboardType: TextInputType.number,
                            ),
                            _buildTextField(
                              label: 'Full Name',
                              controller: _fullNameController,
                            ),
                            _buildTextField(
                              label: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _buildTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildTextField(
                              label: 'Nationality',
                              controller: _nationalityController,
                            ),
                            _buildTextField(
                              label: 'CNIC / ID Number',
                              controller: _cnicController,
                            ),
                            _buildTextField(
                              label: 'Address',
                              controller: _addressController,
                              requiredField: false,
                            ),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Active Assistant'),
                              value: _isActive,
                              activeColor: primaryBlue,
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
                                        _schools.isEmpty
                                    ? null
                                    : _saveAssistant,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Save Assistant',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
