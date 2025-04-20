// If this file doesn't exist, create it

import 'package:flutter/material.dart';
import 'package:happ/ui/screens/legal/legal_document_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:happ/core/providers/theme_provider.dart'; // Add this import

// Run this script once to initialize your Firestore database with medical terms
// Create a file: scripts/initialize_medical_terms.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeMedicalTerms() async {
  await Firebase.initializeApp();
  
  final terms = [
    {
      'term': 'pneumothorax',
      'simplified': 'collapsed lung',
      'definition': 'A collection of air in the space around the lungs, causing collapse',
      'category': 'respiratory',
    },
    {
      'term': 'atherosclerosis',
      'simplified': 'hardening of the arteries',
      'definition': 'Buildup of fats and cholesterol in artery walls',
      'category': 'cardiovascular',
    },
    // Cardiovascular terms
    {
      'term': 'myocardial infarction',
      'simplified': 'heart attack',
      'definition': 'Death of heart muscle due to blocked blood supply to part of the heart',
      'category': 'cardiovascular',
    },
    {
      'term': 'angina pectoris',
      'simplified': 'chest pain',
      'definition': 'Chest pain caused by reduced blood flow to the heart muscle',
      'category': 'cardiovascular',
    },
    {
      'term': 'hypertension',
      'simplified': 'high blood pressure',
      'definition': 'Condition where the force of blood against artery walls is consistently too high',
      'category': 'cardiovascular',
    },
    {
      'term': 'arrhythmia',
      'simplified': 'irregular heartbeat',
      'definition': 'Abnormal heart rhythm where the heart beats too fast, too slow, or irregularly',
      'category': 'cardiovascular',
    },
    
    // Respiratory terms
    {
      'term': 'asthma exacerbation',
      'simplified': 'asthma flare-up',
      'definition': 'Worsening of asthma symptoms requiring additional medication',
      'category': 'respiratory',
    },
    {
      'term': 'chronic obstructive pulmonary disease',
      'simplified': 'COPD',
      'definition': 'Progressive lung disease causing breathing difficulty, including emphysema and chronic bronchitis',
      'category': 'respiratory',
    },
    {
      'term': 'dyspnea',
      'simplified': 'shortness of breath',
      'definition': 'Difficulty breathing or a sensation of breathlessness',
      'category': 'respiratory',
    },
    
    // Neurological terms
    {
      'term': 'cerebrovascular accident',
      'simplified': 'stroke',
      'definition': 'Brain damage from interrupted blood flow, causing brain cells to die',
      'category': 'neurological',
    },
    {
      'term': 'migraine cephalalgia',
      'simplified': 'migraine headache',
      'definition': 'Recurring headaches that cause throbbing or pulsing pain, often with nausea and sensitivity to light/sound',
      'category': 'neurological',
    },
    {
      'term': 'syncope',
      'simplified': 'fainting',
      'definition': 'Temporary loss of consciousness caused by insufficient blood flow to the brain',
      'category': 'neurological',
    },
    
    // Gastrointestinal terms
    {
      'term': 'gastroesophageal reflux disease',
      'simplified': 'acid reflux',
      'definition': 'Digestive disorder where stomach acid frequently flows back into the esophagus',
      'category': 'gastrointestinal',
    },
    {
      'term': 'cholelithiasis',
      'simplified': 'gallstones',
      'definition': 'Hard deposits that form in the gallbladder',
      'category': 'gastrointestinal',
    },
    {
      'term': 'hepatic steatosis',
      'simplified': 'fatty liver',
      'definition': 'Buildup of fat in the liver cells',
      'category': 'gastrointestinal',
    },
    
    // Dermatological terms
    {
      'term': 'urticaria',
      'simplified': 'hives',
      'definition': 'Raised, itchy welts on the skin triggered by an allergic reaction',
      'category': 'dermatological',
    },
    {
      'term': 'pruritus',
      'simplified': 'itching',
      'definition': 'Uncomfortable skin sensation that causes an urge to scratch',
      'category': 'dermatological',
    },
    {
      'term': 'cellulitis',
      'simplified': 'skin infection',
      'definition': 'Bacterial infection of the deeper layers of skin and tissue beneath the skin',
      'category': 'dermatological',
    },
    
    // Endocrine terms
    {
      'term': 'diabetes mellitus',
      'simplified': 'diabetes',
      'definition': 'Group of disorders that affect how your body processes blood sugar',
      'category': 'endocrine',
    },
    {
      'term': 'hypothyroidism',
      'simplified': 'underactive thyroid',
      'definition': 'Condition where the thyroid gland doesn\'t produce enough thyroid hormone',
      'category': 'endocrine',
    },
    {
      'term': 'hyperglycemia',
      'simplified': 'high blood sugar',
      'definition': 'Elevated level of glucose in the bloodstream',
      'category': 'endocrine',
    },
    
    // Musculoskeletal terms
    {
      'term': 'osteoarthritis',
      'simplified': 'wear and tear arthritis',
      'definition': 'Degeneration of joint cartilage and underlying bone causing pain and stiffness',
      'category': 'musculoskeletal',
    },
    {
      'term': 'tendinitis',
      'simplified': 'inflamed tendon',
      'definition': 'Inflammation or irritation of a tendon, causing pain and tenderness',
      'category': 'musculoskeletal',
    },
    {
      'term': 'spondylosis',
      'simplified': 'spine degeneration',
      'definition': 'Age-related wear and tear affecting the spinal disks and joints',
      'category': 'musculoskeletal',
    },
    
    // Surgical terms
    {
      'term': 'appendectomy',
      'simplified': 'appendix removal surgery',
      'definition': 'Surgical removal of the appendix',
      'category': 'surgical',
    },
    {
      'term': 'cholecystectomy',
      'simplified': 'gallbladder removal',
      'definition': 'Surgical removal of the gallbladder',
      'category': 'surgical',
    },
    {
      'term': 'nephrectomy',
      'simplified': 'kidney removal',
      'definition': 'Surgical removal of a kidney',
      'category': 'surgical',
    },
    
    // Ophthalmology terms
    {
      'term': 'presbyopia',
      'simplified': 'age-related farsightedness',
      'definition': 'Gradual loss of ability to focus on nearby objects with age',
      'category': 'ophthalmology',
    },
    {
      'term': 'cataract',
      'simplified': 'cloudy lens',
      'definition': 'Clouding of the normally clear lens of the eye',
      'category': 'ophthalmology',
    },
    {
      'term': 'glaucoma',
      'simplified': 'increased eye pressure',
      'definition': 'Group of eye conditions that damage the optic nerve, often caused by abnormally high pressure in the eye',
      'category': 'ophthalmology',
    },
    
    // Mental health terms
    {
      'term': 'major depressive disorder',
      'simplified': 'clinical depression',
      'definition': 'Mood disorder causing persistent feelings of sadness and loss of interest',
      'category': 'psychiatric',
    },
    {
      'term': 'generalized anxiety disorder',
      'simplified': 'anxiety disorder',
      'definition': 'Persistent and excessive worry about various things that is difficult to control',
      'category': 'psychiatric',
    },
    {
      'term': 'insomnia',
      'simplified': 'sleep disorder',
      'definition': 'Persistent difficulty falling asleep or staying asleep despite opportunity',
      'category': 'psychiatric',
    },
  ];
  
  final batch = FirebaseFirestore.instance.batch();
  final collection = FirebaseFirestore.instance.collection('medical_terminology');
  
  for (final term in terms) {
    final docRef = collection.doc();
    batch.set(docRef, term);
  }
  
  await batch.commit();
  print('Initialized ${terms.length} medical terms in Firestore');
}

void main() async {
  await initializeMedicalTerms();
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Accessibility settings
  bool _simplifyMedicalTerms = true;
  String _textSize = 'Medium';
  bool _highContrastMode = false;
  
  // Notification settings
  bool _appointmentReminders = true;
  bool _medicationReminders = true;
  bool _labResultAlerts = true;
  int _reminderTime = 60; // minutes before appointment
  
  // Privacy settings
  bool _biometricAuth = false;
  bool _shareDataWithDoctors = true;
  String _autoLockTimeout = '5 minutes';
  
  // Appearance settings
  String _themeMode = 'System';
  Color _accentColor = Colors.blue;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllPreferences();
  }
  
  // Load all preferences at once
  Future<void> _loadAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Accessibility
      _simplifyMedicalTerms = prefs.getBool('simplify_medical_terms') ?? true;
      _textSize = prefs.getString('text_size') ?? 'Medium';
      _highContrastMode = prefs.getBool('high_contrast_mode') ?? false;
      
      // Notifications
      _appointmentReminders = prefs.getBool('appointment_reminders') ?? true;
      _medicationReminders = prefs.getBool('medication_reminders') ?? true;
      _labResultAlerts = prefs.getBool('lab_result_alerts') ?? true;
      _reminderTime = prefs.getInt('reminder_time') ?? 60;
      
      // Privacy
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _shareDataWithDoctors = prefs.getBool('share_data_with_doctors') ?? true;
      _autoLockTimeout = prefs.getString('auto_lock_timeout') ?? '5 minutes';
      
      // Appearance
      _themeMode = prefs.getString('theme_mode') ?? 'System';
      final savedColorValue = prefs.getInt('accent_color');
      if (savedColorValue != null) {
        _accentColor = Color(savedColorValue);
      }
      
      _isLoading = false;
    });
  }
  
  // Save methods for each setting group
  Future<void> _saveAccessibilitySetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      switch (key) {
        case 'simplify_medical_terms':
          _simplifyMedicalTerms = value;
          prefs.setBool(key, value);
          break;
        case 'text_size':
          _textSize = value;
          prefs.setString(key, value);
          break;
        case 'high_contrast_mode':
          _highContrastMode = value;
          prefs.setBool(key, value);
          break;
      }
    });
  }
  
  Future<void> _saveNotificationSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      switch (key) {
        case 'appointment_reminders':
          _appointmentReminders = value;
          prefs.setBool(key, value);
          break;
        case 'medication_reminders':
          _medicationReminders = value;
          prefs.setBool(key, value);
          break;
        case 'lab_result_alerts':
          _labResultAlerts = value;
          prefs.setBool(key, value);
          break;
        case 'reminder_time':
          _reminderTime = value;
          prefs.setInt(key, value);
          break;
      }
    });
  }
  
  Future<void> _savePrivacySetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      switch (key) {
        case 'biometric_auth':
          _biometricAuth = value;
          prefs.setBool(key, value);
          // Additional logic to enable/disable biometric auth
          break;
        case 'share_data_with_doctors':
          _shareDataWithDoctors = value;
          prefs.setBool(key, value);
          break;
        case 'auto_lock_timeout':
          _autoLockTimeout = value;
          prefs.setString(key, value);
          break;
      }
    });
  }
  
  Future<void> _saveAppearanceSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      switch (key) {
        case 'theme_mode':
          _themeMode = value;
          prefs.setString(key, value);
          break;
        case 'accent_color':
          _accentColor = value;
          prefs.setInt(key, value.value);
          break;
      }
    });
  }

  // Add these methods to the _SettingsScreenState class

  // Show Terms of Service
  void _showTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegalDocumentScreen(
          title: 'Terms of Service',
          documentType: LegalDocumentType.termsOfService,
        ),
      ),
    );
  }

  // Show Privacy Policy
  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegalDocumentScreen(
          title: 'Privacy Policy',
          documentType: LegalDocumentType.privacyPolicy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ACCESSIBILITY SECTION
                _buildSectionHeader('Accessibility', Icons.accessibility_new, Colors.blue),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Simplify Medical Terms'),
                        subtitle: const Text('Convert medical jargon to plain language'),
                        value: _simplifyMedicalTerms,
                        onChanged: (value) => _saveAccessibilitySetting('simplify_medical_terms', value),
                        secondary: Icon(
                          Icons.medical_services,
                          color: _simplifyMedicalTerms ? Colors.blue : Colors.grey,
                        ),
                      ),
                      // const Divider(height: 1),
                      // ListTile(
                      //   title: const Text('Text Size'),
                      //   subtitle: Text(_textSize),
                      //   leading: const Icon(Icons.format_size, color: Colors.blue),
                      //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      //   onTap: () => _showTextSizeDialog(),
                      // ),
                      // const Divider(height: 1),
                      // SwitchListTile(
                      //   title: const Text('High Contrast Mode'),
                      //   subtitle: const Text('Increase contrast for better readability'),
                      //   value: _highContrastMode,
                      //   onChanged: (value) => _saveAccessibilitySetting('high_contrast_mode', value),
                      //   secondary: Icon(
                      //     Icons.contrast,
                      //     color: _highContrastMode ? Colors.blue : Colors.grey,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                
                // NOTIFICATIONS SECTION
                // _buildSectionHeader('Notifications', Icons.notifications, Colors.orange),
                // Card(
                //   margin: const EdgeInsets.only(bottom: 16),
                //   child: Column(
                //     children: [
                //       SwitchListTile(
                //         title: const Text('Appointment Reminders'),
                //         subtitle: const Text('Get notified before appointments'),
                //         value: _appointmentReminders,
                //         onChanged: (value) => _saveNotificationSetting('appointment_reminders', value),
                //         secondary: Icon(
                //           Icons.calendar_today,
                //           color: _appointmentReminders ? Colors.orange : Colors.grey,
                //         ),
                //       ),
                //       const Divider(height: 1),
                //       SwitchListTile(
                //         title: const Text('Medication Reminders'),
                //         subtitle: const Text('Get reminded to take medications'),
                //         value: _medicationReminders,
                //         onChanged: (value) => _saveNotificationSetting('medication_reminders', value),
                //         secondary: Icon(
                //           Icons.medication,
                //           color: _medicationReminders ? Colors.orange : Colors.grey,
                //         ),
                //       ),
                //       const Divider(height: 1),
                //       SwitchListTile(
                //         title: const Text('Lab Result Alerts'),
                //         subtitle: const Text('Get notified when new lab results arrive'),
                //         value: _labResultAlerts,
                //         onChanged: (value) => _saveNotificationSetting('lab_result_alerts', value),
                //         secondary: Icon(
                //           Icons.science,
                //           color: _labResultAlerts ? Colors.orange : Colors.grey,
                //         ),
                //       ),
                //       const Divider(height: 1),
                //       ListTile(
                //         title: const Text('Reminder Time'),
                //         subtitle: Text('$_reminderTime minutes before appointment'),
                //         leading: const Icon(Icons.timer, color: Colors.orange),
                //         trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                //         onTap: () => _showReminderTimeDialog(),
                //       ),
                //     ],
                //   ),
                // ),
                
                // PRIVACY & SECURITY SECTION
                // _buildSectionHeader('Privacy & Security', Icons.security, Colors.green),
                // Card(
                //   margin: const EdgeInsets.only(bottom: 16),
                //   child: Column(
                //     children: [
                //       SwitchListTile(
                //         title: const Text('Biometric Authentication'),
                //         subtitle: const Text('Use fingerprint or face ID to access the app'),
                //         value: _biometricAuth,
                //         onChanged: (value) => _savePrivacySetting('biometric_auth', value),
                //         secondary: Icon(
                //           Icons.fingerprint,
                //           color: _biometricAuth ? Colors.green : Colors.grey,
                //         ),
                //       ),
                //       const Divider(height: 1),
                //       SwitchListTile(
                //         title: const Text('Share Data with Doctors'),
                //         subtitle: const Text('Allow your doctors to access your health data'),
                //         value: _shareDataWithDoctors,
                //         onChanged: (value) => _savePrivacySetting('share_data_with_doctors', value),
                //         secondary: Icon(
                //           Icons.share,
                //           color: _shareDataWithDoctors ? Colors.green : Colors.grey,
                //         ),
                //       ),
                //       const Divider(height: 1),
                //       ListTile(
                //         title: const Text('Auto-Lock Timeout'),
                //         subtitle: Text(_autoLockTimeout),
                //         leading: const Icon(Icons.lock_clock, color: Colors.green),
                //         trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                //         onTap: () => _showAutoLockDialog(),
                //       ),
                //     ],
                //   ),
                // ),
                
                // APPEARANCE SECTION
                _buildSectionHeader('Appearance', Icons.palette, Colors.purple),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Theme'),
                        subtitle: Text(_themeMode),
                        leading: const Icon(Icons.dark_mode, color: Colors.purple),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showThemeDialog(),
                      ),
                      // const Divider(height: 1),
                      // ListTile(
                      //   title: const Text('Accent Color'),
                      //   subtitle: Row(
                      //     children: [
                      //       Container(
                      //         width: 16,
                      //         height: 16,
                      //         decoration: BoxDecoration(
                      //           color: _accentColor,
                      //           shape: BoxShape.circle,
                      //         ),
                      //       ),
                      //       const SizedBox(width: 8),
                      //       Text(_getColorName(_accentColor)),
                      //     ],
                      //   ),
                      //   leading: const Icon(Icons.color_lens, color: Colors.purple),
                      //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      //   onTap: () => _showColorPickerDialog(),
                      // ),
                    ],
                  ),
                ),
                
                // ACCOUNT & DATA SECTION
                // _buildSectionHeader('Account & Data', Icons.account_circle, Colors.indigo),
                // Card(
                //   margin: const EdgeInsets.only(bottom: 16),
                //   child: Column(
                //     children: [
                //       ListTile(
                //         title: const Text('Manage Health Data'),
                //         subtitle: const Text('Control what health data is stored'),
                //         leading: const Icon(Icons.health_and_safety, color: Colors.indigo),
                //         trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                //         onTap: () {
                //           // Navigate to health data management screen
                //         },
                //       ),
                //       const Divider(height: 1),
                //       ListTile(
                //         title: const Text('Download My Data'),
                //         subtitle: const Text('Export all your health records'),
                //         leading: const Icon(Icons.download, color: Colors.indigo),
                //         trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                //         onTap: () {
                //           // Show data export options
                //         },
                //       ),
                //       const Divider(height: 1),
                //       ListTile(
                //         title: const Text('Update Profile'),
                //         subtitle: const Text('Change your account information'),
                //         leading: const Icon(Icons.edit, color: Colors.indigo),
                //         trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                //         onTap: () {
                //           // Navigate to profile edit screen
                //         },
                //       ),
                //     ],
                //   ),
                // ),
                
                // ABOUT SECTION
                _buildSectionHeader('About', Icons.info, Colors.teal),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('App Version'),
                        subtitle: const Text('1.0.0'),
                        leading: const Icon(Icons.phone_android, color: Colors.teal),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Terms of Service'),
                        leading: const Icon(Icons.description, color: Colors.teal),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showTermsOfService,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Privacy Policy'),
                        leading: const Icon(Icons.privacy_tip, color: Colors.teal),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showPrivacyPolicy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  // Helper methods for building UI components
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  // Dialog for text size selection
  Future<void> _showTextSizeDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextSizeOption('Small'),
            _buildTextSizeOption('Medium'),
            _buildTextSizeOption('Large'),
            _buildTextSizeOption('Extra Large'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextSizeOption(String size) {
    return ListTile(
      title: Text(
        'Text Sample',
        style: TextStyle(
          fontSize: size == 'Small' ? 14 : 
                   size == 'Medium' ? 16 : 
                   size == 'Large' ? 18 : 20,
        ),
      ),
      trailing: _textSize == size ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        _saveAccessibilitySetting('text_size', size);
        Navigator.pop(context);
      },
    );
  }
  
  // Dialog for reminder time selection
  Future<void> _showReminderTimeDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminder Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReminderTimeOption(15),
            _buildReminderTimeOption(30),
            _buildReminderTimeOption(60),
            _buildReminderTimeOption(120),
            _buildReminderTimeOption(1440), // 24 hours
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReminderTimeOption(int minutes) {
    String displayText = minutes == 1440 
        ? '24 hours before' 
        : '$minutes minutes before';
        
    return ListTile(
      title: Text(displayText),
      trailing: _reminderTime == minutes ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        _saveNotificationSetting('reminder_time', minutes);
        Navigator.pop(context);
      },
    );
  }
  
  // Dialog for auto-lock timeout selection
  Future<void> _showAutoLockDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAutoLockOption('Immediately'),
            _buildAutoLockOption('1 minute'),
            _buildAutoLockOption('5 minutes'),
            _buildAutoLockOption('10 minutes'),
            _buildAutoLockOption('30 minutes'),
            _buildAutoLockOption('Never'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAutoLockOption(String timeout) {
    return ListTile(
      title: Text(timeout),
      trailing: _autoLockTimeout == timeout ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        _savePrivacySetting('auto_lock_timeout', timeout);
        Navigator.pop(context);
      },
    );
  }
  
  // Dialog for theme selection with real-time preview
  Future<void> _showThemeDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('Light'),
            _buildThemeOption('Dark'),
            _buildThemeOption('System'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeOption(String theme) {
    return ListTile(
      leading: Icon(
        theme == 'Light' ? Icons.wb_sunny : 
        theme == 'Dark' ? Icons.nightlight_round : 
        Icons.brightness_auto,
        color: theme == 'Light' ? Colors.orange : 
               theme == 'Dark' ? Colors.indigo : 
               Colors.purple,
      ),
      title: Text(theme),
      trailing: _themeMode == theme ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        // Apply theme change immediately
        _applyThemeChange(theme);
        Navigator.pop(context);
      },
    );
  }
  
  // New method to apply theme changes in real-time
  void _applyThemeChange(String theme) async {
    // Save to preferences
    _saveAppearanceSetting('theme_mode', theme);
    
    // Get theme provider and update theme
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    // Convert string mode to ThemeMode enum
    ThemeMode newThemeMode;
    switch (theme) {
      case 'Light':
        newThemeMode = ThemeMode.light;
        break;
      case 'Dark':
        newThemeMode = ThemeMode.dark;
        break;
      case 'System':
      default:
        newThemeMode = ThemeMode.system;
        break;
    }
    
    // Update theme globally
    themeProvider.setThemeMode(newThemeMode);
    
    // Show a confirmation toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Theme updated to $theme mode'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // Dialog for color picker
  Future<void> _showColorPickerDialog() async {
    Color selectedColor = _accentColor;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorOption(Colors.blue, 'Blue'),
              _buildColorOption(Colors.red, 'Red'),
              _buildColorOption(Colors.green, 'Green'),
              _buildColorOption(Colors.purple, 'Purple'),
              _buildColorOption(Colors.orange, 'Orange'),
              _buildColorOption(Colors.teal, 'Teal'),
              _buildColorOption(Colors.pink, 'Pink'),
              _buildColorOption(Colors.indigo, 'Indigo'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorOption(Color color, String name) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(name),
      trailing: _accentColor.value == color.value ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        _saveAppearanceSetting('accent_color', color);
        Navigator.pop(context);
      },
    );
  }
  
  // Helper method to get color name
  String _getColorName(Color color) {
    if (color.value == Colors.blue.value) return 'Blue';
    if (color.value == Colors.red.value) return 'Red';
    if (color.value == Colors.green.value) return 'Green';
    if (color.value == Colors.purple.value) return 'Purple';
    if (color.value == Colors.orange.value) return 'Orange';
    if (color.value == Colors.teal.value) return 'Teal';
    if (color.value == Colors.pink.value) return 'Pink';
    if (color.value == Colors.indigo.value) return 'Indigo';
    return 'Custom';
  }
}
