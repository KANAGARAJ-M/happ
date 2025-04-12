import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final bool isImage;

  const DocumentViewerScreen({
    Key? key,
    required this.url,
    required this.isImage,
  }) : super(key: key);

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  String? _localFilePath;
  String? _errorMessage;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _pdfLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    try {
      final http.Response response = await http.get(Uri.parse(widget.url));
      
      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to download file: Status ${response.statusCode}';
        });
        return;
      }

      // Get temp directory for storing file
      final dir = await getTemporaryDirectory();
      
      // Create a unique filename based on timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      String filename;
      if (widget.isImage) {
        filename = 'image_$timestamp.${widget.url.split('.').last}';
      } else {
        filename = 'document_$timestamp.pdf';
      }
      
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      
      setState(() {
        _localFilePath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error processing file: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Viewer'),
        actions: [
          if (!widget.isImage && _localFilePath != null && !_pdfLoadFailed)
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () {
                try {
                  _pdfViewerController.zoomLevel = 
                      (_pdfViewerController.zoomLevel + 0.25).clamp(0.75, 3.0);
                } catch (e) {
                  // Ignore zoom errors
                }
              },
            ),
          if (!widget.isImage && _localFilePath != null && !_pdfLoadFailed)
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: () {
                try {
                  _pdfViewerController.zoomLevel = 
                      (_pdfViewerController.zoomLevel - 0.25).clamp(0.75, 3.0);
                } catch (e) {
                  // Ignore zoom errors
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document...'),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return _buildErrorView();
    }
    
    if (_localFilePath == null) {
      return const Center(
        child: Text('Error: File could not be downloaded'),
      );
    }
    
    if (widget.isImage) {
      return _buildImageViewer();
    } else {
      return _buildPdfViewerWithFallback();
    }
  }

  Widget _buildPdfViewerWithFallback() {
    try {
      return SfPdfViewer.file(
        File(_localFilePath!),
        controller: _pdfViewerController,
        enableTextSelection: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        pageSpacing: 4,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          setState(() {
            _pdfLoadFailed = true;
            _errorMessage = 'Failed to load PDF: ${details.error}';
          });
        },
      );
    } catch (e) {
      // If the SfPdfViewer fails, fall back to a simple PDF viewer indicator
      return _buildSimplePdfViewer();
    }
  }

  Widget _buildSimplePdfViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            'PDF Document',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const Text(
            'The document has been downloaded and is ready.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reload PDF'),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _pdfLoadFailed = false;
              });
              _downloadFile();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                  _pdfLoadFailed = false;
                });
                _downloadFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: FileImage(File(_localFilePath!)),
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
    );
  }
}