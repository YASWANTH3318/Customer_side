import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/restaurant_service.dart';
import '../../models/restaurant.dart';
import '../restaurant_details_page.dart';
import '../table_booking_page.dart';
import '../../utils/date_format_util.dart';

// Fallback Restaurant model in case the import doesn't match
extension RestaurantCompatibility on Restaurant {
  String get imageUrl => image;
  String get location => address;
  bool get isVeg => tags.contains('Vegetarian');
}

class BloggerRestaurantsPage extends StatefulWidget {
  const BloggerRestaurantsPage({super.key});

  @override
  State<BloggerRestaurantsPage> createState() => _BloggerRestaurantsPageState();
}

class _BloggerRestaurantsPageState extends State<BloggerRestaurantsPage> {
  List<Restaurant>? _featuredRestaurants;
  List<Restaurant>? _popularRestaurants;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadRestaurants(); // Initial load
    _setupRestaurantStreams(); // Setup real-time updates
  }

  Widget _buildSafeImage(
    String? url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final String safeUrl = (url ?? '').trim();
    final bool isValidNetwork = safeUrl.startsWith('http://') || safeUrl.startsWith('https://');

    final Widget placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(Icons.broken_image, color: Colors.grey[500]),
    );

    if (!isValidNetwork) return placeholder;

    return Image.network(
      safeUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Future<void> _loadRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final featured = await RestaurantService.getFeaturedRestaurants();
      final popular = await RestaurantService.getPopularRestaurants();

      if (mounted) {
        setState(() {
          _featuredRestaurants = featured;
          _popularRestaurants = popular;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurants. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // Real-time restaurant loading using streams
  void _setupRestaurantStreams() {
    // Listen to featured restaurants stream
    RestaurantService.streamFeaturedRestaurants().listen((restaurants) {
      if (mounted) {
        setState(() {
          _featuredRestaurants = restaurants;
        });
      }
    });

    // Listen to popular restaurants stream
    RestaurantService.streamPopularRestaurants().listen((restaurants) {
      if (mounted) {
        setState(() {
          _popularRestaurants = restaurants;
        });
      }
    });
  }

  Future<void> _loadRestaurantsByCategory(String category) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedCategory = category;
      });

      final restaurants = await RestaurantService.getRestaurantsByCategory(category);

      if (mounted) {
        setState(() {
          _popularRestaurants = restaurants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurants. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      await _loadRestaurants();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _searchQuery = query;
      });

      final results = await RestaurantService.searchRestaurants(query);

      if (mounted) {
        setState(() {
          _popularRestaurants = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to search restaurants. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRestaurants,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search for restaurants or dishes',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                onChanged: _handleSearch,
              ),
            ),

            if (_searchQuery.isEmpty) ...[
              // Categories
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              _loadRestaurants();
                              setState(() => _selectedCategory = null);
                            },
                            child: const Text('Clear Filter'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryCard('All', Icons.restaurant),
                          _buildCategoryCard('Veg', Icons.eco),
                          _buildCategoryCard('Non-Veg', Icons.restaurant_menu),
                          _buildCategoryCard('Italian', Icons.local_pizza),
                          _buildCategoryCard('Chinese', Icons.ramen_dining),
                          _buildCategoryCard('Indian', Icons.dinner_dining),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Featured Restaurants
              if (_featuredRestaurants != null && _featuredRestaurants!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Featured Restaurants',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // View all featured restaurants
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredRestaurants!.length,
                          itemBuilder: (context, index) {
                            return _buildRestaurantCard(_featuredRestaurants![index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Popular or Searched Restaurants
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Search Results'
                        : _selectedCategory != null
                            ? '$_selectedCategory Restaurants'
                            : 'Popular Restaurants',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_popularRestaurants == null || _popularRestaurants!.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No restaurants found for "$_searchQuery"'
                                : 'No restaurants available',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _popularRestaurants!.length,
                      itemBuilder: (context, index) {
                        return _buildRestaurantListItem(_popularRestaurants![index]);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        if (category == 'All') {
          _loadRestaurants();
          setState(() => _selectedCategory = null);
        } else {
          _loadRestaurantsByCategory(category);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailsPage(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: _buildSafeImage(
                restaurant.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text('${restaurant.rating}'),
                      const SizedBox(width: 4),
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      Expanded(
                        child: Text(
                          restaurant.location.contains(',') 
                              ? restaurant.location.substring(0, restaurant.location.indexOf(','))
                              : restaurant.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        restaurant.isVeg ? Icons.eco : Icons.restaurant,
                        color: restaurant.isVeg ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.cuisine,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantListItem(Restaurant restaurant) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailsPage(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Restaurant image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: _buildSafeImage(
                restaurant.imageUrl,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${restaurant.rating}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant.location.contains(',') 
                                ? restaurant.location.substring(0, restaurant.location.indexOf(','))
                                : restaurant.location,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantDetailsPage(
                                  restaurant: restaurant,
                                ),
                              ),
                            );
                          },
                          child: const Text('View Details'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TableBookingPage(
                                  restaurant: restaurant,
                                  userId: FirebaseAuth.instance.currentUser!.uid,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Book Table'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 