import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../restaurant_details_page.dart';
import '../../models/restaurant.dart';
import '../../utils/date_format_util.dart';

class BloggerNotificationsPage extends StatefulWidget {
  const BloggerNotificationsPage({super.key});

  @override
  State<BloggerNotificationsPage> createState() => _BloggerNotificationsPageState();
}

class _BloggerNotificationsPageState extends State<BloggerNotificationsPage> {
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Try to use the notification service if implemented
      try {
        _notifications = await NotificationService.getNotificationsForUser(userId);
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          // Handle permission denied gracefully - show empty notifications
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
          return;
        }
        
        // If service not implemented, use direct Firestore query as fallback
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .limit(30)
              .get();

          _notifications = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();
        } catch (firestoreError) {
          if (firestoreError.toString().contains('permission-denied')) {
            // Handle permission denied gracefully - show empty notifications
            setState(() {
              _notifications = [];
              _isLoading = false;
            });
            return;
          }
          rethrow;
        }

        // If no notifications, add some sample data for testing
        if (_notifications.isEmpty) {
          _notifications = _getSampleNotifications();
        }
      }

      // Mark notifications as read
      await _markNotificationsAsRead();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Mark notifications as read in Firestore (batch operation)
      final batch = FirebaseFirestore.instance.batch();
      final unreadNotifications = _notifications.where((n) => !n.isRead).toList();
      
      for (final notification in unreadNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id);
        batch.update(docRef, {'isRead': true});
      }
      
      if (unreadNotifications.isNotEmpty) {
        await batch.commit();
      }
      
      // Update local state
      for (final notification in _notifications) {
        notification.isRead = true;
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  List<NotificationModel> _getSampleNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: '1',
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: 'New Follower',
        body: 'Alex started following you',
        type: 'follower',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
        data: {'followerId': 'user123'},
      ),
      NotificationModel(
        id: '2',
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: 'Post Liked',
        body: 'Emma liked your post about Italian cuisine',
        type: 'like',
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: false,
        data: {'postId': 'post123', 'likerId': 'user456'},
      ),
      NotificationModel(
        id: '3',
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: 'Booking Confirmed',
        body: 'Your table reservation at Spice Garden was confirmed',
        type: 'booking',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
        data: {'bookingId': 'booking789', 'restaurantId': 'rest123'},
      ),
      NotificationModel(
        id: '4',
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: 'New Comment',
        body: 'Jason commented on your pizza review',
        type: 'comment',
        timestamp: now.subtract(const Duration(days: 2)),
        isRead: true,
        data: {'postId': 'post456', 'commentId': 'comment123'},
      ),
      NotificationModel(
        id: '5',
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: 'Reel Shared',
        body: 'Your dessert reel was shared 5 times',
        type: 'share',
        timestamp: now.subtract(const Duration(days: 3)),
        isRead: true,
        data: {'reelId': 'reel123'},
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationTile(notification);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'follower':
        iconData = Icons.person_add;
        iconColor = Colors.blue;
        break;
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.comment;
        iconColor = Colors.green;
        break;
      case 'booking':
        iconData = Icons.book_online;
        iconColor = Colors.orange;
        break;
      case 'share':
        iconData = Icons.share;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              DateFormatUtil.formatRelativeTime(notification.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
        // Show unread indicator
        tileColor: notification.isRead ? null : Colors.orange.withOpacity(0.05),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Handle different notification types
    switch (notification.type) {
      case 'follower':
        // Navigate to follower profile
        break;
      case 'like':
        // Navigate to liked post
        break;
      case 'comment':
        // Navigate to post with comment
        break;
      case 'booking':
        // Navigate to booking details
        if (notification.data != null && notification.data!.containsKey('restaurantId')) {
          final restaurantId = notification.data!['restaurantId'];
          _navigateToRestaurantDetails(restaurantId);
        }
        break;
      case 'share':
        // Navigate to shared reel
        break;
    }
  }

  void _navigateToRestaurantDetails(String restaurantId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();

      if (snapshot.exists && mounted) {
        final restaurantData = snapshot.data();
        if (restaurantData != null) {
          // Convert the map to a Restaurant object
          final restaurant = Restaurant.fromMap({
            ...restaurantData,
            'id': restaurantId, // Ensure ID is included
          });
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailsPage(
                restaurant: restaurant,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to restaurant: $e');
    }
  }
} 