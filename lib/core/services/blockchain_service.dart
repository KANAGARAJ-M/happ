import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/services/medical_nlp_service.dart';  // Add this import
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';  // Add this import

class VerificationResult {
  final bool verified;
  final String? blockchainId;
  final String? error;
  final List<MedicalInsight>? insights;  // Add this field

  VerificationResult({
    required this.verified,
    this.blockchainId,
    this.error,
    this.insights,
  });
}

class FederatedVerification {
  final String institutionName;
  final String institutionId;
  final bool verified;
  final String verificationDate;

  FederatedVerification({
    required this.institutionName,
    required this.institutionId,
    required this.verified,
    required this.verificationDate,
  });
}

class RecordProof {
  final String recordId;
  final String blockchainId;
  final String timestamp;
  final String signature;
  final Map<String, dynamic> proofData;

  RecordProof({
    required this.recordId,
    required this.blockchainId,
    required this.timestamp,
    required this.signature,
    required this.proofData,
  });

  Map<String, dynamic> toJson() => {
    'recordId': recordId,
    'blockchainId': blockchainId,
    'timestamp': timestamp,
    'signature': signature,
    'proofData': proofData,
  };
}

class BlockchainService {
  // For development purposes, we'll use Ethereum testnet
  static const String _rpcUrl = 'https://goerli.infura.io/v3/YOUR_INFURA_KEY';
  static const String _contractAddress = '0x123456789abcdef123456789abcdef123456789';
  
  // Private keys would typically be stored securely, not hardcoded
  static const String _privateKey = '';
  
  late final Web3Client _client;
  
  // Singleton pattern
  static final BlockchainService _instance = BlockchainService._internal();
  
  factory BlockchainService() {
    return _instance;
  }
  
  BlockchainService._internal() {
    _initializeClient();
  }
  
  void _initializeClient() {
    try {
      _client = Web3Client(_rpcUrl, http.Client());
      debugPrint('Web3Client initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Web3Client: $e');
    }
  }

  // Add a reference to MedicalNlpService
  final MedicalNlpService _medicalNlpService = MedicalNlpService();

  /// Generates a hash of the record for blockchain storage
  Future<String> getRecordHash(Record record) async {
    try {
      // Create a deterministic representation of the record
      final Map<String, dynamic> recordData = {
        'id': record.id,
        'userId': record.userId,
        'title': record.title,
        'description': record.description,
        'category': record.category,
        'date': record.date.toIso8601String(),
        'createdAt': record.createdAt.toIso8601String(),
        'createdBy': record.createdBy,
      };
      
      // Sort keys to ensure consistent ordering
      final jsonEncoded = json.encode(recordData);
      
      // Generate SHA-256 hash
      final bytes = utf8.encode(jsonEncoded);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      debugPrint('Error generating record hash: $e');
      throw Exception('Failed to generate record hash');
    }
  }
  
  /// Verifies record integrity against blockchain storage and analyzes content
  Future<VerificationResult> verifyRecordIntegrity(
    Record record, 
    String recordHash
  ) async {
    try {
      // In a real implementation, we would query the blockchain
      // For this demo, we'll simulate a verification process
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // For demo purposes, let's verify based on some condition (e.g., even seconds)
      final now = DateTime.now();
      final isVerified = now.second % 3 != 0; // 2/3 chance of verification success
      
      // NEW: Process medical insights if record has documents
      List<MedicalInsight>? insights;
      if (isVerified && record.fileUrls.isNotEmpty) {
        // Process the first document to get insights (real app would process all)
        final resultsMap = await _medicalNlpService.processRecord(record);
        
        // Combine all insights from all documents
        insights = [];
        for (var result in resultsMap.values) {
          insights.addAll(result.criticalInsights);
        }
      }
      
      if (isVerified) {
        return VerificationResult(
          verified: true,
          blockchainId: '0x${recordHash.substring(0, 40)}',
          insights: insights,
        );
      } else {
        return VerificationResult(
          verified: false,
          error: 'Record hash not found on blockchain',
        );
      }
    } catch (e) {
      debugPrint('Error verifying record integrity: $e');
      return VerificationResult(
        verified: false,
        error: 'Verification failed: $e',
      );
    }
  }
  
  // Add a method to analyze document content separately
  Future<DocumentAnalysisResult> analyzeDocument(String fileUrl, String fileType) async {
    return await _medicalNlpService.processDocument(fileUrl, fileType);
  }
  
  // Add a method to analyze an entire record
  Future<Map<String, DocumentAnalysisResult>> analyzeRecordContent(Record record) async {
    return await _medicalNlpService.processRecord(record);
  }

  /// Checks federated healthcare institutions for record verification
  Future<List<FederatedVerification>> checkFederatedSources(
    String recordHash,
    String userId
  ) async {
    try {
      // In a real implementation, this would query other healthcare institutions
      // For this demo, we'll return simulated results
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final random = DateTime.now().millisecondsSinceEpoch;
      final dateFormat = DateFormat('MMM dd, yyyy');
      
      return [
        FederatedVerification(
          institutionName: 'City General Hospital',
          institutionId: '0x11223344556677889900',
          verified: random % 2 == 0,
          verificationDate: dateFormat.format(DateTime.now().subtract(const Duration(days: 5))),
        ),
        FederatedVerification(
          institutionName: 'National Healthcare Network',
          institutionId: '0x99887766554433221100',
          verified: random % 3 == 0,
          verificationDate: dateFormat.format(DateTime.now().subtract(const Duration(days: 2))),
        ),
        FederatedVerification(
          institutionName: 'Medical Research Institute',
          institutionId: '0xaabbccddeeff00112233',
          verified: random % 4 != 0,
          verificationDate: dateFormat.format(DateTime.now().subtract(const Duration(days: 10))),
        ),
      ];
    } catch (e) {
      debugPrint('Error checking federated sources: $e');
      return [];
    }
  }
  
  /// Generates a zero-knowledge proof for secure sharing
  Future<RecordProof> generateZkProof(Record record, String blockchainId) async {
    try {
      // In a real implementation, this would create an actual ZK proof
      // For this demo, we'll create a simulated proof
      
      final now = DateTime.now();
      final timestamp = now.toIso8601String();
      
      // Create a simulated proof data structure
      final Map<String, dynamic> proofData = {
        'recordType': record.category,
        'recordDate': record.date.toIso8601String(),
        'recordCreator': record.createdBy,
        'verificationTimestamp': timestamp,
      };
      
      // Generate a simulated cryptographic signature
      final message = utf8.encode('${record.id}:$blockchainId:$timestamp');
      final signature = base64.encode(message);
      
      return RecordProof(
        recordId: record.id,
        blockchainId: blockchainId,
        timestamp: timestamp,
        signature: signature,
        proofData: proofData,
      );
    } catch (e) {
      debugPrint('Error generating ZK proof: $e');
      throw Exception('Failed to generate verification proof');
    }
  }
  
  /// Gets the audit trail for a record
  Future<List<Map<String, dynamic>>> getRecordAuditTrail(
    String recordId, 
    String? blockchainId
  ) async {
    // In a real implementation, this would query the blockchain for access logs
    // For this demo, we'll return simulated audit entries
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      {
        'accessType': 'View',
        'accessedBy': 'Dr. Sarah Johnson',
        'timestamp': DateTime.now().subtract(const Duration(days: 2, hours: 3)).toIso8601String(),
        'location': 'City General Hospital',
        'device': 'Workstation 42',
      },
      {
        'accessType': 'Edit',
        'accessedBy': 'Dr. Michael Chen',
        'timestamp': DateTime.now().subtract(const Duration(days: 5, hours: 7)).toIso8601String(),
        'location': 'Medical Center West',
        'device': 'Mobile App',
      },
      {
        'accessType': 'View',
        'accessedBy': 'Nurse Alex Rodriguez',
        'timestamp': DateTime.now().subtract(const Duration(days: 5, hours: 8)).toIso8601String(),
        'location': 'Medical Center West',
        'device': 'Tablet Device',
      },
      {
        'accessType': 'View',
        'accessedBy': 'Patient',
        'timestamp': DateTime.now().subtract(const Duration(days: 6, hours: 2)).toIso8601String(),
        'location': 'Remote Access',
        'device': 'Mobile App',
      },
    ];
  }

  /// Stream federated verification results as they come in
  Stream<List<FederatedVerification>> streamFederatedVerifications(String recordId) {
    // In a real implementation, this would connect to a real-time streaming service
    final controller = StreamController<List<FederatedVerification>>();
    
    // Simulate real-time updates from federated sources
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (timer.tick > 5) {
        timer.cancel();
        controller.close();
        return;
      }
      
      // Generate a random new verification result
      final institutions = [
        'City General Hospital',
        'National Healthcare Network',
        'Medical Research Institute',
        'Regional Medical Center',
        'Community Health Alliance',
        'University Medical Center',
      ];
      
      final random = DateTime.now().millisecondsSinceEpoch;
      final institutionIndex = random % institutions.length;
      final dateFormat = DateFormat('MMM dd, yyyy');
      
      final newVerification = FederatedVerification(
        institutionName: institutions[institutionIndex],
        institutionId: '0x${institutionIndex}abbcc${random % 10000}',
        verified: random % 2 == 0,
        verificationDate: dateFormat.format(DateTime.now()),
      );
      
      controller.add([newVerification]);
    });
    
    return controller.stream;
  }

  /// Trigger federated verification process
  Future<void> triggerFederatedVerification(String recordHash, String userId) async {
    // In a real implementation, this would send requests to federated systems
    // For this demo, we rely on the simulated stream
    print('Triggered federated verification for record hash: $recordHash, userId: $userId');
  }

  /// Stream real-time audit trail for a record
  Stream<List<Map<String, dynamic>>> streamRecordAuditTrail(String recordId, String? blockchainId) {
    // In a real implementation, this would connect to a blockchain node or Firestore
    // to get real-time updates on record access
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    // Set up a timer that simulates new activity
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (timer.tick > 30) {
        timer.cancel();
        controller.close();
        return;
      }
      
      // Generate a random new audit entry on each tick
      final accessTypes = ['View', 'Edit', 'Download', 'Share'];
      final devices = ['Mobile App', 'Desktop Browser', 'Tablet Device', 'API Access'];
      final locations = ['City Hospital', 'Remote Access', 'Medical Center', 'Pharmacy Network'];
      final actors = [
        'Dr. Sarah Johnson',
        'Medical Assistant Thomas',
        'Nurse Practitioner Kelly',
        'Pharmacy Tech Robert',
        'Lab Technician Maria'
      ];
      
      final now = DateTime.now();
      final random = now.millisecondsSinceEpoch;
      
      // Create a new audit entry
      final newEntry = {
        'id': 'audit_${now.millisecondsSinceEpoch}',
        'accessType': accessTypes[random % accessTypes.length],
        'accessedBy': actors[random % actors.length],
        'timestamp': now.toIso8601String(),
        'location': locations[random % locations.length],
        'device': devices[random % devices.length],
      };
      
      controller.add([newEntry]);
    });
    
    // Also add streaming support for Firestore audits
    final firebaseAuditRef = FirebaseFirestore.instance
        .collection('records')
        .doc(recordId)
        .collection('audit_trail');
        
    firebaseAuditRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final List<Map<String, dynamic>> firebaseEntries = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Format the timestamp properly
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = data['timestamp'].toDate().toIso8601String();
        }
        
        firebaseEntries.add({
          'id': doc.id,
          ...data,
        });
      }
      
      if (!controller.isClosed) {
        controller.add(firebaseEntries);
      }
    });
    
    return controller.stream;
  }
}