import 'package:flutter/material.dart';
import 'package:happ/core/services/blockchain_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class RecordAuditTrailScreen extends StatefulWidget {
  final String recordId;
  final String? blockchainId;
  
  const RecordAuditTrailScreen({
    super.key,
    required this.recordId,
    this.blockchainId,
  });
  
  @override
  State<RecordAuditTrailScreen> createState() => _RecordAuditTrailScreenState();
}

class _RecordAuditTrailScreenState extends State<RecordAuditTrailScreen> {
  final BlockchainService _blockchainService = BlockchainService();
  StreamSubscription? _auditTrailSubscription;
  List<Map<String, dynamic>> _auditEntries = [];
  String? _errorMessage;
  bool _isLiveMode = true; // Default to live mode
  
  @override
  void initState() {
    super.initState();
    _startRealTimeUpdates();
  }
  
  @override
  void dispose() {
    _auditTrailSubscription?.cancel();
    super.dispose();
  }
  
  void _startRealTimeUpdates() {
    // Get the initial data
    _loadAuditTrail();
    
    // Set up real-time stream subscription
    _auditTrailSubscription?.cancel();
    _auditTrailSubscription = _blockchainService
        .streamRecordAuditTrail(widget.recordId, widget.blockchainId)
        .listen(
      (newEntries) {
        if (mounted) {
          setState(() {
            // Check for new entries that aren't in our current list
            for (var newEntry in newEntries) {
              final entryExists = _auditEntries.any((existing) => 
                existing['id'] == newEntry['id']);
                
              if (!entryExists) {
                // Insert at the beginning to show newest first
                _auditEntries.insert(0, newEntry);
                
                // Show a notification for new activity
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('New access by ${newEntry['accessedBy']} detected'),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: 'VIEW',
                          onPressed: () {
                            // Scroll to the new entry
                            // Implementation would depend on your scroll controller
                          },
                        ),
                      ),
                    );
                  }
                });
              }
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Stream error: $error';
          });
        }
      },
    );
  }
  
  Future<void> _loadAuditTrail() async {
    setState(() {
      _errorMessage = null;
    });
    
    try {
      final auditTrail = await _blockchainService.getRecordAuditTrail(
        widget.recordId,
        widget.blockchainId,
      );
      
      setState(() {
        _auditEntries = auditTrail;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading audit trail: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Record Audit Trail'),
            const SizedBox(width: 8),
            if (_isLiveMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // Toggle between live and static mode
          IconButton(
            icon: Icon(_isLiveMode ? Icons.pause_circle_outline : Icons.play_circle_outline),
            tooltip: _isLiveMode ? 'Pause live updates' : 'Resume live updates',
            onPressed: () {
              setState(() {
                _isLiveMode = !_isLiveMode;
                if (_isLiveMode) {
                  _startRealTimeUpdates();
                } else {
                  _auditTrailSubscription?.cancel();
                  _auditTrailSubscription = null;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh audit trail',
            onPressed: _loadAuditTrail,
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadAuditTrail,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Status bar showing real-time monitoring
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        _isLiveMode ? Icons.monitor_heart : Icons.history,
                        size: 18,
                        color: _isLiveMode ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLiveMode 
                            ? 'Real-time monitoring active' 
                            : 'Historical view (live updates paused)',
                        style: TextStyle(
                          color: _isLiveMode ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Audit entries list
                Expanded(
                  child: _auditEntries.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.security, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No audit trail entries found'),
                              SizedBox(height: 8),
                              Text(
                                'Access events will appear here in real-time',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _auditEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _auditEntries[index];
                            final timestamp = DateTime.parse(entry['timestamp']);
                            final formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(timestamp);
                            
                            // Check if this is a new entry (within last 30 seconds)
                            final isNew = DateTime.now().difference(timestamp).inSeconds < 30;
                            
                            return AnimatedContainer(
                              duration: const Duration(seconds: 1),
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isNew
                                    ? [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: isNew 
                                    ? Colors.yellow[50] 
                                    : Theme.of(context).cardColor,
                                child: ListTile(
                                  leading: Stack(
                                    children: [
                                      _getAuditIcon(entry['accessType']),
                                      if (isNew)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(entry['accessedBy'])),
                                      if (isNew)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'NEW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Access Type: ${entry['accessType']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        'Location: ${entry['location']}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      Text(
                                        'Device: ${entry['device']}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
  
  Widget _getAuditIcon(String accessType) {
    switch (accessType.toLowerCase()) {
      case 'view':
        return CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: const Icon(Icons.visibility, color: Colors.blue),
        );
      case 'edit':
        return CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.edit, color: Colors.orange),
        );
      case 'delete':
        return CircleAvatar(
          backgroundColor: Colors.red[100],
          child: const Icon(Icons.delete, color: Colors.red),
        );
      case 'download':
        return CircleAvatar(
          backgroundColor: Colors.green[100],
          child: const Icon(Icons.download, color: Colors.green),
        );
      case 'share':
        return CircleAvatar(
          backgroundColor: Colors.purple[100],
          child: const Icon(Icons.share, color: Colors.purple),
        );
      default:
        return CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.info_outline, color: Colors.grey),
        );
    }
  }
}