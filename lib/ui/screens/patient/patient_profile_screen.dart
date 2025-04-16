import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happ/ui/screens/patient/patient_medical_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PatientProfileScreen extends StatefulWidget {
  final User? patient; // Add this parameter for doctors viewing patient profiles
  final bool viewOnly; // Add this to control edit functionality
  
  const PatientProfileScreen({
    super.key, 
    this.patient,
    this.viewOnly = false,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _aadhaarController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _allergiesController;
  late TextEditingController _bloodGroupController;
  
  // Image Picker
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  bool _isUploadingImage = false;
  
  DateTime? _selectedDOB;
  String? _profileImageUrl;
  late User _userToDisplay;
  
  @override
  void initState() {
    super.initState();
    // Determine which user to display - the patient passed in or the current user
    if (widget.patient != null) {
      _userToDisplay = widget.patient!;
    } else {
      _userToDisplay = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    }
    
    // Initialize controllers with user data
    _nameController = TextEditingController(text: _userToDisplay.name);
    _phoneController = TextEditingController(text: _userToDisplay.phone ?? '');
    _heightController = TextEditingController(text: _userToDisplay.height?.toString() ?? '');
    _weightController = TextEditingController(text: _userToDisplay.weight?.toString() ?? '');
    _aadhaarController = TextEditingController(text: _userToDisplay.aadhaarNumber ?? '');
    _emergencyContactController = TextEditingController(text: _userToDisplay.emergencyContact ?? '');
    _allergiesController = TextEditingController(text: _userToDisplay.allergies ?? '');
    _bloodGroupController = TextEditingController(text: _userToDisplay.bloodGroup ?? '');
    
    _selectedDOB = _userToDisplay.dob;
    _profileImageUrl = _userToDisplay.profileImageUrl;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _aadhaarController.dispose();
    _emergencyContactController.dispose();
    _allergiesController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }
  
  // Calculate age from DOB
  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || 
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }
  
  Future<void> _selectDate(BuildContext context) async {
    if (!_isEditing) return;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDOB) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }
  
  Future<void> _pickImage() async {
    if (!_isEditing) return;
    
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }
  
  Future<String?> _uploadProfileImage() async {
    if (_pickedImage == null) return _profileImageUrl;
    
    try {
      setState(() {
        _isUploadingImage = true;
      });
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.id;
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      
      final uploadTask = storageRef.putFile(_pickedImage!);
      await uploadTask.whenComplete(() {});
      
      final downloadUrl = await storageRef.getDownloadURL();
      
      setState(() {
        _isUploadingImage = false;
        _profileImageUrl = downloadUrl;
      });
      
      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _errorMessage = 'Failed to upload image: $e';
      });
      return null;
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Upload image if selected
      final String? profileImageUrl = await _uploadProfileImage();
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Prepare updated user data
      final Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _selectedDOB,
        'age': _calculateAge(_selectedDOB),
      };
      
      // Add optional fields if they have values
      if (_heightController.text.isNotEmpty) {
        userData['height'] = double.tryParse(_heightController.text.trim());
      }
      
      if (_weightController.text.isNotEmpty) {
        userData['weight'] = double.tryParse(_weightController.text.trim());
      }
      
      if (_aadhaarController.text.isNotEmpty) {
        userData['aadhaarNumber'] = _aadhaarController.text.trim();
      }
      
      if (_emergencyContactController.text.isNotEmpty) {
        userData['emergencyContact'] = _emergencyContactController.text.trim();
      }
      
      if (_allergiesController.text.isNotEmpty) {
        userData['allergies'] = _allergiesController.text.trim();
      }
      
      if (_bloodGroupController.text.isNotEmpty) {
        userData['bloodGroup'] = _bloodGroupController.text.trim();
      }
      
      if (profileImageUrl != null) {
        userData['profileImageUrl'] = profileImageUrl;
      }
      
      // Update user profile
      final success = await authProvider.updateUserData(userData);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to update profile';
          });
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
    // Always use the determined user (either current user or patient passed in)
    final user = _userToDisplay;
    
    if (user.role != 'patient') {
      return const Scaffold(
        body: Center(
          child: Text('This profile page is only for patients.'),
        ),
      );
    }
    
    return Scaffold(
      // Only show AppBar if not in a tab view (when opened directly)
      appBar: widget.viewOnly ? null : AppBar(
        title: Text(widget.viewOnly ? '${user.name}\'s Profile' : 'My Profile'),
        actions: [
          if (!widget.viewOnly) // Only show edit button if not view-only
            _isEditing
              ? TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SAVE', style: TextStyle(color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                ),
          ElevatedButton.icon(
            icon: const Icon(Icons.medical_services),
            label: const Text('Medical Profile'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientMedicalProfileScreen(
                    patient: _userToDisplay,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add a doctor banner when viewing as a doctor
              if (widget.viewOnly) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are viewing this patient\'s profile as a healthcare provider.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Medical Alerts - Critical information for doctors
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userToDisplay.id)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final List<String> alerts = [];
                    
                    // Check for important medical information
                    if (userData['allergies'] != null && userData['allergies'].toString().isNotEmpty) {
                      alerts.add('Allergies: ${userData['allergies']}');
                    }
                    
                    if (userData['medicalConditions'] != null && userData['medicalConditions'] is List) {
                      final conditions = List<String>.from(userData['medicalConditions']);
                      if (conditions.isNotEmpty) {
                        alerts.add('Medical conditions: ${conditions.join(', ')}');
                      }
                    }
                    
                    if (userData['bloodGroup'] != null && userData['bloodGroup'].toString().isNotEmpty) {
                      alerts.add('Blood Group: ${userData['bloodGroup']}');
                    }
                    
                    if (userData['emergencyContact'] != null && userData['emergencyContact'].toString().isNotEmpty) {
                      alerts.add('Emergency Contact: ${userData['emergencyContact']}');
                    }
                    
                    if (alerts.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medical_services, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'IMPORTANT MEDICAL CONCERNS',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.red),
                          const SizedBox(height: 8),
                          ...alerts.map((alert) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.arrow_right, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alert,
                                    style: TextStyle(color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          
                          // Quick actions for the doctor
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.visibility),
                                label: const Text('View Complete Medical Profile'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PatientMedicalProfileScreen(
                                        patient: _userToDisplay,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              
              // Profile Image and Basic Info
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: !widget.viewOnly && _isEditing ? _pickImage : null,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!) as ImageProvider
                                : (_profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!) as ImageProvider
                                    : null),
                            child: _profileImageUrl == null && _pickedImage == null
                                ? Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 40, color: Colors.white),
                                  )
                                : null,
                          ),
                          if (!widget.viewOnly && _isEditing)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Error message if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Continue with rest of the profile fields, but make them non-editable if in view mode
              // ...
              
              // Rest of the existing UI with conditional enabled state
              // For example:
              
              // Personal Information Section
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Patient ID display (non-editable)
              if (user.patientId != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Patient ID',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    child: Text(
                      user.patientId ?? 'Not assigned',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: user.patientId != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                enabled: !widget.viewOnly && _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Date of Birth
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isEditing
                        ? const Icon(Icons.arrow_drop_down)
                        : null,
                  ),
                  child: Text(
                    _selectedDOB == null
                        ? 'Not set'
                        : DateFormat('MMM dd, yyyy').format(_selectedDOB!),
                  ),
                ),
              ),
              if (_selectedDOB != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                  child: Text(
                    'Age: ${_calculateAge(_selectedDOB)} years',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                enabled: !widget.viewOnly && _isEditing,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Aadhaar Number
              TextFormField(
                controller: _aadhaarController,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar Number',
                  prefixIcon: Icon(Icons.card_membership),
                  border: OutlineInputBorder(),
                ),
                enabled: !widget.viewOnly && _isEditing,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Health Information Section
              const Text(
                'Health Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Height and Weight in a row
              Row(
                children: [
                  // Height Field
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                        border: OutlineInputBorder(),
                      ),
                      enabled: !widget.viewOnly && _isEditing,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Weight Field
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.monitor_weight),
                        border: OutlineInputBorder(),
                      ),
                      enabled: !widget.viewOnly && _isEditing,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Blood Group
              TextFormField(
                controller: _bloodGroupController,
                decoration: const InputDecoration(
                  labelText: 'Blood Group',
                  prefixIcon: Icon(Icons.bloodtype),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. A+, B-, O+, AB+',
                ),
                enabled: !widget.viewOnly && _isEditing,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(3),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\+\-]')),
                ],
              ),
              const SizedBox(height: 16),
              
              // Allergies
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  prefixIcon: Icon(Icons.warning_amber),
                  border: OutlineInputBorder(),
                  hintText: 'List any allergies you have',
                ),
                enabled: !widget.viewOnly && _isEditing,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Emergency Contact
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact',
                  prefixIcon: Icon(Icons.emergency),
                  border: OutlineInputBorder(),
                  hintText: 'Name and phone number',
                ),
                enabled: !widget.viewOnly && _isEditing,
              ),
              const SizedBox(height: 24),
              
              // BMI Calculation if height and weight are available
              if (_heightController.text.isNotEmpty && _weightController.text.isNotEmpty) ...[
                _buildBMICard(),
                const SizedBox(height: 16),
              ],
              
              // Save Button for Edit Mode
              if (!widget.viewOnly && _isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE PROFILE'),
                  ),
                ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBMICard() {
    try {
      final height = double.parse(_heightController.text) / 100; // Convert cm to m
      final weight = double.parse(_weightController.text);
      
      if (height <= 0 || weight <= 0) return const SizedBox.shrink();
      
      final bmi = weight / (height * height);
      
      String category;
      Color color;
      
      if (bmi < 18.5) {
        category = 'Underweight';
        color = Colors.blue;
      } else if (bmi < 25) {
        category = 'Normal';
        color = Colors.green;
      } else if (bmi < 30) {
        category = 'Overweight';
        color = Colors.orange;
      } else {
        category = 'Obese';
        color = Colors.red;
      }
      
      return Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Body Mass Index (BMI)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your BMI',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Category',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}