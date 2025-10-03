import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';
import 'restaurant_service.dart';

class AdminRestaurantService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all restaurants with admin details
  static Future<List<Map<String, dynamic>>> getAllRestaurantsWithDetails() async {
    try {
      final snapshot = await _firestore
          .collection('restaurants')
          .where('metadata.appId', isEqualTo: 3)
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'cuisine': data['cuisine'] ?? 'Unknown',
          'address': data['address'] ?? 'Unknown',
          'phoneNumber': data['phoneNumber'] ?? 'Unknown',
          'rating': data['rating'] ?? 0.0,
          'isFeatured': data['isFeatured'] ?? false,
          'isActive': data['metadata']?['isActive'] ?? true,
          'createdAt': data['metadata']?['createdAt'],
          'lastUpdated': data['lastUpdated'],
          'ownerUserId': data['ownerUserId'],
        };
      }).toList();
    } catch (e) {
      print('Error getting all restaurants with details: $e');
      return [];
    }
  }

  // Toggle restaurant active status
  static Future<void> toggleRestaurantStatus(String restaurantId, bool isActive) async {
    try {
      await RestaurantService.updateRestaurantStatus(restaurantId, isActive);
      print('Restaurant status updated: $restaurantId -> $isActive');
    } catch (e) {
      print('Error toggling restaurant status: $e');
      throw e;
    }
  }

  // Toggle restaurant featured status
  static Future<void> toggleRestaurantFeatured(String restaurantId, bool isFeatured) async {
    try {
      await RestaurantService.updateRestaurantFeaturedStatus(restaurantId, isFeatured);
      print('Restaurant featured status updated: $restaurantId -> $isFeatured');
    } catch (e) {
      print('Error toggling restaurant featured status: $e');
      throw e;
    }
  }

  // Get restaurant statistics
  static Future<Map<String, dynamic>> getRestaurantStats() async {
    try {
      final restaurants = await RestaurantService.getAllRestaurants();
      
      final totalRestaurants = restaurants.length;
      final activeRestaurants = restaurants.where((r) => r.isFeatured).length;
      final featuredRestaurants = restaurants.where((r) => r.isFeatured).length;
      
      // Get average rating
      final totalRating = restaurants.fold(0.0, (sum, r) => sum + r.rating);
      final averageRating = totalRestaurants > 0 ? totalRating / totalRestaurants : 0.0;

      // Get cuisine distribution
      final cuisineCount = <String, int>{};
      for (final restaurant in restaurants) {
        final cuisine = restaurant.cuisine.split('•')[0].trim();
        cuisineCount[cuisine] = (cuisineCount[cuisine] ?? 0) + 1;
      }

      return {
        'totalRestaurants': totalRestaurants,
        'activeRestaurants': activeRestaurants,
        'featuredRestaurants': featuredRestaurants,
        'averageRating': averageRating,
        'cuisineDistribution': cuisineCount,
      };
    } catch (e) {
      print('Error getting restaurant stats: $e');
      return {
        'totalRestaurants': 0,
        'activeRestaurants': 0,
        'featuredRestaurants': 0,
        'averageRating': 0.0,
        'cuisineDistribution': <String, int>{},
      };
    }
  }

  // Search restaurants by name or cuisine
  static Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    try {
      final allRestaurants = await getAllRestaurantsWithDetails();
      final normalizedQuery = query.toLowerCase().trim();
      
      if (normalizedQuery.isEmpty) {
        return allRestaurants;
      }

      return allRestaurants.where((restaurant) {
        final name = (restaurant['name'] as String).toLowerCase();
        final cuisine = (restaurant['cuisine'] as String).toLowerCase();
        final address = (restaurant['address'] as String).toLowerCase();
        
        return name.contains(normalizedQuery) ||
               cuisine.contains(normalizedQuery) ||
               address.contains(normalizedQuery);
      }).toList();
    } catch (e) {
      print('Error searching restaurants: $e');
      return [];
    }
  }

  // Get restaurant by ID with full details
  static Future<Map<String, dynamic>?> getRestaurantDetails(String restaurantId) async {
    try {
      final doc = await _firestore.collection('restaurants').doc(restaurantId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'cuisine': data['cuisine'] ?? 'Unknown',
        'address': data['address'] ?? 'Unknown',
        'phoneNumber': data['phoneNumber'] ?? 'Unknown',
        'rating': data['rating'] ?? 0.0,
        'isFeatured': data['isFeatured'] ?? false,
        'isActive': data['metadata']?['isActive'] ?? true,
        'createdAt': data['metadata']?['createdAt'],
        'lastUpdated': data['lastUpdated'],
        'ownerUserId': data['ownerUserId'],
        'description': data['description'] ?? '',
        'image': data['image'] ?? '',
        'menu': data['menu'] ?? {},
        'availableTables': data['availableTables'] ?? [],
        'openingHours': data['openingHours'] ?? {},
        'tags': data['tags'] ?? [],
        'searchTags': data['searchTags'] ?? [],
      };
    } catch (e) {
      print('Error getting restaurant details: $e');
      return null;
    }
  }

  // Delete restaurant (soft delete by setting inactive)
  static Future<void> deleteRestaurant(String restaurantId) async {
    try {
      await RestaurantService.updateRestaurantStatus(restaurantId, false);
      print('Restaurant soft deleted: $restaurantId');
    } catch (e) {
      print('Error deleting restaurant: $e');
      throw e;
    }
  }

  // Restore restaurant (set active)
  static Future<void> restoreRestaurant(String restaurantId) async {
    try {
      await RestaurantService.updateRestaurantStatus(restaurantId, true);
      print('Restaurant restored: $restaurantId');
    } catch (e) {
      print('Error restoring restaurant: $e');
      throw e;
    }
  }
}
