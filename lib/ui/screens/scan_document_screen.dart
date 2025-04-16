import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:happ/core/services/document_service.dart';
import 'package:happ/core/providers/auth_provider.dart' as MyAuth;
import 'package:happ/core/providers/records_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class DocumentModel {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DocumentModel(
      id: docId,
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }
}

class ScanDocumentScreen extends StatefulWidget {
  const ScanDocumentScreen({super.key});

  @override
  State<ScanDocumentScreen> createState() => _ScanDocumentScreenState();
}

class _ScanDocumentScreenState extends State<ScanDocumentScreen> {
  bool _isScanning = false;
  bool _documentScanned = false;
  String? _scannedText;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  File? _imageFile;
  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isCameraPermissionGranted = status == PermissionStatus.granted;
    });

    if (_isCameraPermissionGranted) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _scanDocument() async {
    if (!_isCameraInitialized) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // Take picture
      final XFile imageFile = await _cameraController!.takePicture();
      final File file = File(imageFile.path);
      setState(() {
        _imageFile = file;
      });

      // Process image with OCR
      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      // Extract text
      final extractedText = recognizedText.text;

      setState(() {
        _isScanning = false;
        _documentScanned = true;
        _scannedText = extractedText;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning document: $e')));
    }
  }

  
  // Future<void> _enhanceOCR() async {
  //   if (_imageFile == null ) return;
  //   setState(() {
  //     _isLoading = true;

  //   });
  //   if(_documentScanned!=_textRecognizer){
  //     final text_reg = _textRecognizer.script(_widget)
  //   }
  // }

  Future<void> _saveDocument() async {
    if (_scannedText == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Get auth provider
      final authProvider = Provider.of<MyAuth.AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get records provider to refresh later
      final recordsProvider = Provider.of<RecordsProvider>(context, listen: false);

      final documentService = DocumentService();
      print("Saving document for user ID: ${authProvider.currentUser!.id}");
      final record = await documentService.saveScannedDocument(
        userId: authProvider.currentUser!.id,
        title: 'Scanned Document - ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        content: _scannedText!,
        category: 'medical',
        imageFile: _imageFile,
        tags: ['scanned', 'document'],
        isPrivate: true, // Always make scanned documents private
        createdBy: authProvider.currentUser!.id, // Explicitly set creator
      );

      // Debug checks
      print("Record returned from DocumentService: ${record?.id}");

      // Only try to save image if record was created successfully
      if (_imageFile != null && record != null) {
        print("About to save scanned document to record: ${record.id}");
        await saveScannedDocument(_imageFile!, record.id);
        
        // Reset records provider to force reload on next access
        recordsProvider.resetInitializedState();
      } else {
        throw Exception('Failed to create record: record=${record != null}');
      }

      setState(() {
        _isLoading = false;
      });

      // Show success and navigate back
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error in _saveDocument: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving document: $e')),
      );
    }
  }

  Future<void> saveScannedDocument(File file, String recordId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Generate unique file name
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/records/$recordId/documents/$fileName');
          
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update the record with this file URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records')
          .doc(recordId)
          .update({
            'fileUrls': FieldValue.arrayUnion([downloadUrl]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Also save to documents subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records')
          .doc(recordId)
          .collection('documents')
          .add({
            'name': fileName,
            'url': downloadUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'image',
            'contentType': 'image/jpeg',
          });
          
    } catch (e) {
      print('Error saving scanned document: $e');
      rethrow;
    }
  }

  Future<List<DocumentModel>> getDocumentsForRecord(String recordId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    try {
      final docsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records')
          .doc(recordId)
          .collection('documents')
          .orderBy('createdAt', descending: true)
          .get();
          
      return docsSnapshot.docs.map((doc) => DocumentModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error fetching documents: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
        actions: [
          if (_documentScanned && !_isLoading)
            TextButton(
              onPressed: _saveDocument,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isCameraPermissionGranted) {
      return _buildPermissionRequest();
    }

    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_documentScanned) {
      return _buildScannedDocument();
    }

    return _buildCameraPreview();
  }

  Widget _buildPermissionRequest() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Camera permission is required to scan documents',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestCameraPermission,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _isScanning
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
              onPressed: _scanDocument,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Capture Document'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildScannedDocument() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Scanner',
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          if (_imageFile != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _scannedText ?? 'No text recognized',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _documentScanned = false;
                      _scannedText = null;
                      _imageFile = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Again'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveDocument,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Save',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
