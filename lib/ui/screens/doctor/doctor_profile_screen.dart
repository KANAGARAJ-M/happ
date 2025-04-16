import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class DoctorProfileScreen extends StatefulWidget {
  final User? doctor; // For viewing other doctor's profile in the future
  final bool viewOnly; // Control edit functionality
  
  const DoctorProfileScreen({
    super.key, 
    this.doctor,
    this.viewOnly = false,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _specializationController;
  late TextEditingController _bioController;
  
  // Image Picker
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  bool _isUploadingImage = false;
  
  DateTime? _selectedDOB;
  String? _profileImageUrl;
  late User _userToDisplay;
  
  // Available specializations list
  final List<String> _specializations = [
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'General Medicine',
    'Neurology',
    'Obstetrics & Gynecology',
    'Oncology',
    'Ophthalmology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Pulmonology',
    'Radiology',
    'Urology'
  ];
  
  @override
  void initState() {
    super.initState();
    // Determine which user to display
    if (widget.doctor != null) {
      _userToDisplay = widget.doctor!;
    } else {
      _userToDisplay = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    }
    
    // Initialize controllers with user data
    _nameController = TextEditingController(text: _userToDisplay.name);
    _phoneController = TextEditingController(text: _userToDisplay.phone ?? '');
    _specializationController = TextEditingController(text: _userToDisplay.specialization ?? '');
    _bioController = TextEditingController(text: _userToDisplay.bio ?? '');
    
    _selectedDOB = _userToDisplay.dob;
    _profileImageUrl = _userToDisplay.profileImageUrl;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
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
      initialDate: _selectedDOB ?? DateTime(1980),
      firstDate: DateTime(1940),
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
        'specialization': _specializationController.text.trim(),
        'bio': _bioController.text.trim(),
      };
      
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
    // Always use the determined user
    final user = _userToDisplay;
    
    if (user.role != 'doctor') {
      return const Scaffold(
        body: Center(
          child: Text('This profile page is only for doctors.'),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            backgroundColor: Colors.blue[100],
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
              
              // Personal Information Section
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
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
              const SizedBox(height: 24),
              
              // Professional Information Section
              const Text(
                'Professional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Specialization Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  prefixIcon: Icon(Icons.medical_services),
                  border: OutlineInputBorder(),
                ),
                value: _specializationController.text.isEmpty 
                    ? null 
                    : _specializationController.text,
                items: _specializations.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: !widget.viewOnly && _isEditing
                    ? (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _specializationController.text = newValue;
                          });
                        }
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your specialization';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Bio Field
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Professional Bio',
                  hintText: 'Tell patients about your qualifications and experience',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                enabled: !widget.viewOnly && _isEditing,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your professional bio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
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
}