import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/route_model.dart' as route_model;
import '../models/van_model.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';

class BookingManagementScreen extends StatefulWidget {
  const BookingManagementScreen({super.key});

  @override
  State<BookingManagementScreen> createState() => _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen> {
  final BookingService _bookingService = BookingService();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedStatusFilter = 'all';
  String _selectedPaymentFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  final List<String> _statusOptions = [
    'all',
    'active',
    'confirmed',
    'completed',
    'cancelled'
  ];

  final List<String> _paymentOptions = [
    'all',
    'pending',
    'paid',
    'failed',
    'refunded'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildFilters(),
            const SizedBox(height: AppConstants.defaultPadding),
            Expanded(child: _buildBookingsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Booking Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _exportBookings,
          icon: const Icon(Icons.file_download),
          label: const Text('Export'),
        ),
        const SizedBox(width: AppConstants.smallPadding),
        ElevatedButton.icon(
          onPressed: () => _showBookingDetails(context),
          icon: const Icon(Icons.add),
          label: const Text('Manual Booking'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by passenger name, email, or booking ID...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Booking Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatusFilter = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _paymentOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentFilter = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _selectedDateRange != null
                        ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                        : 'Select Date Range',
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: AppConstants.smallPadding),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDateRange = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
                const Spacer(),
                Text(
                  'Filters applied: ${_getActiveFiltersCount()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<List<Booking>>(
      stream: _getFilteredBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text('Error loading bookings: ${snapshot.error}'),
                const SizedBox(height: AppConstants.defaultPadding),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data ?? [];
        final filteredBookings = _applySearchFilter(bookings);

        if (filteredBookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  'No bookings found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Text(
                  'Try adjusting your filters or search criteria',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Card(
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    return _buildBookingRow(filteredBookings[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Passenger', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Route', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildBookingRow(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${booking.id.substring(0, 8)}...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${booking.numberOfSeats} seat(s)'),
                Text(booking.paymentMethod),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(booking.userEmail),
                Text(booking.passengerDetails.phone),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.routeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${booking.origin} → ${booking.destination}'),
                Text(DateFormat('h:mm a').format(booking.departureTime)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(DateFormat('MMM dd, yyyy').format(booking.bookingDate)),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.currencySymbol}${booking.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (booking.discountAmount > 0)
                  Text(
                    '- ${AppConstants.currencySymbol}${booking.discountAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildStatusChip(booking.bookingStatus, true),
                const SizedBox(height: 4),
                _buildStatusChip(booking.paymentStatus, false),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _showBookingDetails(context, booking),
                  icon: const Icon(Icons.visibility),
                  tooltip: 'View Details',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleBookingAction(value, booking),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                    const PopupMenuItem(value: 'refund', child: Text('Refund')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isBookingStatus) {
    Color color;
    String label = _formatStatus(status);

    if (isBookingStatus) {
      switch (status) {
        case 'active':
        case 'confirmed':
          color = Colors.blue;
          break;
        case 'completed':
          color = Colors.green;
          break;
        case 'cancelled':
        case 'failed':
          color = Colors.red;
          break;
        default:
          color = Colors.grey;
      }
    } else {
      switch (status) {
        case 'paid':
          color = Colors.green;
          break;
        case 'pending':
          color = Colors.orange;
          break;
        case 'failed':
          color = Colors.red;
          break;
        case 'refunded':
          color = Colors.purple;
          break;
        default:
          color = Colors.grey;
      }
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Stream<List<Booking>> _getFilteredBookingsStream() {
    if (_selectedDateRange != null) {
      return _bookingService.getBookingsByDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
    } else if (_selectedStatusFilter != 'all') {
      return _bookingService.getBookingsByStatus(_selectedStatusFilter);
    } else if (_selectedPaymentFilter != 'all') {
      return _bookingService.getBookingsByPaymentStatus(_selectedPaymentFilter);
    } else {
      return _bookingService.getBookingsStream();
    }
  }

  List<Booking> _applySearchFilter(List<Booking> bookings) {
    if (_searchQuery.isEmpty) return bookings;

    return bookings.where((booking) {
      return booking.userName.toLowerCase().contains(_searchQuery) ||
          booking.userEmail.toLowerCase().contains(_searchQuery) ||
          booking.id.toLowerCase().contains(_searchQuery) ||
          booking.routeName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedStatusFilter != 'all') count++;
    if (_selectedPaymentFilter != 'all') count++;
    if (_selectedDateRange != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _exportBookings() {
    // TODO: Implement CSV export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _showBookingDetails(BuildContext context, [Booking? booking]) {
    showDialog(
      context: context,
      builder: (context) => _BookingDetailsDialog(booking: booking),
    );
  }

  void _handleBookingAction(String action, Booking booking) async {
    try {
      switch (action) {
        case 'edit':
          _showBookingDetails(context, booking);
          break;
        case 'cancel':
          await _bookingService.updateBookingStatus(booking.id, 'cancelled');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking cancelled successfully')),
            );
          }
          break;
        case 'refund':
          await _bookingService.updatePaymentStatus(booking.id, 'refunded');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refund processed successfully')),
            );
          }
          break;
        case 'delete':
          _showDeleteConfirmation(booking);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Booking booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Delete Booking'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete this booking?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking ID: ${booking.id.substring(0, 8)}...', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Passenger: ${booking.userName}'),
                    Text('Route: ${booking.routeName}'),
                    Text('Seats: ${booking.seatIds.join(", ")}'),
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ This action cannot be undone!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteBooking(booking);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBooking(Booking booking) async {
    try {
      await _bookingService.deleteBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BookingDetailsDialog extends StatefulWidget {
  final Booking? booking;

  const _BookingDetailsDialog({this.booking});

  @override
  State<_BookingDetailsDialog> createState() => _BookingDetailsDialogState();
}

class _BookingDetailsDialogState extends State<_BookingDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    if (widget.booking == null) {
      return _ManualBookingDialog();
    }

    return AlertDialog(
      title: Text('Booking Details - ${widget.booking!.id.substring(0, 8)}...'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('Passenger Information', [
                'Name: ${widget.booking!.userName}',
                'Email: ${widget.booking!.userEmail}',
                'Phone: ${widget.booking!.passengerDetails.phone}',
              ]),
              _buildDetailSection('Trip Information', [
                'Route: ${widget.booking!.routeName}',
                'From: ${widget.booking!.origin}',
                'To: ${widget.booking!.destination}',
                'Departure: ${DateFormat('MMM dd, yyyy h:mm a').format(widget.booking!.departureTime)}',
                'Seats: ${widget.booking!.numberOfSeats}',
                'Seat IDs: ${widget.booking!.seatIds.join(', ')}',
              ]),
              _buildDetailSection('Payment Information', [
                'Base Price: ₱${widget.booking!.basePrice.toStringAsFixed(2)}',
                'Discount: ₱${widget.booking!.discountAmount.toStringAsFixed(2)}',
                'Total: ₱${widget.booking!.totalAmount.toStringAsFixed(2)}',
                'Method: ${widget.booking!.paymentMethod}',
                'Status: ${widget.booking!.paymentStatus}',
              ]),
              _buildDetailSection('Booking Information', [
                'Booking Date: ${DateFormat('MMM dd, yyyy h:mm a').format(widget.booking!.bookingDate)}',
                'Status: ${widget.booking!.bookingStatus}',
                'E-Ticket: ${widget.booking!.eTicketId ?? 'Not generated'}',
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(detail),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Manual Booking Dialog
class _ManualBookingDialog extends StatefulWidget {
  const _ManualBookingDialog();

  @override
  State<_ManualBookingDialog> createState() => _ManualBookingDialogState();
}

class _ManualBookingDialogState extends State<_ManualBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final BookingService _bookingService = BookingService();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // Selected values
  String? _selectedRouteId;
  route_model.Route? _selectedRoute;
  Van? _selectedVan; // The boarding van for the selected route
  DateTime _selectedDepartureTime = DateTime.now(); // Auto-set to current time
  String _selectedPaymentMethod = 'GCash';
  List<String> _selectedSeats = [];
  List<String> _reservedSeats = [];
  Map<String, bool> _seatDiscounts = {}; // Track discount per seat
  bool _isLoading = false;
  int _currentStep = 0;

  // Constants
  static const int _maxSeatsPerBooking = 5;
  static const double _discountPercentage = 13.33;
  static const double _bookingFee = 15.0;

  // Van seat layout based on image - Driver, DIB (door), then 4 rows x 4 columns
  final List<String> _seatLabels = [
    'D1A', 'D1B',  // Front two selectable seats
    'L1A', 'L1B', 'R1A', 'R1B',
    'L2A', 'L2B', 'R2A', 'R2B',
    'L3A', 'L3B', 'R3A', 'R3B',
    'L4A', 'L4B', 'R4A', 'R4B',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadReservedSeats() async {
    if (_selectedRouteId == null || _selectedVan == null) return;
    
    setState(() {
      _isLoading = true;
      _reservedSeats = []; // Start with empty list - all seats available
    });

    try {
      print('🔍 Loading reserved seats for route: $_selectedRouteId, van: ${_selectedVan!.plateNumber}');
      
      // Simple query - just get bookings for this route
      // Avoids Firestore index requirement
      QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('routeId', isEqualTo: _selectedRouteId)
          .get();

      print('📋 Found ${bookingSnapshot.docs.length} booking(s) for this route');

      // Filter in Dart to avoid complex Firestore query
      List<String> reserved = [];
      for (var doc in bookingSnapshot.docs) {
        try {
          final booking = Booking.fromFirestore(doc);
          
          // Only count active/confirmed bookings (not cancelled)
          if (booking.bookingStatus == 'confirmed' || booking.bookingStatus == 'active') {
            // Check if booking is for same day
            bool isSameDay = booking.departureTime.year == _selectedDepartureTime.year &&
                booking.departureTime.month == _selectedDepartureTime.month &&
                booking.departureTime.day == _selectedDepartureTime.day;
            
            if (isSameDay) {
              reserved.addAll(booking.seatIds);
              print('  ✓ Booking ${doc.id}: ${booking.seatIds.join(", ")} - ${booking.bookingStatus}');
            }
          }
        } catch (e) {
          print('  ⚠️ Error processing booking ${doc.id}: $e');
        }
      }

      setState(() {
        _reservedSeats = reserved;
        _isLoading = false;
      });
      
      print('✅ Reserved seats loaded: ${reserved.isEmpty ? "None (All available)" : reserved.join(", ")}');
    } catch (e) {
      print('❌ Error loading reserved seats: $e');
      setState(() {
        _isLoading = false;
        _reservedSeats = []; // On error, show all seats as available
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading seat status: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _toggleSeatSelection(String seatId) {
    // CRITICAL: Check if seat is already reserved - DO NOT allow selection
    if (_reservedSeats.contains(seatId)) {
      print('⛔ Seat $seatId is reserved - selection blocked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat $seatId is already reserved'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSeats.contains(seatId)) {
        // Deselect seat and remove discount state
        _selectedSeats.remove(seatId);
        _seatDiscounts.remove(seatId);
        print('✓ Deselected seat: $seatId');
      } else {
        // Check if max seats limit reached
        if (_selectedSeats.length >= _maxSeatsPerBooking) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $_maxSeatsPerBooking seats per booking'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        // Select seat and initialize discount state as false
        _selectedSeats.add(seatId);
        _seatDiscounts[seatId] = false; // Default: no discount
        print('✓ Selected seat: $seatId (Total: ${_selectedSeats.length})');
      }
    });
  }

  Future<void> _submitBooking() async {
    // Comprehensive validation checks
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select at least one seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select a route'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedVan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No boarding van available. Please select another route or try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate van capacity
    final int availableSeats = _selectedVan!.capacity - _selectedVan!.currentOccupancy;
    if (_selectedSeats.length > availableSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Not enough seats available. Only $availableSeats seats left in this van.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate van status
    if (_selectedVan!.status.toLowerCase() != 'boarding') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Van ${_selectedVan!.plateNumber} is not accepting bookings (Status: ${_selectedVan!.status})'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🎫 Creating booking for van ${_selectedVan!.plateNumber}...');
      
      // Calculate pricing with per-seat optional discount and booking fee
      final double basePrice = _selectedRoute!.basePrice * _selectedSeats.length;
      
      // Calculate total discount based on seats with discount applied
      double discountAmount = 0.0;
      int discountedSeatsCount = 0;
      for (String seatId in _selectedSeats) {
        if (_seatDiscounts[seatId] == true) {
          discountAmount += (_selectedRoute!.basePrice * (_discountPercentage / 100));
          discountedSeatsCount++;
        }
      }
      
      final double totalAmount = (basePrice - discountAmount) + _bookingFee;

      // Generate unique ticket ID
      final String ticketId = 'ADM-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create booking with ALL fields matching mobile app structure
      final booking = Booking(
        id: '', // Will be generated by Firestore
        userId: 'admin_manual_booking', // Special ID for admin-created bookings
        userName: _nameController.text.trim(),
        userEmail: _emailController.text.trim(),
        routeId: _selectedRouteId!,
        routeName: _selectedRoute!.name,
        origin: _selectedRoute!.origin,
        destination: _selectedRoute!.destination,
        departureTime: _selectedDepartureTime,
        bookingDate: DateTime.now(),
        seatIds: _selectedSeats,
        numberOfSeats: _selectedSeats.length,
        basePrice: basePrice,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: 'paid', // Auto-confirm as paid for admin bookings
        bookingStatus: 'confirmed', // Auto-confirm booking status
        qrCodeData: ticketId, // Use ticket ID as QR code data for scanning
        eTicketId: ticketId,
        passengerDetails: PassengerDetails(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
        discountApplied: discountedSeatsCount > 0 
            ? 'Discount applied to $discountedSeatsCount seat(s) (${_discountPercentage.toStringAsFixed(2)}%)' 
            : null,
        // Van details - REQUIRED by mobile app for display
        vanPlateNumber: _selectedVan!.plateNumber,
        vanDriverName: _selectedVan!.driver.name,
        vanDriverContact: _selectedVan!.driver.contact,
        // Cancellation fields - null for new bookings
        cancelledAt: null,
        cancellationReason: null,
        cancelledBy: null,
        // Completion fields - null for new bookings
        completedAt: null,
        completionReason: null,
        adminCompletion: null,
      );
      
      print('📋 Booking Details:');
      print('  • Ticket ID: $ticketId');
      print('  • Passenger: ${_nameController.text.trim()}');
      print('  • Route: ${_selectedRoute!.name}');
      print('  • Van: ${_selectedVan!.plateNumber}');
      print('  • Driver: ${_selectedVan!.driver.name} (${_selectedVan!.driver.contact})');
      print('  • Seats: ${_selectedSeats.join(", ")}');
      print('  • Total Amount: ₱${totalAmount.toStringAsFixed(2)}');
      print('  • Payment Status: paid (auto-confirmed)');
      print('  • Booking Status: confirmed (auto-confirmed)');

      await _bookingService.createBooking(booking);

      // Update van occupancy - ONLY for boarding van
      // The service will also update it, but this ensures immediate update for the selected boarding van
      if (_selectedVan!.status.toLowerCase() == 'boarding') {
        final int newOccupancy = _selectedVan!.currentOccupancy + _selectedSeats.length;
        await FirebaseFirestore.instance
            .collection('vans')
            .doc(_selectedVan!.id)
            .update({'currentOccupancy': newOccupancy});

        print('✅ Booking created successfully! Boarding van occupancy updated: ${_selectedVan!.currentOccupancy} → $newOccupancy');
      } else {
        print('✅ Booking created successfully! (Van status: ${_selectedVan!.status} - no occupancy update)');
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Booking Created & Auto-Confirmed!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text('Ticket ID: $ticketId'),
                Text('Van: ${_selectedVan!.plateNumber}'),
                Text('Seats: ${_selectedSeats.join(", ")}'),
                Text('Total: ₱${totalAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                const Text(
                  '✓ Payment Status: PAID',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Text(
                  '✓ Booking Status: CONFIRMED',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating booking: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.add_box, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Manual Booking',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Auto-confirmation info banner
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Booking - Auto-Confirmation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All bookings created here will be automatically confirmed and marked as PAID. The booking will be immediately visible in the mobile app.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified, color: Colors.green[600], size: 20),
                ],
              ),
            ),
            
            // Stepper
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 2) {
                    if (_currentStep == 0 && _selectedVan != null) {
                      _loadReservedSeats();
                      setState(() {
                        _currentStep += 1;
                      });
                    } else if (_currentStep == 1 && _formKey.currentState!.validate()) {
                      setState(() {
                        _currentStep += 1;
                      });
                    }
                  } else {
                    _submitBooking();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() {
                      _currentStep -= 1;
                    });
                  }
                },
                steps: [
                  Step(
                    title: const Text('Select Van'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    content: _buildVanSelection(),
                  ),
                  Step(
                    title: const Text('Passenger Information'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    content: _buildPassengerForm(),
                  ),
                  Step(
                    title: const Text('Select Seats'),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    content: _buildSeatSelection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Boarding Van', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Choose a van that is currently boarding passengers',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('vans')
              .where('status', isEqualTo: 'boarding')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Error state
            if (snapshot.hasError) {
              print('❌ Error loading vans: ${snapshot.error}');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error loading vans',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // No data or empty state
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('⚠️ No boarding vans found in database');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No boarding vans available at the moment. Please check van management.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }

            final vans = snapshot.data!.docs.map((doc) => Van.fromFirestore(doc)).toList();
            
            // Sort vans by queue position in Dart (avoids Firestore index requirement)
            vans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
            
            print('✅ Loaded ${vans.length} boarding van(s)');
            
            // Filter vans with available seats
            final vansWithSeats = vans.where((v) => (v.capacity - v.currentOccupancy) > 0).toList();
            final fullVans = vans.length - vansWithSeats.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary info box
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${vans.length} boarding van(s) found${fullVans > 0 ? ' ($fullVans full)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Van list
                ...vans.map((van) {
                final isSelected = _selectedVan?.id == van.id;
                final availableSeats = van.capacity - van.currentOccupancy;
                final occupancyPercentage = (van.currentOccupancy / van.capacity * 100).toInt();
                
                // Validate van status (additional check)
                final isValidBoardingStatus = van.status.toLowerCase().trim() == 'boarding';
                final hasAvailableSeats = availableSeats > 0;

                return GestureDetector(
                  onTap: () async {
                    // Validation: Only allow selection if van is truly in boarding status
                    if (!isValidBoardingStatus) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Cannot select van ${van.plateNumber}. Status must be "boarding" (current: ${van.status})'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    // Validation: Check if van has available seats
                    if (!hasAvailableSeats) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Van ${van.plateNumber} is full. No seats available.'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    // Validation: Check if van has a route assigned
                    if (van.currentRouteId == null || van.currentRouteId!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Van ${van.plateNumber} has no route assigned.'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _selectedVan = van;
                      _selectedSeats.clear();
                      _reservedSeats.clear();
                    });

                    print('🚐 Selected van: ${van.plateNumber} (Status: ${van.status}, Available: $availableSeats seats)');

                    // Get route information from van
                    try {
                      final routeDoc = await FirebaseFirestore.instance
                          .collection('routes')
                          .doc(van.currentRouteId)
                          .get();
                      
                      if (routeDoc.exists) {
                        setState(() {
                          _selectedRouteId = van.currentRouteId;
                          _selectedRoute = route_model.Route.fromFirestore(routeDoc);
                        });
                        print('✅ Route loaded: ${_selectedRoute!.name} (${_selectedRoute!.origin} → ${_selectedRoute!.destination})');
                      } else {
                        print('⚠️ Route document not found for ID: ${van.currentRouteId}');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Warning: Route information not found'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print('❌ Error loading route: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error loading route: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.blue[50] 
                          : (!hasAvailableSeats ? Colors.grey[100] : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.blue 
                            : (!hasAvailableSeats ? Colors.grey[400]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8, spreadRadius: 2)]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warning banner if van is full
                        if (!hasAvailableSeats)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.red[700], size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'VAN FULL - No seats available',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.blue 
                                    : (!hasAvailableSeats ? Colors.grey[400] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: isSelected 
                                    ? Colors.white 
                                    : (!hasAvailableSeats ? Colors.grey[600] : Colors.grey[700]),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        van.plateNumber,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.blue[900] : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'BOARDING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Driver: ${van.driver.name}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, color: Colors.blue, size: 28),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Route information
                        if (van.currentRouteId != null && van.currentRouteId!.isNotEmpty)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('routes')
                                .doc(van.currentRouteId)
                                .get(),
                            builder: (context, routeSnapshot) {
                              if (routeSnapshot.hasData && routeSnapshot.data!.exists) {
                                final route = route_model.Route.fromFirestore(routeSnapshot.data!);
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.route, size: 16, color: Colors.grey[700]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${route.origin} → ${route.destination}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₱${route.basePrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        const SizedBox(height: 8),
                        // Capacity information
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.event_seat, size: 16, color: Colors.grey[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Capacity: ${van.currentOccupancy}/${van.capacity}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: van.currentOccupancy / van.capacity,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        occupancyPercentage > 80
                                            ? Colors.red
                                            : occupancyPercentage > 50
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: availableSeats > 5 ? Colors.green[100] : Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$availableSeats seats left',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: availableSeats > 5 ? Colors.green[800] : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Queue position
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.format_list_numbered, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Queue Position: #${van.queuePosition}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Departure Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-set to Current Date & Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy - h:mm a').format(_selectedDepartureTime),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green[600]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Display selected van information
        if (_selectedVan != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Boarding Van',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedVan!.plateNumber} - Driver: ${_selectedVan!.driver.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Capacity: ${_selectedVan!.currentOccupancy}/${_selectedVan!.capacity} seats',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified, color: Colors.green[600]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPassengerForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Passenger Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter passenger name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter email address';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payment),
            ),
            items: const [
              DropdownMenuItem(value: 'GCash', child: Text('GCash')),
              DropdownMenuItem(value: 'Maya', child: Text('Maya')),
              DropdownMenuItem(value: 'Physical Payment', child: Text('Physical Payment')),
              DropdownMenuItem(value: 'PayPal', child: Text('PayPal')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSelection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.grey[300]!, 'Available', null),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Selected', null),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.red[300]!, 'Reserved (Locked)', Icons.lock),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Driver label
        const Center(
          child: Text(
            'DRIVER',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Seat layout matching the image
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Front row: Driver (non-selectable) + 2 DIB seats (selectable)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Driver seat (non-selectable)
                    Container(
                      width: 70,
                      height: 70,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.drive_eta, color: Colors.grey[600], size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'Driver',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // DIB1 (selectable)
                    _buildSeat(
                      'D1A',
                      _reservedSeats.contains('D1A'),
                      _selectedSeats.contains('D1B'),
                    ),
                    const SizedBox(width: 4),
                    // DIB2 (selectable)
                    _buildSeat(
                      'D1B',
                      _reservedSeats.contains('D1A'),
                      _selectedSeats.contains('D1B'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 12),
                // 4 rows × 4 columns of seats (L1A, L1B, R1A, R1B, etc.)
                ...List.generate(4, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left pair (L#A, L#B)
                        _buildSeat(
                          _seatLabels[2 + rowIndex * 4],  // Offset by 2 for DIB1, DIB2
                          _reservedSeats.contains(_seatLabels[2 + rowIndex * 4]),
                          _selectedSeats.contains(_seatLabels[2 + rowIndex * 4]),
                        ),
                        const SizedBox(width: 4),
                        _buildSeat(
                          _seatLabels[2 + rowIndex * 4 + 1],
                          _reservedSeats.contains(_seatLabels[2 + rowIndex * 4 + 1]),
                          _selectedSeats.contains(_seatLabels[2 + rowIndex * 4 + 1]),
                        ),
                        const SizedBox(width: 16), // Aisle gap
                        // Right pair (R#A, R#B)
                        _buildSeat(
                          _seatLabels[2 + rowIndex * 4 + 2],
                          _reservedSeats.contains(_seatLabels[2 + rowIndex * 4 + 2]),
                          _selectedSeats.contains(_seatLabels[2 + rowIndex * 4 + 2]),
                        ),
                        const SizedBox(width: 4),
                        _buildSeat(
                          _seatLabels[2 + rowIndex * 4 + 3],
                          _reservedSeats.contains(_seatLabels[2 + rowIndex * 4 + 3]),
                          _selectedSeats.contains(_seatLabels[2 + rowIndex * 4 + 3]),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.grey[300]!, 'Available', null),
            const SizedBox(width: 16),
            _buildLegendItem(Colors.blue, 'Selected', null),
            const SizedBox(width: 16),
            _buildLegendItem(Colors.red[300]!, 'Reserved', Icons.lock),
            const SizedBox(width: 16),
            _buildLegendItem(Colors.green, 'Discount', null),
          ],
        ),
        const SizedBox(height: 16),
        
        // Selected seats summary
        if (_selectedSeats.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_seat, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Seats (${_selectedSeats.length}/$_maxSeatsPerBooking)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedSeats.map((seat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        seat,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedRoute != null) ...[
                  const Divider(height: 24),
                  
                  // Per-Seat Pricing with Individual Discount Options
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Seat Pricing (${_discountPercentage.toStringAsFixed(2)}% discount)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Quick action: Apply discount to all seats
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                final hasAnyDiscount = _seatDiscounts.values.any((v) => v == true);
                                // Toggle: if any has discount, remove all. Otherwise, add to all
                                for (String seatId in _selectedSeats) {
                                  _seatDiscounts[seatId] = !hasAnyDiscount;
                                }
                              });
                            },
                            icon: Icon(
                              _seatDiscounts.values.any((v) => v == true) 
                                  ? Icons.remove_circle_outline 
                                  : Icons.add_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              _seatDiscounts.values.any((v) => v == true)
                                  ? 'Remove All'
                                  : 'Apply to All',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._selectedSeats.map((seatId) {
                        final bool hasDiscount = _seatDiscounts[seatId] ?? false;
                        final double baseSeatPrice = _selectedRoute!.basePrice;
                        final double discountedPrice = baseSeatPrice - (baseSeatPrice * (_discountPercentage / 100));
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasDiscount ? Colors.green[50] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasDiscount ? Colors.green[300]! : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Seat badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  seatId,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Discount checkbox
                              Checkbox(
                                value: hasDiscount,
                                onChanged: (value) {
                                  setState(() {
                                    _seatDiscounts[seatId] = value ?? false;
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              // Discount label
                              Expanded(
                                child: Text(
                                  hasDiscount ? 'Discount' : 'No discount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: hasDiscount ? Colors.green[700] : Colors.grey[600],
                                  ),
                                ),
                              ),
                              // Price
                              Text(
                                hasDiscount
                                    ? '₱${baseSeatPrice.toStringAsFixed(2)}'
                                    : '₱${baseSeatPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  decoration: hasDiscount ? TextDecoration.lineThrough : null,
                                  color: hasDiscount ? Colors.grey : Colors.black87,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '₱${discountedPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildPriceRow(
                    'Booking Fee',
                    '₱${_bookingFee.toStringAsFixed(2)}',
                    isSubtotal: false,
                  ),
                  const Divider(height: 16),
                  _buildPriceRow(
                    'Total Amount',
                    '₱${_calculateTotalAmount().toStringAsFixed(2)}',
                    isSubtotal: true,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_selectedSeats.length >= _maxSeatsPerBooking) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maximum seat limit reached ($_maxSeatsPerBooking seats)',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(String label, String amount, {required bool isSubtotal, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSubtotal ? 15 : 13,
            fontWeight: isSubtotal ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isSubtotal ? 16 : 13,
            fontWeight: isSubtotal ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isSubtotal ? Colors.blue[900] : null),
          ),
        ),
      ],
    );
  }

  double _calculateTotalAmount() {
    if (_selectedRoute == null || _selectedSeats.isEmpty) return 0.0;
    
    // Calculate total with per-seat discount
    double totalAmount = 0.0;
    for (String seatId in _selectedSeats) {
      double seatPrice = _selectedRoute!.basePrice;
      // Apply discount if this seat has discount enabled
      if (_seatDiscounts[seatId] == true) {
        seatPrice -= (seatPrice * (_discountPercentage / 100));
      }
      totalAmount += seatPrice;
    }
    
    // Add booking fee
    totalAmount += _bookingFee;
    
    return totalAmount;
  }

  Widget _buildSeat(String seatId, bool isReserved, bool isSelected) {
    Color backgroundColor;
    Color borderColor;
    IconData? lockIcon;
    
    if (isReserved) {
      // RESERVED SEATS - Red with lock icon
      backgroundColor = Colors.red[300]!;
      borderColor = Colors.red[700]!;
      lockIcon = Icons.lock;
    } else if (isSelected) {
      // SELECTED SEATS - Blue
      backgroundColor = Colors.blue;
      borderColor = Colors.blue[700]!;
    } else {
      // AVAILABLE SEATS - Grey
      backgroundColor = Colors.grey[300]!;
      borderColor = Colors.grey[400]!;
    }

    return InkWell(
      onTap: isReserved ? null : () => _toggleSeatSelection(seatId), // Disable tap for reserved seats
      child: Container(
        width: 50,
        height: 45,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                seatId,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isReserved || isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            // Lock icon for reserved seats
            if (lockIcon != null)
              Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  lockIcon,
                  size: 12,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData? icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon != null
              ? Center(
                  child: Icon(
                    icon,
                    size: 12,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
