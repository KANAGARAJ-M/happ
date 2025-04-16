import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorBookingsScreen extends StatefulWidget {
  const DoctorBookingsScreen({super.key});

  @override
  State<DoctorBookingsScreen> createState() => _DoctorBookingsScreenState();
}

class _DoctorBookingsScreenState extends State<DoctorBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Use post-frame callback to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      
      await appointmentProvider.fetchDoctorAppointments(authProvider.currentUser!.id);
      
      if (!mounted) return;
      setState(() {
        // Only get confirmed appointments
        _appointments = appointmentProvider.appointments
            .where((appointment) => appointment.status == 'confirmed')
            .toList();
        
        // Debug print to check appointments data
        for (var appointment in _appointments) {
          print('Appointment date: ${appointment.date}');
          print('Appointment reason: "${appointment.reason}"');
          print('Appointment timeSlot: ${appointment.timeSlot}');
        }
        
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: $e')),
      );
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

  // Simplify the isAppointmentUpcoming method
  bool _isAppointmentUpcoming(Appointment appointment) {
    final now = DateTime.now();
    
    // First check if date is in the future
    if (appointment.date.isAfter(now)) {
      return true;
    }
    
    // If it's today, check the end time of the time slot
    if (appointment.date.year == now.year && 
        appointment.date.month == now.month && 
        appointment.date.day == now.day) {
      try {
        // Parse the end time more safely
        final timeSlot = appointment.timeSlot;
        if (timeSlot.contains('-')) {
          final endTimeString = timeSlot.split('-').last.trim();
          
          // Extract hours and minutes
          int endHour = 0;
          int endMinute = 0;
          
          if (endTimeString.contains(':')) {
            final timeParts = endTimeString.split(':');
            if (timeParts.length == 2) {
              final hourPart = timeParts[0].trim();
              String minutePart = timeParts[1].trim();
              
              // Handle AM/PM
              bool isPM = false;
              if (minutePart.contains('PM')) {
                isPM = true;
                minutePart = minutePart.replaceAll('PM', '').trim();
              } else if (minutePart.contains('AM')) {
                minutePart = minutePart.replaceAll('AM', '').trim();
              }
              
              endHour = int.tryParse(hourPart) ?? 0;
              endMinute = int.tryParse(minutePart) ?? 0;
              
              // Adjust for PM
              if (isPM && endHour < 12) {
                endHour += 12;
              }
              // Adjust for 12 AM
              if (!isPM && endHour == 12) {
                endHour = 0;
              }
              
              // Create end time for comparison
              final endDateTime = DateTime(
                now.year, now.month, now.day, endHour, endMinute
              );
              
              return endDateTime.isAfter(now);
            }
          }
        }
      } catch (e) {
        print('Error parsing time: $e');
      }
      
      // Default to checking just the date if time parsing fails
      return true;
    }
    
    // Past dates are not upcoming
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Separate upcoming and completed appointments
    final upcomingAppointments = _appointments
        .where((appointment) => _isAppointmentUpcoming(appointment))
        .toList();
    
    final completedAppointments = _appointments
        .where((appointment) => !_isAppointmentUpcoming(appointment))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointment Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Appointments Tab
                _buildAppointmentList(upcomingAppointments, isUpcoming: true),
                
                // Completed Appointments Tab
                _buildAppointmentList(completedAppointments, isUpcoming: false),
              ],
            ),
    );
  }

  Widget _buildAppointmentList(List<Appointment> appointments, {required bool isUpcoming}) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming ? Icons.event_available : Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming appointments' : 'No completed appointments',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return FutureBuilder<User?>(
          future: _fetchPatient(appointment.patientId),
          builder: (context, snapshot) {
            final patient = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isUpcoming ? Colors.blue.shade200 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUpcoming ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUpcoming ? Icons.event : Icons.event_available,
                          color: isUpcoming ? Colors.blue : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Appointment Date:",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                // Fall back to "Invalid Date" if formatting fails
                                (() {
                                  try {
                                    return DateFormat('EEEE, MMMM d, yyyy').format(appointment.date);
                                  } catch (e) {
                                    return "Invalid Date";
                                  }
                                })(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient info
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isLoading
                                  ? Colors.grey[300]
                                  : Theme.of(context).primaryColor,
                              radius: 24,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      patient?.name.substring(0, 1) ?? 'P',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLoading ? 'Loading...' : (patient?.name ?? 'Unknown Patient'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (!isLoading && patient?.email != null)
                                    Text(
                                      patient!.email,
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Time slot
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              appointment.timeSlot,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Reason for appointment
                        const Text(
                          'Reason for Appointment:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            appointment.reason.isNotEmpty 
                              ? appointment.reason 
                              : 'No reason provided',
                            style: TextStyle(
                              color: appointment.reason.isNotEmpty ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                        
                        // Buttons for upcoming appointments
                        if (isUpcoming) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (patient?.phone != null && patient!.phone!.isNotEmpty) {
                                    final phoneUrl = 'tel:${patient.phone}';
                                    if (await canLaunch(phoneUrl)) {
                                      await launch(phoneUrl);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cannot make phone call')),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No phone number available')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.phone),
                                label: const Text('Call Patient'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _markAppointmentAsCompleted(appointment.id);
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Mark Complete'),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  // Ensure marking complete shows proper loading state
  Future<void> _markAppointmentAsCompleted(String appointmentId) async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });
      
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final success = await appointmentProvider.updateAppointmentStatus(appointmentId, 'completed');
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload appointments to refresh the lists
        await _loadAppointments();
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update appointment status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}