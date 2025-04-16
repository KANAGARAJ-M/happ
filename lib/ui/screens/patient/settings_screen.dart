// If this file doesn't exist, create it

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Run this script once to initialize your Firestore database with medical terms
// Create a file: scripts/initialize_medical_terms.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeMedicalTerms() async {
  await Firebase.initializeApp();
  
  // final terms = [
  //   {
  //     'term': 'pneumothorax',
  //     'simplified': 'collapsed lung',
  //     'definition': 'A collection of air in the space around the lungs, causing collapse',
  //     'category': 'respiratory',
  //   },
  //   {
  //     'term': 'atherosclerosis',
  //     'simplified': 'hardening of the arteries',
  //     'definition': 'Buildup of fats and cholesterol in artery walls',
  //     'category': 'cardiovascular',
  //   },
  //   // Add more terms as needed
  // ];


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
  bool _simplifyMedicalTerms = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _simplifyMedicalTerms = prefs.getBool('simplify_medical_terms') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSimplifyPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simplify_medical_terms', value);
    setState(() {
      _simplifyMedicalTerms = value;
    });
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
                const Text(
                  'Accessibility',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    title: const Text('Simplify Medical Terms'),
                    subtitle: const Text(
                        'Automatically convert medical jargon to plain language'),
                    value: _simplifyMedicalTerms,
                    onChanged: _saveSimplifyPreference,
                    secondary: Icon(
                      Icons.medical_services,
                      color: _simplifyMedicalTerms ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
                
                // Add more settings as needed
              ],
            ),
    );
  }
}