import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:happ/core/models/record.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
// Replace firebase_ml_vision with google_mlkit_text_recognition
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
// Add this at the top of the file with other imports
import 'package:happ/core/services/notification_service.dart';
// Add these imports at the top
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalInsight {
  final String id;
  final String term;
  final String definition;
  final String? severity;
  final String? recommendation;
  final int confidenceScore;

  MedicalInsight({
    required this.id,
    required this.term,
    required this.definition,
    this.severity,
    this.recommendation,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'term': term,
    'definition': definition,
    'severity': severity,
    'recommendation': recommendation,
    'confidenceScore': confidenceScore,
  };

  factory MedicalInsight.fromJson(Map<String, dynamic> json) {
    return MedicalInsight(
      id: json['id'] ?? '',
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
      severity: json['severity'],
      recommendation: json['recommendation'],
      confidenceScore: json['confidenceScore'] ?? 0,
    );
  }
}

class DocumentAnalysisResult {
  final List<MedicalInsight> criticalInsights;
  final String summary;
  final Map<String, dynamic> rawAnalysisData;
  final bool verified;

  DocumentAnalysisResult({
    required this.criticalInsights,
    required this.summary,
    required this.rawAnalysisData,
    required this.verified,
  });
}

class SimplifiedMedicalTerm {
  final String original;
  final String simplified;
  final String definition;
  final bool isComplex;
  final int startIndex;
  final int endIndex;

  SimplifiedMedicalTerm({
    required this.original,
    required this.simplified,
    required this.definition,
    required this.isComplex,
    required this.startIndex,
    required this.endIndex,
  });
}

class MedicalNlpService {
  // Singleton pattern
  static final MedicalNlpService _instance = MedicalNlpService._internal();
  
  factory MedicalNlpService() {
    return _instance;
  }
  
  MedicalNlpService._internal();

  // Create a text recognizer instance that can be reused
  final _textRecognizer = TextRecognizer();

  // Medical terminology dictionary
  // final Map<String, String> _medicalDictionary = {
  //   'hypertension': 'High blood pressure that can lead to serious health problems',
  //   'hypercholesterolemia': 'High levels of cholesterol in the blood',
  //   'myocardial infarction': 'Heart attack - blockage of blood flow to the heart muscle',
  //   'diabetes mellitus': 'A disorder where blood sugar levels are abnormally high',
  //   'arrhythmia': 'Irregular heartbeat or abnormal heart rhythm',
  //   'hypothyroidism': 'Underactive thyroid gland not producing enough hormones',
  //   'pneumonia': 'Infection that inflames air sacs in one or both lungs',
  //   'asthma': 'Condition causing narrowing and swelling of airways with excess mucus production',
  //   'copd': 'Chronic obstructive pulmonary disease - inflammatory lung disease',
  //   'osteoarthritis': 'Degeneration of joint cartilage and underlying bone',
  //   // Additional medical terms would be included in a real implementation
  // };

    // Medical terminology dictionary with expanded entries
  final Map<String, String> _medicalDictionary = {
    // Cardiovascular conditions
    'hypertension': 'High blood pressure that can lead to serious health problems',
    'hypercholesterolemia': 'High levels of cholesterol in the blood',
    'myocardial infarction': 'Heart attack - blockage of blood flow to the heart muscle',
    'arrhythmia': 'Irregular heartbeat or abnormal heart rhythm',
    'atrial fibrillation': 'Irregular heart rhythm characterized by rapid and irregular beating of the atria',
    'coronary artery disease': 'Damage or disease in the heart\'s major blood vessels',
    'heart failure': 'Chronic condition where the heart doesn\'t pump blood as well as it should',
    'angina': 'Chest pain caused by reduced blood flow to the heart',
    'deep vein thrombosis': 'Blood clot that forms in a deep vein, usually in the legs',
    'pulmonary embolism': 'Blockage in one of the pulmonary arteries in the lungs',
    'peripheral vascular disease': 'Circulation disorder causing blood vessels to narrow or block',

    // Respiratory conditions
    'pneumonia': 'Infection that inflames air sacs in one or both lungs',
    'asthma': 'Condition causing narrowing and swelling of airways with excess mucus production',
    'copd': 'Chronic obstructive pulmonary disease - inflammatory lung disease',
    'pulmonary fibrosis': 'Scarring of lung tissue leading to breathing problems',
    'tuberculosis': 'Infectious disease affecting primarily the lungs',
    'pleural effusion': 'Buildup of fluid between the layers of tissue lining the lungs and chest cavity',
    'bronchitis': 'Inflammation of the bronchial tubes that carry air to and from the lungs',
    'sleep apnea': 'Sleep disorder where breathing repeatedly stops and starts',
    'cystic fibrosis': 'Hereditary disease affecting the lungs and digestive system',

    // Endocrine disorders
    'diabetes mellitus': 'A disorder where blood sugar levels are abnormally high',
    'hypothyroidism': 'Underactive thyroid gland not producing enough hormones',
    'hyperthyroidism': 'Overactive thyroid gland producing excessive thyroid hormone',
    'cushing syndrome': 'Condition caused by excessive cortisol exposure',
    'addison\'s disease': 'Adrenal glands don\'t produce enough hormones',
    'hashimoto\'s thyroiditis': 'Autoimmune disorder affecting the thyroid gland',
    'graves\' disease': 'Immune system disorder resulting in overproduction of thyroid hormones',
    'hyperparathyroidism': 'Excessive production of parathyroid hormone',
    'pcos': 'Polycystic ovary syndrome - hormonal disorder affecting women',

    // Neurological disorders
    'migraine': 'Recurring headache causing moderate to severe pain',
    'epilepsy': 'Neurological disorder characterized by recurring seizures',
    'parkinson\'s disease': 'Progressive nervous system disorder affecting movement',
    'multiple sclerosis': 'Disease affecting the central nervous system',
    'alzheimer\'s disease': 'Progressive disorder causing brain cells to degenerate and die',
    'stroke': 'Damage to the brain from interruption of its blood supply',
    'tia': 'Transient ischemic attack - temporary period of symptoms similar to stroke',
    'meningitis': 'Inflammation of the membranes surrounding the brain and spinal cord',
    'neuropathy': 'Damage or dysfunction of one or more nerves causing numbness or weakness',
    'dementia': 'Group of symptoms affecting memory, thinking and social abilities',
    'guillain-barré syndrome': 'Rare disorder where immune system attacks peripheral nerves',

    // Musculoskeletal conditions
    'osteoarthritis': 'Degeneration of joint cartilage and underlying bone',
    'rheumatoid arthritis': 'Autoimmune disorder affecting the lining of joints',
    'osteoporosis': 'Bones become weak and brittle due to hormone changes or calcium deficiency',
    'gout': 'Form of inflammatory arthritis characterized by recurrent attacks of red, tender joints',
    'fibromyalgia': 'Disorder characterized by widespread musculoskeletal pain',
    'lupus': 'Systemic autoimmune disease that occurs when the immune system attacks tissues',
    'herniated disc': 'Rupture of intervertebral disc that may press on nearby nerves',
    'scoliosis': 'Sideways curvature of the spine',
    'carpal tunnel syndrome': 'Pressure on median nerve causing numbness and tingling in hand',

    // Gastrointestinal disorders
    'gastroesophageal reflux disease': 'Chronic digestive disease where stomach acid irritates the food pipe',
    'peptic ulcer': 'Open sore on the inner lining of the stomach or duodenum',
    'crohn\'s disease': 'Inflammatory bowel disease causing inflammation of digestive tract',
    'ulcerative colitis': 'Long-term condition causing inflammation and ulcers in colon and rectum',
    'irritable bowel syndrome': 'Common disorder affecting large intestine',
    'diverticulitis': 'Inflammation or infection of small pouches in the digestive tract',
    'gallstones': 'Hardened deposits that form in the gallbladder',
    'hepatitis': 'Inflammation of the liver often caused by viral infection',
    'cirrhosis': 'Late stage of scarring of the liver',
    'pancreatitis': 'Inflammation of the pancreas',
    'celiac disease': 'Immune reaction to gluten that damages small intestine',

    // Mental health conditions
    'depression': 'Mood disorder causing persistent feeling of sadness and loss of interest',
    'anxiety disorder': 'Excessive worry and fear that interferes with daily activities',
    'bipolar disorder': 'Mental health condition causing extreme mood swings',
    'schizophrenia': 'Mental disorder characterized by distortions in thinking and perception',
    'ptsd': 'Post-traumatic stress disorder - anxiety disorder triggered by traumatic events',
    'ocd': 'Obsessive-compulsive disorder - characterized by unreasonable thoughts and fears',
    'adhd': 'Attention deficit hyperactivity disorder - persistent pattern of inattention',
    'autism': 'Developmental disorder affecting communication and behavior',
    'eating disorders': 'Abnormal eating habits that negatively affect physical or mental health',

    // Allergies
    'food allergy': 'Immune system reaction that occurs after eating a certain food',
    'drug allergy': 'Abnormal reaction of the immune system to medication',
    'seasonal allergy': 'Allergic reaction to pollen from trees, grasses, and weeds',
    'dust mite allergy': 'Allergic reaction to tiny bugs that live in house dust',
    'pet allergy': 'Allergic reaction to proteins found in an animal\'s skin cells, saliva or urine',
    'latex allergy': 'Reaction to proteins in natural rubber latex',
    'allergic rhinitis': 'Inflammation of the nasal passages due to allergens',
    'allergic conjunctivitis': 'Inflammation of the conjunctiva due to allergens',
    'anaphylaxis': 'Severe, life-threatening allergic reaction',
    'eczema': 'Skin condition causing itchy, inflamed skin',
    'penicillin allergy': 'Abnormal reaction of the immune system to penicillin group antibiotics',

    // Cancer terms
    'leukemia': 'Cancer of blood-forming tissues including bone marrow',
    'lymphoma': 'Cancer that begins in infection-fighting cells of the immune system',
    'melanoma': 'The most serious type of skin cancer',
    'carcinoma': 'Cancer that starts in cells that make up the skin or tissues lining organs',
    'sarcoma': 'Cancer that begins in the bones or soft tissues',
    'metastasis': 'Spread of cancer cells from the primary site to other parts of the body',
    'oncology': 'Branch of medicine dealing with prevention, diagnosis, and treatment of cancer',
    'chemotherapy': 'Treatment that uses drugs to kill rapidly growing cancer cells',
    'radiation therapy': 'Treatment using high doses of radiation to kill cancer cells',
    'biopsy': 'Removal of tissue to examine for disease',

    // Common procedures
    'mri': 'Magnetic Resonance Imaging - medical imaging technique using magnetic fields',
    'ct scan': 'Computed Tomography - detailed X-ray imaging',
    'echocardiogram': 'Ultrasound of the heart',
    'colonoscopy': 'Examination of the large intestine using a camera on a flexible tube',
    'endoscopy': 'Procedure to examine internal organs using a flexible tube with a camera',
    'angiography': 'Imaging technique to visualize the inside of blood vessels',
    'arthroscopy': 'Minimally invasive procedure to examine and treat joint problems',
    'dialysis': 'Artificial process to remove waste products from the blood',
    'lumbar puncture': 'Procedure to collect cerebrospinal fluid from the spinal canal',

    // Common medications
    'antibiotic': 'Medication used to treat bacterial infections',
    'antidepressant': 'Medication used to treat depression',
    'antihypertensive': 'Medication used to treat high blood pressure',
    'statin': 'Medication used to lower cholesterol levels',
    'nsaid': 'Non-steroidal anti-inflammatory drug used to reduce pain and inflammation',
    'corticosteroid': 'Medication used to reduce inflammation in the body',
    'anticoagulant': 'Medication that prevents or reduces blood clotting',
    'insulin': 'Hormone used to treat diabetes by regulating blood sugar',
    'bronchodilator': 'Medication that relaxes bronchial muscles to improve airflow',
    'antihistamine': 'Medication that reduces allergic reactions',
    'immunosuppressant': 'Medication that inhibits or prevents activity of the immune system',

    // Chronic conditions
    'chronic kidney disease': 'Long-term condition where kidneys don\'t work effectively',
    'chronic fatigue syndrome': 'Disorder characterized by extreme fatigue that can\'t be explained',
    'chronic pain': 'Pain that persists for longer than three months',
    'chronic bronchitis': 'Long-term inflammation of the bronchi',
    'chronic sinusitis': 'Long-lasting inflammation of the sinuses',
    
    // Infectious diseases
    'hiv': 'Human Immunodeficiency Virus - attacks the body\'s immune system',
    'aids': 'Acquired Immunodeficiency Syndrome - final stage of HIV infection',
    'influenza': 'Contagious respiratory illness caused by influenza viruses',
    'malaria': 'Serious disease caused by a parasite transmitted by mosquitoes',
    'lyme disease': 'Infectious disease caused by bacteria transmitted by ticks',
    'covid-19': 'Infectious disease caused by the SARS-CoV-2 virus',
    'hepatitis b': 'Viral infection affecting the liver',
    'hepatitis c': 'Viral infection causing liver inflammation and damage',
    // Existing dictionary entries
    'antihypertensive': 'Medication used to treat high blood pressure',
    'statin': 'Medication used to lower cholesterol levels',
    // ...existing entries...
    
    // Add more simplified medical terms
    'hypertension': 'High blood pressure',
    'hyperlipidemia': 'High levels of fat in the blood',
    'myocardial infarction': 'Heart attack',
    'dyspnea': 'Difficulty breathing',
    'tachycardia': 'Abnormally fast heart rate',
    'bradycardia': 'Abnormally slow heart rate',
    'arrhythmia': 'Irregular heart rhythm',
    'cerebrovascular accident': 'Stroke',
    'gastroesophageal reflux disease': 'Acid reflux',
    'pneumonia': 'Lung infection',
    'otitis media': 'Middle ear infection',
    'pruritus': 'Itching',
    'erythema': 'Skin redness',
    'edema': 'Swelling caused by fluid retention',
    'syncope': 'Fainting or passing out',
    'dyslipidemia': 'Abnormal levels of fats in the blood',
    'hyperglycemia': 'High blood sugar',
    'hypoglycemia': 'Low blood sugar',
    'pyrexia': 'Fever',
    'anemia': 'Low red blood cell count',
    'carcinoma': 'Cancer that starts in skin or tissue cells',
    'metastasis': 'Spread of cancer to other parts of the body',
    'benign': 'Not cancerous',
    'malignant': 'Cancerous',
    'hysterectomy': 'Surgical removal of the uterus',
    'appendectomy': 'Surgical removal of the appendix',
    'cholecystectomy': 'Surgical removal of the gallbladder',
    'rhinitis': 'Inflammation of the nasal passages',
  };

  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Extract text from PDF document using Syncfusion
  Future<String> extractTextFromPdf(String fileUrl) async {
    try {
      // Download the PDF file
      final http.Response response = await http.get(Uri.parse(fileUrl));
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempDocPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(tempDocPath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: response.bodyBytes);
      
      // Extract text from all pages
      String extractedText = '';
      PdfTextExtractor extractor = PdfTextExtractor(document);
      
      for (int i = 0; i < document.pages.count; i++) {
        extractedText += '${extractor.extractText(startPageIndex: i)}\n';
      }
      
      // Dispose the document
      document.dispose();
      
      // Clean up temporary file
      await file.delete();
      
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from PDF: $e');
      return '';
    }
  }

  /// Extract text from image using Google ML Kit
  Future<String> extractTextFromImage(String fileUrl) async {
    try {
      // Download the image
      final http.Response response = await http.get(Uri.parse(fileUrl));
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempImagePath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(tempImagePath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Create input image from file
      final inputImage = InputImage.fromFile(file);
      
      // Process the image and extract text
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Build extracted text from blocks
      String extractedText = recognizedText.text;
      
      // Clean up resources
      await file.delete();
      
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      return '';
    } finally {
      // We don't close the recognizer here as we're using a single instance
      // It will be closed when the app closes
    }
  }

  /// Clean up resources when done
  void dispose() {
    _textRecognizer.close();
  }

  /// Analyze text content for medical insights
  Future<DocumentAnalysisResult> analyzeContent(String text) async {
    try {
      // In a real implementation, this would call an NLP API service
      // Here we'll use simple pattern matching for demonstration
      
      List<MedicalInsight> insights = [];
      int insightId = 0;
      
      // Convert text to lowercase for case-insensitive matching
      final lowerText = text.toLowerCase();
      
      // Search for medical terms
      _medicalDictionary.forEach((term, definition) {
        if (lowerText.contains(term)) {
          // Simple algorithm to determine severity (would be more sophisticated in real app)
          String? severity;
          String? recommendation;
          
          if (term == 'hypertension' || term == 'diabetes mellitus' || 
              term == 'myocardial infarction') {
            severity = 'High';
            recommendation = 'Immediate physician consultation recommended';
          } else if (term == 'hypercholesterolemia' || term == 'arrhythmia' || 
                    term == 'pneumonia') {
            severity = 'Medium';
            recommendation = 'Follow-up with healthcare provider recommended';
          } else {
            severity = 'Low';
            recommendation = 'Monitor condition';
          }
          
          // Calculate a simulated confidence score (70-95%)
          final confidenceScore = 70 + (DateTime.now().millisecondsSinceEpoch % 26);
          
          insights.add(MedicalInsight(
            id: 'insight_${++insightId}',
            term: term,
            definition: definition,
            severity: severity,
            recommendation: recommendation,
            confidenceScore: confidenceScore,
          ));
        }
      });
      
      // Generate a simple summary
      String summary = insights.isEmpty
          ? 'No significant medical conditions detected in this document.'
          : 'Analysis identified ${insights.length} medical condition(s) mentioned in this document.';
          
      if (insights.isNotEmpty) {
        final highSeverityCount = insights.where((i) => i.severity == 'High').length;
        if (highSeverityCount > 0) {
          summary += ' $highSeverityCount high severity conditions found.';
        }
      }
      
      return DocumentAnalysisResult(
        criticalInsights: insights,
        summary: summary,
        rawAnalysisData: {
          'text_length': text.length,
          'analysis_timestamp': DateTime.now().toIso8601String(),
          'terms_found': insights.map((i) => i.term).toList(),
        },
        verified: insights.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error analyzing medical content: $e');
      return DocumentAnalysisResult(
        criticalInsights: [],
        summary: 'Error analyzing document content.',
        rawAnalysisData: {'error': e.toString()},
        verified: false,
      );
    }
  }

  /// Process document and extract insights
  Future<DocumentAnalysisResult> processDocument(String fileUrl, String fileType) async {
    try {
      String extractedText = '';
      
      // Extract text based on file type
      if (fileType.toLowerCase().endsWith('pdf')) {
        extractedText = await extractTextFromPdf(fileUrl);
      } else if (['jpg', 'jpeg', 'png'].contains(fileType.toLowerCase())) {
        extractedText = await extractTextFromImage(fileUrl);
      } else {
        return DocumentAnalysisResult(
          criticalInsights: [],
          summary: 'Unsupported document type for analysis.',
          rawAnalysisData: {'file_type': fileType},
          verified: false,
        );
      }
      
      if (extractedText.isEmpty) {
        return DocumentAnalysisResult(
          criticalInsights: [],
          summary: 'No text could be extracted from the document.',
          rawAnalysisData: {'extraction_failed': true},
          verified: false,
        );
      }
      
      // Analyze the extracted text
      return await analyzeContent(extractedText);
    } catch (e) {
      debugPrint('Error processing document: $e');
      return DocumentAnalysisResult(
        criticalInsights: [],
        summary: 'Error processing document.',
        rawAnalysisData: {'error': e.toString()},
        verified: false,
      );
    }
  }

  /// Process complete record with multiple documents
  Future<Map<String, DocumentAnalysisResult>> processRecord(Record record) async {
    Map<String, DocumentAnalysisResult> results = {};
    
    // Process each file in the record
    for (String fileUrl in record.fileUrls) {
      final fileType = _getFileExtension(fileUrl);
      final result = await processDocument(fileUrl, fileType);
      results[fileUrl] = result;
    }
    
    // Also analyze the record description
    if (record.description.isNotEmpty) {
      final textResult = await analyzeContent(record.description);
      results['record_description'] = textResult;
    }
    
    return results;
  }

  /// Process complete record with multiple documents and update patient profile
  Future<Map<String, DocumentAnalysisResult>> processRecordAndUpdatePatient(Record record) async {
    // First process the record normally
    final results = await processRecord(record);
    
    // Extract all medical insights from all documents
    final List<MedicalInsight> allInsights = [];
    results.forEach((fileUrl, result) {
      allInsights.addAll(result.criticalInsights);
    });
    
    // If we found medical conditions, update the patient profile
    if (allInsights.isNotEmpty) {
      await _updatePatientMedicalProfile(record.userId, allInsights);
    }
    
    return results;
  }
  
  /// Update patient medical profile with discovered insights
  Future<void> _updatePatientMedicalProfile(String userId, List<MedicalInsight> insights) async {
    try {
      // Get current user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('User document not found for ID: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      final User user = User.fromJson({'id': userDoc.id, ...userData});
      
      // Create a map for the medical conditions to update
      final Map<String, dynamic> updateData = {};
      final List<String> medicalConditions = [];
      final List<String> allergies = [];
      
      // Add existing conditions if available
      if (userData.containsKey('medicalConditions') && userData['medicalConditions'] is List) {
        medicalConditions.addAll(
          List<String>.from(userData['medicalConditions'])
        );
      }
      
      // Add existing allergies if available
      if (user.allergies != null && user.allergies!.isNotEmpty) {
        allergies.addAll(user.allergies!.split(',').map((e) => e.trim()));
      }
      
      // Process insights and add to medical profile
      for (final insight in insights) {
        final term = insight.term.trim();
        
        // Look for allergies specifically
        if (term.toLowerCase().contains('allergy') || 
            term.toLowerCase().contains('allergic')) {
          if (!allergies.contains(term)) {
            allergies.add(term);
          }
        } 
        // Add other medical conditions
        else if (!medicalConditions.contains(term)) {
          medicalConditions.add(term);
        }
      }
      
      // Prepare update data if we have new information
      if (medicalConditions.isNotEmpty) {
        updateData['medicalConditions'] = medicalConditions;
      }
      
      if (allergies.isNotEmpty) {
        updateData['allergies'] = allergies.join(', ');
      }
      
      // Only update if we have data to update
      if (updateData.isNotEmpty) {
        // Get creation timestamp for the medical history entry
        final timestamp = FieldValue.serverTimestamp();
        
        // Update the user document
        await _firestore.collection('users').doc(userId).update(updateData);
        
        // Also create a medical history entry for tracking
        final currentUser = auth.FirebaseAuth.instance.currentUser;
        final createdById = currentUser?.uid ?? userId;
        
        await _firestore.collection('users')
                        .doc(userId)
                        .collection('medicalHistory')
                        .add({
                          'conditions': medicalConditions,
                          'allergies': allergies,
                          'insights': insights.map((i) => i.toJson()).toList(),
                          'createdAt': timestamp,
                          'createdBy': createdById,
                          'associatedRecordId': insights.isNotEmpty ? insights.first.id : null,
                          'automatic': true // Flag to indicate this was automatically generated
                        });
      }
      
      // After adding medical conditions to the patient profile, send notifications for high-severity conditions
      final notificationService = NotificationService();
      
      // Get high severity conditions to notify about
      final highSeverityInsights = insights.where((insight) => insight.severity == 'High').toList();
      
      // Send notifications for high severity conditions
      for (final insight in highSeverityInsights) {
        await notificationService.sendMedicalInsightNotification(
          userId: userId,
          condition: insight.term,
          severity: 'high',
        );
      }
      
    } catch (e) {
      debugPrint('Error updating patient medical profile: $e');
    }
  }

  /// Method to manually trigger an update of patient medical profile
  Future<void> updatePatientMedicalProfileFromRecord(Record record) async {
    final results = await processRecord(record);
    
    final List<MedicalInsight> allInsights = [];
    results.forEach((fileUrl, result) {
      allInsights.addAll(result.criticalInsights);
    });
    
    if (allInsights.isNotEmpty) {
      await _updatePatientMedicalProfile(record.userId, allInsights);
    }
  }
  
  String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1) {
      return path.substring(lastDot + 1).toLowerCase();
    }
    return '';
  }

  // New method to simplify medical text
  Future<List<SimplifiedMedicalTerm>> simplifyMedicalText(String text) async {
    if (text.isEmpty) {
      return [];
    }
    
    final List<SimplifiedMedicalTerm> simplifiedTerms = [];
    final lowerText = text.toLowerCase();
    
    // First check against our local dictionary
    for (final term in _medicalDictionary.keys) {
      int startIndex = 0;
      while (true) {
        final index = lowerText.indexOf(term, startIndex);
        if (index == -1) break;
        
        // Check that we found a whole word, not part of another word
        final isWholeWord = _isWholeWord(lowerText, index, term.length);
        
        if (isWholeWord) {
          simplifiedTerms.add(
            SimplifiedMedicalTerm(
              original: text.substring(index, index + term.length),
              simplified: _getSimplifiedTerm(term),
              definition: _medicalDictionary[term] ?? '',
              isComplex: _isComplexTerm(term),
              startIndex: index,
              endIndex: index + term.length,
            ),
          );
        }
        
        startIndex = index + term.length;
      }
    }
    
    // Then check against the Firestore extended dictionary
    // This allows for remote updates to our medical terminology
    try {
      final extendedTerms = await FirebaseFirestore.instance
          .collection('medical_terminology')
          .get();
          
      for (final doc in extendedTerms.docs) {
        final data = doc.data();
        if (!data.containsKey('term') || !data.containsKey('definition')) {
          continue;
        }
        
        final term = data['term'] as String;
        
        // Skip terms we've already processed
        if (_medicalDictionary.containsKey(term)) {
          continue;
        }
        
        final definition = data['definition'] as String;
        final simplified = data['simplified'] as String? ?? term;
        
        // Search for this term in the text
        int startIndex = 0;
        final lowerTerm = term.toLowerCase();
        
        while (true) {
          final index = lowerText.indexOf(lowerTerm, startIndex);
          if (index == -1) break;
          
          final isWholeWord = _isWholeWord(lowerText, index, lowerTerm.length);
          
          if (isWholeWord) {
            simplifiedTerms.add(
              SimplifiedMedicalTerm(
                original: text.substring(index, index + lowerTerm.length),
                simplified: simplified,
                definition: definition,
                isComplex: _isComplexTerm(term),
                startIndex: index,
                endIndex: index + lowerTerm.length,
              ),
            );
          }
          
          startIndex = index + lowerTerm.length;
        }
      }
    } catch (e) {
      debugPrint('Error fetching extended medical terminology: $e');
    }
    
    // Sort terms by their position in the text
    simplifiedTerms.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    
    return simplifiedTerms;
  }
  
  // Generate a simplified version of the text with explanations
  String generateSimplifiedText(String originalText, List<SimplifiedMedicalTerm> terms) {
    if (terms.isEmpty) {
      return originalText;
    }
    
    String result = originalText;
    
    // Process in reverse order to keep indices valid
    for (int i = terms.length - 1; i >= 0; i--) {
      final term = terms[i];
      final simplified = '${term.original} (${term.simplified})';
      result = result.replaceRange(term.startIndex, term.endIndex, simplified);
    }
    
    return result;
  }
  
  bool _isWholeWord(String text, int index, int length) {
    final beforeChar = index > 0 ? text[index - 1] : ' ';
    final afterChar = index + length < text.length ? text[index + length] : ' ';
    
    return !_isAlphabetic(beforeChar) && !_isAlphabetic(afterChar);
  }
  
  bool _isAlphabetic(String char) {
    return RegExp(r'[a-zA-Z0-9]').hasMatch(char);
  }
  
  String _getSimplifiedTerm(String term) {
    // Dictionary of complex medical terms with simpler alternatives
    const Map<String, String> simplifications = {
      'myocardial infarction': 'heart attack',
      'cerebrovascular accident': 'stroke',
      'hypertension': 'high blood pressure',
      'hyperlipidemia': 'high cholesterol',
      'dyspnea': 'shortness of breath',
      'syncope': 'fainting',
      // Add more mappings as needed
    };
    
    return simplifications[term.toLowerCase()] ?? term;
  }
  
  bool _isComplexTerm(String term) {
    // Terms that are considered complex and should be highlighted
    const complexIndicators = [
      'itis', 'emia', 'ectomy', 'otomy', 'ostomy', 'pathy',
      'algia', 'megaly', 'oma', 'scopy', 'plasty', 'lysis'
    ];
    
    final lowerTerm = term.toLowerCase();
    
    // Check if any complex indicator is present
    for (final indicator in complexIndicators) {
      if (lowerTerm.contains(indicator)) {
        return true;
      }
    }
    
    // Check if it contains multiple words
    if (lowerTerm.contains(' ') && lowerTerm.length > 15) {
      return true;
    }
    
    return false;
  }

  // Existing methods...
}