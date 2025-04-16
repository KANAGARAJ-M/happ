import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/screens/appointments/appointment_details_screen.dart';
import 'package:happ/core/models/record.dart'; // Import your Record model

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
          
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _clearAllNotifications() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final notificationDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();
          
      for (var doc in notificationDocs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _isLoading ? null : _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all notifications',
            onPressed: _isLoading ? null : _clearAllNotifications,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(user.id, false),
                _buildNotificationList(user.id, true),
              ],
            ),
    );
  }
  
  Widget _buildNotificationList(String userId, bool onlyUnread) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: onlyUnread ? false : null)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  onlyUnread ? Icons.notifications_none : Icons.notifications_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  onlyUnread ? 'No unread notifications' : 'No notifications',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(8.0),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final String title = data['title'] ?? 'Notification';
            final String body = data['body'] ?? '';
            final bool read = data['read'] ?? false;
            final String type = data['type'] ?? 'general';
            
            // Format timestamp
            String timeAgo = '';
            if (data['timestamp'] != null) {
              final timestamp = (data['timestamp'] as Timestamp).toDate();
              timeAgo = _getTimeAgo(timestamp);
            }
            
            return Dismissible(
              key: Key(doc.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('notifications')
                    .doc(doc.id)
                    .delete();
              },
              child: Card(
                elevation: read ? 1 : 3,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                color: read ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                child: ListTile(
                  leading: _getNotificationIcon(type),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(body),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  trailing: read
                      ? null
                      : Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  onTap: () async {
                    // Mark as read
                    if (!read) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .doc(doc.id)
                          .update({'read': true});
                    }
                    
                    // Navigate to relevant screen based on notification type
                    _handleNotificationTap(data);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
  
  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment':
        return CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.2),
          child: const Icon(Icons.calendar_today, color: Colors.blue),
        );
      case 'record_access':
        return CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: const Icon(Icons.folder_shared, color: Colors.orange),
        );
      case 'medical_insight':
        return CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.2),
          child: const Icon(Icons.health_and_safety, color: Colors.red),
        );
      default:
        return CircleAvatar(
          backgroundColor: Colors.grey.withOpacity(0.2),
          child: const Icon(Icons.notifications, color: Colors.grey),
        );
    }
  }
  
  void _handleNotificationTap(Map<String, dynamic> data) async {
    // Navigation logic based on notification type
    final String type = data['type'] ?? '';
    
    switch (type) {
      case 'appointment':
        if (data['data'] != null && data['data']['appointmentId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentDetailsScreen(
                appointmentId: data['data']['appointmentId'],
              ),
            ),
          );
        }
        break;
        
      case 'record_access':
        if (data['recordId'] != null) {
          setState(() => _isLoading = true);
          // Get current user ID from AuthProvider
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = authProvider.currentUser?.id;
          
          // Use better error handling with try/catch
          try {
            // First check if record exists in the specific user's collection
            final recordSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['userId'] ?? currentUserId) // Use provided userId or current user
                .collection('records')
                .doc(data['recordId'])
                .get();
                
            if (recordSnapshot.exists) {
              final recordData = recordSnapshot.data()!;
              
              // Create Record properly with ID
              final record = Record.fromJson({
                ...recordData,
                'id': data['recordId']
              });
              
              if (mounted) {
                setState(() => _isLoading = false);
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecordDetailScreen(
                      record: record,
                    ),
                  ),
                );
              }
            } else {
              // Fallback to collectionGroup query if not found in direct path
              final querySnapshot = await FirebaseFirestore.instance
                  .collectionGroup('records')
                  .where('id', isEqualTo: data['recordId'])
                  .limit(1)
                  .get();
                  
              if (querySnapshot.docs.isNotEmpty) {
                final recordData = querySnapshot.docs.first.data();
                
                // Create Record with ID
                final record = Record.fromJson({
                  ...recordData,
                  'id': data['recordId']
                });
                
                if (mounted) {
                  setState(() => _isLoading = false);
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordDetailScreen(
                        record: record,
                      ),
                    ),
                  );
                }
              } else {
                // Record not found
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Record not found or may have been deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading record: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
        
      case 'medical_insight':
        // Navigate to medical profile or medical insights screen
        if (data['condition'] != null) {
          // You could navigate to a specific section showing this condition
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Medical insight for ${data['condition']}')),
          );
        }
        break;
        
      default:
        // Do nothing for general notifications
        break;
    }
  }
}