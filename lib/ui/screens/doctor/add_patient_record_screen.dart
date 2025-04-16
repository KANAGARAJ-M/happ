import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/providers/auth_provider.dart'; // Keep only one import
import 'package:happ/ui/widgets/tag_input.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

// Remove the duplicate import below
// import 'package:happ/core/providers/auth_provider.dart';

class AddPatientRecordScreen extends StatefulWidget {
  final User patient;

  const AddPatientRecordScreen({super.key, required this.patient});

  @override
  State<AddPatientRecordScreen> createState() => _AddPatientRecordScreenState();
}

class _AddPatientRecordScreenState extends State<AddPatientRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final String _selectedCategory = 'doctor';
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextAppointmentDate;
  List<String> _tags = ['doctor']; // Default tag for doctor-created records
  final List<String> _fileUrls = [];
  final bool _isPrivate = true; // Always private by default
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectNextAppointmentDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextAppointmentDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      // Also show time picker
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (pickedTime != null) {
        setState(() {
          _nextAppointmentDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = path.basename(file.path);

        setState(() {
          _isUploading = true;
          _uploadProgress = 0;
        });

        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final storagePath = 'records/${widget.patient.id}/${timestamp}_$fileName';
        final ref = _storage.ref().child(storagePath);

        final uploadTask = ref.putFile(file);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        await uploadTask;
        final downloadUrl = await ref.getDownloadURL();

        setState(() {
          _fileUrls.add(downloadUrl);
          _isUploading = false;
        });

        // Make sure doctor tag is added when a file is uploaded
        if (!_tags.contains('doctor')) {
          setState(() {
            _tags.add('doctor');
          });
        }
      }
    } catch (e) {
      print('Error uploading file: $e');
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _fileUrls.removeAt(index);
    });
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Ensure doctor tag is present
    if (!_tags.contains('doctor')) {
      setState(() {
        _tags.add('doctor');
      });
    }

    setState(() => _isLoading = true);

    try {
      final recordsProvider = Provider.of<RecordsProvider>(
        context, 
        listen: false,
      );

      // Prepare the record
      String description = _descriptionController.text.trim();
      
      // Add next appointment info if set
      if (_nextAppointmentDate != null) {
        final appointmentInfo = "\n\nNext Appointment: ${DateFormat('MMM d, yyyy').format(_nextAppointmentDate!)} at ${DateFormat('h:mm a').format(_nextAppointmentDate!)}";
        description += appointmentInfo;
      }

      final record = Record(
        id: '', // Will be set by Firestore
        userId: widget.patient.id,
        title: _titleController.text.trim(),
        description: description,
        category: _selectedCategory,
        date: _selectedDate,
        tags: _tags,
        fileUrls: _fileUrls,
        isPrivate: _isPrivate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: Provider.of<AuthProvider>(context, listen: false).currentUser!.id,
      );

      final newRecord = await recordsProvider.addRecord(record);

      if (newRecord != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record added successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add record')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Record for ${widget.patient.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Record date picker
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Record Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Next appointment date picker
                  InkWell(
                    onTap: () => _selectNextAppointmentDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Next Appointment (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _nextAppointmentDate == null
                            ? 'Set next appointment'
                            : '${DateFormat('MMM d, yyyy').format(_nextAppointmentDate!)} at ${DateFormat('h:mm a').format(_nextAppointmentDate!)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Find the TagInput widget and update it
                  TagInput(
                    tags: _tags,
                    requiredTags: ['doctor'], // Make 'doctor' tag required
                    suggestedTags: ['medication', 'appointment', 'treatment', 'diagnosis', 'follow-up'],
                    onTagsChanged: (tags) {
                      setState(() {
                        _tags = tags;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload File'),
                        ),
                      ),
                    ],
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Display uploaded files
                  if (_fileUrls.isNotEmpty) ...[
                    const Text('Uploaded Files:'),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _fileUrls.length,
                      (index) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(
                          'File ${index + 1}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeFile(index),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'All records are private and only visible to you and the patient.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading || _isUploading ? null : _saveRecord,
                    child: const Text('Save Record'),
                  ),
                ],
              ),
            ),
    );
  }
}