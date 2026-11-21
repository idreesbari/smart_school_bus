
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/assistant_service.dart';

class EditAssistantScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> assistantData;

  const EditAssistantScreen({
    super.key,
    required this.documentId,
    required this.assistantData,
  });

  @override
  State<EditAssistantScreen> createState() =>
      _EditAssistantScreenState();
}

class _EditAssistantScreenState
    extends State<EditAssistantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assistantService = AssistantService();

  final _assistantId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nationality = TextEditingController();
  final _cnic = TextEditingController();
  final _address = TextEditingController();
  final _schoolName = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.assistantData;

    _assistantId.text = data['assistantId']?.toString() ?? '';
    _name.text = data['fullName']?.toString() ?? '';
    _email.text = data['email']?.toString() ?? '';
    _phone.text = data['phone']?.toString() ?? '';
    _nationality.text = data['nationality']?.toString() ?? '';
    _cnic.text = data['cnic']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    _schoolName.text = data['schoolName']?.toString() ?? '';
  }

  Future<void> _updateAssistant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _assistantService.updateAssistant(
        widget.documentId,
        {
          'fullName': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'nationality': _nationality.text.trim(),
          'cnic': _cnic.text.trim(),
          'address': _address.text.trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assistant updated successfully'),
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
    _assistantId.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _nationality.dispose();
    _cnic.dispose();
    _address.dispose();
    _schoolName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Edit Bus Assistant'),
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
                    'Assistant Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _field(
                    'Assistant ID',
                    _assistantId,
                    readOnly: true,
                  ),

                  if (_schoolName.text.isNotEmpty)
                    _field(
                      'School',
                      _schoolName,
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

                  _field('Address', _address),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _updateAssistant,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('UPDATE ASSISTANT'),
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
