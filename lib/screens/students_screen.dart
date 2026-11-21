import 'package:flutter/material.dart';

import '../services/student_service.dart';
import 'add_student_screen.dart';
import 'edit_student_screen.dart';
import 'assign_student_route_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final StudentService _studentService = StudentService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddStudentScreen()),
    );
  }

  Future<void> _assignRoute(Map<String, dynamic> student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignStudentRouteScreen(
          studentDocumentId: student['id'],
          studentData: student,
        ),
      ),
    );
  }

  Future<void> _editStudent(Map<String, dynamic> student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditStudentScreen(documentId: student['id'], studentData: student),
      ),
    );
  }

  List<Map<String, dynamic>> _filterStudents(
    List<Map<String, dynamic>> students,
  ) {
    if (_searchQuery.isEmpty) return students;

    final query = _searchQuery.toLowerCase();

    return students.where((student) {
      return [
        student['studentId'],
        student['fullName'],
        student['email'],
        student['schoolName'],
      ].any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student['fullName']}?',
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
      await _studentService.deleteStudent(student['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Widget _studentCard(Map<String, dynamic> student) {
    final isActive = student['isActive'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withValues(alpha: 0.1),
          child: const Icon(Icons.school_outlined, color: primaryBlue),
        ),
        title: Text(
          student['fullName'] ?? 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student ID: ${student['studentId'] ?? '-'}'),
              Text(
                'School: ${student['schoolName'] ?? student['schoolId'] ?? '-'}',
              ),
              Text('Grade: ${student['grade'] ?? '-'}'),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Assign Route',
              icon: const Icon(Icons.alt_route, color: Colors.green),
              onPressed: () => _assignRoute(student),
            ),
            IconButton(
              tooltip: 'Edit Student',
              icon: const Icon(Icons.edit_outlined, color: primaryBlue),
              onPressed: () => _editStudent(student),
            ),
            IconButton(
              tooltip: 'Delete Student',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteStudent(student),
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
          Icon(Icons.school_outlined, size: 55, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No students found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Students will appear here once added.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Students Management'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Students',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage registered students in the Smart Bus system.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                if (!isMobile) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addStudent,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (isMobile) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addStudent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],

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
                  stream: _studentService.getStudents(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading students:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allStudents = snapshot.data ?? [];
                    final students = _filterStudents(allStudents);

                    if (students.isEmpty) {
                      return _emptyState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Students: ${allStudents.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Expanded(
                          child: ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              return _studentCard(students[index]);
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
