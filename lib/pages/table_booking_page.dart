import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/restaurant.dart';
import '../models/pre_order.dart';
import '../models/reservation.dart';
import '../services/pre_order_service.dart';
import '../services/reservation_service.dart';
import '../services/table_inventory_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pre_order_page.dart';

class TableBookingPage extends StatefulWidget {
  final Restaurant restaurant;
  final String userId;

  const TableBookingPage({
    super.key,
    required this.restaurant,
    required this.userId,
  });

  @override
  State<TableBookingPage> createState() => _TableBookingPageState();
}

class _TableBookingPageState extends State<TableBookingPage> {
  DateTime _selectedDate = DateTime.now();
  int _numberOfGuests = 2;
  String? _selectedTime;
  bool _isLoading = false;
  String? _reservationId;
  String? _specialRequests;
  Map<int, int> _availability = {};
  int? _selectedCapacity;

  final List<String> _availableTimes = [
    '11:00', '11:30', '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
    '15:00', '15:30', '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
    '19:00', '19:30', '20:00', '20:30', '21:00', '21:30', '22:00', '22:30',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Table'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(widget.restaurant.cuisine),
                    Text(widget.restaurant.address),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Calendar
            Card(
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: _selectedDate,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    _selectedTime = null;
                    _availability = {};
                  });
                },
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Number of Guests
            Text(
              'Number of Guests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _numberOfGuests > 1
                      ? () => setState(() => _numberOfGuests--)
                      : null,
                ),
                Text(
                  _numberOfGuests.toString(),
                  style: const TextStyle(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _numberOfGuests < 10
                      ? () => setState(() => _numberOfGuests++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Time Selection
            Text(
              'Select Time',
              style: Theme.of(context).textTheme.titleLarge,
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
                    if (selected) {
                      final slotKey = TableInventoryService.buildSlotKey(_selectedDate, time);
                      // Start listening; silent if rules block
                      TableInventoryService.watchAvailability(
                        restaurantId: widget.restaurant.id,
                        slotKey: slotKey,
                      ).listen((map) {
                        if (mounted) {
                          setState(() => _availability = map);
                        }
                      });
                    } else {
                      setState(() => _availability = {});
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (_selectedTime != null) ...[
              Text(
                'Availability for ${_selectedTime!}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final List<int> caps = _availability.isEmpty
                    ? widget.restaurant.availableTables.map((t) => t.capacity).toSet().toList()
                    : _availability.keys.toList();
                caps.sort();
                final List<Widget> chips = caps.map((cap) {
                  final int available = _availability.isEmpty
                      ? widget.restaurant.availableTables.where((t) => t.capacity == cap && t.isAvailable).length
                      : (_availability[cap] ?? 0);
                  final bool selectable = available > 0 && _numberOfGuests <= cap;
                  final bool selected = _selectedCapacity == cap;
                  return ChoiceChip(
                    label: Text('${cap}p: $available available'),
                    selected: selected,
                    onSelected: selectable
                        ? (v) async {
                            if (!v) {
                              setState(() => _selectedCapacity = null);
                              return;
                            }
                            setState(() => _selectedCapacity = cap);
                            // Auto-book immediately on selection
                            await _bookTable();
                          }
                        : null,
                  );
                }).toList();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                );
              }),
              const SizedBox(height: 16),
            ],

            // Special Requests
            Text(
              'Special Requests (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'e.g., Birthday celebration, Allergies, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => _specialRequests = value,
            ),
            const SizedBox(height: 32),

            // Pre-order Option
            if (_selectedTime != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: const Text('Pre-order Food'),
                  subtitle: const Text('Order your food in advance to save time'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showPreOrderPage(),
                ),
              ),
            const SizedBox(height: 16),

            // No explicit confirmation button; booking happens on table selection
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              )),
          ],
        ),
      ),
    );
  }

  void _showPreOrderPage() {
    if (_selectedTime == null) return;

    final reservationDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(_selectedTime!.split(':')[0]),
      int.parse(_selectedTime!.split(':')[1]),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreOrderPage(
          restaurant: widget.restaurant,
          reservationId: _reservationId ?? '',
          userId: widget.userId,
          reservationDate: reservationDateTime,
          numberOfGuests: _numberOfGuests,
        ),
      ),
    );
  }

  Future<void> _bookTable() async {
    if (_selectedTime == null) return;

    setState(() => _isLoading = true);

    try {
      // Create a unique reservation ID
      _reservationId = DateTime.now().millisecondsSinceEpoch.toString();

      // Build slot key and hold a table atomically in Firestore
      final slotKey = TableInventoryService.buildSlotKey(_selectedDate, _selectedTime!);
      final chosenCapacity = await TableInventoryService.holdTable(
        restaurantId: widget.restaurant.id,
        slotKey: slotKey,
        // if user selected a capacity, prioritize that capacity
        minGuests: _selectedCapacity ?? _numberOfGuests,
      );

      // Find any table with chosenCapacity to label type/id (fallbacks if absent locally)
      final availableTable = widget.restaurant.availableTables.firstWhere(
        (t) => t.capacity == chosenCapacity,
        orElse: () => TableType(
          id: 'cap_$chosenCapacity',
          capacity: chosenCapacity,
          type: 'Standard',
          isAvailable: true,
          minimumSpend: 0,
        ),
      );

      final reservation = Reservation(
        id: _reservationId!,
        userId: widget.userId,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        restaurantImage: widget.restaurant.image,
        reservationDate: _selectedDate,
        reservationTime: _selectedTime!,
        numberOfGuests: _numberOfGuests,
        tableId: availableTable.id,
        tableType: availableTable.type,
        tableCapacity: chosenCapacity,
        slotKey: slotKey,
        status: ReservationStatus.confirmed,
        createdAt: DateTime.now(),
        specialRequests: _specialRequests?.trim(),
      );

      final createdId = await ReservationService.createReservation(reservation);
      _reservationId = createdId;

      // Fire notifications: to customer and to restaurant owner
      try {
        final bookingDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          int.parse(_selectedTime!.split(':')[0]),
          int.parse(_selectedTime!.split(':')[1]),
        );

        // Notify customer (confirmation)
        await NotificationService.createBookingNotification(
          userId: widget.userId,
          restaurantName: widget.restaurant.name,
          bookingId: createdId,
          restaurantId: widget.restaurant.id,
          bookingTime: bookingDateTime,
          guestCount: _numberOfGuests,
        );

        // Load owner user id from restaurants collection (fallback to restaurant.id)
        String ownerUserId = widget.restaurant.id;
        try {
          final doc = await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurant.id).get();
          final data = doc.data();
          if (data != null && data['ownerUserId'] is String) {
            ownerUserId = data['ownerUserId'];
          }
        } catch (_) {}

        // Notify restaurant owner (received)
        await NotificationService.createNotification(
          userId: ownerUserId,
          title: 'New Table Booking',
          body: 'New booking at ${widget.restaurant.name} for $_numberOfGuests guests',
          type: 'booking_received',
          data: {
            'bookingId': createdId,
            'restaurantId': widget.restaurant.id,
            'bookingTime': bookingDateTime.millisecondsSinceEpoch,
            'guestCount': _numberOfGuests,
            'byUserId': widget.userId,
          },
        );
      } catch (e) {
        // Don't fail the booking on notification errors
        // Optionally show a subtle message in debug
        // print('Notification error: $e');
      }
      
      // Silent success: no confirmation popups; keep user on page
    } catch (e) {
      // If hold succeeded but reservation failed, try to release seat
      if (_selectedTime != null && _reservationId != null) {
        try {
          final slotKey = TableInventoryService.buildSlotKey(_selectedDate, _selectedTime!);
          // We don't know chosenCapacity here reliably, so skip release; handled by expiry/admin.
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking table: $e'),
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
} 