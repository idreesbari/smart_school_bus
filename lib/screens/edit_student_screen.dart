
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/student_service.dart';

class EditStudentScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> studentData;

  const EditStudentScreen({
    super.key,
    required this.documentId,
    required this.studentData,
  });

  @override
  State<EditStudentScreen> createState() =>
      _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();

  late final TextEditingController _studentId;
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _parentName;
  late final TextEditingController _parentPhone;
  late final TextEditingController _school;
  late final TextEditingController _grade;
  late final TextEditingController _address;
  late final TextEditingController _routeId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.studentData;

    _studentId = TextEditingController(
      text: data['studentId']?.toString() ?? '',
    );

    _name = TextEditingController(text: data['fullName'] ?? '');
    _email = TextEditingController(text: data['email'] ?? '');
    _phone = TextEditingController(text: data['phone'] ?? '');
    _parentName = TextEditingController(text: data['parentName'] ?? '');
    _parentPhone = TextEditingController(text: data['parentPhone'] ?? '');
    _school = TextEditingController(text: data['schoolName'] ?? '');
    _grade = TextEditingController(text: data['grade'] ?? '');
    _address = TextEditingController(text: data['address'] ?? '');
    _routeId = TextEditingController(text: data['routeId'] ?? '');
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _studentService.updateStudent(
        widget.documentId,
        {
          'fullName': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'parentName': _parentName.text.trim(),
          'parentPhone': _parentPhone.text.trim(),
          'schoolName': _school.text.trim(),
          'grade': _grade.text.trim(),
          'address': _address.text.trim(),
          'routeId': _routeId.text.trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully'),
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
          filled: readOnly,
          fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline)
              : null,
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
        title: const Text('Edit Student'),
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
                    'Student Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _field('Student ID', _studentId, readOnly: true),

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

                  _field('School Name', _school, readOnly: true),

                  _field('Class / Grade', _grade),
                  _field('Home Address', _address),
                  _field('Assigned Route ID', _routeId),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('UPDATE STUDENT'),
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
