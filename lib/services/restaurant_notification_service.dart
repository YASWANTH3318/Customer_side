import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class RestaurantNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send notification to all customers when a new restaurant registers
  static Future<void> notifyNewRestaurantRegistration({
    required String restaurantId,
    required String restaurantName,
    required String cuisine,
    required String address,
  }) async {
    try {
      // Get all customer users (appId = 1)
      final customersSnapshot = await _firestore
          .collection('users')
          .where('metadata.appId', isEqualTo: 1)
          .get();

      // Send notification to each customer
      for (final customerDoc in customersSnapshot.docs) {
        await NotificationService.createNotification(
          userId: customerDoc.id,
          title: 'New Restaurant Available! 🍽️',
          body: '$restaurantName ($cuisine) is now available for booking near you',
          type: 'new_restaurant',
          data: {
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
            'cuisine': cuisine,
            'address': address,
          },
        );
      }

      // Get all blogger users (appId = 2)
      final bloggersSnapshot = await _firestore
          .collection('users')
          .where('metadata.appId', isEqualTo: 2)
          .get();

      // Send notification to each blogger
      for (final bloggerDoc in bloggersSnapshot.docs) {
        await NotificationService.createNotification(
          userId: bloggerDoc.id,
          title: 'New Restaurant to Review! 📝',
          body: '$restaurantName ($cuisine) is now available for review and booking',
          type: 'new_restaurant_blogger',
          data: {
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
            'cuisine': cuisine,
            'address': address,
          },
        );
      }

      print('New restaurant notifications sent successfully for: $restaurantName');
    } catch (e) {
      print('Error sending new restaurant notifications: $e');
      // Don't throw error as this is a background notification
    }
  }

  // Send notification when restaurant updates their menu
  static Future<void> notifyMenuUpdate({
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      // Get all customer users who have booked this restaurant before
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      final Set<String> customerIds = reservationsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();

      // Send notification to each customer who has booked this restaurant
      for (final customerId in customerIds) {
        await NotificationService.createNotification(
          userId: customerId,
          title: 'Menu Updated! 🍽️',
          body: '$restaurantName has updated their menu with new items',
          type: 'menu_update',
          data: {
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
          },
        );
      }

      print('Menu update notifications sent successfully for: $restaurantName');
    } catch (e) {
      print('Error sending menu update notifications: $e');
    }
  }

  // Send notification when restaurant updates their table availability
  static Future<void> notifyTableUpdate({
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      // Get all customer users who have booked this restaurant before
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      final Set<String> customerIds = reservationsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();

      // Send notification to each customer who has booked this restaurant
      for (final customerId in customerIds) {
        await NotificationService.createNotification(
          userId: customerId,
          title: 'New Tables Available! 🪑',
          body: '$restaurantName has updated their table availability',
          type: 'table_update',
          data: {
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
          },
        );
      }

      print('Table update notifications sent successfully for: $restaurantName');
    } catch (e) {
      print('Error sending table update notifications: $e');
    }
  }

  // Send notification when restaurant changes their hours
  static Future<void> notifyHoursUpdate({
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      // Get all customer users who have booked this restaurant before
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      final Set<String> customerIds = reservationsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();

      // Send notification to each customer who has booked this restaurant
      for (final customerId in customerIds) {
        await NotificationService.createNotification(
          userId: customerId,
          title: 'Hours Updated! ⏰',
          body: '$restaurantName has updated their operating hours',
          type: 'hours_update',
          data: {
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
          },
        );
      }

      print('Hours update notifications sent successfully for: $restaurantName');
    } catch (e) {
      print('Error sending hours update notifications: $e');
    }
  }
}
