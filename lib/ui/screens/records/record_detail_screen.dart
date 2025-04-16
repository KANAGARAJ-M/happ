import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/core/services/notification_service.dart';
import 'package:happ/ui/screens/RecordVerificationScreen.dart';
import 'package:happ/ui/screens/documents/document_viewer_screen.dart';
import 'package:happ/ui/screens/records/edit_record_screen.dart';
import 'package:provider/provider.dart';
import 'package:happ/ui/widgets/medical_term_simplifier.dart';

class RecordDetailScreen extends StatefulWidget {
  final Record record;

  const RecordDetailScreen({super.key, required this.record});

  @override
  _RecordDetailScreenState createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  @override
  void initState() {
    super.initState();
    
    // Log access to the record
    _logRecordAccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified),
            tooltip: 'Verify Record Integrity',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordVerificationScreen(record: widget.record),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              NavigationService.navigateTo(EditRecordScreen(record: widget.record));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.record.category == 'medical'
                              ? Icons.medical_services
                              : Icons.gavel,
                          color:
                              widget.record.category == 'medical'
                                  ? Colors.blue
                                  : Colors.amber,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.record.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow('Category', widget.record.categoryName),
                    _buildInfoRow('Date', widget.record.formattedDate),
                    _buildInfoRow(
                      'Privacy',
                      widget.record.isPrivate ? 'Private' : 'Shared',
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            color: Colors.grey[100],
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: MedicalTermSimplifier(
                                medicalText: widget.record.description,
                                textStyle: const TextStyle(fontSize: 16, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.record.tags.isNotEmpty) ...[
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    widget.record.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Update file display section
            if (widget.record.fileUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Documents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.record.fileUrls.length,
                itemBuilder: (context, index) {
                  final file = widget.record.fileUrls[index];
                  final fileExtension = _getFileExtension(file);
                  final fileIcon = _getFileIcon(fileExtension);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      leading: Icon(fileIcon, color: Theme.of(context).primaryColor),
                      title: Text('Document ${index + 1}'),
                      subtitle: Text(_getDocumentTypeName(fileExtension)),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _openDocument(context, file, fileExtension),
                      ),
                    ),
                  );
                },
              ),
            ],

            // Add this information to the details displayed:
            if (widget.record.createdBy != null && 
                widget.record.createdBy != widget.record.userId) ...[
              Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Healthcare Provider Record',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'This record was added to your profile by a healthcare provider.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Record'),
            content: const Text(
              'Are you sure you want to delete this record? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final recordsProvider = Provider.of<RecordsProvider>(
        context,
        listen: false,
      );
      
      // Using the removeRecord method instead of deleteRecord
      final success = await recordsProvider.removeRecord(widget.record.id);

      if (success) {
        NavigationService.navigatorKey.currentState?.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting record')),
        );
      }
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
  
  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  String _getDocumentTypeName(String extension) {
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      default:
        return 'Document';
    }
  }
  
  void _openDocument(BuildContext context, String url, String extension) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening document...')),
      );
      
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        // Navigate to image viewer for images
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentViewerScreen(url: url, isImage: true),
          ),
        );
      } else {
        // Navigate to PDF/document viewer for other file types
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentViewerScreen(url: url, isImage: false),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
    }
  }

  Future<void> _logRecordAccess() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null || widget.record.userId == currentUser.id) {
        // Don't log if viewing own records
        return;
      }
      
      final recordOwner = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.record.userId)
          .get();
          
      if (!recordOwner.exists) return;
      
      // Log access in audit trail
      final accessEntry = {
        'accessedBy': currentUser.name,
        'accessorId': currentUser.id,
        'accessorRole': currentUser.role,
        'timestamp': FieldValue.serverTimestamp(),
        'accessType': 'view',
        'location': 'In-App',
        'device': 'Mobile App',
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.record.userId)
          .collection('records')
          .doc(widget.record.id)
          .collection('audit_trail')
          .add(accessEntry);
      
      // Notify the record owner if they're not the current user
      if (currentUser.id != widget.record.userId) {
        final notificationService = NotificationService();
        await notificationService.sendRecordAccessNotification(
          userId: widget.record.userId,
          record: widget.record,
          accessedBy: currentUser.name,
          accessType: 'viewed',
        );
      }
    } catch (e) {
      print('Error logging record access: $e');
    }
  }
}
