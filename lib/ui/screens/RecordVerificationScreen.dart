import 'package:flutter/material.dart';
import 'package:happ/core/services/medical_nlp_service.dart';
import 'package:web3dart/web3dart.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/services/blockchain_service.dart';
import 'package:happ/ui/widgets/record_proof_share_sheet.dart';
import 'package:happ/ui/screens/records/record_audit_trail_screen.dart';
import 'package:happ/ui/screens/records/medical_insights_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class RecordVerificationScreen extends StatefulWidget {
  final Record record;
  
  const RecordVerificationScreen({super.key, required this.record});
  
  @override
  State<RecordVerificationScreen> createState() => _RecordVerificationScreenState();
}

class _RecordVerificationScreenState extends State<RecordVerificationScreen> {
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _verificationError;
  String? _blockchainId;
  final List<FederatedVerification> _federatedVerifications = [];
  Timer? _refreshTimer;
  StreamSubscription? _recordStreamSubscription;
  StreamSubscription? _federatedUpdatesSubscription;
  final int _refreshIntervalSeconds = 30;
  int _remainingSeconds = 30;
  Timer? _countdownTimer;
  
  // Verification step tracking
  int _currentStep = 0;
  final List<String> _verificationSteps = [
    'Computing record hash',
    'Verifying on blockchain',
    'Checking federated sources',
    'Processing medical insights'
  ];
  final List<bool> _stepCompleted = [false, false, false, false];
  final List<String?> _stepResults = [null, null, null, null];
  
  @override
  void initState() {
    super.initState();
    _setupRealTimeListeners();
    _verifyRecord();
    
    // Set up periodic refresh for background verification
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds), 
      (_) => _verifyRecord()
    );
    
    // Set up countdown timer for UI
    _startCountdownTimer();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _recordStreamSubscription?.cancel();
    _federatedUpdatesSubscription?.cancel();
    super.dispose();
  }
  
  void _setupRealTimeListeners() {
    // Listen for real-time updates to the record document
    _recordStreamSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.record.userId)
        .collection('records')
        .doc(widget.record.id)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      
      // Check if record has been verified since last check
      final data = snapshot.data();
      if (data != null && data['verified'] == true && !_isVerified) {
        if (mounted) {
          setState(() {
            _isVerified = true;
            _blockchainId = data['blockchainId'] ?? _blockchainId;
          });
          
          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Record verified successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
    
    // Set up federation listener
    _setupFederationListener();
  }
  
  void _setupFederationListener() {
    // This would be connected to a real WebSocket or Firebase Realtime DB
    // in a production environment
    final blockchainService = BlockchainService();
    
    // Create a stream controller to simulate real-time federation updates
    _federatedUpdatesSubscription = blockchainService
        .streamFederatedVerifications(widget.record.id)
        .listen((verifications) {
      if (mounted) {
        setState(() {
          // Merge new verifications with existing ones
          for (var newVerification in verifications) {
            final index = _federatedVerifications.indexWhere(
                (v) => v.institutionId == newVerification.institutionId);
                
            if (index >= 0) {
              _federatedVerifications[index] = newVerification;
            } else {
              _federatedVerifications.add(newVerification);
            }
          }
          
          // Update step status
          if (_currentStep >= 2) {
            _stepCompleted[2] = true;
            _stepResults[2] = '${verifications.length} sources checked';
          }
        });
      }
    });
  }
  
  void _startCountdownTimer() {
    _remainingSeconds = _refreshIntervalSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _remainingSeconds = _refreshIntervalSeconds;
          }
        });
      }
    });
  }
  
  Future<void> _verifyRecord() async {
    if (_isVerifying) return;
    
    setState(() {
      _isVerifying = true;
      _verificationError = null;
      _currentStep = 0;
      _stepCompleted.fillRange(0, _stepCompleted.length, false);
      _stepResults.fillRange(0, _stepResults.length, null);
    });
    
    try {
      final blockchainService = BlockchainService();
      
      // Step 1: Get record hash ID from blockchain
      setState(() => _currentStep = 0);
      final recordHash = await blockchainService.getRecordHash(widget.record);
      setState(() {
        _stepCompleted[0] = true;
        _stepResults[0] = 'Hash: ${recordHash.substring(0, 8)}...';
        _currentStep = 1;
      });
      
      // Step 2: Check if hash exists on blockchain
      final verificationResult = await blockchainService.verifyRecordIntegrity(
        widget.record,
        recordHash
      );
      setState(() {
        _stepCompleted[1] = true;
        _stepResults[1] = verificationResult.verified 
            ? 'Verified on blockchain'
            : 'Not verified: ${verificationResult.error ?? "Unknown error"}';
        _currentStep = 2;
      });
      
      // Step 3: Check federated sources for record verification (now streaming)
      blockchainService.triggerFederatedVerification(recordHash, widget.record.userId);
      
      // Step 4: If verified, update patient medical profile
      if (verificationResult.verified) {
        setState(() => _currentStep = 3);
        final medicalNlpService = MedicalNlpService();
        await medicalNlpService.updatePatientMedicalProfileFromRecord(widget.record);
        setState(() {
          _stepCompleted[3] = true;
          _stepResults[3] = 'Medical insights processed';
        });
        
        // Write verification to Firestore for real-time updates across devices
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.record.userId)
            .collection('records')
            .doc(widget.record.id)
            .update({
              'verified': true,
              'blockchainId': verificationResult.blockchainId,
              'verifiedAt': FieldValue.serverTimestamp(),
            });
      }
      
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isVerified = verificationResult.verified;
          _blockchainId = verificationResult.blockchainId;
          _verificationError = verificationResult.error;
        });
      }
      
      // Reset countdown timer after successful refresh
      _startCountdownTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verificationError = 'Verification error: $e';
          
          // Mark current step as failed
          if (_currentStep < _stepCompleted.length) {
            _stepResults[_currentStep] = 'Failed: $e';
          }
        });
      }
    }
  }
  
  Future<void> _shareVerificationProof() async {
    // Generate zero-knowledge proof of record validity
    // without exposing actual record content
    final proofData = await BlockchainService().generateZkProof(
      widget.record,
      _blockchainId!
    );
    
    if (!mounted) return;
    
    // Show QR code or sharing options for the proof
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RecordProofShareSheet(proofData: proofData),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh verification status',
            onPressed: _isVerifying ? null : _verifyRecord,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auto-refresh indicator
              if (!_isVerifying) 
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    label: 'Auto-refreshes in $_remainingSeconds seconds',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Refreshes in $_remainingSeconds s',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Real-time verification steps
              if (_isVerifying) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real-time Verification in Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(_verificationSteps.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                if (_currentStep == index && !_stepCompleted[index])
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else if (_stepCompleted[index])
                                  const Icon(Icons.check_circle, color: Colors.green)
                                else
                                  const Icon(Icons.circle_outlined, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_verificationSteps[index]),
                                      if (_stepResults[index] != null)
                                        Text(
                                          _stepResults[index]!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
                
              // Verification status card
              Semantics(
                label: _isVerified 
                  ? 'Record verified on blockchain'
                  : 'Record verification issue',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isVerified ? Icons.verified : Icons.warning,
                              size: 48,
                              color: _isVerified ? Colors.green : Colors.orange,
                              semanticLabel: _isVerified ? 'Verified' : 'Warning',
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVerified
                                        ? 'Record Verified'
                                        : 'Verification Issue',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Text(
                                    _isVerified
                                        ? 'This record has been cryptographically verified'
                                        : _verificationError ?? 'Could not verify record integrity',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_isVerified) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Semantics(
                                label: 'Blockchain ID',
                                child: Text('Blockchain ID: ${_blockchainId!.substring(0, 10)}...'),
                              ),
                              TextButton(
                                onPressed: () => _shareVerificationProof(),
                                child: const Text('Share Proof'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Federated verifications - now updates in real-time
              Semantics(
                label: 'Federated Verifications',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Federated Verifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_federatedVerifications.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          'Live',
                          style: TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_federatedVerifications.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No federated verifications yet - checking sources...'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _federatedVerifications.length,
                  itemBuilder: (context, index) {
                    final verification = _federatedVerifications[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: Icon(
                          Icons.verified_user,
                          color: verification.verified ? Colors.green : Colors.grey,
                          semanticLabel: verification.verified ? 'Verified' : 'Not Verified',
                        ),
                        title: Text(verification.institutionName),
                        subtitle: Text(
                          verification.verified
                              ? 'Verified on ${verification.verificationDate}'
                              : 'Not verified by this institution',
                        ),
                        trailing: verification.verified
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 24),
              
              // Audit trail
              // Semantics(
              //   label: 'Record Access Audit Trail',
              //   child: Text(
              //     'Record Access Audit Trail',
              //     style: Theme.of(context).textTheme.titleMedium,
              //   ),
              // ),
              // const SizedBox(height: 8),
              // ElevatedButton(
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => RecordAuditTrailScreen(
              //           recordId: widget.record.id,
              //           blockchainId: _blockchainId,
              //         ),
              //       ),
              //     );
              //   },
              //   style: ElevatedButton.styleFrom(
              //     minimumSize: const Size.fromHeight(50),
              //   ),
              //   child: const Text('View Audit Trail'),
              // ),
              const SizedBox(height: 24),
              
              // Medical Insights
              Semantics(
                label: 'Medical Insights from Document Analysis',
                child: Text(
                  'Medical Insights',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicalInsightsScreen(
                        record: widget.record,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blueAccent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.medical_information),
                    SizedBox(width: 8),
                    Text('Analyze Medical Content With AI'),
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