import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:happ/core/models/emergency_contact.dart';
import 'package:happ/core/services/emergency_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }
  
  Future<void> _loadContacts() async {
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
      
      final contacts = await _emergencyService.getEmergencyContacts(userId);
      
      if (mounted) {
        setState(() {
          _contacts = contacts;
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
  
  Future<void> _deleteContact(String contactId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this emergency contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final userId = auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _emergencyService.deleteEmergencyContact(userId, contactId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          _loadContacts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete contact'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        title: const Text('Emergency Contacts'),
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
                        'Error loading contacts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadContacts,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'These contacts will be notified in case of an emergency. '
                        'They will receive an SMS with your location and emergency details.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    Expanded(
                      child: _contacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.contacts,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No emergency contacts added yet',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add your first emergency contact to be notified in case of emergency',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: contact.isPrimaryContact
                                          ? Colors.green.shade300
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: contact.isPrimaryContact
                                                  ? Colors.green.shade100
                                                  : Colors.blue.shade100,
                                              child: Icon(
                                                Icons.person,
                                                color: contact.isPrimaryContact
                                                    ? Colors.green
                                                    : Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    contact.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    contact.relationship,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed: () => _deleteContact(contact.id),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(contact.phoneNumber),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (contact.isPrimaryContact)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.green.shade200),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  size: 14,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Primary Contact',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Switch(
                                              value: contact.notifyOnEmergency,
                                              onChanged: null,
                                            ),
                                            Text(
                                              contact.notifyOnEmergency
                                                  ? 'Will be notified in emergencies'
                                                  : 'Will NOT be notified in emergencies',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: contact.notifyOnEmergency
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyContactFormScreen(),
            ),
          ).then((_) => _loadContacts());
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EmergencyContactFormScreen extends StatefulWidget {
  final EmergencyContact? contact;
  
  const EmergencyContactFormScreen({super.key, this.contact});

  @override
  State<EmergencyContactFormScreen> createState() => _EmergencyContactFormScreenState();
}

class _EmergencyContactFormScreenState extends State<EmergencyContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPrimaryContact = false;
  bool _notifyOnEmergency = true;
  bool _isLoading = false;
  final EmergencyService _emergencyService = EmergencyService();
  
  @override
  void initState() {
    super.initState();
    
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _relationshipController.text = widget.contact!.relationship;
      _phoneController.text = widget.contact!.phoneNumber;
      _isPrimaryContact = widget.contact!.isPrimaryContact;
      _notifyOnEmergency = widget.contact!.notifyOnEmergency;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final contact = EmergencyContact(
        id: widget.contact?.id ?? '',
        userId: userId,
        name: _nameController.text.trim(),
        relationship: _relationshipController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        isPrimaryContact: _isPrimaryContact,
        notifyOnEmergency: _notifyOnEmergency,
        createdAt: DateTime.now(),
      );
      
      final savedContact = await _emergencyService.saveEmergencyContact(contact);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (savedContact != null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save contact'),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Add Emergency Contact' : 'Edit Emergency Contact'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship *',
                hintText: 'E.g., Spouse, Parent, Child, Friend',
                prefixIcon: Icon(Icons.people),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter relationship';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'Enter mobile number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a phone number';
                }
                // Simple phone validation
                if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value.trim().replaceAll(RegExp(r'[^0-9+]'), ''))) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Set as Primary Contact'),
              subtitle: const Text(
                'Primary contact will be called first in emergencies',
                style: TextStyle(fontSize: 12),
              ),
              value: _isPrimaryContact,
              onChanged: (value) {
                setState(() {
                  _isPrimaryContact = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Notify in Emergencies'),
              subtitle: const Text(
                'This contact will receive emergency alerts',
                style: TextStyle(fontSize: 12),
              ),
              value: _notifyOnEmergency,
              onChanged: (value) {
                setState(() {
                  _notifyOnEmergency = value;
                });
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('SAVE CONTACT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}