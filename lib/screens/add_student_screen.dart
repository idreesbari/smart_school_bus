
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/student_service.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();

  final _studentId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _parentName = TextEditingController();
  final _parentPhone = TextEditingController();
  final _school = TextEditingController();
  final _grade = TextEditingController();
  final _address = TextEditingController();
  final _routeId = TextEditingController();

  String? _role;
  String? _selectedSchoolId;

  List<Map<String, dynamic>> _schools = [];

  bool _isLoading = false;
  bool _isLoadingProfile = true;

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

      final profileData = profile.data()!;
      final role = profileData['role']?.toString();

      if (role != 'mainAdmin' &&
          role != 'admin' &&
          role != 'schoolAdmin') {
        throw Exception('You are not authorized.');
      }

      List<Map<String, dynamic>> schools = [];
      String? selectedSchoolId;

      if (role == 'schoolAdmin') {
        selectedSchoolId = profileData['schoolId']?.toString();

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

        if (role == 'schoolAdmin') {
          _selectedSchoolId = selectedSchoolId;
          _school.text =
              schools.first['schoolName']?.toString() ?? '';
        }
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
    if (schoolId == null) return;

    final selectedSchool = _schools.firstWhere(
      (school) => school['id'] == schoolId,
    );

    setState(() {
      _selectedSchoolId = schoolId;
      _school.text = selectedSchool['schoolName']?.toString() ?? '';
    });
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSchoolId == null ||
        _selectedSchoolId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentData = {
        'studentId': _studentId.text.trim(),
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'parentName': _parentName.text.trim(),
        'parentPhone': _parentPhone.text.trim(),
        'schoolName': _school.text.trim(),
        'schoolId': _selectedSchoolId,
        'grade': _grade.text.trim(),
        'address': _address.text.trim(),
        'routeId': _routeId.text.trim(),
        'isActive': true,
      };

      final studentId =
          await _studentService.addStudent(studentData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Student added: $studentId')),
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

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool numericOnly = false,
    bool emailValidation = false,
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
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
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

  Widget _schoolDropdown() {
    if (_role == 'schoolAdmin') {
      return _field(
        'Assigned School',
        _school,
        readOnly: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedSchoolId,
        decoration: const InputDecoration(
          labelText: 'Select School',
          border: OutlineInputBorder(),
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

  @override
  void dispose() {
    _studentId.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _parentName.dispose();
    _parentPhone.dispose();
    _school.dispose();
    _grade.dispose();
    _address.dispose();
    _routeId.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Add Student'),
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
            child: _isLoadingProfile
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Student Information',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _schoolDropdown(),

                        _field(
                          'Student ID',
                          _studentId,
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

                        _field('Parent / Guardian Name', _parentName),

                        _field(
                          'Parent / Guardian Phone',
                          _parentPhone,
                          keyboardType: TextInputType.phone,
                          numericOnly: true,
                        ),

                        _field(
                          'Class / Grade',
                          _grade,
                        ),

                        _field('Home Address', _address),
                        _field('Assigned Route ID', _routeId),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ||
                                    _schools.isEmpty
                                ? null
                                : _saveStudent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text('SAVE STUDENT'),
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
