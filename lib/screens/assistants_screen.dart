
import 'package:flutter/material.dart';

import '../services/assistant_service.dart';
import 'add_assistant_screen.dart';
import 'edit_assistant_screen.dart';

class AssistantsScreen extends StatefulWidget {
  const AssistantsScreen({super.key});

  @override
  State<AssistantsScreen> createState() => _AssistantsScreenState();
}

class _AssistantsScreenState extends State<AssistantsScreen> {
  static const Color primaryBlue = Color(0xFF2563EB);

  final AssistantService _assistantService = AssistantService();
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addAssistant() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddAssistantScreen(),
      ),
    );
  }

  Future<void> _editAssistant(
    Map<String, dynamic> assistant,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAssistantScreen(
          documentId: assistant['id'],
          assistantData: assistant,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAssistants(
    List<Map<String, dynamic>> assistants,
  ) {
    if (_searchQuery.isEmpty) return assistants;

    final query = _searchQuery.toLowerCase();

    return assistants.where((assistant) {
      return [
        assistant['assistantId'],
        assistant['fullName'],
        assistant['email'],
        assistant['phone'],
        assistant['nationality'],
        assistant['schoolName'],
        assistant['schoolId'],
      ].any(
        (value) =>
            value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Widget _assistantCard(Map<String, dynamic> assistant) {
    final isActive = assistant['isActive'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withValues(alpha: 0.1),
          child: const Icon(
            Icons.support_agent_outlined,
            color: primaryBlue,
          ),
        ),
        title: Text(
          assistant['fullName'] ?? 'Unknown Assistant',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assistant ID: ${assistant['assistantId'] ?? '-'}'),
              Text('Phone: ${assistant['phone'] ?? '-'}'),
              Text('Nationality: ${assistant['nationality'] ?? '-'}'),
              Text(
                'Assigned School: ${assistant['schoolName'] ?? assistant['schoolId'] ?? '-'}',
              ),
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
              tooltip: 'Edit Assistant',
              icon: const Icon(
                Icons.edit_outlined,
                color: primaryBlue,
              ),
              onPressed: () => _editAssistant(assistant),
            ),
            IconButton(
              tooltip: 'Delete Assistant',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: () => _deleteAssistant(assistant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAssistant(
    Map<String, dynamic> assistant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assistant'),
        content: Text(
          'Are you sure you want to delete ${assistant['fullName']}?',
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
      await _assistantService.deleteAssistant(assistant['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assistant deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.support_agent_outlined,
            size: 55,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No assistants found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Assistants will appear here once added.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search assistants...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _addButton({bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: _addAssistant,
        icon: const Icon(Icons.add),
        label: const Text('Add Assistant'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Assistants Management'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Assistants',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage registered bus assistants in the Smart Bus system.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 550) {
                  return Column(
                    children: [
                      _searchField(),
                      const SizedBox(height: 12),
                      _addButton(fullWidth: true),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 12),
                    _addButton(),
                  ],
                );
              },
            ),

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
                  stream: _assistantService.getAssistants(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading assistants:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final allAssistants = snapshot.data ?? [];
                    final assistants =
                        _filterAssistants(allAssistants);

                    if (assistants.isEmpty) {
                      return _emptyState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Assistants: ${allAssistants.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Expanded(
                          child: ListView.builder(
                            itemCount: assistants.length,
                            itemBuilder: (context, index) {
                              return _assistantCard(
                                assistants[index],
                              );
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
