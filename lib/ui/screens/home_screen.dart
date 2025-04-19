import 'package:flutter/material.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/ui/screens/doctor/doctor_bookings_screen.dart';
import 'package:happ/ui/screens/doctor/doctor_dashboard_screen.dart';
import 'package:happ/ui/screens/doctor/doctor_profile_screen.dart';
import 'package:happ/ui/screens/doctor/patient_list_screen.dart';
import 'package:happ/ui/screens/notifications/notification_history_screen.dart';
import 'package:happ/ui/screens/patient/doctor_list_screen.dart';
import 'package:happ/ui/screens/patient/my_appointments_screen.dart';
import 'package:happ/ui/screens/patient/patient_dashboard_screen.dart';
import 'package:happ/ui/screens/patient/patient_profile_screen.dart';
import 'package:happ/ui/screens/patient/settings_screen.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/widgets/notification_badge.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/core/models/record.dart' as model;
import 'package:happ/ui/screens/auth/login_screen.dart';
import 'package:happ/ui/screens/records/record_list_screen.dart';
import 'package:happ/ui/screens/scan_document_screen.dart';
import 'package:happ/ui/screens/appointments/appointment_requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recordsProvider = Provider.of<RecordsProvider>(
        context,
        listen: false,
      );
      // Force reload records if not already loaded
      if (!recordsProvider.initialized) {
        _loadRecordsIfNeeded();
      }
    });
  }

  Future<void> _loadRecordsIfNeeded() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recordsProvider = Provider.of<RecordsProvider>(context, listen: false);

      if (authProvider.currentUser != null) {
        print("Loading records from HomeScreen for user ${authProvider.currentUser!.id}");
        // Use the fetchRecordsWithPermissions method
        await recordsProvider.fetchRecordsWithPermissions(
          authProvider.currentUser!.id,
          authProvider.currentUser!.role,
        );
      }
    } catch (e) {
      print("Error loading dashboard data: $e");
      // Don't rethrow to prevent app crashes
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      NavigationService.navigateToAndClearStack(const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final recordsProvider = Provider.of<RecordsProvider>(context);

    final bool isLoading = recordsProvider.isLoading;
    final user = authProvider.currentUser;
    final records = recordsProvider.records;

    // Initialize screens based on user role
    final List<Widget> screens;
    if (authProvider.currentUser?.role == 'doctor') {
      screens = [
        const DoctorDashboardScreen(),
        const PatientListScreen(),
        const AppointmentRequestsScreen(),
        const DoctorProfileScreen(), // Use DoctorProfileScreen for doctors
      ];
    } else {
      screens = [
        const PatientDashboardScreen(),
        const RecordListScreen(),
        const PatientProfileScreen(),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedicoLegal Records'),
        actions: [
          // Add notification icon with badge
          NotificationBadge(
            badgeColor: Theme.of(context).colorScheme.error,
            child: IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationHistoryScreen(),
                  ),
                );
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          if (authProvider.currentUser?.role == 'patient')
            const BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Records'),
          if (authProvider.currentUser?.role == 'doctor')
            const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'My Patients'),
          if (authProvider.currentUser?.role == 'doctor')
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Requests'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     NavigationService.navigateTo(const AddRecordScreen());
      //   },
      //   icon: const Icon(Icons.add),
      //   label: const Text('Add Record'),
      // ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Records'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            // ListTile(
            //   leading: const Icon(Icons.search),
            //   title: const Text('Search'),
            //   onTap: () {
            //     _onItemTapped(2);
            //     Navigator.pop(context);
            //   },
            // ),
            if (authProvider.currentUser?.role == 'patient')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PatientProfileScreen(),
                    ),
                  );
              },
            ),
            if (authProvider.currentUser?.role == 'doctor')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorProfileScreen(),
                    ),
                  );
              },
            ),
            if (authProvider.currentUser?.role == 'doctor')
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('My Patients'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PatientListScreen(),
                    ),
                  );
                },
              ),
            if (authProvider.currentUser?.role == 'patient')
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            if (authProvider.currentUser?.role == 'doctor')
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Appointment Requests'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppointmentRequestsScreen(),
                    ),
                  );
                },
              ),

            if (authProvider.currentUser?.role == 'doctor')
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Confirmed Appointments'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorBookingsScreen(),
                    ),
                  );
                },
              ),

            if (authProvider.currentUser?.role == 'patient')
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Book Appointment'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorListScreen(),
                    ),
                  );
                },
              ),
            if (authProvider.currentUser?.role == 'patient')
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: const Text('My Appointments'),
                subtitle: const Text('View and manage your appointments'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyAppointmentsScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(User? user, List<model.Record> records) {
    final recordsProvider = Provider.of<RecordsProvider>(context);

    // Get record statistics
    final doctorRecords =
        records.where((record) => record.category == 'doctor').length;

    final patientRecords =
        records.where((record) => record.category == 'patient').length;

    final recentRecords = records.take(5).toList();

    return RefreshIndicator(
      onRefresh: _loadRecordsIfNeeded,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        user?.name.isNotEmpty == true
                            ? user!.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name ?? 'User'}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'No email available',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Records Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Statistics cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Doctor Records',
                    doctorRecords.toString(),
                    Colors.blue,
                    Icons.medical_services,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Patient Records',
                    patientRecords.toString(),
                    Colors.amber,
                    Icons.person,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Records',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                TextButton.icon(
                  onPressed: () {
                    _onItemTapped(1); // Navigate to Records tab
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent records list
            recentRecords.isEmpty
                ? const Center(child: Text('No records available'))
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentRecords.length,
                  itemBuilder: (context, index) {
                    final record = recentRecords[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: Icon(
                          record.category == 'doctor'
                              ? Icons.medical_services
                              : Icons.person,
                          color:
                              record.category == 'doctor'
                                  ? Colors.blue
                                  : Colors.amber,
                        ),
                        title: Text(record.title),
                        subtitle: Text(
                          'Date: ${record.formattedDate} • Category: ${record.categoryName}',
                        ),
                        onTap: () {
                          // Navigate to record details
                          NavigationService.navigateTo(
                            RecordDetailScreen(record: record),
                          );
                        },
                      ),
                    );
                  },
                ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                NavigationService.navigateTo(const ScanDocumentScreen());
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Document'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
