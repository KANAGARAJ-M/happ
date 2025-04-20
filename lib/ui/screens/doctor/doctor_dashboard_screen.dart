import 'package:flutter/material.dart';
import 'package:happ/ui/screens/notifications/notification_history_screen.dart';
import 'package:happ/ui/screens/patient/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/ui/screens/doctor/doctor_bookings_screen.dart';
import 'package:happ/ui/screens/appointments/appointment_requests_screen.dart';
import 'package:happ/ui/screens/doctor/patient_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  bool _isLoading = true;
  int _totalPatients = 0;
  int _totalAppointments = 0;
  int _pendingRequests = 0;
  int _todayAppointments = 0;
  List<Appointment> _upcomingAppointments = [];

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
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final doctorId = authProvider.currentUser!.id;
      
      // Fetch appointments
      await appointmentProvider.fetchDoctorAppointments(doctorId);
      
      // Calculate metrics from fetched appointments
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final allAppointments = appointmentProvider.appointments;
      
      final pendingRequests = allAppointments.where((a) => a.status == 'pending').length;
      
      final todayAppointments = allAppointments.where((a) {
        final appointmentDate = DateTime(a.date.year, a.date.month, a.date.day);
        return a.status == 'confirmed' && appointmentDate.isAtSameMomentAs(today);
      }).length;
      
      // Get upcoming appointments (for the next 7 days)
      final nextWeek = today.add(const Duration(days: 7));
      final upcomingAppointments = allAppointments.where((a) {
        final appointmentDate = DateTime(a.date.year, a.date.month, a.date.day);
        return a.status == 'confirmed' && 
              appointmentDate.isAtSameMomentAs(today) || 
              (appointmentDate.isAfter(today) && appointmentDate.isBefore(nextWeek));
      }).toList();
      
      // Sort upcoming appointments by date and time
      upcomingAppointments.sort((a, b) {
        final dateComparison = a.date.compareTo(b.date);
        if (dateComparison != 0) return dateComparison;
        
        // If same date, compare by time slot
        return a.timeSlot.compareTo(b.timeSlot);
      });
      
      // Get total unique patients
      final patientIds = appointmentProvider.appointments
          .map((appointment) => appointment.patientId)
          .toSet()
          .length;
      
      // Get total appointments (not counting pending)
      final totalAppointments = allAppointments
          .where((a) => a.status != 'pending')
          .length;
      
      if (!mounted) return;
      
      setState(() {
        _totalPatients = patientIds;
        _totalAppointments = totalAppointments;
        _pendingRequests = pendingRequests;
        _todayAppointments = todayAppointments;
        _upcomingAppointments = upcomingAppointments.take(5).toList(); // Limit to 5
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data')),
        );
      }
    }
  }

  Future<User?> _fetchPatient(String patientId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(patientId).get();
      if (doc.exists) {
        return User.fromJson({'id': doc.id, ...doc.data()!});
      }
    } catch (e) {
      print('Error fetching patient: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final doctorName = authProvider.currentUser?.name ?? 'Doctor';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  radius: 30,
                                  child: Text(
                                    doctorName.substring(0, 1),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, Dr. ${doctorName.split(' ')[0]}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Stats overview
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Today',
                            _todayAppointments.toString(),
                            Icons.today,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            _pendingRequests.toString(),
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Patients',
                            _totalPatients.toString(),
                            Icons.people,
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Appointments',
                            _totalAppointments.toString(),
                            Icons.calendar_month,
                            Colors.purple,
                          ),
                        ),
                      ],
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildQuickAction(
                                  context,
                                  Icons.calendar_today,
                                  'Requests',
                                  Colors.orange,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AppointmentRequestsScreen(),
                                    ),
                                  ),
                                ),
                                _buildQuickAction(
                                  context,
                                  Icons.book_online,
                                  'Bookings',
                                  Colors.blue,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DoctorBookingsScreen(),
                                    ),
                                  ),
                                ),
                                _buildQuickAction(
                                  context,
                                  Icons.people,
                                  'Patients',
                                  Colors.green,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PatientListScreen(),
                                    ),
                                  ),
                                ),
                                _buildQuickAction(
                                  context,
                                  Icons.settings,
                                  'Settings',
                                  Colors.grey,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SettingsScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Upcoming appointments
                    const Text(
                      'Upcoming Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _upcomingAppointments.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.event_available, color: Colors.grey[400], size: 32),
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
                      : Column(
                          children: _upcomingAppointments.map((appointment) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.blue.shade100),
                              ),
                              child: FutureBuilder<User?>(
                                future: _fetchPatient(appointment.patientId),
                                builder: (context, snapshot) {
                                  final patient = snapshot.data;
                                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                                  
                                  final appointmentDate = DateFormat('EEE, MMM d').format(appointment.date);
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isLoading
                                          ? Colors.grey[300]
                                          : Theme.of(context).primaryColor,
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              patient?.name.substring(0, 1) ?? 'P',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                    ),
                                    title: Text(
                                      isLoading ? 'Loading...' : (patient?.name ?? 'Unknown Patient'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('$appointmentDate • ${appointment.timeSlot}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.arrow_forward),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const DoctorBookingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.people, color: Colors.blue),
                      ),
                      title: const Text('Patient Profiles'),
                      subtitle: const Text('View and manage your patients\' profiles'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PatientListScreen()),
                        );
                      },
                    ),
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
                                builder: (context) => const NotificationHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentNotifications(authProvider.currentUser?.id),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  ),
                ),
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
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
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
        stream: FirebaseFirestore.instance
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
                    color: read ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (!read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.primary,
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
                              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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