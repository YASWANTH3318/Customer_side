import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .get();

        final notifications = querySnapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();

        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          // Handle permission denied gracefully - show empty notifications
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Notifications'),
                    content: const Text('Are you sure you want to clear all notifications?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  // TODO: Implement clear all notifications
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll see your notifications here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            _getNotificationIcon(notification['type'] ?? ''),
                            color: _getNotificationColor(notification['type'] ?? ''),
                          ),
                          title: Text(notification['title'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(notification['timestamp']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            // TODO: Handle notification tap
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.receipt_long;
      case 'reservation':
        return Icons.calendar_today;
      case 'promotion':
        return Icons.local_offer;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Colors.blue;
      case 'reservation':
        return Colors.green;
      case 'promotion':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = timestamp is Timestamp 
        ? timestamp.toDate() 
        : DateTime.now();
    
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 