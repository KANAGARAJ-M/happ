import 'package:flutter/material.dart';
import 'package:happ/ui/screens/emergency/emergency_contacts_screen.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/providers/emergency_provider.dart';
import 'package:happ/ui/screens/emergency/emergency_active_screen.dart';

class EmergencyAlertScreen extends StatefulWidget {
  final EmergencyType initialType;
  final String userId;
  final String userName;
  
  const EmergencyAlertScreen({
    super.key,
    required this.initialType,
    required this.userId,
    required this.userName,
  });

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  late EmergencyType _selectedType;
  final TextEditingController _additionalInfoController = TextEditingController();
  bool _isTriggering = false;
  
  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }
  
  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Emergency Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildEmergencyTypeSelector(),
            const SizedBox(height: 24),
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _additionalInfoController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter any additional details that might help emergency responders',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Emergency Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildEmergencyContacts(),
            const SizedBox(height: 32),
            _buildTriggerButton(),
            const SizedBox(height: 16),
            const Text(
              'When you trigger an emergency alert:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.sms, 
              'Your emergency contacts will receive an SMS with your location'
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.medical_services, 
              'For medical emergencies, your healthcare providers will be notified'
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.location_on, 
              'Your current location will be shared to help emergency responders find you'
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmergencyTypeSelector() {
    return Column(
      children: [
        ListTile(
          title: const Text('Medical Emergency'),
          subtitle: const Text('Heart attack, stroke, severe injury, etc.'),
          leading: Radio<EmergencyType>(
            value: EmergencyType.medical,
            groupValue: _selectedType,
            activeColor: Colors.red,
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          trailing: const Icon(Icons.medical_services, color: Colors.red),
        ),
        ListTile(
          title: const Text('Accident'),
          subtitle: const Text('Vehicle accident, fall, workplace injury, etc.'),
          leading: Radio<EmergencyType>(
            value: EmergencyType.accident,
            groupValue: _selectedType,
            activeColor: Colors.orange,
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          trailing: const Icon(Icons.car_crash, color: Colors.orange),
        ),
        ListTile(
          title: const Text('Other Emergency'),
          subtitle: const Text('Any other situation requiring immediate assistance'),
          leading: Radio<EmergencyType>(
            value: EmergencyType.other,
            groupValue: _selectedType,
            activeColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          trailing: const Icon(Icons.emergency, color: Colors.blue),
        ),
      ],
    );
  }
  
  Widget _buildEmergencyContacts() {
    final emergencyProvider = Provider.of<EmergencyProvider>(context);
    final contacts = emergencyProvider.emergencyContacts;
    
    if (emergencyProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (contacts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 32),
              const SizedBox(height: 8),
              const Text(
                'No emergency contacts found',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add emergency contacts to notify them in case of an emergency',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen(),
                    ),
                  );
                },
                child: const Text('Add Emergency Contacts'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: contacts.map((contact) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(contact.name),
            subtitle: Text('${contact.relationship} • ${contact.phoneNumber}'),
            leading: CircleAvatar(
              child: Text(contact.name.substring(0, 1)),
            ),
            trailing: contact.notifyOnEmergency
                ? const Icon(Icons.notifications_active, color: Colors.green)
                : const Icon(Icons.notifications_off, color: Colors.red),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildTriggerButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isTriggering ? null : _triggerEmergencyAlert,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isTriggering
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Sending Alert...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, size: 28),
                  SizedBox(width: 16),
                  Text(
                    'TRIGGER EMERGENCY ALERT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[700], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
  
  Future<void> _triggerEmergencyAlert() async {
    if (_isTriggering) return;
    
    setState(() {
      _isTriggering = true;
    });
    
    try {
      final emergencyProvider = Provider.of<EmergencyProvider>(context, listen: false);
      
      final alert = await emergencyProvider.triggerEmergencyAlert(
        type: _selectedType,
        userId: widget.userId,
        userName: widget.userName,
        additionalInfo: _additionalInfoController.text.trim(),
      );
      
      if (alert != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyActiveScreen(alert: alert),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to trigger emergency alert. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isTriggering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isTriggering = false;
        });
      }
    }
  }
}