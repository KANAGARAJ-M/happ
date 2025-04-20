import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:happ/ui/screens/notifications/notification_history_screen.dart';
import 'package:happ/ui/screens/patient/ai/AISchedulingAssistant.dart';
import 'package:happ/ui/screens/patient/emergency/sos_emergency_screen.dart';
import 'package:happ/ui/screens/patient/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/patient/doctor_list_screen.dart';
import 'package:happ/ui/screens/patient/my_appointments_screen.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/screens/records/record_list_screen.dart';
import 'package:happ/ui/screens/records/add_record_screen.dart';
import 'package:happ/ui/screens/scan_document_screen.dart';
import 'package:happ/ui/screens/patient/ai/PersonalHealthAssistant.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  bool _isLoading = true;
  List<Appointment> _upcomingAppointments = [];
  int _totalAppointments = 0;
  int _totalDoctors = 0;
  int _totalRecords = 0;
  int _recentRecords = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recordsProvider = Provider.of<RecordsProvider>(
        context,
        listen: false,
      );
      final appointmentProvider = Provider.of<AppointmentProvider>(
        context,
        listen: false,
      );
      final patientId = authProvider.currentUser!.id;

      // Load records if not already loaded
      if (!recordsProvider.initialized) {
        await recordsProvider.fetchRecords(patientId);
      }

      // Fetch appointments
      await appointmentProvider.fetchPatientAppointments(patientId);

      // Calculate metrics
      final now = DateTime.now();
      final allAppointments = appointmentProvider.appointments;

      // Get upcoming appointments (confirmed only)
      _upcomingAppointments =
          allAppointments
              .where((a) => a.status == 'confirmed' && a.date.isAfter(now))
              .toList();

      // Sort by date
      _upcomingAppointments.sort((a, b) => a.date.compareTo(b.date));

      // Get total appointments
      _totalAppointments = allAppointments.length;

      // Get unique doctors count
      final doctorIds =
          allAppointments
              .map((appointment) => appointment.doctorId)
              .toSet()
              .length;
      _totalDoctors = doctorIds;

      // Get records statistics
      final allRecords = recordsProvider.records;
      _totalRecords = allRecords.length;

      // Recent records (last 30 days)
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      _recentRecords =
          allRecords
              .where((record) => record.date.isAfter(thirtyDaysAgo))
              .length;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
      }
    }
  }

  Future<User?> _fetchDoctor(String doctorId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(doctorId)
              .get();
      if (doc.exists) {
        return User.fromJson({'id': doc.id, ...doc.data()!});
      }
    } catch (e) {
      print('Error fetching doctor: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final recordsProvider = Provider.of<RecordsProvider>(context);
    final user = authProvider.currentUser;
    final records = recordsProvider.records.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  // Add these physics to handle scrolling properly
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isSmallWidth =
                                  constraints.maxWidth < 300;

                              if (isSmallWidth) {
                                // Stack layout for small screens
                                return Column(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      radius: 30,
                                      child: Text(
                                        user?.name.isNotEmpty == true
                                            ? user!.name
                                                .substring(0, 1)
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Welcome, ${user?.name ?? 'Patient'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'EEEE, MMMM d, yyyy',
                                      ).format(DateTime.now()),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              } else {
                                // Row layout for normal screens
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      radius: 30,
                                      child: Text(
                                        user?.name.isNotEmpty == true
                                            ? user!.name
                                                .substring(0, 1)
                                                .toUpperCase()
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome, ${user?.name ?? 'Patient'}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat(
                                              'EEEE, MMMM d, yyyy',
                                            ).format(DateTime.now()),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Stats overview
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool useVerticalLayout =
                              constraints.maxWidth < 500;

                          if (useVerticalLayout) {
                            // Column layout for narrow screens
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Appointments',
                                        _totalAppointments.toString(),
                                        Icons.calendar_month,
                                        Colors.blue,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Doctors',
                                        _totalDoctors.toString(),
                                        Icons.medical_services,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Records',
                                        _totalRecords.toString(),
                                        Icons.folder,
                                        Colors.amber,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Recent Records',
                                        _recentRecords.toString(),
                                        Icons.history,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            // Row layout for wider screens
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Appointments',
                                    _totalAppointments.toString(),
                                    Icons.calendar_month,
                                    Colors.blue,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatCard(
                                    'Doctors',
                                    _totalDoctors.toString(),
                                    Icons.medical_services,
                                    Colors.green,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatCard(
                                    'Records',
                                    _totalRecords.toString(),
                                    Icons.folder,
                                    Colors.amber,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatCard(
                                    'Recent Records',
                                    _recentRecords.toString(),
                                    Icons.history,
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Calculate how many buttons per row based on available width
                                  final double availableWidth =
                                      constraints.maxWidth;
                                  final int buttonsPerRow =
                                      availableWidth < 300
                                          ? 2
                                          : availableWidth < 600
                                          ? 4
                                          : 6;

                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: buttonsPerRow,
                                    childAspectRatio: 0.8,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    children: [
                                      _buildQuickAction(
                                        context,
                                        Icons.add_box,
                                        'New Record',
                                        Colors.amber,
                                        () => NavigationService.navigateTo(
                                          const AddRecordScreen(),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.calendar_month,
                                        'Book Appt',
                                        Colors.blue,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const DoctorListScreen(),
                                          ),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.document_scanner,
                                        'Scan Doc',
                                        Colors.green,
                                        () => NavigationService.navigateTo(
                                          const ScanDocumentScreen(),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.folder,
                                        'My Records',
                                        Colors.purple,
                                        () => NavigationService.navigateTo(
                                          const RecordListScreen(),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.assistant,
                                        'AI Booking',
                                        Colors.green,
                                        () => NavigationService.navigateTo(
                                          const AISchedulingAssistant(),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.health_and_safety,
                                        'AI Health Assistant',
                                        Colors.teal,
                                        () => NavigationService.navigateTo(
                                          const PersonalHealthAssistant(),
                                        ),
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.emergency,
                                        'SOS',
                                        Colors.red,
                                        () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SOSEmergencyScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      _buildQuickAction(
                                        context,
                                        Icons.settings,
                                        'Settings',
                                        Colors.grey,
                                        () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SettingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Upcoming appointments
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upcoming Appointments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const MyAppointmentsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _upcomingAppointments.isEmpty
                          ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'No upcoming appointments',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true, // Add this
                            physics:
                                const NeverScrollableScrollPhysics(), // Add this
                            itemCount:
                                _upcomingAppointments.length > 3
                                    ? 3
                                    : _upcomingAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = _upcomingAppointments[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.blue.shade100),
                                ),
                                child: FutureBuilder<User?>(
                                  future: _fetchDoctor(appointment.doctorId),
                                  builder: (context, snapshot) {
                                    final doctor = snapshot.data;
                                    final isLoading =
                                        snapshot.connectionState ==
                                        ConnectionState.waiting;

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            isLoading
                                                ? Colors.grey[300]
                                                : Colors.blue,
                                        child:
                                            isLoading
                                                ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                                : Text(
                                                  doctor?.name.substring(
                                                        0,
                                                        1,
                                                      ) ??
                                                      'D',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                      ),
                                      title: Text(
                                        isLoading
                                            ? 'Loading...'
                                            : 'Dr. ${doctor?.name ?? 'Unknown'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${DateFormat('MMM d').format(appointment.date)} • ${appointment.timeSlot}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const MyAppointmentsScreen(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                      const SizedBox(height: 24),

                      // Recent notifications section
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Notifications',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const NotificationHistoryScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildRecentNotifications(),

                      // Recent records
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              NavigationService.navigateTo(
                                const RecordListScreen(),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      records.isEmpty
                          ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'No records available',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true, // Add this
                            physics:
                                const NeverScrollableScrollPhysics(), // Add this
                            itemCount: records.length > 3 ? 3 : records.length,
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
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
                                    NavigationService.navigateTo(
                                      RecordDetailScreen(record: record),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                      const SizedBox(height: 16),
                      // const SizedBox(height: 24),

                      // // Future Features Section
                      // Container(
                      //   margin: const EdgeInsets.only(bottom: 24),
                      //   decoration: BoxDecoration(
                      //     gradient: LinearGradient(
                      //       colors: [
                      //         Colors.blue.shade100,
                      //         Colors.indigo.shade100,
                      //       ],
                      //       begin: Alignment.topLeft,
                      //       end: Alignment.bottomRight,
                      //     ),
                      //     borderRadius: BorderRadius.circular(16),
                      //   ),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       Padding(
                      //         padding: const EdgeInsets.all(16),
                      //         child: Row(
                      //           children: [
                      //             Icon(Icons.star, color: Colors.amber),
                      //             const SizedBox(width: 8),
                      //             Text(
                      //               'Coming Up Features',
                      //               style: Theme.of(
                      //                 context,
                      //               ).textTheme.titleLarge!.copyWith(
                      //                 fontWeight: FontWeight.bold,
                      //                 color: Colors.indigo.shade800,
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //       _buildComingFeatureItem(
                      //         Icons.watch,
                      //         'Smart Health Tracking',
                      //         'Real-time health monitoring via smartwatch integration.',
                      //         Colors.purple,
                      //       ),
                      //       _buildComingFeatureItem(
                      //         Icons.smart_toy,
                      //         'AI Appointment Booking',
                      //         'Let AI find the perfect appointment time with your doctor.',
                      //         Colors.blue,
                      //       ),
                      //       _buildComingFeatureItem(
                      //         Icons.emergency,
                      //         'SOS Emergency Feature',
                      //         'One-tap emergency alerts with location sharing.',
                      //         Colors.red,
                      //       ),
                      //       _buildComingFeatureItem(
                      //         Icons.assistant,
                      //         'Personal AI Health Assistant',
                      //         'AI-powered insights from your medical records and vitals.',
                      //         Colors.green,
                      //       ),
                      //       _buildComingFeatureItem(
                      //         Icons.shopping_cart,
                      //         'Medicine E-Shop',
                      //         'Purchase prescription medications directly through the app.',
                      //         Colors.orange,
                      //       ),
                      //       Padding(
                      //         padding: const EdgeInsets.all(16),
                      //         child: ElevatedButton(
                      //           onPressed: () => _showComingUpFeatures(context),
                      //           style: ElevatedButton.styleFrom(
                      //             backgroundColor: Colors.indigo,
                      //             foregroundColor: Colors.white,
                      //             minimumSize: const Size(double.infinity, 50),
                      //           ),
                      //           child: const Text('Notify Me When Available'),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
                Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    // Get screen width to make widgets adaptive
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust width based on screen size
    final buttonWidth =
        screenWidth < 360
            ? 70.0
            : screenWidth < 600
            ? 80.0
            : 100.0;

    return Container(
      width: buttonWidth,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: screenWidth < 360 ? 20 : 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: screenWidth < 360 ? 10 : 12,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNotifications([String? userId]) {
    final currentUserId = userId ?? auth.FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 160,
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Card(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No recent notifications',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String title = data['title'] ?? 'Notification';
              final String body = data['body'] ?? '';
              final bool read = data['read'] ?? false;
              final String type = data['type'] ?? 'general';

              // Format timestamp
              String timeAgo = '';
              if (data['timestamp'] != null) {
                final timestamp = (data['timestamp'] as Timestamp).toDate();
                final now = DateTime.now();
                final difference = now.difference(timestamp);

                if (difference.inMinutes < 60) {
                  timeAgo = '${difference.inMinutes}m ago';
                } else if (difference.inHours < 24) {
                  timeAgo = '${difference.inHours}h ago';
                } else {
                  timeAgo = '${difference.inDays}d ago';
                }
              }

              IconData iconData;
              Color iconColor;

              switch (type) {
                case 'appointment':
                  iconData = Icons.calendar_today;
                  iconColor = Colors.blue;
                  break;
                case 'record_access':
                  iconData = Icons.folder_shared;
                  iconColor = Colors.orange;
                  break;
                case 'medical_insight':
                  iconData = Icons.health_and_safety;
                  iconColor = Colors.red;
                  break;
                default:
                  iconData = Icons.notifications;
                  iconColor = Colors.grey;
              }

              return GestureDetector(
                onTap: () async {
                  // Mark as read when tapped
                  if (!read) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .collection('notifications')
                        .doc(doc.id)
                        .update({'read': true});
                  }

                  // Navigate to notification details
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationHistoryScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    elevation: read ? 1 : 3,
                    color:
                        read
                            ? null
                            : Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(iconData, color: iconColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _showComingUpFeatures(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Coming Soon!'),
          content: const Text('These exciting features are in development.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}

Widget _buildComingFeatureItem(
  IconData icon,
  String title,
  String description,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
      ],
    ),
  );
}
