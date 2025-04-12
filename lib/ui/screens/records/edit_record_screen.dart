import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/ui/widgets/tag_input.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class EditRecordScreen extends StatefulWidget {
  final Record record;

  const EditRecordScreen({super.key, required this.record});

  @override
  State<EditRecordScreen> createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  late List<String> _tags;
  late List<String> _fileUrls;
  late bool _isPrivate;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing record data
    _titleController = TextEditingController(text: widget.record.title);
    _descriptionController = TextEditingController(
      text: widget.record.description,
    );
    _selectedCategory = widget.record.category;
    _selectedDate = widget.record.date;
    _tags = List.from(widget.record.tags);
    _fileUrls = List.from(widget.record.fileUrls);
    _isPrivate = widget.record.isPrivate;
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
      // Use FilePicker to select files
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

        // Create a unique file path in Firebase Storage
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final storagePath =
            'records/${widget.record.userId}/${widget.record.id}/${timestamp}_$fileName';

        // Start upload task
        final uploadTask = _storage.ref(storagePath).putFile(file);

        // Listen for upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        // Wait for upload to complete
        await uploadTask.whenComplete(() {});

        // Get download URL
        final downloadUrl = await uploadTask.snapshot.ref.getDownloadURL();

        // Add the URL to the file list
        setState(() {
          _fileUrls.add(downloadUrl);
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  Future<void> _removeFile(int index) async {
    try {
      final fileUrl = _fileUrls[index];

      // If the URL starts with https, it's a Firebase Storage URL
      if (fileUrl.startsWith('https://')) {
        // Extract the file reference and delete it
        try {
          final ref = FirebaseStorage.instance.refFromURL(fileUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting file from storage: $e');
          // Continue even if deletion fails
        }
      }

      setState(() {
        _fileUrls.removeAt(index);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing file: $e')));
    }
  }

  Future<void> _updateRecord() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final recordsProvider = Provider.of<RecordsProvider>(
          context,
          listen: false,
        );

        final updatedRecord = Record(
          id: widget.record.id,
          userId: widget.record.userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          date: _selectedDate,
          tags: _tags,
          fileUrls: _fileUrls,
          isPrivate: _isPrivate,
          createdAt: widget.record.createdAt,
          updatedAt: DateTime.now(),
        );

        final success = await recordsProvider.updateRecord(updatedRecord);

        if (success && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record updated successfully')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update record')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Record'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateRecord,
            child:
                _isLoading
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
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'patient', child: Text('Patient')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                      // Ensure appropriate tag based on category
                      if (value == 'doctor' && !_tags.contains('doctor')) {
                        _tags.add('doctor');
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TagInput(
                tags: _tags,
                requiredTags: _selectedCategory == 'doctor' ? ['doctor'] : null,
                suggestedTags: _selectedCategory == 'doctor' 
                    ? ['medication', 'appointment', 'treatment', 'diagnosis', 'follow-up']
                    : ['consultation', 'history', 'insurance', 'payment'],
                onTagsChanged: (tags) {
                  setState(() => _tags = tags);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Documents',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_fileUrls.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _fileUrls.length,
                  itemBuilder: (context, index) {
                    final file = _fileUrls[index];
                    final fileName =
                        file.contains('/')
                            ? file.split('/').last
                            : 'Document ${index + 1}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: _getFileIcon(file),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _getFileDescription(file),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeFile(index),
                        ),
                        onTap: () => _openFile(file),
                      ),
                    );
                  },
                ),

              // Show upload progress if uploading
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Uploading file...'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: _uploadProgress),
                      Text('${(_uploadProgress * 100).toInt()}%'),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Document'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Make Private'),
                subtitle: const Text('Private records are only visible to you'),
                value: _isPrivate,
                onChanged: (value) {
                  setState(() => _isPrivate = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getFileIcon(String fileUrl) {
    if (fileUrl.toLowerCase().endsWith('.pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (fileUrl.toLowerCase().endsWith('.doc') ||
        fileUrl.toLowerCase().endsWith('.docx')) {
      return const Icon(Icons.article, color: Colors.blue);
    } else if (fileUrl.toLowerCase().endsWith('.jpg') ||
        fileUrl.toLowerCase().endsWith('.jpeg') ||
        fileUrl.toLowerCase().endsWith('.png')) {
      return const Icon(Icons.image, color: Colors.green);
    } else {
      return const Icon(Icons.description);
    }
  }

  String _getFileDescription(String fileUrl) {
    if (fileUrl.startsWith('https://')) {
      return 'Uploaded document';
    } else {
      return fileUrl;
    }
  }

  void _openFile(String fileUrl) {
    // Implement file opening logic
    // You might use url_launcher for web URLs or a PDF viewer for PDF files
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening file...')));
  }
}
