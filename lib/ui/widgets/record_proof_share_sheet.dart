import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:happ/core/services/blockchain_service.dart';

class RecordProofShareSheet extends StatefulWidget {
  final RecordProof proofData;
  
  const RecordProofShareSheet({super.key, required this.proofData});

  @override
  State<RecordProofShareSheet> createState() => _RecordProofShareSheetState();
}

class _RecordProofShareSheetState extends State<RecordProofShareSheet> {
  bool _showDetails = false;
  
  // Encode proof data to JSON for sharing
  String get _proofJson => jsonEncode(widget.proofData.toJson());
  
  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _proofJson));
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification proof copied to clipboard')),
    );
  }
  
  Future<void> _shareProof() async {
    try {
      final result = await Share.share(
        'Medical Record Verification Proof:\n\n$_proofJson',
        subject: 'Medical Record Verification Proof',
      );
      print('Share result: $result');
    } catch (e) {
      print('Error sharing: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Verification Proof',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This QR code contains a zero-knowledge proof that verifies this medical record\'s authenticity without revealing its contents.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: QrImageView(
              data: _proofJson,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              semanticsLabel: 'Medical Record Verification QR Code',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
                onPressed: _copyToClipboard,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                onPressed: _shareProof,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showDetails = !_showDetails;
              });
            },
            child: Text(_showDetails ? 'Hide Details' : 'Show Details'),
          ),
          if (_showDetails)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Record ID', widget.proofData.recordId),
                  _buildDetailRow('Blockchain ID', widget.proofData.blockchainId),
                  _buildDetailRow('Timestamp', widget.proofData.timestamp),
                  if (widget.proofData.proofData['recordType'] != null)
                    _buildDetailRow('Record Type', widget.proofData.proofData['recordType'].toString()),
                  if (widget.proofData.proofData['recordDate'] != null)
                    _buildDetailRow('Record Date', widget.proofData.proofData['recordDate'].toString()),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}