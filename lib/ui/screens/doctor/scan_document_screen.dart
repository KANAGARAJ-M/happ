import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/services/permission_service.dart';
import 'package:happ/ui/screens/records/add_record_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanDocumentScreen extends StatefulWidget {
  final User patient;
  
  const ScanDocumentScreen({
    super.key,
    required this.patient,
  });

  @override
  State<ScanDocumentScreen> createState() => _ScanDocumentScreenState();
}

class _ScanDocumentScreenState extends State<ScanDocumentScreen> {
  late List<CameraDescription> cameras;
  CameraController? controller;
  XFile? imageFile;
  bool isReady = false;
  bool isCapturing = false;
  
  @override
  void initState() {
    super.initState();
    _initCamera();
  }
  
  Future<void> _initCamera() async {
    final permissionStatus = await PermissionService.requestPermission(
      Permission.camera,
    );
    
    if (permissionStatus != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to scan documents')),
        );
      }
      return;
    }
    
    try {
      cameras = await availableCameras();
      controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await controller!.initialize();
      
      if (mounted) {
        setState(() {
          isReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
  
  Future<void> _takePicture() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    
    setState(() {
      isCapturing = true;
    });
    
    try {
      final XFile file = await controller!.takePicture();
      
      setState(() {
        imageFile = file;
        isCapturing = false;
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
      setState(() {
        isCapturing = false;
      });
    }
  }
  
  void _proceedWithImage() {
    if (imageFile == null) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecordScreen(
          patient: widget.patient,
          // Pre-loaded file
          initialFile: File(imageFile!.path),
        ),
      ),
    );
  }
  
  void _retakeImage() {
    setState(() {
      imageFile = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
      ),
      body: !isReady
          ? const Center(child: CircularProgressIndicator())
          : imageFile == null
              ? _buildCameraPreview()
              : _buildImagePreview(),
    );
  }
  
  Widget _buildCameraPreview() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(controller!),
              // Overlay for document alignment
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 1.1,
                child: const Center(
                  child: Text(
                    'Align document within frame',
                    style: TextStyle(color: Colors.white, shadows: [
                      Shadow(blurRadius: 2, color: Colors.black),
                    ]),
                  ),
                ),
              ),
              if (isCapturing)
                const CircularProgressIndicator(),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: isCapturing ? null : _takePicture,
            icon: const Icon(Icons.camera),
            label: const Text('Capture Document'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Image.file(
              File(imageFile!.path),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _retakeImage,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _proceedWithImage,
                icon: const Icon(Icons.check),
                label: const Text('Use Image'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}