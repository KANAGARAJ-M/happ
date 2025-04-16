import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:intl/intl.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final String appointmentId;
  
  const AppointmentDetailsScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Appointment not found'));
          }
          
          final appointmentData = snapshot.data!.data() as Map<String, dynamic>;
          final appointment = Appointment.fromJson({...appointmentData, 'id': appointmentId});
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(appointment.status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                appointment.status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('MMM d, yyyy').format(appointment.date),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(context, 'Patient', appointment.patientName),
                        const SizedBox(height: 8),
                        _buildInfoRow(context, 'Doctor', appointment.doctorName),
                        const SizedBox(height: 8),
                        _buildInfoRow(context, 'Time', appointment.timeSlot),
                        
                        if (appointment.reason.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Reason for Visit:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            width: double.infinity,
                            child: Text(appointment.reason),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Actions based on appointment status
                if (appointment.status == 'pending') ...[
                  const Text(
                    'Appointment Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateStatus(context, appointment.id, 'cancelled'),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(context, appointment.id, 'confirmed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ]
                else if (appointment.status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(context, appointment.id, 'cancelled'),
                      child: const Text('Cancel Appointment'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'approved':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  Future<void> _updateStatus(BuildContext context, String appointmentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment ${status == 'confirmed' ? 'confirmed' : 'cancelled'} successfully'),
            backgroundColor: status == 'confirmed' ? Colors.green : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}