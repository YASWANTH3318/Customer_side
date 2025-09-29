import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/reservation.dart';
import '../models/review.dart';
import '../services/reservation_service.dart';
import '../services/review_service.dart';
import 'package:intl/intl.dart';
import '../pages/table_booking_page.dart';
import '../pages/pre_order_page.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  String? _selectedTime;
  int _guestCount = 2;
  Review? _userReview;
  bool _isLoadingReviews = false;
  String? _specialRequests;

  final List<String> _availableTimes = [
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
    '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM',
    '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserReview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  Future<void> _loadUserReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoadingReviews = true);
      try {
        final reviews = await ReviewService.getUserReviews(user.uid);
        final userReview = reviews.firstWhere(
          (review) => review.restaurantId == widget.restaurant.id,
          orElse: () => Review(
            id: '',
            userId: user.uid,
            userName: user.displayName ?? 'Anonymous',
            userImage: user.photoURL ?? '',
            restaurantId: widget.restaurant.id,
            rating: 0,
            comment: '',
            date: DateTime.now(),
          ),
        );
        if (mounted) {
          setState(() {
            _userReview = userReview;
            _isLoadingReviews = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingReviews = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading review: $e')),
          );
        }
      }
    }
  }

  void _showReservationDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to make a reservation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? specialRequests;

    // Old confirmation dialog removed per new flow (auto-booking happens on booking page)
    return;
  }

  void _showReviewDialog({bool isEdit = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave a review')),
      );
      return;
    }

    double rating = _userReview?.rating ?? 0;
    final commentController = TextEditingController(text: _userReview?.comment ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Review' : 'Add Review'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      rating = index + 1.0;
                      (context as Element).markNeedsBuild();
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (isEdit && _userReview?.id.isNotEmpty == true)
            TextButton(
              onPressed: () async {
                try {
                  await ReviewService.deleteReview(
                    _userReview!.id,
                    widget.restaurant.id,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _userReview = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting review: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () async {
              if (rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a rating')),
                );
                return;
              }

              final review = Review(
                id: _userReview?.id ?? '',
                userId: user.uid,
                userName: user.displayName ?? 'Anonymous',
                userImage: user.photoURL ?? '',
                restaurantId: widget.restaurant.id,
                rating: rating,
                comment: commentController.text.trim(),
                date: DateTime.now(),
              );

              try {
                if (isEdit && review.id.isNotEmpty) {
                  await ReviewService.updateReview(review.id, review);
                } else {
                  await ReviewService.createReview(review);
                }

                if (mounted) {
                  Navigator.pop(context);
                  setState(() => _userReview = review);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Review updated successfully' : 'Review added successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving review: $e')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ReviewService.getRestaurantReviews(widget.restaurant.id),
        ReviewService.getReviewStats(widget.restaurant.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final reviews = snapshot.data![0] as List<Review>;
        final stats = snapshot.data![1] as ReviewStats;
        final user = FirebaseAuth.instance.currentUser;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await _loadUserReview();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Rating Overview Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                stats.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < stats.averageRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats.totalReviews} reviews',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((rating) {
                                final percentage = stats.ratingPercentages[rating] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$rating',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star, size: 12),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percentage / 100,
                                            backgroundColor: Colors.grey[200],
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          '${percentage.round()}%',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // User's Review Section
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Review',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingReviews)
                          const Center(child: CircularProgressIndicator())
                        else if (_userReview?.id.isEmpty ?? true)
                          Center(
                            child: ElevatedButton(
                              onPressed: () => _showReviewDialog(),
                              child: const Text('Add Review'),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < (_userReview?.rating ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    );
                                  }),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _showReviewDialog(isEdit: true),
                                    child: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_userReview?.comment ?? ''),
                              const SizedBox(height: 8),
                              Text(
                                'Posted on ${DateFormat('MMM d, yyyy').format(_userReview?.date ?? DateTime.now())}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],

              // All Reviews Section
              const Text(
                'All Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (reviews.isEmpty)
                const Center(
                  child: Text('No reviews yet. Be the first to review!'),
                )
              else
                ...reviews
                    .where((review) => review.userId != user?.uid)
                    .map((review) => Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: review.userImage.isNotEmpty
                                          ? NetworkImage(review.userImage)
                                          : null,
                                      child: review.userImage.isEmpty
                                          ? Text(review.userName[0])
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM d, yyyy')
                                                .format(review.date),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < review.rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 20,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                if (review.comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(review.comment),
                                ],
                              ],
                            ),
                          ),
                        ))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: (widget.restaurant.image.startsWith('http://') || widget.restaurant.image.startsWith('https://'))
                  ? Image.network(
                      widget.restaurant.image,
                      fit: BoxFit.cover,
                    )
                  : Container(color: Colors.grey[300]),
              title: Text(
                widget.restaurant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            widget.restaurant.rating.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(widget.restaurant.deliveryTime),
                          const SizedBox(width: 16),
                          Icon(Icons.location_on, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(widget.restaurant.distance),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: widget.restaurant.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: Colors.grey[200],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Reserve'),
                    Tab(text: 'Menu'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Reserve Tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            // Hero Image Section
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: (widget.restaurant.image.startsWith('http://') || widget.restaurant.image.startsWith('https://'))
                                  ? BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(widget.restaurant.image),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.4),
                                          BlendMode.darken,
                                        ),
                                      ),
                                    )
                                  : BoxDecoration(color: Colors.grey[400]),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Reserve Your Table',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Experience the finest dining at ${widget.restaurant.name}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Restaurant Info Card
                                  Card(
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.restaurant, color: Colors.orange),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Restaurant Information',
                                                style: Theme.of(context).textTheme.titleLarge,
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(Icons.location_on, widget.restaurant.address),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(Icons.access_time, 'Open Hours: 11:00 AM - 11:00 PM'),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(Icons.phone, widget.restaurant.phoneNumber),
                                          const SizedBox(height: 8),
                                          _buildInfoRow(Icons.category, widget.restaurant.cuisine),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Booking Section
                                  Card(
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, color: Colors.orange),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Book Your Table',
                                                style: Theme.of(context).textTheme.titleLarge,
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          const SizedBox(height: 16),

                                          // Date Selection
                                          Text(
                                            'Select Date',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          InkWell(
                                            onTap: () => _selectDate(context),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey[300]!),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.calendar_today),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _selectedDate == null
                                                        ? 'Choose a date'
                                                        : DateFormat('MMM d, yyyy').format(_selectedDate!),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),

                                          // Time Selection
                                          if (_selectedDate != null) ...[
                                            Text(
                                              'Select Time',
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _availableTimes.map((time) {
                                                final isSelected = _selectedTime == time;
                                                return ChoiceChip(
                                                  label: Text(time),
                                                  selected: isSelected,
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      _selectedTime = selected ? time : null;
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 24),
                                          ],

                                          // Number of Guests
                                          Text(
                                            'Number of Guests',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                onPressed: _guestCount > 1
                                                    ? () => setState(() => _guestCount--)
                                                    : null,
                                              ),
                                              Text(
                                                _guestCount.toString(),
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                onPressed: _guestCount < 10
                                                    ? () => setState(() => _guestCount++)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),

                                          // Special Requests
                                          Text(
                                            'Special Requests (Optional)',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            decoration: const InputDecoration(
                                              hintText: 'e.g., Birthday celebration, Allergies, etc.',
                                              border: OutlineInputBorder(),
                                            ),
                                            maxLines: 2,
                                            onChanged: (value) => setState(() {
                                              _specialRequests = value;
                                            }),
                                          ),
                                          const SizedBox(height: 24),

                                          // Pre-order Option
                                          if (_selectedDate != null && _selectedTime != null)
                                            Card(
                                              color: Colors.grey[100],
                                              child: ListTile(
                                                leading: const Icon(Icons.restaurant_menu),
                                                title: const Text('Pre-order Food'),
                                                subtitle: const Text('Order your food in advance to save time'),
                                                trailing: const Icon(Icons.arrow_forward_ios),
                                                onTap: () {
                                                  final user = FirebaseAuth.instance.currentUser;
                                                  if (user == null) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Please sign in to pre-order'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => PreOrderPage(
                                                        restaurant: widget.restaurant,
                                                        reservationId: DateTime.now().millisecondsSinceEpoch.toString(),
                                                        userId: user.uid,
                                                        reservationDate: _selectedDate!,
                                                        numberOfGuests: _guestCount,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          const SizedBox(height: 24),

                                          // Book Table Button
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: (_selectedDate != null && _selectedTime != null)
                                                  ? _showReservationDialog
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                backgroundColor: Theme.of(context).primaryColor,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: Colors.grey[300],
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.check_circle_outline),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    (_selectedDate != null && _selectedTime != null)
                                                        ? 'Book Table'
                                                        : 'Select Date and Time',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_selectedDate == null || _selectedTime == null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                'Please select both date and time to proceed',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Center(child: Text('Menu Coming Soon')),
                      _buildMenuTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTab() {
    if (widget.restaurant.menu.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 50, color: Colors.grey),
            SizedBox(height: 16),
            Text('No menu available for this restaurant', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (String category in widget.restaurant.menu.keys)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange.withOpacity(0.1),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...widget.restaurant.menu[category]!.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.image != null && item.image!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.image!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.restaurant, color: Colors.grey),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.description,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (item.isVegetarian)
                                  _buildFeatureChip('Vegetarian'),
                                if (item.isVegan)
                                  _buildFeatureChip('Vegan'),
                                if (item.isSpicy)
                                  _buildFeatureChip('Spicy'),
                                if (item.allergens.isNotEmpty)
                                  ...item.allergens.map((allergen) => _buildFeatureChip('Contains $allergen')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
              const SizedBox(height: 24),
            ],
          ),
      ],
    );
  }

  Widget _buildFeatureChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: Colors.grey[800],
      ),
    );
  }
} 