import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:happ/ui/screens/patient/book_appointment_screen.dart';

class AISchedulingAssistant extends StatefulWidget {
  const AISchedulingAssistant({Key? key}) : super(key: key);

  @override
  State<AISchedulingAssistant> createState() => _AISchedulingAssistantState();
}

class _AISchedulingAssistantState extends State<AISchedulingAssistant> {
  final TextEditingController _queryController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recommendations = [];
  Map<String, dynamic>? _selectedRecommendation;

  // Comprehensive symptoms to medical specialty mapping
  // final Map<String, String> _symptomsToSpecialty = {
  //   // Cardiology
  //   'heart': 'Cardiology',
  //   'chest pain': 'Cardiology',
  //   'palpitation': 'Cardiology',
  //   'shortness of breath': 'Cardiology',
  //   'high blood pressure': 'Cardiology',
  //   'hypertension': 'Cardiology',
  //   'cholesterol': 'Cardiology',
  //   'arrhythmia': 'Cardiology',
  //   'heart attack': 'Cardiology',
  //   'myocardial infarction': 'Cardiology',
  //   'angina': 'Cardiology',
  //   'heart failure': 'Cardiology',
  //   'cardiac': 'Cardiology',
  //   'pulse': 'Cardiology',

  //   // Dermatology
  //   'skin': 'Dermatology',
  //   'rash': 'Dermatology',
  //   'acne': 'Dermatology',
  //   'eczema': 'Dermatology',
  //   'itching': 'Dermatology',
  //   'psoriasis': 'Dermatology',
  //   'skin lesion': 'Dermatology',
  //   'mole': 'Dermatology',
  //   'hair loss': 'Dermatology',
  //   'nail problem': 'Dermatology',
  //   'skin infection': 'Dermatology',
  //   'fungal': 'Dermatology',

  //   // Endocrinology
  //   'diabetes': 'Endocrinology',
  //   'thyroid': 'Endocrinology',
  //   'hormone': 'Endocrinology',
  //   'blood sugar': 'Endocrinology',
  //   'glucose': 'Endocrinology',
  //   'insulin': 'Endocrinology',
  //   'hyperthyroidism': 'Endocrinology',
  //   'hypothyroidism': 'Endocrinology',
  //   'cushing': 'Endocrinology',
  //   'addison': 'Endocrinology',
  //   'pituitary': 'Endocrinology',
  //   'metabolic': 'Endocrinology',
  //   'growth': 'Endocrinology',

  //   // Gastroenterology
  //   'stomach': 'Gastroenterology',
  //   'digestion': 'Gastroenterology',
  //   'abdominal pain': 'Gastroenterology',
  //   'ulcer': 'Gastroenterology',
  //   'heartburn': 'Gastroenterology',
  //   'acid reflux': 'Gastroenterology',
  //   'gerd': 'Gastroenterology',
  //   'diarrhea': 'Gastroenterology',
  //   'constipation': 'Gastroenterology',
  //   'colon': 'Gastroenterology',
  //   'gallbladder': 'Gastroenterology',
  //   'liver': 'Gastroenterology',
  //   'hepatitis': 'Gastroenterology',
  //   'cirrhosis': 'Gastroenterology',
  //   'inflammatory bowel': 'Gastroenterology',
  //   'crohn': 'Gastroenterology',
  //   'ulcerative colitis': 'Gastroenterology',
  //   'irritable bowel': 'Gastroenterology',
  //   'ibs': 'Gastroenterology',
  //   'nausea': 'Gastroenterology',
  //   'vomiting': 'Gastroenterology',
  //   'gastritis': 'Gastroenterology',
  //   'pancreatitis': 'Gastroenterology',

  //   // General Medicine
  //   'checkup': 'General Medicine',
  //   'fever': 'General Medicine',
  //   'cold': 'General Medicine',
  //   'flu': 'General Medicine',
  //   'infection': 'General Medicine',
  //   'general health': 'General Medicine',
  //   'routine checkup': 'General Medicine',
  //   'vaccine': 'General Medicine',
  //   'vaccination': 'General Medicine',
  //   'physical exam': 'General Medicine',
  //   'fatigue': 'General Medicine',
  //   'weakness': 'General Medicine',
  //   'preventive care': 'General Medicine',
  //   'health screening': 'General Medicine',
  //   'wellness': 'General Medicine',
  //   'annual exam': 'General Medicine',

  //   // Neurology
  //   'headache': 'Neurology',
  //   'migraine': 'Neurology',
  //   'seizure': 'Neurology',
  //   'epilepsy': 'Neurology',
  //   'stroke': 'Neurology',
  //   'dizziness': 'Neurology',
  //   'vertigo': 'Neurology',
  //   'tremor': 'Neurology',
  //   'memory loss': 'Neurology',
  //   'numbness': 'Neurology',
  //   'tingling': 'Neurology',
  //   'multiple sclerosis': 'Neurology',
  //   'parkinson': 'Neurology',
  //   'alzheimer': 'Neurology',
  //   'dementia': 'Neurology',
  //   'brain': 'Neurology',
  //   'nerve': 'Neurology',
  //   'neuropathy': 'Neurology',

  //   // Obstetrics & Gynecology
  //   'pregnancy': 'Obstetrics & Gynecology',
  //   'prenatal': 'Obstetrics & Gynecology',
  //   'menstrual': 'Obstetrics & Gynecology',
  //   'period': 'Obstetrics & Gynecology',
  //   'pelvic pain': 'Obstetrics & Gynecology',
  //   'gynecologic': 'Obstetrics & Gynecology',
  //   'fertility': 'Obstetrics & Gynecology',
  //   'contraception': 'Obstetrics & Gynecology',
  //   'menopause': 'Obstetrics & Gynecology',
  //   'pap smear': 'Obstetrics & Gynecology',
  //   'ovarian': 'Obstetrics & Gynecology',
  //   'uterine': 'Obstetrics & Gynecology',
  //   'vaginal': 'Obstetrics & Gynecology',
  //   'cervical': 'Obstetrics & Gynecology',
  //   'pcos': 'Obstetrics & Gynecology',
  //   'endometriosis': 'Obstetrics & Gynecology',

  //   // Oncology
  //   'cancer': 'Oncology',
  //   'tumor': 'Oncology',
  //   'mass': 'Oncology',
  //   'chemotherapy': 'Oncology',
  //   'radiation': 'Oncology',
  //   'oncology follow up': 'Oncology',
  //   'lump': 'Oncology',
  //   'abnormal growth': 'Oncology',
  //   'leukemia': 'Oncology',
  //   'lymphoma': 'Oncology',
  //   'carcinoma': 'Oncology',
  //   'malignancy': 'Oncology',
  //   'metastasis': 'Oncology',

  //   // Ophthalmology
  //   'eye': 'Ophthalmology',
  //   'vision': 'Ophthalmology',
  //   'blurry vision': 'Ophthalmology',
  //   'cataract': 'Ophthalmology',
  //   'glaucoma': 'Ophthalmology',
  //   'eye pain': 'Ophthalmology',
  //   'dry eye': 'Ophthalmology',
  //   'retina': 'Ophthalmology',
  //   'macular degeneration': 'Ophthalmology',
  //   'blind': 'Ophthalmology',
  //   'floaters': 'Ophthalmology',
  //   'double vision': 'Ophthalmology',
  //   'conjunctivitis': 'Ophthalmology',
  //   'pink eye': 'Ophthalmology',

  //   // Orthopedics
  //   'joint pain': 'Orthopedics',
  //   'bone': 'Orthopedics',
  //   'fracture': 'Orthopedics',
  //   'broken bone': 'Orthopedics',
  //   'sprain': 'Orthopedics',
  //   'arthritis': 'Orthopedics',
  //   'back pain': 'Orthopedics',
  //   'knee pain': 'Orthopedics',
  //   'shoulder pain': 'Orthopedics',
  //   'hip pain': 'Orthopedics',
  //   'osteoporosis': 'Orthopedics',
  //   'tendonitis': 'Orthopedics',
  //   'ligament': 'Orthopedics',
  //   'sports injury': 'Orthopedics',
  //   'scoliosis': 'Orthopedics',
  //   'herniated disc': 'Orthopedics',
  //   'carpal tunnel': 'Orthopedics',

  //   // Pediatrics
  //   'child': 'Pediatrics',
  //   'baby': 'Pediatrics',
  //   'infant': 'Pediatrics',
  //   'toddler': 'Pediatrics',
  //   'childhood': 'Pediatrics',
  //   'developmental': 'Pediatrics',
  //   'growth delay': 'Pediatrics',
  //   'pediatric': 'Pediatrics',
  //   'newborn': 'Pediatrics',
  //   'childhood vaccine': 'Pediatrics',
  //   'well child visit': 'Pediatrics',

  //   // Psychiatry
  //   'anxiety': 'Psychiatry',
  //   'depression': 'Psychiatry',
  //   'mood': 'Psychiatry',
  //   'mental health': 'Psychiatry',
  //   'stress': 'Psychiatry',
  //   'psychiatric': 'Psychiatry',
  //   'insomnia': 'Psychiatry',
  //   'sleep disorder': 'Psychiatry',
  //   'bipolar': 'Psychiatry',
  //   'schizophrenia': 'Psychiatry',
  //   'panic attack': 'Psychiatry',
  //   'ptsd': 'Psychiatry',
  //   'ocd': 'Psychiatry',
  //   'adhd': 'Psychiatry',
  //   'eating disorder': 'Psychiatry',
  //   'addiction': 'Psychiatry',
  //   'substance abuse': 'Psychiatry',

  //   // Pulmonology
  //   'breathing': 'Pulmonology',
  //   'cough': 'Pulmonology',
  //   'shortness of breath': 'Pulmonology',
  //   'asthma': 'Pulmonology',
  //   'copd': 'Pulmonology',
  //   'emphysema': 'Pulmonology',
  //   'bronchitis': 'Pulmonology',
  //   'pneumonia': 'Pulmonology',
  //   'respiratory': 'Pulmonology',
  //   'lung': 'Pulmonology',
  //   'wheezing': 'Pulmonology',
  //   'pulmonary': 'Pulmonology',
  //   'tb': 'Pulmonology',
  //   'tuberculosis': 'Pulmonology',
  //   'covid': 'Pulmonology',
  //   'sleep apnea': 'Pulmonology',

  //   // Radiology - mainly for referrals
  //   'xray': 'Radiology',
  //   'x-ray': 'Radiology',
  //   'ultrasound': 'Radiology',
  //   'mri': 'Radiology',
  //   'ct scan': 'Radiology',
  //   'cat scan': 'Radiology',
  //   'imaging': 'Radiology',
  //   'mammogram': 'Radiology',
  //   'dexa scan': 'Radiology',
  //   'bone density': 'Radiology',
  //   'pet scan': 'Radiology',

  //   // Urology
  //   'urinary': 'Urology',
  //   'bladder': 'Urology',
  //   'kidney': 'Urology',
  //   'prostate': 'Urology',
  //   'testicular': 'Urology',
  //   'uti': 'Urology',
  //   'urinary tract infection': 'Urology',
  //   'kidney stone': 'Urology',
  //   'incontinence': 'Urology',
  //   'blood in urine': 'Urology',
  //   'erectile dysfunction': 'Urology',
  //   'urination problem': 'Urology',
  //   'frequent urination': 'Urology',
  //   'painful urination': 'Urology',
  //   'male infertility': 'Urology',

  //   // ENT (Otolaryngology) - added for completeness
  //   'ear': 'ENT',
  //   'nose': 'ENT',
  //   'throat': 'ENT',
  //   'hearing': 'ENT',
  //   'sinus': 'ENT',
  //   'tonsil': 'ENT',
  //   'sore throat': 'ENT',
  //   'hearing loss': 'ENT',
  //   'tinnitus': 'ENT',
  //   'ear infection': 'ENT',
  //   'sinusitis': 'ENT',
  //   'nasal congestion': 'ENT',
  //   'voice': 'ENT',
  //   'swallowing difficulty': 'ENT',
  //   'snoring': 'ENT',
  // };

  // Enhanced symptoms to medical specialty mapping with simple English terms
  final Map<String, String> _symptomsToSpecialty = {
    // Cardiology - existing terms plus additions
    'heart': 'Cardiology',
    'chest pain': 'Cardiology',
    'palpitation': 'Cardiology',
    'shortness of breath': 'Cardiology',
    'high blood pressure': 'Cardiology',
    'hypertension': 'Cardiology',
    'cholesterol': 'Cardiology',
    'arrhythmia': 'Cardiology',
    'heart attack': 'Cardiology',
    'myocardial infarction': 'Cardiology',
    'angina': 'Cardiology',
    'heart failure': 'Cardiology',
    'cardiac': 'Cardiology',
    'pulse': 'Cardiology',
    // Simple English additions for Cardiology
    'chest discomfort': 'Cardiology',
    'heart racing': 'Cardiology',
    'heart pounding': 'Cardiology',
    'can\'t breathe': 'Cardiology',
    'trouble breathing': 'Cardiology',
    'heart skipping beats': 'Cardiology',
    'pressure in chest': 'Cardiology',
    'heart rhythm': 'Cardiology',
    'breathing difficulty': 'Cardiology',
    'heart problems': 'Cardiology',
    'bluish lips or skin': 'Cardiology',
    'swollen ankles': 'Cardiology',
    'fainting': 'Cardiology',

    // Dermatology - existing terms plus additions
    'skin': 'Dermatology',
    'rash': 'Dermatology',
    'acne': 'Dermatology',
    'eczema': 'Dermatology',
    'itching': 'Dermatology',
    'psoriasis': 'Dermatology',
    'skin lesion': 'Dermatology',
    'mole': 'Dermatology',
    'hair loss': 'Dermatology',
    'nail problem': 'Dermatology',
    'skin infection': 'Dermatology',
    'fungal': 'Dermatology',
    // Simple English additions for Dermatology
    'skin redness': 'Dermatology',
    'pimples': 'Dermatology',
    'skin bumps': 'Dermatology',
    'itchy skin': 'Dermatology',
    'dry skin': 'Dermatology',
    'scaly skin': 'Dermatology',
    'dandruff': 'Dermatology',
    'bald spots': 'Dermatology',
    'warts': 'Dermatology',
    'skin tags': 'Dermatology',
    'birthmark': 'Dermatology',
    'hives': 'Dermatology',
    'spots on skin': 'Dermatology',
    'facial redness': 'Dermatology',
    'boils': 'Dermatology',

    // Endocrinology - existing terms plus additions
    'diabetes': 'Endocrinology',
    'thyroid': 'Endocrinology',
    'hormone': 'Endocrinology',
    'blood sugar': 'Endocrinology',
    'glucose': 'Endocrinology',
    'insulin': 'Endocrinology',
    'hyperthyroidism': 'Endocrinology',
    'hypothyroidism': 'Endocrinology',
    'cushing': 'Endocrinology',
    'addison': 'Endocrinology',
    'pituitary': 'Endocrinology',
    'metabolic': 'Endocrinology',
    'growth': 'Endocrinology',
    // Simple English additions for Endocrinology
    'sugar problem': 'Endocrinology',
    'always thirsty': 'Endocrinology',
    'frequent urination': 'Endocrinology',
    'always tired': 'Endocrinology',
    'weight gain': 'Endocrinology',
    'weight loss': 'Endocrinology',
    'neck swelling': 'Endocrinology',
    'sweating a lot': 'Endocrinology',
    'always cold': 'Endocrinology',
    'always hot': 'Endocrinology',
    'hair thinning': 'Endocrinology',
    'excessive hunger': 'Endocrinology',
    'sugar levels': 'Endocrinology',

    // Gastroenterology - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for Gastroenterology
    'stomachache': 'Gastroenterology',
    'tummy pain': 'Gastroenterology',
    'belly pain': 'Gastroenterology',
    'indigestion': 'Gastroenterology',
    'upset stomach': 'Gastroenterology',
    'can\'t poop': 'Gastroenterology',
    'loose stools': 'Gastroenterology',
    'throwing up': 'Gastroenterology',
    'bloating': 'Gastroenterology',
    'gas': 'Gastroenterology',
    'burping': 'Gastroenterology',
    'heartburn': 'Gastroenterology',
    'stomach burning': 'Gastroenterology',
    'food coming back up': 'Gastroenterology',
    'jaundice': 'Gastroenterology',
    'yellow skin': 'Gastroenterology',
    'yellow eyes': 'Gastroenterology',
    'stomach bug': 'Gastroenterology',

    // Neurology - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for Neurology
    'head hurts': 'Neurology',
    'bad headache': 'Neurology',
    'passing out': 'Neurology',
    'spinning room': 'Neurology',
    'feel dizzy': 'Neurology',
    'shaking hands': 'Neurology',
    'forgetting things': 'Neurology',
    'pins and needles': 'Neurology',
    'feeling numb': 'Neurology',
    'blackouts': 'Neurology',
    'confusion': 'Neurology',
    'forgetfulness': 'Neurology',
    'slurred speech': 'Neurology',
    'balance problems': 'Neurology',
    'difficulty speaking': 'Neurology',
    'face drooping': 'Neurology',

    // Obstetrics & Gynecology - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for OB/GYN
    'missed period': 'Obstetrics & Gynecology',
    'pregnant': 'Obstetrics & Gynecology',
    'heavy periods': 'Obstetrics & Gynecology',
    'painful periods': 'Obstetrics & Gynecology',
    'irregular periods': 'Obstetrics & Gynecology',
    'cramps': 'Obstetrics & Gynecology',
    'hot flashes': 'Obstetrics & Gynecology',
    'night sweats': 'Obstetrics & Gynecology',
    'vaginal discharge': 'Obstetrics & Gynecology',
    'breast lump': 'Obstetrics & Gynecology',
    'breast pain': 'Obstetrics & Gynecology',
    'spotting': 'Obstetrics & Gynecology',
    'bleeding between periods': 'Obstetrics & Gynecology',
    'birth control': 'Obstetrics & Gynecology',

    // Ophthalmology - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for Ophthalmology
    'eye problems': 'Ophthalmology',
    'can\'t see well': 'Ophthalmology',
    'blurry sight': 'Ophthalmology',
    'seeing spots': 'Ophthalmology',
    'watery eyes': 'Ophthalmology',
    'itchy eyes': 'Ophthalmology',
    'red eyes': 'Ophthalmology',
    'eye irritation': 'Ophthalmology',
    'light sensitivity': 'Ophthalmology',
    'eye pressure': 'Ophthalmology',
    'dark spots in vision': 'Ophthalmology',
    'eye discharge': 'Ophthalmology',
    'night blindness': 'Ophthalmology',
    'seeing halos': 'Ophthalmology',

    // Orthopedics - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for Orthopedics
    'aching joints': 'Orthopedics',
    'stiff joints': 'Orthopedics',
    'twisted ankle': 'Orthopedics',
    'bad back': 'Orthopedics',
    'sore knee': 'Orthopedics',
    'painful shoulder': 'Orthopedics',
    'hip problems': 'Orthopedics',
    'weak bones': 'Orthopedics',
    'muscle pain': 'Orthopedics',
    'bones hurt': 'Orthopedics',
    'limping': 'Orthopedics',
    'trouble walking': 'Orthopedics',
    'wrist pain': 'Orthopedics',
    'elbow pain': 'Orthopedics',
    'foot pain': 'Orthopedics',
    'ankle swelling': 'Orthopedics',

    // ENT (Otolaryngology) - existing terms plus additions
    // (keeping existing entries...)

    // Simple English additions for ENT
    'ear pain': 'ENT',
    'ear ache': 'ENT',
    'stuffy nose': 'ENT',
    'runny nose': 'ENT',
    'sore throat': 'ENT',
    'can\'t hear well': 'ENT',
    'ringing ears': 'ENT',
    'nose bleeds': 'ENT',
    'can\'t smell': 'ENT',
    'throat infection': 'ENT',
    'hoarse voice': 'ENT',
    'can\'t swallow': 'ENT',
    'lump in throat': 'ENT',
    'post-nasal drip': 'ENT',
    'stuffy ears': 'ENT',
    'ear wax': 'ENT',
    'itchy ears': 'ENT',

    // Keep all other existing specialty mappings
    // ...
  };

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _processQuery() async {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _recommendations = [];
      _selectedRecommendation = null;
    });

    try {
      // Step 1: Determine medical specialty based on symptoms
      final recommendedSpecialties = _analyzeSymptoms(query);

      // Step 2: Find available doctors matching specialties
      final availableDoctors = await _findMatchingDoctors(
        recommendedSpecialties,
      );

      // Step 3: Generate appointment recommendations
      await _generateRecommendations(availableDoctors, query);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing your request: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  List<String> _analyzeSymptoms(String query) {
    List<String> matchedSpecialties = [];

    // Simple keyword matching
    _symptomsToSpecialty.forEach((symptom, specialty) {
      if (query.contains(symptom) && !matchedSpecialties.contains(specialty)) {
        matchedSpecialties.add(specialty);
      }
    });

    // If no matches, default to General Medicine
    if (matchedSpecialties.isEmpty) {
      matchedSpecialties.add('General Medicine');
    }

    return matchedSpecialties;
  }

  Future<List<User>> _findMatchingDoctors(List<String> specialties) async {
    List<User> doctors = [];

    // Query for doctors with matching specialties
    final querySnapshot =
        await _firestore
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .get();

    for (var doc in querySnapshot.docs) {
      final userData = doc.data();
      final user = User.fromJson({'id': doc.id, ...userData});

      // Check if doctor specialization matches or is a general practitioner
      if (user.specialization != null) {
        if (specialties.contains(user.specialization) ||
            user.specialization == 'General Medicine') {
          doctors.add(user);
        }
      }
    }

    return doctors;
  }

  Future<void> _generateRecommendations(
    List<User> doctors,
    String query,
  ) async {
    if (doctors.isEmpty) {
      setState(() {
        _errorMessage =
            'No doctors found for your symptoms. Please try a different description.';
      });
      return;
    }

    List<Map<String, dynamic>> recommendations = [];
    final now = DateTime.now();

    // For each doctor, find their next available slot
    for (var doctor in doctors) {
      try {
        // Get doctor's booked appointments for the next 7 days
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfWeek = startOfDay.add(const Duration(days: 7));

        final bookedSlots = await _getBookedTimeSlots(
          doctor.id,
          startOfDay,
          endOfWeek,
        );

        // Find next available date (skip weekends)
        DateTime? nextAvailableDate;
        String? availableTimeSlot;

        for (var i = 0; i < 7; i++) {
          final date = startOfDay.add(Duration(days: i));

          // Skip weekends
          if (date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday) {
            continue;
          }

          // Check for available slots on this day
          final availableSlots = _getAvailableSlotsForDate(date, bookedSlots);
          if (availableSlots.isNotEmpty) {
            nextAvailableDate = date;
            availableTimeSlot = availableSlots.first;
            break;
          }
        }

        if (nextAvailableDate != null && availableTimeSlot != null) {
          // Determine urgency score based on keywords
          final urgencyScore = _calculateUrgencyScore(query);

          // Determine specialty match score
          final specialtyMatchScore = _calculateSpecialtyMatchScore(
            doctor,
            query,
          );

          // Calculate an overall recommendation score
          final recommendationScore = urgencyScore + specialtyMatchScore;

          recommendations.add({
            'doctor': doctor,
            'date': nextAvailableDate,
            'timeSlot': availableTimeSlot,
            'score': recommendationScore,
            'urgency': urgencyScore,
            'specialtyMatch': specialtyMatchScore,
          });
        }
      } catch (e) {
        print('Error generating recommendation for doctor ${doctor.name}: $e');
      }
    }

    // Sort by recommendation score (highest first)
    recommendations.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    setState(() {
      _recommendations = recommendations;
    });
  }

  Future<Map<DateTime, List<String>>> _getBookedTimeSlots(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    Map<DateTime, List<String>> bookedSlots = {};

    final snapshot =
        await _firestore
            .collection('appointments')
            .where('doctorId', isEqualTo: doctorId)
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .where('status', whereIn: ['pending', 'confirmed'])
            .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final timeSlot = data['timeSlot'] as String;

      // Normalize date to remove time part
      final normalizedDate = DateTime(date.year, date.month, date.day);

      if (!bookedSlots.containsKey(normalizedDate)) {
        bookedSlots[normalizedDate] = [];
      }

      bookedSlots[normalizedDate]!.add(timeSlot);
    }

    return bookedSlots;
  }

  List<String> _getAvailableSlotsForDate(
    DateTime date,
    Map<DateTime, List<String>> bookedSlots,
  ) {
    // Standard time slots
    final allTimeSlots = [
      '9:00 AM',
      '9:30 AM',
      '10:00 AM',
      '10:30 AM',
      '11:00 AM',
      '11:30 AM',
      '12:00 PM',
      '12:30 PM',
      '2:00 PM',
      '2:30 PM',
      '3:00 PM',
      '3:30 PM',
      '4:00 PM',
      '4:30 PM',
    ];

    // Normalize date to remove time part
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // If there are booked slots for this date, filter them out
    if (bookedSlots.containsKey(normalizedDate)) {
      return allTimeSlots
          .where((slot) => !bookedSlots[normalizedDate]!.contains(slot))
          .toList();
    }

    return allTimeSlots;
  }

  double _calculateUrgencyScore(String query) {
    final urgentKeywords = {
      'emergency': 5.0,
      'severe': 4.0,
      'urgent': 4.0,
      'pain': 3.0,
      'immediate': 4.0,
      'worse': 3.0,
      'trouble': 3.0,
      'difficulty': 2.5,
      'problem': 2.0,
      'issue': 1.5,
      'concerned': 1.5,
      'worry': 1.5,
      'check': 1.0,
      'routine': 0.5,
    };

    double score = 1.0; // base score

    urgentKeywords.forEach((keyword, value) {
      if (query.contains(keyword)) {
        score += value;
      }
    });

    // Cap score between 1 and 5
    return score > 5.0 ? 5.0 : (score < 1.0 ? 1.0 : score);
  }

  double _calculateSpecialtyMatchScore(User doctor, String query) {
    if (doctor.specialization == null) return 1.0;

    // Check if doctor specialization directly matches symptoms
    double score = 1.0; // base score

    _symptomsToSpecialty.forEach((symptom, specialty) {
      if (query.contains(symptom) && doctor.specialization == specialty) {
        score += 2.0;
      }
    });

    // If general practitioner, give a moderate score
    if (doctor.specialization == 'General Medicine') {
      score += 1.0;
    }

    return score;
  }

  void _bookSelectedAppointment() {
    if (_selectedRecommendation == null) return;

    final User doctor = _selectedRecommendation!['doctor'];
    final DateTime date = _selectedRecommendation!['date'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BookAppointmentScreen(
              selectedDoctor: doctor,
              // Optional: Pass initial values for date and time slot
              // This would require modifying BookAppointmentScreen to accept these parameters
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Scheduling Assistant')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content area with scrollable content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro text - keep existing code
                    const Text(
                      'Describe your symptoms or reason for visit, and I\'ll help you find the right doctor and appointment time.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Input field - keep existing code
                    TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'e.g. "I have a severe headache for 3 days"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _processQuery,
                        ),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _processQuery(),
                    ),

                    // Error message - keep existing code
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Loading indicator - keep existing code
                    if (_isProcessing) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing your symptoms and finding the best doctor...',
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Recommendations - keep existing code
                    if (_recommendations.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Recommended Appointments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final recommendation = _recommendations[index];
                            final doctor = recommendation['doctor'] as User;
                            final date = recommendation['date'] as DateTime;
                            final timeSlot =
                                recommendation['timeSlot'] as String;
                            final urgency = recommendation['urgency'] as double;

                            final isSelected =
                                _selectedRecommendation == recommendation;

                            return Card(
                              elevation: isSelected ? 4 : 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side:
                                    isSelected
                                        ? BorderSide(
                                          color: Theme.of(context).primaryColor,
                                          width: 2,
                                        )
                                        : BorderSide.none,
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedRecommendation = recommendation;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            radius: 24,
                                            child: Text(
                                              doctor.name.substring(0, 1),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doctor.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  doctor.specialization ??
                                                      'General Practitioner',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getUrgencyColor(urgency),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getUrgencyLabel(urgency),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat(
                                              'EEE, MMM d',
                                            ).format(date),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeSlot,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton(
                                              onPressed:
                                                  _bookSelectedAppointment,
                                              child: const Text(
                                                'Book This Appointment',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // New search button at bottom
            if (_recommendations.isEmpty && !_isProcessing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _processQuery,
                  icon: const Icon(Icons.search),
                  label: const Text('Find Available Doctors'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          _selectedRecommendation != null
              ? FloatingActionButton.extended(
                onPressed: _bookSelectedAppointment,
                label: const Text('Book Selected Appointment'),
                icon: const Icon(Icons.check),
              )
              : null,
    );
  }

  Color _getUrgencyColor(double urgency) {
    if (urgency >= 4.0) return Colors.red;
    if (urgency >= 3.0) return Colors.orange;
    if (urgency >= 2.0) return Colors.amber;
    return Colors.green;
  }

  String _getUrgencyLabel(double urgency) {
    if (urgency >= 4.0) return 'Urgent';
    if (urgency >= 3.0) return 'Priority';
    if (urgency >= 2.0) return 'Soon';
    return 'Routine';
  }
}
