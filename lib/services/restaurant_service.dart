import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';

class RestaurantService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'restaurants';

  // Get featured restaurants
  static Future<List<Restaurant>> getFeaturedRestaurants() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isFeatured', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(5)
          .get();

      return snapshot.docs
          .map((doc) => Restaurant.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting featured restaurants: $e');
      rethrow;
    }
  }

  // Get popular restaurants
  static Future<List<Restaurant>> getPopularRestaurants() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('rating', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Restaurant.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting popular restaurants: $e');
      rethrow;
    }
  }

  // Get restaurant by ID
  static Future<Restaurant?> getRestaurantById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return Restaurant.fromMap({...doc.data()!, 'id': doc.id});
    } catch (e) {
      print('Error getting restaurant by ID: $e');
      rethrow;
    }
  }

  // Search restaurants
  static Future<List<Restaurant>> searchRestaurants(String query, {double? maxDistance}) async {
    try {
      final results = <Restaurant>[];
      final snapshot = await _firestore.collection(_collection).get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';
        final cuisine = data['cuisine'] ?? '';
        final description = data['description'] ?? '';
        final tags = List<String>.from(data['tags'] ?? []);

        // Check if restaurant matches search query
        if (query.isEmpty ||
            name.toLowerCase().contains(query.toLowerCase()) ||
            cuisine.toLowerCase().contains(query.toLowerCase()) ||
            description.toLowerCase().contains(query.toLowerCase()) ||
            tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))) {
          
          final restaurant = Restaurant.fromMap({...data, 'id': doc.id});
          
          // Filter by distance if provided
          if (maxDistance != null) {
            try {
              // Extract distance value from string (e.g., "2.5 km" -> 2.5)
              final distanceString = restaurant.distance.split(' ').first;
              final distanceValue = double.tryParse(distanceString) ?? 0.0;
              
              if (distanceValue <= maxDistance) {
                results.add(restaurant);
              }
            } catch (e) {
              // If distance parsing fails, just add the restaurant
              print('Error parsing distance for ${restaurant.name}: $e');
              results.add(restaurant);
            }
          } else {
            results.add(restaurant);
          }
        }
      }

      return results;
    } catch (e) {
      print('Error searching restaurants: $e');
      return []; // Return empty list instead of throwing exception
    }
  }

  // Add sample restaurants to Firebase (only for development)
  static Future<bool> addSampleRestaurants() async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection(_collection);

      // First, check if restaurants already exist to avoid duplicates
      final existingDocs = await collection
          .where('name', whereIn: _sampleRestaurants.map((r) => r.name).toList())
          .get();
      
      if (existingDocs.docs.isNotEmpty) {
        print('Some restaurants already exist. Skipping...');
        return false;
      }

      for (final restaurant in _sampleRestaurants) {
        final doc = collection.doc();
        final data = restaurant.toMap();
        // Ensure all required fields are non-null
        data['isFeatured'] = data['isFeatured'] ?? false;
        data['searchTags'] = data['searchTags'] ?? [];
        batch.set(doc, data);
      }

      await batch.commit();
      print('Sample restaurants added successfully');
      return true;
    } catch (e) {
      print('Error adding sample restaurants: $e');
      return false;
    }
  }

  static Future<List<Restaurant>> getRestaurantsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('foodType', isEqualTo: category.toLowerCase())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Restaurant.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting restaurants by category: $e');
      return [];
    }
  }

  static Future<List<Restaurant>> getRestaurantsByCuisine(String cuisine) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('cuisine', isEqualTo: cuisine)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Restaurant.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting restaurants by cuisine: $e');
      return [];
    }
  }
}

// Sample restaurant data
final List<Restaurant> _sampleRestaurants = [
  Restaurant(
    id: '1',
    name: 'The Spice Garden',
    image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
    cuisine: 'Indian • Traditional',
    rating: 4.5,
    deliveryTime: '30-40 min',
    distance: '2.5 km',
    tags: ['Spicy', 'Vegetarian Options'],
    description: 'Authentic Indian cuisine with a modern twist.',
    menu: {
      'Starters': [
        MenuItem(
          name: 'Samosa',
          description: 'Crispy pastry filled with spiced potatoes and peas',
          price: 5.99,
          allergens: ['Gluten'],
          isVegetarian: true,
        ),
      ],
    },
    availableTables: [
      TableType(
        id: 't1',
        capacity: 4,
        type: 'Standard',
        isAvailable: true,
        minimumSpend: 50.0,
      ),
    ],
    openingHours: OpeningHours(
      weeklyHours: {
        'monday': DayHours(
          isOpen: true,
          openTime: '11:00',
          closeTime: '22:00',
        ),
      },
    ),
    address: '123 Spice Street',
    phoneNumber: '+1234567890',
    isFeatured: true,
    searchTags: ['indian', 'spicy', 'vegetarian', 'traditional'],
  ),
  
  // Tamil Nadu Restaurant

];

// Firebase Structure:
/*
restaurants (collection)
  |- restaurantId (document)
      |- name: string
      |- image: string
      |- cuisine: string
      |- rating: number
      |- deliveryTime: string
      |- distance: string
      |- tags: array<string>
      |- description: string
      |- isFeatured: boolean
      |- searchTags: array<string> (lowercase tags for better search)
      |- menu: {
          categoryName: [{
            name: string,
            description: string,
            price: number,
            image: string?,
            allergens: array<string>,
            isVegetarian: boolean,
            isVegan: boolean,
            isSpicy: boolean
          }]
        }
      |- availableTables: [{
          id: string,
          capacity: number,
          type: string,
          isAvailable: boolean,
          minimumSpend: number
        }]
      |- openingHours: {
          dayName: {
            isOpen: boolean,
            openTime: string,
            closeTime: string,
            breakStartTime: string?,
            breakEndTime: string?
          }
        }
      |- address: string
      |- phoneNumber: string

reviews (collection)
  |- reviewId (document)
      |- userId: string
      |- userName: string
      |- userImage: string
      |- restaurantId: string
      |- rating: number
      |- comment: string
      |- date: timestamp
*/ 