import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/services/emergency_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  List<EmergencyAlert> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }
  
  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final userId = auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }
      
      final alerts = await _emergencyService.getAlertHistory(userId);
      
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading alerts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAlerts,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No emergency alerts in history',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your emergency alert history will appear here',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            leading: _getAlertIcon(alert),
                            title: Text(
                              '${alert.type.toString().split('.').last} Emergency',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date: ${DateFormat('MMM d, yyyy h:mm a').format(alert.timestamp)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Status: ${_getStatusText(alert.status)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getStatusColor(alert.status),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    
                                    // Additional info
                                    if (alert.additionalInfo != null && alert.additionalInfo!.isNotEmpty) ...[
                                      Text(
                                        'Additional Information:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(alert.additionalInfo!),
                                      const SizedBox(height: 16),
                                    ],
                                    
                                    // Notified contacts
                                    Text(
                                      'Notified Contacts:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    alert.notifiedContacts.isEmpty
                                        ? const Text('No contacts were notified')
                                        : Text('${alert.notifiedContacts.length} contacts notified'),
                                    const SizedBox(height: 16),
                                    
                                    // Resolution info
                                    if (alert.status != 'active') ...[
                                      Text(
                                        'Resolution:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (alert.resolvedAt != null)
                                        Text(
                                          'Resolved on: ${DateFormat('MMM d, yyyy h:mm a').format(alert.resolvedAt!)}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
  
  Widget _getAlertIcon(EmergencyAlert alert) {
    IconData iconData;
    Color iconColor;
    
    switch (alert.type) {
      case EmergencyType.medical:
        iconData = Icons.medical_services;
        iconColor = Colors.red;
        break;
      case EmergencyType.accident:
        iconData = Icons.car_crash;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.warning;
        iconColor = Colors.amber;
    }
    
    if (alert.status != 'active') {
      iconColor = Colors.grey;
    }
    
    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(iconData, color: iconColor),
    );
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'resolved':
        return 'Resolved';
      case 'canceled':
        return 'Canceled';
      default:
        return status;
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red;
      case 'resolved':
        return Colors.green;
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}