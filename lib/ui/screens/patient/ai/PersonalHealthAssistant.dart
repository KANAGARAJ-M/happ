import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:happ/core/services/medical_nlp_service.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';

class PersonalHealthAssistant extends StatefulWidget {
  const PersonalHealthAssistant({Key? key}) : super(key: key);

  @override
  State<PersonalHealthAssistant> createState() => _PersonalHealthAssistantState();
}

class _PersonalHealthAssistantState extends State<PersonalHealthAssistant> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicalNlpService _medicalNlpService = MedicalNlpService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  String? _errorMessage;
  User? _currentUser;
  
  // Patient health data
  List<Record> _patientRecords = [];
  List<Appointment> _appointments = [];
  Map<String, dynamic> _healthInsights = {};
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _healthTips = [];
  
  // Analysis results
  Map<String, dynamic> _analysisResults = {
    'conditions': [],
    'allergies': [],
    'medications': [],
    'recentVisits': [],
    'upcomingAppointments': [],
    'missedAppointments': [],
    'healthTrends': {},
  };

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get current user from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _currentUser = authProvider.currentUser;
      
      if (_currentUser == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Fetch records using RecordsProvider
      final recordsProvider = Provider.of<RecordsProvider>(context, listen: false);
      if (!recordsProvider.initialized) {
        await recordsProvider.fetchRecords(_currentUser!.id);
      }
      _patientRecords = recordsProvider.records;

      // Fetch appointments using AppointmentProvider
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      await appointmentProvider.fetchPatientAppointments(_currentUser!.id);
      _appointments = appointmentProvider.appointments;

      // Fetch medical history and health insights from Firestore
      await _fetchHealthInsights();
      
      // Run AI analysis on the patient data
      await _analyzePatientData();
      
      // Add new health trend analysis
      final trends = await _analyzeHealthTrends();
      _analysisResults['healthTrends'] = trends;
      
      // Generate personalized recommendations
      _generateRecommendations();
      
      // Add health goals
      // _analysisResults['healthGoals'] = _generateHealthGoals();
      
      // Add conversation starters
      _analysisResults['conversationStarters'] = _generateDoctorConversationStarters();
      
      // Run advanced AI analysis
      final advancedInsights = await _performAdvancedHealthAnalysis();
      _analysisResults['advancedInsights'] = advancedInsights;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading patient data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHealthInsights() async {
    try {
      // Fetch medical conditions and allergies from the user document
      final userDoc = await _firestore.collection('users').doc(_currentUser!.id).get();
      final userData = userDoc.data();
      
      if (userData != null) {
        _healthInsights = {
          'conditions': userData['medicalConditions'] ?? [],
          'allergies': userData['allergies'] ?? '',
          'bloodType': userData['bloodGroup'] ?? 'Unknown',
          'height': userData['height'] ?? 'Not specified',
          'weight': userData['weight'] ?? 'Not specified',
        };
      }
      
      // Fetch medical history collection
      final historySnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .collection('medicalHistory')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      if (historySnapshot.docs.isNotEmpty) {
        // Extract insights from medical history
        for (var doc in historySnapshot.docs) {
          final data = doc.data();
          
          // Add conditions to analysisResults if not already there
          if (data['conditions'] != null && data['conditions'] is List) {
            for (var condition in List<String>.from(data['conditions'])) {
              if (!_analysisResults['conditions'].contains(condition)) {
                _analysisResults['conditions'].add(condition);
              }
            }
          }
          
          // Process medical insights if available
          if (data['insights'] != null && data['insights'] is List) {
            final insights = List<Map<String, dynamic>>.from(data['insights']);
            
            for (var insight in insights) {
              // Check if this is a high-severity insight
              if (insight['severity'] == 'High') {
                // Add to critical insights
                if (!_analysisResults['criticalInsights']) {
                  _analysisResults['criticalInsights'] = [];
                }
                _analysisResults['criticalInsights'].add(insight);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching health insights: $e');
    }
  }

  Future<void> _analyzePatientData() async {
    try {
      // Sort records by date (newest first)
      _patientRecords.sort((a, b) => b.date.compareTo(a.date));
      
      // Analyze recent records (last 90 days)
      final DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final recentRecords = _patientRecords.where((r) => r.date.isAfter(threeMonthsAgo)).toList();
      
      // Extract medical terms from recent records
      List<String> medicalTerms = [];
      for (var record in recentRecords) {
        // We'll use our existing MedicalNLPService to extract terms
        final analysisResult = await _medicalNlpService.analyzeContent(record.description);
        
        // Add each term to our list
        for (var insight in analysisResult.criticalInsights) {
          if (!medicalTerms.contains(insight.term)) {
            medicalTerms.add(insight.term);
          }
        }
      }
      
      // Add these terms to analysis results
      _analysisResults['recentTerms'] = medicalTerms;
      
      // Categorize appointments
      final now = DateTime.now();
      
      // Upcoming appointments
      _analysisResults['upcomingAppointments'] = _appointments
          .where((a) => a.date.isAfter(now) && a.status == 'confirmed')
          .toList();
      
      // Recent visits
      _analysisResults['recentVisits'] = _appointments
          .where((a) => a.date.isBefore(now) && a.status == 'completed')
          .toList();
      
      // Missed appointments
      _analysisResults['missedAppointments'] = _appointments
          .where((a) => a.date.isBefore(now) && a.status == 'cancelled')
          .toList();
      
      // Calculate appointment adherence rate
      final totalPastAppointments = _analysisResults['recentVisits'].length + 
                                   _analysisResults['missedAppointments'].length;
      
      if (totalPastAppointments > 0) {
        final adherenceRate = (_analysisResults['recentVisits'].length / totalPastAppointments) * 100;
        _analysisResults['appointmentAdherence'] = adherenceRate.toStringAsFixed(1) + '%';
      } else {
        _analysisResults['appointmentAdherence'] = 'N/A';
      }
      
      // Check for gaps in care (no appointments in last 6 months)
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final hasRecentAppointment = _appointments.any((a) => 
          (a.status == 'completed' || a.status == 'confirmed') && 
          a.date.isAfter(sixMonthsAgo));
      
      _analysisResults['hasCareGap'] = !hasRecentAppointment;
      
      // Identify potential health risks based on medical conditions
      _identifyHealthRisks();
      
      // Analyze health trends over time
      _analysisResults['healthTrends'] = await _analyzeHealthTrends();
    } catch (e) {
      print('Error analyzing patient data: $e');
    }
  }
  
  void _identifyHealthRisks() {
    List<Map<String, dynamic>> healthRisks = [];
    
    // Check for known conditions and allergies
    final conditions = _analysisResults['conditions'] ?? [];
    
    // Create risk assessment for specific conditions
    for (var condition in conditions) {
      if (condition.toString().toLowerCase().contains('hypertension') || 
          condition.toString().toLowerCase().contains('high blood pressure')) {
        healthRisks.add({
          'condition': 'Hypertension',
          'riskLevel': 'High',
          'description': 'Hypertension increases risk of heart disease and stroke.',
          'recommendations': [
            'Monitor blood pressure regularly',
            'Reduce sodium intake',
            'Exercise regularly',
            'Take medications as prescribed'
          ]
        });
      }
      
      if (condition.toString().toLowerCase().contains('diabetes')) {
        healthRisks.add({
          'condition': 'Diabetes',
          'riskLevel': 'High',
          'description': 'Diabetes requires careful management to prevent complications.',
          'recommendations': [
            'Monitor blood glucose levels',
            'Follow prescribed diet',
            'Regular physical activity',
            'Regular foot examinations'
          ]
        });
      }
      
      if (condition.toString().toLowerCase().contains('heart') || 
          condition.toString().toLowerCase().contains('cardiac') ||
          condition.toString().toLowerCase().contains('coronary')) {
        healthRisks.add({
          'condition': 'Heart Condition',
          'riskLevel': 'High',
          'description': 'Heart conditions require careful monitoring and lifestyle management.',
          'recommendations': [
            'Take medications as prescribed',
            'Follow a heart-healthy diet',
            'Regular cardiac checkups',
            'Monitor weight and exercise appropriately'
          ]
        });
      }
    }
    
    // Check for care gaps and adherence issues
    if (_analysisResults['hasCareGap'] == true) {
      healthRisks.add({
        'condition': 'Care Gap Detected',
        'riskLevel': 'Medium',
        'description': 'No healthcare visits in the past 6 months.',
        'recommendations': [
          'Schedule a wellness checkup',
          'Update your health screening tests',
          'Review your current medications with a provider'
        ]
      });
    }
    
    if (_analysisResults['appointmentAdherence'] != 'N/A' && 
        double.parse(_analysisResults['appointmentAdherence'].replaceAll('%', '')) < 80) {
      healthRisks.add({
        'condition': 'Low Appointment Adherence',
        'riskLevel': 'Medium',
        'description': 'Missing scheduled appointments may impact your health management.',
        'recommendations': [
          'Set reminders for upcoming appointments',
          'Use app notifications for appointment alerts',
          'Consider telehealth options if transportation is an issue'
        ]
      });
    }
    
    _analysisResults['healthRisks'] = healthRisks;
  }
  
  void _generateRecommendations() {
    List<Map<String, dynamic>> recommendations = [];
    
    // Add recommendations based on health risks
    final healthRisks = _analysisResults['healthRisks'] ?? [];
    for (var risk in healthRisks) {
      recommendations.add({
        'title': risk['condition'],
        'description': risk['description'],
        'recommendations': risk['recommendations'],
        'priority': risk['riskLevel'] == 'High' ? 1 : (risk['riskLevel'] == 'Medium' ? 2 : 3),
        'icon': _getIconForCondition(risk['condition']),
        'color': _getColorForRiskLevel(risk['riskLevel'])
      });
    }
    
    // Add upcoming appointment reminders
    final upcomingAppointments = _analysisResults['upcomingAppointments'] ?? [];
    if (upcomingAppointments.isNotEmpty) {
      final nextAppointment = upcomingAppointments[0];
      recommendations.add({
        'title': 'Upcoming Appointment',
        'description': 'You have an appointment on ${DateFormat('EEEE, MMM d').format(nextAppointment.date)} at ${nextAppointment.timeSlot}',
        'recommendations': [
          'Prepare questions for your doctor',
          'Bring a list of your current medications',
          'Arrive 15 minutes early to complete paperwork'
        ],
        'priority': 2,
        'icon': Icons.calendar_today,
        'color': Colors.blue
      });
    }
    
    // Add general health tips based on patient data
    _generateHealthTips();
    
    // Sort recommendations by priority (1 = highest)
    recommendations.sort((a, b) => a['priority'].compareTo(b['priority']));
    
    _recommendations = recommendations;
  }
  
  void _generateHealthTips() {
    List<Map<String, dynamic>> healthTips = [
      {
        'title': 'Stay Hydrated',
        'description': 'Drink at least 8 glasses of water daily for optimal health.',
        'icon': Icons.water_drop,
        'color': Colors.blue
      },
      {
        'title': 'Regular Exercise',
        'description': 'Aim for at least 150 minutes of moderate activity per week.',
        'icon': Icons.directions_run,
        'color': Colors.green
      },
      {
        'title': 'Balanced Diet',
        'description': 'Include fruits, vegetables, lean proteins, and whole grains.',
        'icon': Icons.restaurant,
        'color': Colors.orange
      },
      {
        'title': 'Adequate Sleep',
        'description': 'Adults should aim for 7-9 hours of quality sleep each night.',
        'icon': Icons.nightlight,
        'color': Colors.indigo
      },
      {
        'title': 'Stress Management',
        'description': 'Practice meditation, deep breathing, or other relaxation techniques.',
        'icon': Icons.spa,
        'color': Colors.purple
      }
    ];
    
    // Personalize tips based on conditions
    final conditions = _analysisResults['conditions'] ?? [];
    
    // Filter or customize tips based on conditions
    if (conditions.any((c) => c.toString().toLowerCase().contains('heart') || 
                       c.toString().toLowerCase().contains('hypertension'))) {
      healthTips.add({
        'title': 'Heart-Healthy Diet',
        'description': 'Focus on low-sodium foods, whole grains, and heart-healthy fats.',
        'icon': Icons.favorite,
        'color': Colors.red
      });
    }
    
    if (conditions.any((c) => c.toString().toLowerCase().contains('diabetes'))) {
      healthTips.add({
        'title': 'Blood Sugar Management',
        'description': 'Monitor carbohydrate intake and eat regular, balanced meals.',
        'icon': Icons.show_chart,
        'color': Colors.blue
      });
    }
    
    _healthTips = healthTips;
  }
  
  IconData _getIconForCondition(String condition) {
    condition = condition.toLowerCase();
    
    if (condition.contains('hypertension') || condition.contains('blood pressure')) {
      return Icons.monitor_heart;
    } else if (condition.contains('diabetes')) {
      return Icons.bloodtype;
    } else if (condition.contains('heart') || condition.contains('cardiac')) {
      return Icons.favorite;
    } else if (condition.contains('care gap')) {
      return Icons.event_busy;
    } else if (condition.contains('appointment')) {
      return Icons.calendar_today;
    } else if (condition.contains('upcoming')) {
      return Icons.event;
    }
    
    return Icons.health_and_safety;
  }
  
  Color _getColorForRiskLevel(String riskLevel) {
    switch (riskLevel) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }

  // Add these new methods to the _PersonalHealthAssistantState class

  // Analyze health trends over time for more intelligent insights
  Future<Map<String, dynamic>> _analyzeHealthTrends() async {
    Map<String, dynamic> trends = {};
    
    try {
      // If we have records spanning multiple dates, analyze trends
      if (_patientRecords.length > 3) {
        _patientRecords.sort((a, b) => b.date.compareTo(a.date));
        
        // Look for patterns in reported symptoms
        final symptomsMap = <String, List<DateTime>>{};
        final recordsByMonth = <int, int>{};
        
        for (var record in _patientRecords) {
          // Track records by month to identify frequency patterns
          final month = record.date.month;
          recordsByMonth[month] = (recordsByMonth[month] ?? 0) + 1;
          
          // Analyze record descriptions for symptoms
          final analysisResult = await _medicalNlpService.analyzeContent(record.description);
          
          for (var insight in analysisResult.criticalInsights) {
            if (!symptomsMap.containsKey(insight.term)) {
              symptomsMap[insight.term] = [];
            }
            symptomsMap[insight.term]!.add(record.date);
          }
        }
        
        // Identify recurring symptoms (reported more than once)
        final recurringSymptoms = symptomsMap.entries
            .where((entry) => entry.value.length > 1)
            .map((entry) => {
                  'term': entry.key,
                  'frequency': entry.value.length,
                  'dates': entry.value,
                })
            .toList();
        
        // Identify seasonal patterns (symptoms occurring in same season)
        final seasonalPatterns = <Map<String, dynamic>>[];
        for (var symptom in recurringSymptoms) {
          final dates = symptom['dates'] as List<DateTime>;
          final seasons = dates.map((date) => (date.month % 12) ~/ 3).toSet();
          
          // If all occurrences fall in same season, it might be seasonal
          if (seasons.length == 1 && dates.length >= 2) {
            final seasonNames = ['Winter', 'Spring', 'Summer', 'Fall'];
            seasonalPatterns.add({
              'term': symptom['term'],
              'season': seasonNames[seasons.first],
              'frequency': dates.length,
            });
          }
        }
        
        // Calculate wellness score trend (0-100)
        // A simple algorithm that improves with fewer reported symptoms and more regular checkups
        final now = DateTime.now();
        final sixMonthsAgo = now.subtract(const Duration(days: 180));
        final recentRecords = _patientRecords.where((r) => r.date.isAfter(sixMonthsAgo)).toList();
        
        final hasRegularCheckups = recentRecords.length >= 2;
        final recentSymptoms = recurringSymptoms.where((s) => 
            (s['dates'] as List<DateTime>).any((date) => date.isAfter(sixMonthsAgo))).length;
            
        final baseScore = 70.0;
        double wellnessScore = baseScore;
        
        // Adjust score based on findings
        wellnessScore += hasRegularCheckups ? 10 : 0;
        wellnessScore -= recentSymptoms * 5;
        
        // Cap score between 0-100
        wellnessScore = wellnessScore > 100 ? 100 : (wellnessScore < 0 ? 0 : wellnessScore);
        
        trends = {
          'recurringSymptoms': recurringSymptoms,
          'seasonalPatterns': seasonalPatterns,
          'recordsByMonth': recordsByMonth,
          'wellnessScore': wellnessScore.round(),
        };
      }
      
      return trends;
    } catch (e) {
      print('Error analyzing health trends: $e');
      return {};
    }
  }
  
  // Generate tailored health goals based on patient data
  List<Map<String, dynamic>> _generateHealthGoals() {
    List<Map<String, dynamic>> goals = [];
    
    // Get current health status
    final conditions = _analysisResults['conditions'] ?? [];
    final hasCareGap = _analysisResults['hasCareGap'] ?? false;
    final wellnessScore = _analysisResults['healthTrends']?['wellnessScore'] ?? 75;
    
    // Basic goals for everyone
    goals.add({
      'title': 'Daily Physical Activity',
      'description': 'Aim for at least 30 minutes of moderate activity daily',
      'target': '150 minutes per week',
      'progress': 0,
      'icon': Icons.directions_run,
      'color': Colors.green,
      'achievable': true,
    });
    
    // Add condition-specific goals
    if (conditions.any((c) => c.toString().toLowerCase().contains('hypertension'))) {
      goals.add({
        'title': 'Blood Pressure Monitoring',
        'description': 'Track your blood pressure regularly',
        'target': 'Keep under 120/80 mmHg',
        'progress': 0,
        'icon': Icons.monitor_heart,
        'color': Colors.red,
        'achievable': true,
      });
    }
    
    if (conditions.any((c) => c.toString().toLowerCase().contains('diabetes'))) {
      goals.add({
        'title': 'Blood Sugar Control',
        'description': 'Monitor glucose levels and maintain healthy diet',
        'target': 'HbA1c below 7.0%',
        'progress': 0,
        'icon': Icons.bloodtype,
        'color': Colors.purple,
        'achievable': true,
      });
    }
    
    // Check for care gaps
    if (hasCareGap) {
      goals.add({
        'title': 'Schedule Checkup',
        'description': 'It\'s been over 6 months since your last visit',
        'target': 'Within 30 days',
        'progress': 0,
        'icon': Icons.event,
        'color': Colors.blue,
        'achievable': true,
        'priority': true,
      });
    }
    
    // Add wellness score improvement goal if score is below 80
    if (wellnessScore < 80) {
      goals.add({
        'title': 'Improve Wellness Score',
        'description': 'Follow recommendations to improve your overall wellness',
        'target': '${wellnessScore + 10} points (currently $wellnessScore)',
        'progress': 0,
        'icon': Icons.trending_up,
        'color': Colors.amber,
        'achievable': true,
      });
    }
    
    return goals;
  }
  
  // Generate AI-driven conversation starters for doctor visits
  List<String> _generateDoctorConversationStarters() {
    List<String> conversationStarters = [];
    
    // Basic conversation starters everyone can use
    conversationStarters.add('How do my results compare to someone my age?');
    conversationStarters.add('Are there any preventive screenings I should consider?');
    
    // Get patient-specific data
    final conditions = _analysisResults['conditions'] ?? [];
    final recurringSymptoms = _analysisResults['healthTrends']?['recurringSymptoms'] ?? [];
    
    // Add condition-specific conversation starters
    for (var condition in conditions) {
      final conditionStr = condition.toString().toLowerCase();
      
      if (conditionStr.contains('hypertension') || conditionStr.contains('blood pressure')) {
        conversationStarters.add('What lifestyle changes would most impact my blood pressure?');
        conversationStarters.add('How does stress affect my blood pressure readings?');
      }
      
      if (conditionStr.contains('diabetes')) {
        conversationStarters.add('How will I know if my diabetes is affecting my kidneys or eyes?');
        conversationStarters.add('What signs should I watch for regarding low blood sugar?');
      }
      
      if (conditionStr.contains('heart') || conditionStr.contains('cardiac')) {
        conversationStarters.add('How can I tell the difference between normal fatigue and heart-related fatigue?');
        conversationStarters.add('Would I benefit from cardiac rehabilitation programs?');
      }
    }
    
    // Add conversation starters for recurring symptoms
    for (var symptom in recurringSymptoms) {
      final term = symptom['term'].toString();
      conversationStarters.add('I\'ve noticed $term occurring multiple times. Could this indicate a pattern?');
    }
    
    // Ensure we don't have too many starters
    if (conversationStarters.length > 6) {
      // Keep more specific ones by shuffling and taking first 6
      conversationStarters.shuffle();
      conversationStarters = conversationStarters.take(6).toList();
    }
    
    return conversationStarters;
  }

  // Add this after your existing _generateDoctorConversationStarters method

  // Perform deep analysis of patient data to find hidden patterns
  Future<Map<String, dynamic>> _performAdvancedHealthAnalysis() async {
    Map<String, dynamic> advancedInsights = {};
    
    try {
      // Extract more detailed patterns from medical records
      if (_patientRecords.length > 0) {
        // Group symptoms by body system for holistic analysis
        Map<String, List<String>> systemSymptoms = {
          'cardiovascular': [],
          'respiratory': [],
          'digestive': [],
          'neurological': [],
          'musculoskeletal': [],
          'endocrine': [],
          'other': []
        };
        
        // Map of keywords to body systems
        final Map<String, String> symptomToSystem = {
          'heart': 'cardiovascular',
          'chest': 'cardiovascular',
          'pressure': 'cardiovascular',
          'pulse': 'cardiovascular',
          'breath': 'respiratory',
          'lung': 'respiratory',
          'cough': 'respiratory',
          'wheez': 'respiratory',
          'stomach': 'digestive',
          'digest': 'digestive',
          'nausea': 'digestive',
          'bowel': 'digestive',
          'headache': 'neurological',
          'dizz': 'neurological',
          'numbness': 'neurological',
          'tingling': 'neurological',
          'joint': 'musculoskeletal',
          'muscle': 'musculoskeletal',
          'pain': 'musculoskeletal',
          'sugar': 'endocrine',
          'thyroid': 'endocrine',
          'hormone': 'endocrine',
        };
        
        // Analyze record descriptions and extract symptoms by system
        for (var record in _patientRecords) {
          final description = record.description.toLowerCase();
          
          symptomToSystem.forEach((symptom, system) {
            if (description.contains(symptom)) {
              // Extract relevant phrases (simulating NLP extraction)
              final regex = RegExp('.{0,20}$symptom.{0,20}');
              final matches = regex.allMatches(description);
              for (var match in matches) {
                final phrase = match.group(0)?.trim() ?? '';
                if (phrase.isNotEmpty && !systemSymptoms[system]!.contains(phrase)) {
                  systemSymptoms[system]!.add(phrase);
                }
              }
            }
          });
        }
        
        // Identify body systems with multiple symptoms as potential areas of concern
        final systemConcerns = systemSymptoms.entries
            .where((entry) => entry.value.length >= 2)
            .map((entry) => {
                  'system': entry.key,
                  'symptoms': entry.value,
                  'concernLevel': _calculateConcernLevel(entry.value.length),
                })
            .toList();
        
        // Identify potential correlations between symptoms across systems
        List<Map<String, dynamic>> correlations = [];
        if (systemConcerns.length >= 2) {
          // Check for known medical correlations (simplified simulation)
          if (systemSymptoms['cardiovascular']!.isNotEmpty && 
              systemSymptoms['respiratory']!.isNotEmpty) {
            correlations.add({
              'systems': ['cardiovascular', 'respiratory'],
              'insight': 'Potential cardiopulmonary correlation detected',
              'explanation': 'Symptoms in both cardiovascular and respiratory systems may indicate related conditions.',
              'recommendation': 'Comprehensive evaluation recommended'
            });
          }
          
          if (systemSymptoms['endocrine']!.isNotEmpty && 
              systemSymptoms['cardiovascular']!.isNotEmpty) {
            correlations.add({
              'systems': ['endocrine', 'cardiovascular'],
              'insight': 'Metabolic impact on cardiovascular health detected',
              'explanation': 'Endocrine issues often affect cardiovascular function.',
              'recommendation': 'Consider metabolic screening'
            });
          }
        }
        
        // Predict health trajectory based on patterns (simplified AI prediction)
        Map<String, dynamic> healthTrajectory = {};
        final symptomsIncreasing = _checkSymptomProgression(_patientRecords);
        final hasMissedMedications = _checkMedicationAdherence();
        final potentialComplications = _predictPotentialComplications();
        
        healthTrajectory = {
          'direction': symptomsIncreasing ? 'concerning' : 'stable',
          'factors': {
            'symptomProgression': symptomsIncreasing,
            'medicationAdherence': !hasMissedMedications,
            'lifestyleFactors': _analyzeLifestyleFactors(),
          },
          'potentialComplications': potentialComplications,
          'preventiveRecommendations': _generatePreventiveRecommendations(potentialComplications),
        };
        
        // Assemble advanced insights
        advancedInsights = {
          'systemAnalysis': systemConcerns,
          'symptomCorrelations': correlations,
          'healthTrajectory': healthTrajectory,
          'aiConfidence': _calculateAIConfidence(),
        };
      }
      
      return advancedInsights;
    } catch (e) {
      print('Error in advanced health analysis: $e');
      return {'error': e.toString()};
    }
  }

  // Calculate concern level based on number and severity of symptoms
  String _calculateConcernLevel(int symptomCount) {
    if (symptomCount >= 5) return 'High';
    if (symptomCount >= 3) return 'Moderate';
    return 'Low';
  }

  // Analyze symptom progression over time
  bool _checkSymptomProgression(List<Record> records) {
    if (records.length < 2) return false;
    
    // Sort by date (oldest first)
    records.sort((a, b) => a.date.compareTo(b.date));
    
    // Simple algorithm to detect if symptoms are mentioned more frequently in newer records
    int olderRecordsSymptomCount = 0;
    int newerRecordsSymptomCount = 0;
    
    final midpoint = records.length ~/ 2;
    
    // Count symptoms in older half
    for (var i = 0; i < midpoint; i++) {
      final symptomMatches = RegExp(r'\b(pain|ache|discomfort|symptom|issue|problem)\b')
          .allMatches(records[i].description.toLowerCase())
          .length;
      olderRecordsSymptomCount += symptomMatches;
    }
    
    // Count symptoms in newer half
    for (var i = midpoint; i < records.length; i++) {
      final symptomMatches = RegExp(r'\b(pain|ache|discomfort|symptom|issue|problem)\b')
          .allMatches(records[i].description.toLowerCase())
          .length;
      newerRecordsSymptomCount += symptomMatches;
    }
    
    // Normalize by number of records in each half
    final olderAvg = olderRecordsSymptomCount / midpoint;
    final newerAvg = newerRecordsSymptomCount / (records.length - midpoint);
    
    // Return true if symptoms are increasing
    return newerAvg > olderAvg * 1.2; // 20% increase threshold
  }

  // Simulate checking medication adherence
  bool _checkMedicationAdherence() {
    // In a real app, you would check medication records
    // This is a simplified version that randomly determines adherence
    return DateTime.now().millisecondsSinceEpoch % 2 == 0;
  }

  // Analyze lifestyle factors from records
  Map<String, dynamic> _analyzeLifestyleFactors() {
    Map<String, dynamic> factors = {};
    
    // Extract lifestyle related keywords from records
    int exerciseReferences = 0;
    int dietReferences = 0;
    int stressReferences = 0;
    int sleepReferences = 0;
    
    for (var record in _patientRecords) {
      final desc = record.description.toLowerCase();
      
      if (desc.contains('exercise') || desc.contains('physical activity') || 
          desc.contains('workout') || desc.contains('gym')) {
        exerciseReferences++;
      }
      
      if (desc.contains('diet') || desc.contains('food') || 
          desc.contains('nutrition') || desc.contains('eating')) {
        dietReferences++;
      }
      
      if (desc.contains('stress') || desc.contains('anxiety') || 
          desc.contains('worry') || desc.contains('pressure')) {
        stressReferences++;
      }
      
      if (desc.contains('sleep') || desc.contains('insomnia') || 
          desc.contains('rest') || desc.contains('fatigue')) {
        sleepReferences++;
      }
    }
    
    // Determine concerns based on reference frequency
    factors['exercise'] = exerciseReferences > 2 ? 'Mentioned' : 'Not emphasized';
    factors['diet'] = dietReferences > 2 ? 'Mentioned' : 'Not emphasized';
    factors['stress'] = stressReferences > 2 ? 'Concern' : 'Not emphasized';
    factors['sleep'] = sleepReferences > 2 ? 'Concern' : 'Not emphasized';
    
    return factors;
  }

  // Predict potential complications based on conditions and patterns
  List<Map<String, dynamic>> _predictPotentialComplications() {
    List<Map<String, dynamic>> complications = [];
    final conditions = _analysisResults['conditions'] ?? [];
    
    // Check for diabetes and add related complications
    if (conditions.any((c) => c.toString().toLowerCase().contains('diabetes'))) {
      complications.add({
        'condition': 'Diabetic Retinopathy',
        'probability': 'Moderate',
        'timeframe': 'Long-term',
        'preventionStrategy': 'Regular eye exams, blood sugar control'
      });
      
      complications.add({
        'condition': 'Diabetic Neuropathy',
        'probability': 'Moderate',
        'timeframe': 'Long-term',
        'preventionStrategy': 'Blood sugar control, regular foot exams'
      });
    }
    
    // Check for hypertension and add related complications
    if (conditions.any((c) => c.toString().toLowerCase().contains('hypertension') || 
                           c.toString().toLowerCase().contains('blood pressure'))) {
      complications.add({
        'condition': 'Stroke Risk',
        'probability': 'Variable',
        'timeframe': 'Long-term',
        'preventionStrategy': 'Blood pressure control, healthy lifestyle'
      });
      
      complications.add({
        'condition': 'Kidney Damage',
        'probability': 'Low to Moderate',
        'timeframe': 'Long-term',
        'preventionStrategy': 'Blood pressure control, kidney function monitoring'
      });
    }
    
    // Limit to 3 most relevant complications
    if (complications.length > 3) {
      complications = complications.take(3).toList();
    }
    
    return complications;
  }

  // Generate preventive recommendations based on predicted complications
  List<String> _generatePreventiveRecommendations(List<Map<String, dynamic>> complications) {
    Set<String> recommendations = {};
    
    // Add general recommendations
    recommendations.add('Maintain regular check-ups with your healthcare provider');
    recommendations.add('Follow a balanced diet rich in fruits, vegetables, and whole grains');
    
    // Add complication-specific recommendations
    for (var complication in complications) {
      recommendations.add(complication['preventionStrategy']);
    }
    
    // Add conditions-specific recommendations
    final conditions = _analysisResults['conditions'] ?? [];
    if (conditions.isNotEmpty) {
      if (conditions.any((c) => c.toString().toLowerCase().contains('heart'))) {
        recommendations.add('Monitor cholesterol levels regularly');
        recommendations.add('Consider heart-healthy Mediterranean diet');
      }
      
      if (conditions.any((c) => c.toString().toLowerCase().contains('respiratory'))) {
        recommendations.add('Avoid smoke exposure and air pollutants');
        recommendations.add('Consider respiratory exercises to improve lung function');
      }
    }
    
    return recommendations.toList();
  }

  // Calculate AI confidence level based on data quantity and quality
  double _calculateAIConfidence() {
    // Base confidence
    double confidence = 65.0;
    
    // Adjust based on data quantity
    if (_patientRecords.length > 10) confidence += 15;
    else if (_patientRecords.length > 5) confidence += 10;
    else if (_patientRecords.length > 2) confidence += 5;
    
    // Adjust based on recency of data
    final recentRecords = _patientRecords.where((r) => 
        r.date.isAfter(DateTime.now().subtract(const Duration(days: 365)))).length;
    if (recentRecords > 5) confidence += 10;
    else if (recentRecords > 2) confidence += 5;
    
    // Cap confidence
    if (confidence > 95) confidence = 95;
    
    return confidence;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size information for responsive adjustments
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
    final isLargeScreen = screenSize.width >= 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Health Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatientData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorScreen()
              : RefreshIndicator(
                  onRefresh: _loadPatientData,
                  child: _buildMainContent(isSmallScreen, isMediumScreen, isLargeScreen),
                ),
    );
  }
  
  Widget _buildMainContent(bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header with patient name
          _buildWelcomeSection(isSmallScreen),
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Health summary section
          _buildHealthSummarySection(isSmallScreen),
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Personalized recommendations
          Text(
            'Personalized Recommendations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18 : 20,
            ),
          ),
          const SizedBox(height: 16),
          
          // Recommendations list
          ..._recommendations.map((recommendation) => 
              _buildRecommendationCard(recommendation, isSmallScreen)),
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // The remaining sections with responsiveness
          // Health tips, wellness score, etc.
          // ...existing code with isSmallScreen parameters...
          // Health tips section
          Text(
            'Health Tips & Reminders',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18 : 20,
            ),
          ),
          const SizedBox(height: 16),

          // Health tips grid with responsiveness
          LayoutBuilder(
            builder: (context, constraints) {
              // Determine number of columns based on available width
              final double availableWidth = constraints.maxWidth;
              final int columnsCount = availableWidth < 360 ? 1 : 
                                    availableWidth < 600 ? 2 : 3;
                                    
              // Adjust aspect ratio based on columns and screen size
              final double aspectRatio = columnsCount == 1 ? 2.0 : 
                                        availableWidth < 400 ? 1.0 : 1.3;
                                        
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnsCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _healthTips.length,
                itemBuilder: (context, index) => _buildHealthTipCard(_healthTips[index], isSmallScreen),
              );
            },
          ),

          // Add wellness score if available
          if (_analysisResults.containsKey('healthTrends') && 
              _analysisResults['healthTrends'].containsKey('wellnessScore')) ...[
            const SizedBox(height: 24),
            _buildWellnessScoreCard(_analysisResults['healthTrends']['wellnessScore']),
          ],

          // Add the Advanced AI insights section
          if (_analysisResults.containsKey('advancedInsights')) ...[
            const SizedBox(height: 24),
            _buildAdvancedAISection(_analysisResults['advancedInsights']),
          ],

          // Add the analyzed records section (NEW SECTION)
          const SizedBox(height: 24),
          Text(
            'Analyzed Medical Records',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18 : 20,
            ),
          ),
          const SizedBox(height: 12),
          _patientRecords.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        color: Colors.grey[400],
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No medical records available',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add medical records for AI analysis and personalized insights',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Record analysis summary
                  Card(
                    elevation: 1,
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI has analyzed ${_patientRecords.length} medical records spanning ${_getRecordsDateRange()}',
                              style: const TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Display most recent 3 records with analysis indicators
                  ...List.generate(
                    min(3, _patientRecords.length), 
                    (index) => _buildAnalyzedRecordCard(_patientRecords[index], isSmallScreen)
                  ),
                  if (_patientRecords.length > 3) 
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to records list screen
                        },
                        icon: const Icon(Icons.folder_open),
                        label: const Text('View All Records'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
  
  Widget _buildWelcomeSection(bool isSmallScreen) {
    return Card(
      elevation: isSmallScreen ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // For very small screens, stack the avatar and text
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 24,
                        child: const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hello, ${_currentUser?.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 28,
                        child: const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${_currentUser?.name}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            Text(
              'I\'m your personal AI health assistant. I analyze your medical records and provide personalized health recommendations.',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              textAlign: isSmallScreen ? TextAlign.center : TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHealthSummarySection(bool isSmallScreen) {
    // Extract health summary info
    final conditions = _analysisResults['conditions'] ?? [];
    final upcomingAppointments = _analysisResults['upcomingAppointments'] ?? [];
    final appointmentAdherence = _analysisResults['appointmentAdherence'] ?? 'N/A';
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Health Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Health indicators - adaptive layout
            isSmallScreen
                ? Column(
                    children: [
                      _buildSingleHealthIndicator(
                        'Medical Conditions',
                        conditions.length.toString(),
                        Icons.medical_information,
                        Colors.purple,
                        isSmallScreen,
                      ),
                      const SizedBox(height: 8),
                      _buildSingleHealthIndicator(
                        'Upcoming Appointments',
                        upcomingAppointments.length.toString(),
                        Icons.event,
                        Colors.blue,
                        isSmallScreen,
                      ),
                      const SizedBox(height: 8),
                      _buildSingleHealthIndicator(
                        'Appointment Adherence',
                        appointmentAdherence,
                        Icons.check_circle,
                        Colors.green,
                        isSmallScreen,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _buildHealthIndicator(
                        'Medical\nConditions',
                        conditions.length.toString(),
                        Icons.medical_information,
                        Colors.purple,
                        isSmallScreen,
                      ),
                      _buildHealthIndicator(
                        'Upcoming\nAppointments',
                        upcomingAppointments.length.toString(),
                        Icons.event,
                        Colors.blue,
                        isSmallScreen,
                      ),
                      _buildHealthIndicator(
                        'Appointment\nAdherence',
                        appointmentAdherence,
                        Icons.check_circle,
                        Colors.green,
                        isSmallScreen,
                      ),
                    ],
                  ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // AI-generated health summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.psychology,
                  color: Colors.blue.shade700,
                  size: isSmallScreen ? 18 : 22,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    _generateHealthSummary(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isSmallScreen ? 12 : 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add a new method for single health indicator (used on small screens)
  Widget _buildSingleHealthIndicator(
    String label, 
    String value, 
    IconData icon, 
    Color color,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: isSmallScreen ? 20 : 24,
          child: Icon(
            icon,
            color: color,
            size: isSmallScreen ? 18 : 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Update existing health indicator method
  Expanded _buildHealthIndicator(
    String label, 
    String value, 
    IconData icon, 
    Color color,
    bool isSmallScreen,
  ) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: isSmallScreen ? 22 : 28,
            child: Icon(
              icon,
              color: color,
              size: isSmallScreen ? 18 : 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 16 : 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordCard(Record record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: record.category == 'medical'
              ? Colors.blue.shade100
              : Colors.amber.shade100,
          child: Icon(
            record.category == 'medical' 
                ? Icons.medical_services
                : Icons.description,
            color: record.category == 'medical' 
                ? Colors.blue
                : Colors.amber,
          ),
        ),
        title: Text(
          record.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy').format(record.date),
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWellnessScoreCard(int score) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    // Determine color based on score
    Color scoreColor;
    String statusText;
    
    // Determine color and status text based on score
    if (score >= 80) {
      scoreColor = Colors.green;
      statusText = 'Excellent';
    } else if (score >= 60) {
      scoreColor = Colors.amber;
      statusText = 'Good';
    } else if (score >= 40) {
      scoreColor = Colors.orange;
      statusText = 'Fair';
    } else {
      scoreColor = Colors.red;
      statusText = 'Needs Attention';
    }
    
    return Card(
      elevation: isSmallScreen ? 2 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, 
                     color: Colors.blue, 
                     size: isSmallScreen ? 22 : 24),
                const SizedBox(width: 8),
                Text(
                  'AI Wellness Analysis',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Different layouts for different screen sizes
            isSmallScreen
                ? Column(
                    children: [
                      // Score circle
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  score.toString(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                  ),
                                ),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Status and description
                      Text(
                        'Wellness Score: $statusText',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on your health records, appointments, and medical conditions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  score.toString(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                  ),
                                ),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wellness Score: $statusText',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Based on your health records, appointments, and medical conditions, our AI has calculated your wellness score.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _getWellnessAdvice(score),
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getWellnessAdvice(int score) {
    if (score >= 85) {
      return 'You\'re doing great! Continue your healthy habits and regular checkups to maintain optimal health.';
    } else if (score >= 70) {
      return 'Your health is in good shape. Follow your personalized recommendations to address any minor concerns.';
    } else if (score >= 50) {
      return 'There are some areas of your health that need attention. Focus on the high-priority recommendations.';
    } else {
      return 'Your wellness score indicates several health concerns. Please schedule an appointment with your healthcare provider soon.';
    }
  }
  
  String _generateHealthSummary() {
    // Extract relevant data for summary
    final conditions = _analysisResults['conditions'] ?? [];
    final upcomingAppointments = _analysisResults['upcomingAppointments'] ?? [];
    final recentVisits = _analysisResults['recentVisits'] ?? [];
    final wellnessScore = _analysisResults['healthTrends']?['wellnessScore'] ?? 0;
    
    // Start building the summary
    String summary = '';
    
    // Add based on wellness score
    if (wellnessScore > 80) {
      summary += 'Your overall health appears good based on available data. ';
    } else if (wellnessScore > 60) {
      summary += 'Your health has some areas that may need attention. ';
    } else if (wellnessScore > 0) {
      summary += 'Your health indicators suggest several areas need medical attention. ';
    } else {
      summary += 'Based on your records, we recommend consulting your healthcare provider. ';
    }
    
    // Add information about conditions
    if (conditions.isNotEmpty) {
      if (conditions.length == 1) {
        summary += 'You have 1 recorded medical condition. ';
      } else {
        summary += 'You have ${conditions.length} recorded medical conditions. ';
      }
    } else {
      summary += 'No chronic conditions are currently recorded in your profile. ';
    }
    
    // Add information about appointments
    if (upcomingAppointments.isNotEmpty) {
      summary += 'You have upcoming appointments scheduled. ';
    } else {
      summary += 'You don\'t have any upcoming appointments scheduled. ';
    }
    
    // Add recent visit info
    if (recentVisits.isNotEmpty) {
      final mostRecentVisit = recentVisits[0];
      summary += 'Your last medical visit was on ${DateFormat('MMM d, yyyy').format(mostRecentVisit.date)}. ';
    }
    
    // Add care gap info
    if (_analysisResults['hasCareGap'] == true) {
      summary += 'It\'s been more than 6 months since your last checkup. Consider scheduling a wellness visit.';
    } else {
      summary += 'You\'ve been maintaining regular healthcare visits.';
    }
    
    return summary;
  }
  
  List<Widget> _buildHealthGoalsList(List<dynamic> goals) {
    return goals.map<Widget>((goal) {
      final Map<String, dynamic> g = goal as Map<String, dynamic>;
      final bool isPriority = g['priority'] ?? false;
      
      return Card(
        elevation: isPriority ? 3 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPriority ? BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (g['color'] as Color).withOpacity(0.2),
                    child: Icon(g['icon'] as IconData, color: g['color'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isPriority)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Priority',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          g['description'] as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Target: ${g['target']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (g['progress'] as int) / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(g['color'] as Color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
  
  Widget _buildConversationStartersCard(List<dynamic> starters) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.question_answer, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-Generated Questions for Your Doctor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Based on your health profile, here are some important questions to ask at your next visit:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ...starters.map<Widget>((starter) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18, color: Colors.purple.shade300),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      starter as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHealthTipCard(Map<String, dynamic> tip, bool isSmallScreen) {
    // Get screen width for more precise responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Adjust size parameters based on screen width for finer control
    final double iconSize = screenWidth < 320 ? 16 : isSmallScreen ? 18 : 22;
    final double titleSize = screenWidth < 320 ? 13 : isSmallScreen ? 14 : 16;
    final double descSize = screenWidth < 320 ? 11 : isSmallScreen ? 12 : 14;
    final double padding = screenWidth < 320 ? 10 : isSmallScreen ? 12 : 16;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use a more flexible layout for the icon and title
            screenWidth < 320
                // Stack layout for very small screens
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: (tip['color'] as Color).withOpacity(0.2),
                        radius: iconSize,
                        child: Icon(
                          tip['icon'] as IconData,
                          color: tip['color'] as Color,
                          size: iconSize * 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tip['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: titleSize,
                        ),
                        textAlign: TextAlign.center,
                        // Add overflow handling for title
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                // Row layout for normal screens
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (tip['color'] as Color).withOpacity(0.2),
                        radius: iconSize,
                        child: Icon(
                          tip['icon'] as IconData,
                          color: tip['color'] as Color,
                          size: iconSize * 0.8,
                        ),
                      ),
                      SizedBox(width: padding * 0.7),
                      Expanded(
                        child: Text(
                          tip['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: titleSize,
                          ),
                          // Add overflow handling for title
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
            
            // Description with proper spacing
            SizedBox(height: padding * 0.7),
            
            // Description text with overflow handling and adaptive sizing
            Expanded(
              child: Text(
                tip['description'] as String,
                style: TextStyle(
                  fontSize: descSize,
                  height: 1.3,
                  color: Colors.grey[800],
                ),
                // Ensure text fits properly within card
                maxLines: screenWidth < 360 ? 4 : 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdvancedAISection(Map<String, dynamic> insights) {
    if (insights.isEmpty) return const SizedBox.shrink();
    
    final healthTrajectory = insights['healthTrajectory'] ?? {};
    final systemAnalysis = insights['systemAnalysis'] ?? [];
    final aiConfidence = insights['aiConfidence'] ?? 75.0;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.psychology_alt,
                    color: Colors.deepPurple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Advanced AI Health Analysis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Container(
                          //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          //   decoration: BoxDecoration(
                          //     color: Colors.grey.shade100,
                          //     borderRadius: BorderRadius.circular(12),
                          //     border: Border.all(color: Colors.grey.shade300),
                          //   ),
                          //   child: Text(
                          //     'AI Confidence: ${aiConfidence.toStringAsFixed(1)}%',
                          //     style: TextStyle(
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.w500,
                          //       color: Colors.grey.shade700,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pattern recognition and predictive health insights',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'AI Confidence: ${aiConfidence.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            // Health trajectory
            if (healthTrajectory.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Health Trajectory Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    healthTrajectory['direction'] == 'concerning' 
                        ? Icons.trending_down 
                        : Icons.trending_up,
                    color: healthTrajectory['direction'] == 'concerning'
                        ? Colors.orange
                        : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    healthTrajectory['direction'] == 'concerning'
                        ? 'Some concerning trends detected'
                        : 'Your health appears stable',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: healthTrajectory['direction'] == 'concerning'
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              
              // Preventive recommendations
              if (healthTrajectory['preventiveRecommendations'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  'AI-Recommended Preventive Measures:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  min(3, (healthTrajectory['preventiveRecommendations'] as List).length),
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, 
                             size: 16, 
                             color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        // Add Expanded widget to prevent overflow
                        Expanded(
                          child: Text(
                            healthTrajectory['preventiveRecommendations'][index],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if ((healthTrajectory['preventiveRecommendations'] as List).length > 3)
                  TextButton(
                    onPressed: () {
                      // Show full list in a dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('All Preventive Recommendations'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...(healthTrajectory['preventiveRecommendations'] as List)
                                    .map((rec) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.check_circle_outline, 
                                               size: 16, 
                                               color: Colors.green.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(rec),
                                          ),
                                        ],
                                      ),
                                    ))
                                    .toList(),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'View all ${(healthTrajectory['preventiveRecommendations'] as List).length} recommendations',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ],
            
            // System analysis
            if (systemAnalysis.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Body Systems Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (var system in systemAnalysis)
                _buildBodySystemItem(system),
            ],
            
            // Note about AI analysis
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This analysis is based on AI pattern recognition and is not a medical diagnosis. Always consult with healthcare professionals regarding your health.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodySystemItem(Map<String, dynamic> system) {
    // Get humanized system name
    final systemName = _getHumanReadableSystemName(system['system']);
    final concernLevel = system['concernLevel'];
    
    // Determine color based on concern level
    Color concernColor;
    switch (concernLevel) {
      case 'High':
        concernColor = Colors.red;
        break;
      case 'Moderate':
        concernColor = Colors.orange;
        break;
      default:
        concernColor = Colors.green;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: concernColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getSystemIcon(system['system']),
              size: 18,
              color: concernColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      systemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: concernColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: concernColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        concernLevel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: concernColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Patterns detected: ${(system['symptoms'] as List).length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHumanReadableSystemName(String systemKey) {
    switch (systemKey) {
      case 'cardiovascular':
        return 'Cardiovascular System';
      case 'respiratory':
        return 'Respiratory System';
      case 'digestive':
        return 'Digestive System';
      case 'neurological':
        return 'Neurological System';
      case 'musculoskeletal':
        return 'Musculoskeletal System';
      case 'endocrine':
        return 'Endocrine System';
      default:
        return 'Other Systems';
    }
  }

  IconData _getSystemIcon(String systemKey) {
    switch (systemKey) {
      case 'cardiovascular':
        return Icons.favorite;
      case 'respiratory':
        return Icons.air;
      case 'digestive':
        return Icons.restaurant;
      case 'neurological':
        return Icons.psychology;
      case 'musculoskeletal':
        return Icons.accessibility_new;
      case 'endocrine':
        return Icons.biotech;
      default:
        return Icons.medical_services;
    }
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation, bool isSmallScreen) {
    final icon = recommendation['icon'] as IconData;
    final color = recommendation['color'] as Color;
    final title = recommendation['title'] as String;
    final description = recommendation['description'] as String;
    final recommendations = recommendation['recommendations'] as List;
    
    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: isSmallScreen ? 18 : 22,
            child: Icon(icon, color: color, size: isSmallScreen ? 18 : 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 12 : 16, 
                0, 
                isSmallScreen ? 12 : 16, 
                isSmallScreen ? 12 : 16
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Recommendations:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: isSmallScreen ? 14 : 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rec.toString(),
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: isSmallScreen ? 36 : 48),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'Error Loading Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: isSmallScreen ? 18 : 22,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            SizedBox(height: isSmallScreen ? 18 : 24),
            ElevatedButton.icon(
              onPressed: _loadPatientData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 10 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add these helper methods to your class

  // Build a record card with analysis indicators
  Widget _buildAnalyzedRecordCard(Record record, bool isSmallScreen) {
    // Find any insights related to this record
    final recordInsights = _findInsightsForRecord(record);
    final hasInsights = recordInsights.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: hasInsights ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: hasInsights 
          ? BorderSide(color: Colors.amber.shade300, width: 1) 
          : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: record.category == 'medical'
                  ? Colors.blue.shade100
                  : Colors.amber.shade100,
              child: Icon(
                record.category == 'medical' 
                    ? Icons.medical_services
                    : Icons.description,
                color: record.category == 'medical' 
                    ? Colors.blue
                    : Colors.amber,
              ),
            ),
            title: Text(
              record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(record.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                ),
                if (hasInsights)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.offline_bolt, 
                          size: 14, 
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recordInsights.length} medical insights',
                          style: TextStyle(
                            color: Colors.amber.shade700,
                            fontSize: isSmallScreen ? 11 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: hasInsights
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AI Analyzed',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordDetailScreen(record: record),
                ),
              );
            },
          ),
          // Show insights preview if available
          if (hasInsights && !isSmallScreen)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const SizedBox(width: 56), // Align with title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          'Key Medical Insights:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recordInsights.map((i) => i['term']).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            ),
        ],
      ),
    );
  }

  // Find insights for a specific record
  List<Map<String, dynamic>> _findInsightsForRecord(Record record) {
    try {
      // In a real implementation, you'd have stored the analysis results for each record
      // Here we'll simulate it with a simplified approach
      final List<Map<String, dynamic>> insights = [];
      
      // For this example, let's say 1 in 2 records has insights
      if (record.id.hashCode % 2 == 0) {
        // Generate some sample insights based on the record description
        final description = record.description.toLowerCase();
        
        for (var keyword in ['pain', 'blood', 'pressure', 'heart', 'breathing', 'diabetes']) {
          if (description.contains(keyword)) {
            insights.add({
              'term': '$keyword issue',
              'severity': keyword == 'heart' || keyword == 'blood' ? 'High' : 'Medium',
            });
          }
        }
        
        // Always add at least one insight for demo purposes
        if (insights.isEmpty) {
          insights.add({
            'term': 'General health observation',
            'severity': 'Low',
          });
        }
      }
      
      return insights;
    } catch (e) {
      print('Error finding insights: $e');
      return [];
    }
  }

  // Get a readable date range for the records
  String _getRecordsDateRange() {
    if (_patientRecords.isEmpty) return "no timeframe";
    
    _patientRecords.sort((a, b) => a.date.compareTo(b.date));
    final oldest = _patientRecords.first.date;
    final newest = _patientRecords.last.date;
    
    // If same year
    if (oldest.year == newest.year) {
      if (oldest.month == newest.month) {
        return DateFormat('MMMM yyyy').format(oldest);
      }
      return '${DateFormat('MMM').format(oldest)} - ${DateFormat('MMM yyyy').format(newest)}';
    }
    
    return '${DateFormat('MMM yyyy').format(oldest)} - ${DateFormat('MMM yyyy').format(newest)}';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}