
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/transfer_service.dart';

class TransferManagementScreen extends StatefulWidget {
  const TransferManagementScreen({super.key});

  @override
  State<TransferManagementScreen> createState() =>
      _TransferManagementScreenState();
}

class _TransferManagementScreenState
    extends State<TransferManagementScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF4F7FC);

  final TransferService _transferService = TransferService();

  late TabController _tabController;

  bool _isMainAdmin = false;
  bool _isLoading = true;
  String? _errorMessage;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _sentStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _incomingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _allStream;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(
            // The service validates the current authenticated user.
            // Profile role is read here to configure the tabs.
            _currentUid,
          )
          .get();

      if (!profile.exists) {
        throw Exception('User profile not found.');
      }

      final data = profile.data()!;

      if (data['isActive'] != true) {
        throw Exception('Your account is inactive.');
      }

      final role = data['role'];

      if (role == 'mainAdmin' || role == 'admin') {
        _isMainAdmin = true;
        _tabController = TabController(length: 1, vsync: this);

        _allStream = await _transferService.getAllRequests();
      } else if (role == 'schoolAdmin') {
        _tabController = TabController(length: 2, vsync: this);

        _sentStream = await _transferService.getSentRequests();
        _incomingStream =
            await _transferService.getIncomingRequests();
      } else {
        throw Exception(
          'You do not have permission to access Transfer Management.',
        );
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _currentUid {
    // Firebase Authentication is used by TransferService.
    // Importing FirebaseAuth is intentionally avoided here;
    // the profile lookup below is completed using the UID getter.
    return _authUid;
  }

  String get _authUid {
    return _firebaseUserId;
  }

  String get _firebaseUserId {
    return _getAuthenticatedUid();
  }

  String _getAuthenticatedUid() {
    return FirebaseAuthHelper.currentUid;
  }

  @override
  void dispose() {
    if (!_isLoading) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _reviewRequest(
    String requestId,
    String decision,
  ) async {
    final action = decision == 'approved' ? 'approve' : 'reject';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision == 'approved'
              ? 'Approve Transfer Request'
              : 'Reject Transfer Request',
        ),
        content: Text(
          'Are you sure you want to $action this transfer request?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: decision == 'approved'
                  ? primaryBlue
                  : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              decision == 'approved' ? 'Approve' : 'Reject',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _transferService.reviewTransferRequest(
        requestId: requestId,
        decision: decision,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer request ${decision == 'approved' ? 'approved' : 'rejected'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Transfer Management'),
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Transfer Management',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryBlue,
          tabs: _isMainAdmin
              ? const [
                  Tab(text: 'All Requests'),
                ]
              : const [
                  Tab(text: 'Sent Requests'),
                  Tab(text: 'Incoming Requests'),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isMainAdmin
            ? [
                _buildRequestList(
                  _allStream!,
                  showActions: false,
                ),
              ]
            : [
                _buildRequestList(
                  _sentStream!,
                  showActions: false,
                ),
                _buildRequestList(
                  _incomingStream!,
                  showActions: true,
                ),
              ],
      ),
    );
  }

  Widget _buildRequestList(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    required bool showActions,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load transfer requests:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 55,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No transfer requests found.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];

            return _buildRequestCard(
              document.id,
              document.data(),
              showActions: showActions,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
    String requestId,
    Map<String, dynamic> data, {
    required bool showActions,
  }) {
    final entityType =
        (data['entityType'] ?? '').toString();

    final entityId =
        (data['entityId'] ?? '').toString();

    final sourceSchool =
        (data['sourceSchoolId'] ?? '').toString();

    final targetSchool =
        (data['targetSchoolId'] ?? '').toString();

    final status =
        (data['status'] ?? 'pending').toString();

    final isPending = status == 'pending';

    final requestedAt = data['requestedAt'];

    String dateText = 'Not available';

    if (requestedAt is Timestamp) {
      dateText = requestedAt.toDate().toLocal().toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                child: Icon(
                  _entityIcon(entityType),
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _entityLabel(entityType),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Record ID: $entityId',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const Divider(height: 26),
          _detailRow('From School', sourceSchool),
          const SizedBox(height: 8),
          _detailRow('To School', targetSchool),
          const SizedBox(height: 8),
          _detailRow('Requested On', dateText),
          const SizedBox(height: 8),
          _detailRow(
            'Requested By',
            (data['requestedBy'] ?? '').toString(),
          ),
          if (data['reviewedBy'] != null) ...[
            const SizedBox(height: 8),
            _detailRow(
              'Reviewed By',
              data['reviewedBy'].toString(),
            ),
          ],
          if (showActions && isPending) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewRequest(
                      requestId,
                      'rejected',
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reviewRequest(
                      requestId,
                      'approved',
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            const Text(
              'Approved. The record has not been moved yet.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _entityIcon(String type) {
    switch (type) {
      case 'student':
        return Icons.school;
      case 'driver':
        return Icons.person;
      case 'assistant':
        return Icons.support_agent;
      case 'bus':
        return Icons.directions_bus;
      default:
        return Icons.swap_horiz;
    }
  }

  String _entityLabel(String type) {
    switch (type) {
      case 'student':
        return 'Student Transfer';
      case 'driver':
        return 'Driver Transfer';
      case 'assistant':
        return 'Assistant Transfer';
      case 'bus':
        return 'Bus Transfer';
      default:
        return 'Transfer Request';
    }
  }
}

// Small helper to access the currently authenticated user.
class FirebaseAuthHelper {
  static String get currentUid {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }
}
