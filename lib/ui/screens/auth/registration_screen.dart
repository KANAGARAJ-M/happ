import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/ui/screens/auth/login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _patientIdController = TextEditingController(); // New patient ID controller
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _specializationController = TextEditingController();
  final _bioController = TextEditingController();
  
  DateTime? _selectedDOB;
  String _role = 'patient'; // Default role
  bool _acceptedTerms = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _generatePatientId = true; // Option to auto-generate patient ID

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
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _aadhaarController.dispose();
    _patientIdController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Generate a unique patient ID
  String _generateUniquePatientId() {
    // Format: PID-[Year]-[Random 5 digit number]
    final year = DateTime.now().year.toString();
    final random = (10000 + DateTime.now().millisecondsSinceEpoch % 90000).toString();
    return 'PID-$year-$random';
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

  Future<bool> _checkPatientIdExists(String patientId) async {
    try {
      // Query Firestore to check if patientId already exists
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking patient ID: $e');
      return false;
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (!_acceptedTerms) {
      setState(() {
        _errorMessage = 'You must accept the terms and conditions to continue';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Basic user information for registration
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      
      // Additional fields to update after basic registration
      final Map<String, dynamic> additionalInfo = {
        'phone': _phoneController.text.trim(),
        'role': _role,
      };
      
      // Add DOB if selected
      if (_selectedDOB != null) {
        additionalInfo['dob'] = _selectedDOB;
        additionalInfo['age'] = _calculateAge(_selectedDOB);
      }
      
      // Add role-specific fields
      if (_role == 'patient') {
        // Handle patient ID (either generate or use provided)
        String patientId;
        if (_generatePatientId) {
          // Generate until we get a unique one
          bool idExists;
          do {
            patientId = _generateUniquePatientId();
            idExists = await _checkPatientIdExists(patientId);
          } while (idExists);
        } else {
          patientId = _patientIdController.text.trim();
          // Verify patient ID is unique if manually entered
          if (patientId.isNotEmpty) {
            bool idExists = await _checkPatientIdExists(patientId);
            if (idExists) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Patient ID already exists. Please use a different ID or let the system generate one.';
              });
              return;
            }
          }
        }
        
        // Add patientId to the user record
        additionalInfo['patientId'] = patientId;
        
        if (_aadhaarController.text.isNotEmpty) {
          additionalInfo['aadhaarNumber'] = _aadhaarController.text.trim();
        }
        
        if (_heightController.text.isNotEmpty) {
          additionalInfo['height'] = double.tryParse(_heightController.text.trim());
        }
        
        if (_weightController.text.isNotEmpty) {
          additionalInfo['weight'] = double.tryParse(_weightController.text.trim());
        }
      } else { // Doctor
        if (_specializationController.text.isNotEmpty) {
          additionalInfo['specialization'] = _specializationController.text.trim();
        }
        
        if (_bioController.text.isNotEmpty) {
          additionalInfo['bio'] = _bioController.text.trim();
        }
      }
      
      // Register the user with all information
      final success = await authProvider.signUp(
        name,
        email,
        password,
        additionalInfo: additionalInfo,
      );
      
      if (success && mounted) {
        // Show success message with patient ID if applicable
        String message = 'Registration successful! Please login';
        if (_role == 'patient' && additionalInfo.containsKey('patientId')) {
          message = 'Registration successful! Your Patient ID is ${additionalInfo['patientId']}. Please login.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
        );
        
        // Navigate to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Continue to next step if validation passes
  void _continue() {
    bool isLastStep = _currentStep == 2;
    
    if (isLastStep) {
      _registerUser();
    } else {
      // Validate current step before proceeding
      bool isValid = true;
      
      if (_currentStep == 0) {
        // Basic info validation
        if (_nameController.text.isEmpty || 
            _emailController.text.isEmpty ||
            _passwordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty ||
            _passwordController.text != _confirmPasswordController.text) {
          isValid = false;
        }
      } else if (_currentStep == 1) {
        // Role-specific info validation
        if (_phoneController.text.isEmpty || _selectedDOB == null) {
          isValid = false;
        }
        
        if (_role == 'doctor' && _specializationController.text.isEmpty) {
          isValid = false;
        }
        
        if (_role == 'patient' && !_generatePatientId && _patientIdController.text.isEmpty) {
          isValid = false;
        }
      }
      
      if (isValid) {
        setState(() {
          _currentStep += 1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields correctly')),
        );
      }
    }
  }

  void _cancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Material(
        child: Form(
          key: _formKey,
          child: Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _continue,
            onStepCancel: _cancel,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : details.onStepContinue,
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...')
                                ],
                              )
                            : Text(_currentStep == 2
                                ? 'Register'
                                : 'Next'),
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Step 1: Basic Information & Role Selection
              Step(
                title: const Text('Basic Info'),
                isActive: _currentStep >= 0,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display error message if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
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
                    ],
                    
                    // Role Selection
                    const Text(
                      'I am a:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            child: ChoiceChip(
                              label: const Text('Patient'),
                              selected: _role == 'patient',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _role = 'patient';
                                  });
                                }
                              },
                              selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Material(
                            child: ChoiceChip(
                              label: const Text('Doctor'),
                              selected: _role == 'doctor',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _role = 'doctor';
                                  });
                                }
                              },
                              selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: const Icon(Icons.lock_clock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              // Step 2: Personal Information (changes based on role)
              Step(
                title: const Text('Personal Info'),
                isActive: _currentStep >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone number (common for both)
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
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
                    
                    // Date of Birth (common for both)
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDOB == null
                              ? 'Select Date of Birth'
                              : DateFormat('MMM dd, yyyy').format(_selectedDOB!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Age display (calculated from DOB)
                    if (_selectedDOB != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          'Age: ${_calculateAge(_selectedDOB)} years',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Role-specific fields
                    if (_role == 'patient') ...[
                      // Patient ID section - NEW
                      const Text(
                        'Patient ID',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Option to auto-generate or manually enter
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Auto-generate'),
                              value: true,
                              groupValue: _generatePatientId,
                              onChanged: (value) {
                                setState(() {
                                  _generatePatientId = value!;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Enter manually'),
                              value: false,
                              groupValue: _generatePatientId,
                              onChanged: (value) {
                                setState(() {
                                  _generatePatientId = value!;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      
                      // Show text field only if manual entry is selected
                      if (!_generatePatientId) ...[
                        TextFormField(
                          controller: _patientIdController,
                          decoration: const InputDecoration(
                            labelText: 'Patient ID *',
                            hintText: 'Enter unique patient identifier',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (!_generatePatientId && (value == null || value.isEmpty)) {
                              return 'Please enter a patient ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Aadhaar number (for patient)
                      TextFormField(
                        controller: _aadhaarController,
                        decoration: const InputDecoration(
                          labelText: 'Aadhaar Number *',
                          prefixIcon: Icon(Icons.credit_card),
                          border: OutlineInputBorder(),
                          hintText: '12-digit Aadhaar Number',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your Aadhaar number';
                          }
                          if (value.length != 12) {
                            return 'Aadhaar number must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Height (optional for patient)
                      TextFormField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height (cm) - Optional',
                          prefixIcon: Icon(Icons.height),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Weight (optional for patient)
                      TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg) - Optional',
                          prefixIcon: Icon(Icons.monitor_weight),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
                        ],
                      ),
                    ] else ...[
                      // Specialization (for doctor)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Specialization *',
                          prefixIcon: Icon(Icons.local_hospital),
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
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _specializationController.text = newValue;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your specialization';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Bio (for doctor)
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Professional Bio *',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          hintText: 'Brief description of your qualifications and experience',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your professional bio';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              // Step 3: Terms and Conditions
              Step(
                title: const Text('Terms'),
                isActive: _currentStep >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SingleChildScrollView(
                        child: Text(
                          'By using this application, you agree to the following terms and conditions:\n\n'
                          '1. Your personal information will be processed in accordance with our Privacy Policy.\n\n'
                          '2. You acknowledge that this application is not a substitute for professional medical advice, diagnosis, or treatment.\n\n'
                          '3. For Doctors: You confirm that you are a licensed medical practitioner and all information provided is accurate and up-to-date.\n\n'
                          '4. For Patients: You agree to provide accurate personal and medical information.\n\n'
                          '5. All users agree to use the application in accordance with applicable laws and regulations.\n\n'
                          '6. We reserve the right to modify these terms at any time.\n\n'
                          '7. Your data may be shared with healthcare providers involved in your care.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('I accept the terms and conditions'),
                      value: _acceptedTerms,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}