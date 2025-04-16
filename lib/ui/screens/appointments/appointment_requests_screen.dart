import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentRequestsScreen extends StatefulWidget {
  const AppointmentRequestsScreen({super.key});

  @override
  State<AppointmentRequestsScreen> createState() => _AppointmentRequestsScreenState();
}

class _AppointmentRequestsScreenState extends State<AppointmentRequestsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Using a post-frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAppointments();
      }
    });
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    if (authProvider.currentUser!.role == 'doctor') {
      await appointmentProvider.fetchDoctorAppointments(authProvider.currentUser!.id);
    } else {
      await appointmentProvider.fetchPatientAppointments(authProvider.currentUser!.id);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<User?> _fetchUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromJson({'id': doc.id, ...doc.data()!});
      }
    } catch (e) {
      print('Error fetching user: $e');
    }
    return null;
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final success = await appointmentProvider.updateAppointmentStatus(appointmentId, status);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'confirmed' 
                ? 'Appointment confirmed successfully' 
                : status == 'cancelled' 
                  ? 'Appointment cancelled successfully'
                  : 'Appointment status updated successfully'
            ),
            backgroundColor: status == 'confirmed' ? Colors.green : Colors.blue,
          ),
        );
        
        // Reload appointments to refresh the list
        await _loadAppointments();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update appointment status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final isDoctor = authProvider.currentUser?.role == 'doctor' ?? false;
    
    // Create a local filtered list instead of filtering in the ListView builder
    final filteredAppointments = appointmentProvider.appointments.where((appointment) {
      if (isDoctor) {
        return appointment.status == 'pending';
      }
      return true;
    }).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isDoctor ? 'Appointment Requests' : 'My Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredAppointments.isEmpty
              ? Center(
                  child: Text(
                    isDoctor ? 'No appointment requests' : 'No appointments scheduled',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredAppointments.length,
                  itemBuilder: (context, index) {
                    final appointment = filteredAppointments[index];
                    
                    return FutureBuilder<User?>(
                      future: _fetchUser(isDoctor ? appointment.patientId : appointment.doctorId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('Loading...'),
                              subtitle: LinearProgressIndicator(),
                            ),
                          );
                        }
                        
                        final otherUser = snapshot.data;
                        final userName = otherUser?.name ?? 'Unknown User';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  child: Text(userName.substring(0, 1)),
                                ),
                                title: Text(userName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${DateFormat('MMM d, yyyy').format(appointment.date)} at ${appointment.timeSlot}',
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(appointment.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        appointment.status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (appointment.reason.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(appointment.reason),
                                ),
                              if (isDoctor && appointment.status == 'pending')
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _updateAppointmentStatus(
                                          appointment.id,
                                          'cancelled',
                                        ),
                                        child: const Text('Decline'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _updateAppointmentStatus(
                                          appointment.id,
                                          'confirmed',
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!isDoctor && appointment.status == 'confirmed')
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _updateAppointmentStatus(
                                          appointment.id,
                                          'cancelled',
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  // Update the status color method
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed': // Handle both confirmed and approved
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}