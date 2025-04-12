import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/ui/widgets/tag_input.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

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
  bool _isPrivate = true;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
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

        final userId = authProvider.currentUser?.id;
        if (userId == null) {
          throw Exception("No authenticated user found");
        }

        final fileUrls = await _uploadFilesToStorage(userId);

        final now = DateTime.now();
        final id = now.millisecondsSinceEpoch.toString();

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
            _errorMessage = "Failed to add record"; // Replace with actual error message
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Record'),
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
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Medical'),
                      value: 'medical',
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Legal'),
                      value: 'legal',
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TagInput(
                tags: _tags,
                onTagsChanged: (tags) {
                  setState(() {
                    _tags = tags;
                  });
                },
              ),
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
              SwitchListTile(
                title: const Text('Private Record'),
                subtitle: const Text('Only you can access this record'),
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
