import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/models/emergency_contact.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/services/emergency_service.dart';
import 'package:happ/ui/screens/patient/emergency/emergency_contacts_screen.dart';
import 'package:happ/ui/screens/patient/emergency/alert_history_screen.dart';

class SOSEmergencyScreen extends StatefulWidget {
  const SOSEmergencyScreen({super.key});

  @override
  State<SOSEmergencyScreen> createState() => _SOSEmergencyScreenState();
}

class _SOSEmergencyScreenState extends State<SOSEmergencyScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  bool _isLoading = false;
  String? _errorMessage;
  List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyAlert> _activeAlerts = [];
  EmergencyType _selectedEmergencyType = EmergencyType.medical;
  final TextEditingController _additionalInfoController = TextEditingController();
  bool _locationEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadEmergencyContacts();
    _loadActiveAlerts();
  }
  
  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }
  
  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      setState(() {
        _locationEnabled = serviceEnabled && 
            (permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse);
      });
      
      if (!_locationEnabled) {
        LocationPermission requestedPermission = await Geolocator.requestPermission();
        setState(() {
          _locationEnabled = requestedPermission == LocationPermission.always || 
                            requestedPermission == LocationPermission.whileInUse;
        });
      }
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }
  
  Future<void> _loadEmergencyContacts() async {
    final userId = auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final contacts = await _emergencyService.getEmergencyContacts(userId);
      if (mounted) {
        setState(() {
          _emergencyContacts = contacts;
        });
      }
    } catch (e) {
      print('Error loading emergency contacts: $e');
    }
  }
  
  Future<void> _loadActiveAlerts() async {
    final userId = auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final alerts = await _emergencyService.getActiveAlerts(userId);
      if (mounted) {
        setState(() {
          _activeAlerts = alerts;
        });
      }
    } catch (e) {
      print('Error loading active alerts: $e');
    }
  }
  
  Future<void> _triggerEmergencyAlert() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }
    
    if (!_locationEnabled) {
      _showLocationRequiredDialog();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final alert = await _emergencyService.triggerEmergencyAlert(
        type: _selectedEmergencyType,
        userId: currentUser.id,
        userName: currentUser.name,
        additionalInfo: _additionalInfoController.text.trim(),
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (alert != null) {
          // Show success and reset form
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency alert sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _additionalInfoController.clear();
          
          // Refresh active alerts
          _loadActiveAlerts();
          
          // Show detailed confirmation dialog
          _showAlertConfirmationDialog(alert);
        } else {
          setState(() {
            _errorMessage = 'Failed to send emergency alert';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _callEmergencyServices() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _emergencyService.callEmergencyServices();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to make call. Please dial emergency number manually.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _cancelAlert(String alertId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _emergencyService.cancelEmergencyAlert(alertId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency alert cancelled'),
              backgroundColor: Colors.green,
            ),
          );
          
          _loadActiveAlerts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel alert'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }
  
  void _showLocationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Access Required'),
        content: const Text(
          'Location access is required to send your location with the emergency alert. '
          'Please enable location services and grant permissions.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkLocationPermission();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  void _showAlertConfirmationDialog(EmergencyAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert type: ${alert.type.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Time: ${DateFormat('MMM d, yyyy h:mm a').format(alert.timestamp)}'),
            const SizedBox(height: 16),
            const Text(
              'Your emergency contacts have been notified with your location.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (alert.type == EmergencyType.medical)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Your healthcare providers have also been notified.'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _callEmergencyServices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call Emergency Services'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 360;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Alert History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlertHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.contacts),
            tooltip: 'Emergency Contacts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyContactsScreen(),
                ),
              ).then((_) => _loadEmergencyContacts());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Processing emergency request...',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Main scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isNarrow ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error message and location warnings (collapsible)
                          if (_errorMessage != null || !_locationEnabled)
                            _buildAlertSection(isNarrow),
                          
                          // Active alerts - always visible at the top when present
                          if (_activeAlerts.isNotEmpty) ...[
                            _buildActiveAlertsSection(),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Emergency type selection - make it more prominent
                          Text(
                            'Select Emergency Type',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildEmergencyTypeSelector(isNarrow),
                          const SizedBox(height: 24),
                          
                          // Additional info - simplified with better guidance
                          Text(
                            'Additional Information',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _additionalInfoController,
                            decoration: InputDecoration(
                              hintText: 'Describe what\'s happening (optional)',
                              border: const OutlineInputBorder(),
                              helperText: 'This helps emergency responders prepare',
                              prefixIcon: const Icon(Icons.description_outlined),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          
                          // Emergency contacts summary card - redesigned for clarity
                          _buildContactsSummaryCard(theme, isNarrow),
                        ],
                      ),
                    ),
                  ),
                  
                  // Fixed bottom panel with SOS actions - always accessible
                  _buildSOSActions(theme, isNarrow),
                ],
              ),
            ),
    );
  }
  
  // Alert messages section (errors and location warnings)
  Widget _buildAlertSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isNarrow ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: isNarrow ? 18 : 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontSize: isNarrow ? 13 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        if (!_locationEnabled) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isNarrow ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Location access is required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: isNarrow ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Emergency responders need your location to find you quickly.',
                  style: TextStyle(color: Colors.orange),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Geolocator.openAppSettings();
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Enable Location'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
  
  // Redesigned emergency type selector for better visual impact
  Widget _buildEmergencyTypeSelector(bool isNarrow) {
    final buttonSize = isNarrow ? 60.0 : 70.0;
    final iconSize = isNarrow ? 22.0 : 28.0;
    final fontSize = isNarrow ? 12.0 : 14.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildEmergencyTypeOption(
          'Medical',
          Icons.medical_services,
          EmergencyType.medical,
          buttonSize,
          iconSize,
          fontSize,
        ),
        const SizedBox(width: 16),
        _buildEmergencyTypeOption(
          'Accident',
          Icons.car_crash,
          EmergencyType.accident,
          buttonSize,
          iconSize,
          fontSize,
        ),
        const SizedBox(width: 16),
        _buildEmergencyTypeOption(
          'Other',
          Icons.warning,
          EmergencyType.other,
          buttonSize,
          iconSize,
          fontSize,
        ),
      ],
    );
  }
  
  // Individual emergency type option
  Widget _buildEmergencyTypeOption(
    String label, 
    IconData icon, 
    EmergencyType type,
    double size,
    double iconSize,
    double fontSize,
  ) {
    final isSelected = _selectedEmergencyType == type;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedEmergencyType = type;
          });
        },
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: iconSize,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize,
                color: isSelected ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Emergency contacts summary card
  Widget _buildContactsSummaryCard(ThemeData theme, bool isNarrow) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _emergencyContacts.isEmpty 
              ? Colors.orange.shade200 
              : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _emergencyContacts.isEmpty 
                      ? Icons.warning_amber 
                      : Icons.group,
                  color: _emergencyContacts.isEmpty 
                      ? Colors.orange 
                      : Colors.green,
                  size: isNarrow ? 20 : 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emergencyContacts.isEmpty
                        ? 'No Emergency Contacts'
                        : 'Emergency Contacts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isNarrow ? 15 : 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyContactsScreen(),
                      ),
                    ).then((_) => _loadEmergencyContacts());
                  },
                  child: Text(
                    _emergencyContacts.isEmpty ? 'Add' : 'Manage',
                    style: TextStyle(
                      fontWeight: _emergencyContacts.isEmpty 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            
            if (_emergencyContacts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Adding emergency contacts ensures someone is notified in case of emergency',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle, 
                    color: Colors.green, 
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_emergencyContacts.length} contact${_emergencyContacts.length != 1 ? "s" : ""} will be notified',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              
              if (_emergencyContacts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final primaryContact = _emergencyContacts.firstWhere(
                      (c) => c.isPrimaryContact, 
                      orElse: () => _emergencyContacts.first,
                    );
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(
                          Icons.person, 
                          color: Colors.green,
                        ),
                      ),
                      title: Text(
                        primaryContact.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(primaryContact.relationship),
                          Text(
                            primaryContact.phoneNumber,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, 
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  // Active alerts section
  Widget _buildActiveAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.red,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Active Emergency Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._activeAlerts.map((alert) => _buildActiveAlertCard(alert)),
      ],
    );
  }
  
  // Bottom fixed SOS actions panel
  Widget _buildSOSActions(ThemeData theme, bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SOS button - larger with pulse animation
          SizedBox(
            width: double.infinity,
            height: 80,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _triggerEmergencyAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.emergency,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SEND EMERGENCY ALERT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Notify contacts and healthcare providers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Direct call button
          OutlinedButton.icon(
            onPressed: _callEmergencyServices,
            icon: const Icon(Icons.phone, color: Colors.red, size: 18),
            label: const Text(
              'Call Emergency Services (911)',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          // Small disclaimer text
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'For life-threatening emergencies, call 911 directly',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActiveAlertCard(EmergencyAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.red, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    alert.type == EmergencyType.medical
                        ? Icons.medical_services
                        : alert.type == EmergencyType.accident
                            ? Icons.car_crash
                            : Icons.warning,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active ${alert.type.toString().split('.').last} Emergency',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Sent: ${DateFormat('MMM d, h:mm a').format(alert.timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alert.additionalInfo != null && alert.additionalInfo!.isNotEmpty) ...[
              Text(
                'Additional Info:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(alert.additionalInfo!),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelAlert(alert.id),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text(
                    'Cancel Alert',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}