import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/models/user.dart'; // Add this import
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/ui/widgets/tag_input.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class AddRecordScreen extends StatefulWidget {
  final User? patient;
  final File? initialFile; // Add this parameter

  const AddRecordScreen({super.key, this.patient, this.initialFile});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'medical';
  DateTime _selectedDate = DateTime.now();
  List<String> _tags = [];
  final List<Map<String, dynamic>> _files = [];
  final bool _isPrivate = true; // Always private, no option to change
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late User? _currentUser;

  @override
  void initState() {
    super.initState();
    // If this screen is opened for a patient by a doctor
    if (widget.patient != null) {
      _selectedCategory = 'doctor'; // Set default category to 'doctor'
      _tags = ['doctor']; // Add the doctor tag by default
    }

    // Get current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUser = authProvider.currentUser;

    // Process initial file if provided
    if (widget.initialFile != null) {
      _processInitialFile();
    }
  }

  void _processInitialFile() {
    final fileName = path.basename(widget.initialFile!.path);
    setState(() {
      _files.add({
        'file': widget.initialFile!,
        'name': fileName,
        'size': _getFileSize(widget.initialFile!),
        'type': _getFileType(fileName),
        'isUploaded': false,
      });

      // Set a default title based on file type
      if (_titleController.text.isEmpty) {
        _titleController.text =
            'Scanned Document (${DateFormat('MM/dd/yyyy').format(DateTime.now())})';
      }
    });
  }

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
          _files.add({
            'file': file,
            'name': fileName,
            'size': _getFileSize(file),
            'type': _getFileType(fileName),
            'isUploaded': false,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File added successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
    }
  }

  String _getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png'].contains(extension)) return 'image';
    if (extension == '.pdf') return 'pdf';
    if (['.doc', '.docx'].contains(extension)) return 'doc';
    return 'file';
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String type) {
    switch (type) {
      case 'image':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      case 'doc':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<List<String>> _uploadFilesToStorage(String userId) async {
    if (_files.isEmpty) return [];

    List<String> fileUrls = [];

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      int filesUploaded = 0;

      for (var fileData in _files) {
        final file = fileData['file'] as File;
        final fileName = path.basename(file.path);

        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final storagePath = 'records/$userId/$timestamp-$fileName';

        final uploadTask = _storage.ref(storagePath).putFile(file);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final totalProgress =
              (filesUploaded +
                  (snapshot.bytesTransferred / snapshot.totalBytes)) /
              _files.length;
          setState(() {
            _uploadProgress = totalProgress;
          });
        });

        await uploadTask.whenComplete(() {});

        final url = await uploadTask.snapshot.ref.getDownloadURL();
        fileUrls.add(url);

        filesUploaded++;
      }

      return fileUrls;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final recordsProvider = Provider.of<RecordsProvider>(
          context,
          listen: false,
        );

        // If opened by a doctor for a patient
        final String userId =
            widget.patient?.id ?? authProvider.currentUser!.id;
        if (userId.isEmpty) {
          throw Exception("No user found");
        }

        final fileUrls = await _uploadFilesToStorage(userId);

        final now = DateTime.now();
        final id = now.millisecondsSinceEpoch.toString();

        // If this is a doctor adding for a patient, ensure doctor tag
        if (widget.patient != null && !_tags.contains('doctor')) {
          _tags.add('doctor');
        }

        final newRecord = Record(
          id: id,
          userId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          date: _selectedDate,
          tags: _tags,
          fileUrls: fileUrls,
          isPrivate: _isPrivate,
          createdAt: now,
          updatedAt: now,
          createdBy: authProvider.currentUser!.id, // Add this line
        );

        final success = await recordsProvider.addRecord(newRecord);

        if (!mounted) return;

        if (success != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record added successfully')),
          );
        } else {
          setState(() {
            _errorMessage = "Failed to add record";
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom title based on context
    final String screenTitle =
        widget.patient != null
            ? 'Add Record for ${widget.patient!.name}'
            : 'Add Record';

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        actions: [
          TextButton(
            onPressed: (_isLoading || _isUploading) ? null : _saveRecord,
            child:
                _isLoading || _isUploading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message container
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Patient information if doctor is adding a record
              if (widget.patient != null) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(widget.patient!.name.substring(0, 1)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patient!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(widget.patient!.email),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Title field
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

              // Category selection - only show doctor/patient if it's a doctor adding
              if (_currentUser?.role == 'doctor') ...[
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Doctor'),
                        value: 'doctor',
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                            // Ensure doctor tag is added when selecting doctor category
                            if (!_tags.contains('doctor')) {
                              _tags.add('doctor');
                            }
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Patient'),
                        value: 'patient',
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                            // Remove doctor tag if not a doctor category
                            _tags.removeWhere((tag) => tag == 'doctor');
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ] else if (_currentUser?.role == 'patient') ...[
                // For patients, just show patient category as selected and disabled
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Category: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Patient',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ),
              ],

              // Rest of your form fields
              const SizedBox(height: 16),
              // Date selector
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
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
              // Tags input
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TagInput(
                tags: _tags,
                // If doctor is adding for patient, 'doctor' tag should be required
                requiredTags: widget.patient != null ? ['doctor'] : null,
                onTagsChanged: (tags) {
                  setState(() {
                    _tags = tags;
                  });
                },
              ),

              // Rest of your existing document upload and other fields...
              const SizedBox(height: 16),
              Text('Documents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_isUploading) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text('Uploading: ${(_uploadProgress * 100).toInt()}%'),
                const SizedBox(height: 16),
              ],
              _files.isEmpty
                  ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No documents attached')),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final fileData = _files[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: Icon(
                            _getFileIcon(fileData['type']),
                            color: _getFileIconColor(fileData['type']),
                          ),
                          title: Text(
                            fileData['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(fileData['size']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _files.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_isLoading || _isUploading) ? null : _uploadFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach Document'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'All records are private and only visible to you and your healthcare providers.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: (_isLoading || _isUploading) ? null : _saveRecord,
                icon:
                    _isLoading || _isUploading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(
                  _isLoading || _isUploading ? 'Saving...' : 'Save Record',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
