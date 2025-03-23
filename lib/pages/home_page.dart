import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import '../services/restaurant_service.dart';
import '../services/reservation_service.dart';
import '../models/user_model.dart';
import '../models/restaurant.dart';
import '../models/reservation.dart';
import '../pages/restaurant_details_page.dart';
import '../services/review_service.dart';
import '../pages/search_page.dart';
import '../pages/complete_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/blog_page.dart';
import 'user/faq_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<Restaurant>? _featuredRestaurants;
  List<Restaurant>? _popularRestaurants;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
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

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await UserService.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Greedy Bites'),
        actions: [
          // Development only button
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Add Sample Restaurants (Dev Only)',
            onPressed: () async {
              try {
                final success = await RestaurantService.addSampleRestaurants();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                          ? 'Sample restaurants added successfully!'
                          : 'Restaurants already exist or operation failed.',
                      ),
                      backgroundColor: success ? Colors.green : Colors.orange,
                    ),
                  );
                  if (success) {
                    _loadRestaurants(); // Reload only if new restaurants were added
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(user!),
          _buildSearchTab(),
          const BlogPage(),
          _buildOrdersTab(),
          _buildProfileTab(user),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 80, // Increased height to accommodate the protruding circle
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) => setState(() => _selectedIndex = index),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: Colors.grey,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.search_outlined),
                    activeIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  // Blog item with transparent icon to reserve space
                  BottomNavigationBarItem(
                    icon: SizedBox(
                      height: 35,
                      width: 50,
                      child: Opacity(opacity: 0, child: Icon(Icons.article_outlined)),
                    ),
                    label: 'Blog',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'History',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
            // Blog icon with orange circle
            Positioned(
              bottom: 25, // Adjusted to move the circle down
              left: MediaQuery.of(context).size.width * 0.5 - 25,
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 2),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.article,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(User user) {
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
            // User greeting and search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder(
                    future: UserService.getUserData(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        return Text(
                          'Hello, ${userData?['name'] ?? 'User'}! 👋',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return const Text('Hello! 👋');
                    },
                  ),
                  // const SizedBox(height: 16),
                  // TextField(
                  //   decoration: InputDecoration(
                  //     hintText: 'Search for restaurants or dishes',
                  //     prefixIcon: const Icon(Icons.search),
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //       borderSide: BorderSide.none,
                  //     ),
                  //     filled: true,
                  //     fillColor: Colors.grey[200],
                  //   ),
                  //   onChanged: _handleSearch,
                  // ),
                ],
              ),
            ),

            if (_searchQuery.isEmpty) ...[
              // Categories
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryCard('Pizza', Icons.local_pizza),
                          _buildCategoryCard('Burger', Icons.lunch_dining),
                          _buildCategoryCard('Sushi', Icons.set_meal),
                          _buildCategoryCard('Dessert', Icons.icecream),
                          _buildCategoryCard('Drinks', Icons.local_bar),
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
                              // TODO: Navigate to all restaurants
                            },
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredRestaurants!.length,
                          itemBuilder: (context, index) {
                            return FeaturedRestaurantCard(
                              restaurant: _featuredRestaurants![index],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Popular or Search Results
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchQuery.isEmpty ? 'Popular Near You' : 'Search Results',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_popularRestaurants != null && _popularRestaurants!.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _popularRestaurants!.length,
                      itemBuilder: (context, index) {
                        return RestaurantCard(
                          restaurant: _popularRestaurants![index],
                        );
                      },
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No restaurants available'
                              : 'No restaurants found for "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return const SearchPage();
  }

  Widget _buildOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please sign in to view orders'));

    return FutureBuilder<List<Reservation>>(
      future: ReservationService.getUserReservations(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final reservations = snapshot.data ?? [];

        if (reservations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, 
                  size: 64, 
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No reservations yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your restaurant reservations will appear here',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Group reservations by status
        final upcomingReservations = reservations
            .where((r) => r.status == ReservationStatus.confirmed && 
                        r.reservationDate.isAfter(DateTime.now()))
            .toList();
        final pastReservations = reservations
            .where((r) => r.status == ReservationStatus.completed || 
                        r.reservationDate.isBefore(DateTime.now()))
            .toList();
        final pendingReservations = reservations
            .where((r) => r.status == ReservationStatus.pending)
            .toList();
        final cancelledReservations = reservations
            .where((r) => r.status == ReservationStatus.cancelled)
            .toList();

        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Past'),
                  Tab(text: 'Cancelled'),
                ],
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildReservationList(upcomingReservations),
                    _buildReservationList(pendingReservations),
                    _buildReservationList(pastReservations),
                    _buildReservationList(cancelledReservations),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReservationList(List<Reservation> reservations) {
    if (reservations.isEmpty) {
      return Center(
        child: Text(
          'No reservations',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                reservation.restaurantImage,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              reservation.restaurantName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(reservation.reservationDate),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 8),
                    Text(reservation.reservationTime),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, size: 16),
                    const SizedBox(width: 8),
                    Text('${reservation.numberOfGuests} guests'),
                    const SizedBox(width: 16),
                    const Icon(Icons.chair, size: 16),
                    const SizedBox(width: 8),
                    Text(reservation.tableType),
                  ],
                ),
                if (reservation.specialRequests != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: ${reservation.specialRequests}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            trailing: reservation.status == ReservationStatus.confirmed ||
                      reservation.status == ReservationStatus.pending
                ? IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    color: Colors.red,
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel Reservation'),
                          content: const Text(
                            'Are you sure you want to cancel this reservation?'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Yes',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && mounted) {
                        try {
                          await ReservationService.cancelReservation(
                            reservation.id
                          );
                          setState(() {}); // Refresh the list
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reservation cancelled successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error cancelling reservation: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(User user) {
    return FutureBuilder(
      future: UserService.getUserData(user.uid),
      builder: (context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Retry loading data
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data.exists) {
          // Create a basic profile if user document doesn't exist
          final newUser = UserModel(
            id: user.uid,
            email: user.email ?? 'No email',
            name: user.displayName ?? user.email?.split('@')[0] ?? 'User',
            username: user.email?.split('@')[0] ?? 'user',
            profileImageUrl: user.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isEmailVerified: user.emailVerified,
            metadata: {
              'createdBy': 'app',
              'accountType': user.providerData.first.providerId,
              'role': 'user',
            },
          );

          // Create the user document
          UserService.createUser(newUser);

          return _buildProfileContent({
            'name': newUser.name,
            'email': newUser.email,
            'photoURL': newUser.profileImageUrl,
          });
        }

        final userData = snapshot.data.data() as Map<String, dynamic>;
        return _buildProfileContent(userData);
      },
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Image
          Stack(
            children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: userData['profileImageUrl'] != null
                ? NetworkImage(userData['profileImageUrl'])
                : null,
            child: userData['profileImageUrl'] == null
                ? Text(
                    (userData['name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 40),
                  )
                : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _navigateToCompleteProfile(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // User Name
          Text(
            userData['name'] ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // User Email
          Text(
            userData['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),

          // Phone Number
          if (userData['phoneNumber'] != null) ...[
            Text(
              userData['phoneNumber'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Address
          if (userData['address'] != null) ...[
            Text(
              userData['address'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ],

          // Complete Profile Button (if profile is incomplete)
          if (userData['phoneNumber'] == null || userData['address'] == null)
            OutlinedButton.icon(
              onPressed: () => _navigateToCompleteProfile(),
              icon: const Icon(Icons.person_add),
              label: const Text('Complete Your Profile'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Profile Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Orders', '0'),
              _buildStatItem('Reviews', '0'),
              _buildStatItem('Points', '0'),
            ],
          ),
          const SizedBox(height: 32),

          // Profile Options
          _buildProfileOption(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {
              // TODO: Implement notifications settings
            },
          ),
          _buildProfileOption(
            icon: Icons.location_on_outlined,
            title: 'Delivery Address',
            onTap: () {
              // TODO: Implement address management
            },
          ),
          _buildProfileOption(
            icon: Icons.payment_outlined,
            title: 'Payment Methods',
            onTap: () {
              // TODO: Implement payment methods
            },
          ),
          _buildProfileOption(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // TODO: Implement settings
            },
          ),
          _buildProfileOption(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              // TODO: Implement help & support
            },
          ),
          _buildProfileOption(
            icon: Icons.question_answer_outlined,
            title: 'FAQs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FAQPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleSignOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCompleteProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in first')),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Get user data from Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = doc.data() ?? {};

      // Helper function to safely convert timestamp
      DateTime _parseTimestamp(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is Timestamp) return value.toDate();
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      // Create UserModel with proper type casting
      final userModel = UserModel(
        id: user.uid,
        email: (userData['email'] as String?) ?? user.email ?? '',
        name: (userData['name'] as String?) ?? user.displayName ?? '',
        username: (userData['username'] as String?) ?? 
                 ((userData['email'] as String?)?.split('@')[0]) ?? 
                 (user.email?.split('@')[0]) ?? '',
        phoneNumber: userData['phoneNumber'] as String?,
        address: userData['address'] as String?,
        profileImageUrl: userData['profileImageUrl'] as String?,
        createdAt: _parseTimestamp(userData['createdAt']),
        lastLoginAt: _parseTimestamp(userData['lastLoginAt']),
        isEmailVerified: (userData['isEmailVerified'] as bool?) ?? user.emailVerified,
        metadata: (userData['metadata'] as Map<String, dynamic>?) ?? {},
      );

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompleteProfilePage(
            initialData: userModel,
          ),
        ),
      );

      if (result == true && mounted) {
        setState(() {
          _isLoading = true;
        });
        await _loadUserData();
      }
    } catch (e) {
      print('Error navigating to profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to category
        },
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const FeaturedRestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantDetailsPage(
                  restaurant: restaurant,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                restaurant.image,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<ReviewStats>(
                      future: ReviewService.getReviewStats(restaurant.id),
                      builder: (context, snapshot) {
                        final rating = snapshot.hasData && snapshot.data!.averageRating > 0
                            ? snapshot.data!.averageRating
                            : restaurant.rating;
                        final reviewCount = snapshot.hasData ? snapshot.data!.totalReviews : 0;
                        
                        return Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[600], size: 20),
                        const SizedBox(width: 4),
                            Text('$rating ${reviewCount > 0 ? '($reviewCount)' : ''}'),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 4),
                        Text(restaurant.deliveryTime),
                      ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailsPage(
                restaurant: restaurant,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  restaurant.image,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<ReviewStats>(
                      future: ReviewService.getReviewStats(restaurant.id),
                      builder: (context, snapshot) {
                        final rating = snapshot.hasData && snapshot.data!.averageRating > 0
                            ? snapshot.data!.averageRating
                            : restaurant.rating;
                        final reviewCount = snapshot.hasData ? snapshot.data!.totalReviews : 0;
                        
                        return Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[600], size: 20),
                        const SizedBox(width: 4),
                            Text('$rating ${reviewCount > 0 ? '($reviewCount)' : ''}'),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 4),
                        Text(restaurant.distance),
                      ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: restaurant.tags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.grey[200],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 