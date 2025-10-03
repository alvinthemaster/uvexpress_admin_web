import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
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
                    value: _selectedStatusFilter,
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
                    value: _selectedPaymentFilter,
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
                  '₱${booking.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (booking.discountAmount > 0)
                  Text(
                    '- ₱${booking.discountAmount.toStringAsFixed(2)}',
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _BookingDetailsDialog extends StatelessWidget {
  final Booking? booking;

  const _BookingDetailsDialog({this.booking});

  @override
  Widget build(BuildContext context) {
    if (booking == null) {
      return AlertDialog(
        title: const Text('Manual Booking'),
        content: const SizedBox(
          width: 500,
          height: 400,
          child: Center(child: Text('Manual booking form coming soon')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('Booking Details - ${booking!.id.substring(0, 8)}...'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('Passenger Information', [
                'Name: ${booking!.userName}',
                'Email: ${booking!.userEmail}',
                'Phone: ${booking!.passengerDetails.phone}',
              ]),
              _buildDetailSection('Trip Information', [
                'Route: ${booking!.routeName}',
                'From: ${booking!.origin}',
                'To: ${booking!.destination}',
                'Departure: ${DateFormat('MMM dd, yyyy h:mm a').format(booking!.departureTime)}',
                'Seats: ${booking!.numberOfSeats}',
                'Seat IDs: ${booking!.seatIds.join(', ')}',
              ]),
              _buildDetailSection('Payment Information', [
                'Base Price: ₱${booking!.basePrice.toStringAsFixed(2)}',
                'Discount: ₱${booking!.discountAmount.toStringAsFixed(2)}',
                'Total: ₱${booking!.totalAmount.toStringAsFixed(2)}',
                'Method: ${booking!.paymentMethod}',
                'Status: ${booking!.paymentStatus}',
              ]),
              _buildDetailSection('Booking Information', [
                'Booking Date: ${DateFormat('MMM dd, yyyy h:mm a').format(booking!.bookingDate)}',
                'Status: ${booking!.bookingStatus}',
                'E-Ticket: ${booking!.eTicketId ?? 'Not generated'}',
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
            // TODO: Edit booking functionality
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
