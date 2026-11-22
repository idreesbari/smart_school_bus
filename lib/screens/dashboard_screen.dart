
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'schools_screen.dart';
import 'login_screen.dart';
import 'students_screen.dart';
import 'assistants_screen.dart';
import 'drivers_screen.dart';
import 'buses_screen.dart';
import 'routes_screen.dart';
import 'driver_attendance_screen.dart';
import 'attendance_reports_screen.dart';
import 'school_calendar_screen.dart';
import 'transfer_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF4F7FC);

  Future<Map<String, dynamic>> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      throw Exception('User profile not found.');
    }

    final data = doc.data()!;

    if (data['isActive'] != true) {
      throw Exception('Your account is inactive.');
    }

    final role = data['role'];

    if (![
      'mainAdmin',
      'admin',
      'schoolAdmin',
      'driver',
      'assistant',
    ].contains(role)) {
      throw Exception('Invalid user role.');
    }

    if (role == 'schoolAdmin' &&
        (data['schoolId'] == null ||
            data['schoolId'].toString().isEmpty)) {
      throw Exception('No school assigned to this account.');
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profileSnapshot.hasError || !profileSnapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text(
                profileSnapshot.error?.toString() ??
                    'Unable to load user profile.',
              ),
            ),
          );
        }

        final profile = profileSnapshot.data!;
        final role = profile['role'];

        final isMainAdmin =
            role == 'mainAdmin' || role == 'admin';

        final isSchoolAdmin = role == 'schoolAdmin';
        final isDriver = role == 'driver';
        final isAssistant = role == 'assistant';

        final isStaff = isDriver || isAssistant;

        final schoolId = profile['schoolId']?.toString();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 750;

            return Scaffold(
              backgroundColor: backgroundColor,
              drawer: isWide
                  ? null
                  : Drawer(
                      backgroundColor: Colors.white,
                      child: SafeArea(
                        child: _buildSidebar(
                          context,
                          isMainAdmin,
                          isSchoolAdmin,
                          isStaff,
                        ),
                      ),
                    ),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: Text(
                  isStaff
                      ? 'Smart Bus Management'
                      : 'Smart Bus Admin',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: primaryBlue,
                    ),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();

                      if (!context.mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: Row(
                children: [
                  if (isWide)
                    Container(
                      width: 220,
                      color: Colors.white,
                      child: _buildSidebar(
                        context,
                        isMainAdmin,
                        isSchoolAdmin,
                        isStaff,
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: isStaff
                          ? _buildStaffDashboard(
                              context,
                              isDriver,
                            )
                          : _buildAdminDashboard(
                              context,
                              profile,
                              isMainAdmin,
                              schoolId,
                              constraints.maxWidth,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminDashboard(
    BuildContext context,
    Map<String, dynamic> profile,
    bool isMainAdmin,
    String? schoolId,
    double screenWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard Overview',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isMainAdmin
              ? 'Welcome to Smart Bus Management System'
              : 'Welcome to your School Dashboard',
          style: const TextStyle(color: Colors.grey),
        ),
        if (!isMainAdmin) ...[
          const SizedBox(height: 8),
          Text(
            'School: ${profile['schoolName'] ?? 'Assigned School'}',
            style: const TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),
        GridView.count(
          crossAxisCount: screenWidth > 1000
              ? 4
              : screenWidth > 500
                  ? 2
                  : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: screenWidth < 500 ? 2.5 : 1.6,
          children: [
            _FirestoreStatCard(
              title: 'Total Students',
              collection: 'students',
              schoolId: schoolId,
              icon: Icons.school,
              color: const Color(0xFF2563EB),
            ),
            _FirestoreStatCard(
              title: 'Total Drivers',
              collection: 'drivers',
              schoolId: schoolId,
              icon: Icons.person,
              color: const Color(0xFF16A34A),
            ),
            _FirestoreStatCard(
              title: 'Total Assistants',
              collection: 'assistants',
              schoolId: schoolId,
              icon: Icons.support_agent,
              color: const Color(0xFF9333EA),
            ),
            _FirestoreStatCard(
              title: 'Total Buses',
              collection: 'buses',
              schoolId: schoolId,
              icon: Icons.directions_bus,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: Text(
                  'No activities available yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffDashboard(
    BuildContext context,
    bool isDriver,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDriver ? 'Driver Dashboard' : 'Assistant Dashboard',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDriver
              ? 'Welcome to your driver dashboard.'
              : 'Welcome to your bus assistant dashboard.',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fact_check,
                color: primaryBlue,
                size: 38,
              ),
              const SizedBox(height: 16),
              const Text(
                'Student Attendance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'View students assigned to your routes and '
                'mark their attendance for each journey.',
                style: TextStyle(
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DriverAttendanceScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Open Student Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    bool isMainAdmin,
    bool isSchoolAdmin,
    bool isStaff,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        _menuItem(
          context,
          Icons.dashboard,
          'Dashboard',
          true,
        ),
        if (!isStaff) ...[
          if (isMainAdmin)
            _menuItem(
              context,
              Icons.business,
              'Schools',
              false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolsScreen(),
                  ),
                );
              },
            ),
          _menuItem(
            context,
            Icons.school,
            'Students',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentsScreen(),
                ),
              );
            },
          ),
          _menuItem(
            context,
            Icons.person,
            'Bus Drivers',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriversScreen(),
                ),
              );
            },
          ),
          _menuItem(
            context,
            Icons.support_agent,
            'Bus Assistants',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AssistantsScreen(),
                ),
              );
            },
          ),
          _menuItem(
            context,
            Icons.directions_bus,
            'Buses',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusesScreen(),
                ),
              );
            },
          ),
          _menuItem(
            context,
            Icons.route,
            'Routes',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoutesScreen(),
                ),
              );
            },
          ),

          // Transfer Management for School Admin and Main Admin.
          _menuItem(
            context,
            Icons.swap_horiz,
            'Transfer Management',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const TransferManagementScreen(),
                ),
              );
            },
          ),

          if (isSchoolAdmin) ...[
            _menuItem(
              context,
              Icons.assessment,
              'Attendance Reports',
              false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AttendanceReportsScreen(),
                  ),
                );
              },
            ),
            _menuItem(
              context,
              Icons.calendar_month,
              'School Calendar',
              false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const SchoolCalendarScreen(),
                  ),
                );
              },
            ),
          ],

          if (isMainAdmin)
            _menuItem(
              context,
              Icons.assessment,
              'Reports',
              false,
            ),
        ],
        if (isStaff)
          _menuItem(
            context,
            Icons.fact_check,
            'Student Attendance',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const DriverAttendanceScreen(),
                ),
              );
            },
          ),
        if (!isStaff)
          _menuItem(
            context,
            Icons.settings,
            'Settings',
            false,
          ),
      ],
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    bool selected, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFEFF6FF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? primaryBlue : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? primaryBlue : Colors.black87,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// Dashboard Statistics

class _FirestoreStatCard extends StatelessWidget {
  final String title;
  final String collection;
  final String? schoolId;
  final IconData icon;
  final Color color;

  const _FirestoreStatCard({
    required this.title,
    required this.collection,
    required this.schoolId,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Query query =
        FirebaseFirestore.instance.collection(collection);

    if (schoolId != null && schoolId!.isNotEmpty) {
      query = query.where(
        'schoolId',
        isEqualTo: schoolId,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        String value = '...';

        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        } else if (snapshot.hasError) {
          value = 'Error';
        }

        return _StatCard(
          title: title,
          value: value,
          icon: icon,
          color: color,
        );
      },
    );
  }
}

// Statistics Card Design

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
