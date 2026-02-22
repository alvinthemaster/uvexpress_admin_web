import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/booking_service.dart';
import '../services/van_service.dart';
import '../models/van_model.dart';
import '../models/booking_model.dart';
import '../models/rental_van_listing_model.dart';
import '../providers/van_provider.dart';
import '../providers/rental_van_listing_provider.dart';
import '../utils/constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final VanService _vanService = VanService();
  
  late TabController _tabController;
  String _selectedPeriod = 'week';
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _statistics = {};
  Map<int, int> _hourlyDistribution = {};
  bool _isLoading = true;

  // Trip History filters
  DateTime? _tripHistoryStartDate;
  DateTime? _tripHistoryEndDate;
  String? _selectedVehicleFilter;
  String? _selectedRouteFilter;
  List<Map<String, dynamic>> _completedTrips = [];
  bool _isLoadingTrips = false;

  final List<String> _periodOptions = ['day', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _completedTrips.isEmpty) {
        _loadTripHistory();
      }
    });
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DateTimeRange range = _getDateRange();
      
      final statistics = await _bookingService.getBookingStatistics(
        range.start,
        range.end,
      );
      
      final hourlyDistribution = await _bookingService.getHourlyBookingDistribution(
        _selectedDate,
      );

      // Get active vans count from van provider
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      final activeVansCount = vanProvider.activeVansCount;

      setState(() {
        _statistics = statistics;
        _statistics['activeVans'] = activeVansCount; // Replace activeUsers with activeVans
        _hourlyDistribution = hourlyDistribution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  Future<void> _loadTripHistory() async {
    setState(() {
      _isLoadingTrips = true;
    });

    try {
      // Note: We'll use StreamBuilder in the UI instead of loading here
      // This method just sets the loading state
      setState(() {
        _isLoadingTrips = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTrips = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trip history: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _buildTripList(List<Booking> bookings, List<Van> vans) {
    final vanMap = {for (var van in vans) van.plateNumber: van};

    // Group bookings by trip (van + departure time + route)
    Map<String, List<Booking>> tripGroups = {};
    
    for (var booking in bookings) {
      // Only include completed trips
      if (booking.bookingStatus.toLowerCase() == 'completed' && booking.vanPlateNumber != null) {
        // Create a unique trip key: vanPlate_date_route
        final tripDate = DateFormat('yyyy-MM-dd').format(booking.departureTime);
        final tripKey = '${booking.vanPlateNumber}_${tripDate}_${booking.routeId}';
        
        if (!tripGroups.containsKey(tripKey)) {
          tripGroups[tripKey] = [];
        }
        tripGroups[tripKey]!.add(booking);
      }
    }

    // Convert to trip records
    List<Map<String, dynamic>> trips = [];
    tripGroups.forEach((tripKey, tripBookings) {
      if (tripBookings.isNotEmpty) {
        final firstBooking = tripBookings.first;
        final van = vanMap[firstBooking.vanPlateNumber];
        
        trips.add({
          'tripId': tripKey,
          'vanPlateNumber': firstBooking.vanPlateNumber,
          'vanName': firstBooking.vanPlateNumber ?? 'Unknown Vehicle',
          'vehicleType': van?.vehicleType ?? 'van',
          'routeId': firstBooking.routeId,
          'routeName': firstBooking.routeName,
          'origin': firstBooking.origin,
          'destination': firstBooking.destination,
          'departureTime': firstBooking.departureTime,
          'totalPassengers': tripBookings.length,
          'bookings': tripBookings,
        });
      }
    });

    // Sort by departure time (most recent first)
    trips.sort((a, b) => (b['departureTime'] as DateTime).compareTo(a['departureTime'] as DateTime));

    // Apply filters
    return _applyTripFilters(trips);
  }

  List<Map<String, dynamic>> _applyTripFilters(List<Map<String, dynamic>> trips) {
    return trips.where((trip) {
      // Date range filter
      if (_tripHistoryStartDate != null) {
        final tripDate = trip['departureTime'] as DateTime;
        if (tripDate.isBefore(_tripHistoryStartDate!)) return false;
      }
      if (_tripHistoryEndDate != null) {
        final tripDate = trip['departureTime'] as DateTime;
        if (tripDate.isAfter(_tripHistoryEndDate!.add(const Duration(days: 1)))) return false;
      }

      // Vehicle filter
      if (_selectedVehicleFilter != null && _selectedVehicleFilter!.isNotEmpty) {
        if (trip['vanPlateNumber'] != _selectedVehicleFilter) return false;
      }

      // Route filter
      if (_selectedRouteFilter != null && _selectedRouteFilter!.isNotEmpty) {
        if (trip['routeId'] != _selectedRouteFilter) return false;
      }

      return true;
    }).toList();
  }

  DateTimeRange _getDateRange() {
    final now = _selectedDate;
    
    switch (_selectedPeriod) {
      case 'day':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59),
        );
      case 'month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case 'year':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: _buildHeader(),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.history), text: 'Trip History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnalyticsTab(),
                _buildTripHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: AppConstants.defaultPadding),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAnalytics(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Analytics & Reports',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _exportReport,
          icon: const Icon(Icons.download),
          label: const Text('Export Report'),
        ),
        const SizedBox(width: AppConstants.smallPadding),
        IconButton(
          onPressed: _loadAnalytics,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Data',
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Text(
              'Period:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            ...(_periodOptions.map((period) => Padding(
              padding: const EdgeInsets.only(right: AppConstants.smallPadding),
              child: ChoiceChip(
                label: Text(period.toUpperCase()),
                selected: _selectedPeriod == period,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                    _loadAnalytics();
                  }
                },
              ),
            ))),
            const Spacer(),
            TextButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.date_range),
              label: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatsCards(),
          const SizedBox(height: AppConstants.defaultPadding),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRevenueChart()),
              const SizedBox(width: AppConstants.defaultPadding),
              Expanded(child: _buildPaymentMethodChart()),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildHourlyDistributionChart()),
              const SizedBox(width: AppConstants.defaultPadding),
              Expanded(child: _buildVanUtilizationCard()),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildRentalVansSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          'Total Bookings',
          _statistics['totalBookings']?.toString() ?? '0',
          Icons.book_online,
          Colors.blue,
        )),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(child: _buildStatCard(
          'Total User Accounts',
          _statistics['totalUsers']?.toString() ?? '0',
          Icons.account_circle,
          Colors.green,
        )),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(child: _buildActiveVansCard()),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(child: _buildStatCard(
          'New Users Today',
          _statistics['newUsersToday']?.toString() ?? '0',
          Icons.person_add,
          Colors.purple,
        )),
      ],
    );
  }

  Widget _buildActiveVansCard() {
    return StreamBuilder<List<Van>>(
      stream: _vanService.getVansStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildStatCard(
            'Active Vans',
            '0',
            Icons.local_shipping,
            Colors.orange,
          );
        }

        final vans = snapshot.data!;
        final activeVans = vans.where((van) => van.isActive).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Show icons with status colors
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: activeVans.take(5).map((van) {
                        final statusColor = _getStatusColor(van.status);
                        final vehicleIcon = van.vehicleType.toLowerCase() == 'bus' 
                            ? Icons.directions_bus 
                            : Icons.local_shipping;
                        
                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Icon(
                            vehicleIcon,
                            color: statusColor,
                            size: 16,
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPeriodLabel(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Text(
                  activeVans.length.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  'Active Vans',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Rental Vans Summary Card ─────────────────────────────────────────────

  Widget _buildRentalVansSummaryCard() {
    return Consumer<RentalVanListingProvider>(
      builder: (_, provider, __) {
        final listings = provider.listings;
        final statusBreakdown = <String, int>{};
        for (final s in RentalVanListing.rentalStatuses) {
          statusBreakdown[s] = listings.where((l) => l.rentalStatus == s).length;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.car_rental, color: Colors.teal[700], size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Rental Vans Overview',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal[200]!),
                      ),
                      child: Text(
                        '${listings.length} total listing${listings.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.teal[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.defaultPadding),

                // ── Status breakdown chips ──────────────────────────────
                LayoutBuilder(builder: (ctx, constraints) {
                  return Wrap(
                    spacing: AppConstants.smallPadding,
                    runSpacing: AppConstants.smallPadding,
                    children: RentalVanListing.rentalStatuses.map((s) {
                      final color = Color(
                          RentalVanListing.rentalStatusColors[s] ??
                              0xFF9E9E9E);
                      final count = statusBreakdown[s] ?? 0;
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 110,
                          maxWidth: (constraints.maxWidth > 700
                              ? constraints.maxWidth / 5
                              : constraints.maxWidth > 400
                                  ? constraints.maxWidth / 3
                                  : constraints.maxWidth / 2) -
                              AppConstants.smallPadding,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: color.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                  radius: 5, backgroundColor: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s[0].toUpperCase() + s.substring(1),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: color),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),

                if (listings.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  const Divider(),
                  const SizedBox(height: AppConstants.smallPadding),

                  // ── Listings table ────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                            label: Text('Plate',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Brand / Model',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Type',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Price / Day',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            numeric: true),
                        DataColumn(
                            label: Text('Rental Status',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Visible',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                      ],
                      rows: listings.map((l) {
                        final fmt = NumberFormat.currency(
                            symbol: '₱', decimalDigits: 0);
                        final rsColor = Color(
                            RentalVanListing.rentalStatusColors[
                                    l.rentalStatus] ??
                                0xFF9E9E9E);
                        return DataRow(cells: [
                          DataCell(Text(l.plateNumber,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(
                              l.brand.isNotEmpty ? l.brand : '—')),
                          DataCell(Text(l.vehicleType[0].toUpperCase() +
                              l.vehicleType.substring(1))),
                          DataCell(Text(fmt.format(l.pricePerDay))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rsColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              l.rentalStatus[0].toUpperCase() +
                                  l.rentalStatus.substring(1),
                              style: TextStyle(
                                  color: rsColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11),
                            ),
                          )),
                          DataCell(Icon(
                            l.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: l.isAvailable
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();
    
    switch (normalizedStatus) {
      case 'boarding':
      case 'loading':
        return Colors.green; // Actively boarding passengers
      case 'in_queue':
      case 'in-queue':
      case 'queue':
      case 'ready':
      case 'available':
      case 'active':
        return Colors.blue; // Ready/waiting in queue
      case 'in_transit':
      case 'in-transit':
      case 'transit':
      case 'traveling':
        return Colors.purple; // On the road
      case 'maintenance':
      case 'under_maintenance':
      case 'under-maintenance':
        return Colors.red; // Under maintenance
      case 'inactive':
      case 'offline':
      case 'disabled':
        return Colors.grey; // Inactive
      case 'full':
        return Colors.orange; // Full capacity
      default:
        return Colors.blueGrey; // Unknown status
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getPeriodLabel(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Registration Trends',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 200,
              child: _buildUserRegistrationChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRegistrationChart() {
    final totalUsers = _statistics['totalUsers']?.toDouble() ?? 0.0;
    final activeVans = _statistics['activeVans']?.toDouble() ?? 0.0;
    final newUsersToday = _statistics['newUsersToday']?.toDouble() ?? 0.0;
    
    final total = totalUsers + activeVans + newUsersToday;
    
    if (total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No data available',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      );
    }

    final List<PieChartSectionData> sections = [
      PieChartSectionData(
        value: totalUsers,
        title: '${totalUsers.toInt()}',
        color: Colors.blue,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: null,
      ),
      PieChartSectionData(
        value: activeVans,
        title: '${activeVans.toInt()}',
        color: Colors.green,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: newUsersToday,
        title: '${newUsersToday.toInt()}',
        color: Colors.orange,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Optional: Add touch interaction
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildLegendItem('Total Users', Colors.blue, totalUsers.toInt()),
            _buildLegendItem('Active Vans', Colors.green, activeVans.toInt()),
            _buildLegendItem('New Today', Colors.orange, newUsersToday.toInt()),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Activity Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 200,
              child: _buildUserActivityChart(),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildUserActivityLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyDistributionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Booking Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 200,
              child: _hourlyDistribution.isEmpty
                  ? const Center(child: Text('No hourly data available'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString());
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 4,
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toInt()}:00');
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _hourlyDistribution.entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                                .toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
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

  Widget _buildVanUtilizationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Van Utilization',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            StreamBuilder<List<Van>>(
              stream: _vanService.getVansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('No van data available')),
                  );
                }

                final vans = snapshot.data!;
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: vans.length,
                    itemBuilder: (context, index) {
                      final van = vans[index];
                      final utilizationPercentage = van.capacity > 0 
                          ? (van.currentOccupancy / van.capacity * 100)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(van.plateNumber),
                                const Spacer(),
                                Text('${van.currentOccupancy}/${van.capacity}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: utilizationPercentage / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                utilizationPercentage > 80
                                    ? Colors.red
                                    : utilizationPercentage > 60
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart() {
    final Map<String, int> userActivityData = {
      'Total Users': _statistics['totalUsers'] ?? 0,
      'Active Vans': _statistics['activeVans'] ?? 0,
      'New Users Today': _statistics['newUsersToday'] ?? 0,
    };

    if (userActivityData.values.every((value) => value == 0)) {
      return const Center(child: Text('No user activity data available'));
    }

    return PieChart(
      PieChartData(
        sections: _createUserActivityPieChartSections(userActivityData),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  List<PieChartSectionData> _createUserActivityPieChartSections(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b).toDouble();
    if (total == 0) return [];

    final colors = [Colors.blue, Colors.green, Colors.orange];
    int colorIndex = 0;

    return data.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildUserActivityLegend() {
    final Map<String, int> userActivityData = {
      'Total Users': _statistics['totalUsers'] ?? 0,
      'Active Vans': _statistics['activeVans'] ?? 0,
      'New Users Today': _statistics['newUsersToday'] ?? 0,
    };

    final colors = [Colors.blue, Colors.green, Colors.orange];
    int colorIndex = 0;

    return Column(
      children: userActivityData.entries.map((entry) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.key),
              const Spacer(),
              Text('${entry.value}'),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'day':
        return 'TODAY';
      case 'week':
        return 'THIS WEEK';
      case 'month':
        return 'THIS MONTH';
      case 'year':
        return 'THIS YEAR';
      default:
        return 'PERIOD';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAnalytics();
    }
  }

  // ==================== TRIP HISTORY TAB ====================

  Widget _buildTripHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          _buildTripHistoryFilters(),
          const SizedBox(height: AppConstants.defaultPadding),
          Expanded(
            child: _buildTripHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _tripHistoryStartDate = null;
                      _tripHistoryEndDate = null;
                      _selectedVehicleFilter = null;
                      _selectedRouteFilter = null;
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                        initialDateRange: _tripHistoryStartDate != null && _tripHistoryEndDate != null
                            ? DateTimeRange(start: _tripHistoryStartDate!, end: _tripHistoryEndDate!)
                            : null,
                      );
                      if (picked != null) {
                        setState(() {
                          _tripHistoryStartDate = picked.start;
                          _tripHistoryEndDate = picked.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _tripHistoryStartDate != null && _tripHistoryEndDate != null
                          ? '${DateFormat('MMM dd').format(_tripHistoryStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_tripHistoryEndDate!)}'
                          : 'Select Date Range',
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: StreamBuilder<List<Van>>(
                    stream: _vanService.getVansStream(),
                    builder: (context, snapshot) {
                      final vans = snapshot.data ?? [];
                      return DropdownButtonFormField<String?>(
                        value: _selectedVehicleFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Vehicle',
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Vehicles')),
                          ...vans.map((van) => DropdownMenuItem(
                            value: van.plateNumber,
                            child: Text('${van.plateNumber} (${van.vehicleType})'),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicleFilter = value;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Route',
                      prefixIcon: Icon(Icons.route),
                      hintText: 'Enter route name',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedRouteFilter = value.isEmpty ? null : value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHistoryList() {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.getBookingsStream(),
      builder: (context, bookingSnapshot) {
        if (bookingSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!bookingSnapshot.hasData || bookingSnapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No trip history available', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return StreamBuilder<List<Van>>(
          stream: _vanService.getVansStream(),
          builder: (context, vanSnapshot) {
            if (!vanSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = _buildTripList(bookingSnapshot.data!, vanSnapshot.data!);

            if (trips.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No trips match the selected filters', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return Card(
              child: ListView.separated(
                itemCount: trips.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _buildTripListItem(trip);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTripListItem(Map<String, dynamic> trip) {
    final vehicleIcon = trip['vehicleType'] == 'bus' ? Icons.directions_bus : Icons.local_shipping;
    final departureTime = trip['departureTime'] as DateTime;
    final bookings = trip['bookings'] as List<Booking>;

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withOpacity(0.1),
        child: Icon(vehicleIcon, color: Colors.blue),
      ),
      title: Row(
        children: [
          Text(
            trip['vanName'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Text(
              trip['vehicleType'].toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.route, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${trip['origin']} → ${trip['destination']}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(departureTime),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people, size: 16, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '${trip['totalPassengers']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
      children: [
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary Section
              _buildBookingSummary(bookings),
              const SizedBox(height: AppConstants.largePadding),
              
              // Passenger Details by Status
              _buildPassengersByStatus(bookings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSummary(List<Booking> bookings) {
    // Calculate summary statistics
    final confirmedCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'confirmed').length;
    final activeCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'active').length;
    final completedCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'completed').length;
    final cancelledCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'cancelled').length;
    
    final totalRevenue = bookings.where((b) => b.paymentStatus == 'paid').fold<double>(0, (sum, b) => sum + b.totalAmount);
    final pendingRevenue = bookings.where((b) => b.paymentStatus == 'pending').fold<double>(0, (sum, b) => sum + b.totalAmount);
    final totalDiscount = bookings.fold<double>(0, (sum, b) => sum + b.discountAmount);
    
    final totalSeats = bookings.fold<int>(0, (sum, b) => sum + b.numberOfSeats);
    
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Booking Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _exportToPdf(bookings),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Status Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Confirmed',
                    confirmedCount.toString(),
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Active',
                    activeCount.toString(),
                    Icons.directions_bus,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Completed',
                    completedCount.toString(),
                    Icons.done_all,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Cancelled',
                    cancelledCount.toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Financial Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Total Revenue',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'Paid bookings',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.green[200],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pending_actions, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${pendingRevenue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            'Awaiting payment',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.green[200],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.discount, size: 16, color: Colors.red[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Total Discount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${totalDiscount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          Text(
                            'Savings applied',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.green[200],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.airline_seat_recline_normal, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Total Seats',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalSeats.toString(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          Text(
                            '${bookings.length} booking${bookings.length > 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
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
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersByStatus(List<Booking> bookings) {
    // Group bookings by status
    final Map<String, List<Booking>> bookingsByStatus = {
      'confirmed': bookings.where((b) => b.bookingStatus.toLowerCase() == 'confirmed').toList(),
      'active': bookings.where((b) => b.bookingStatus.toLowerCase() == 'active').toList(),
      'completed': bookings.where((b) => b.bookingStatus.toLowerCase() == 'completed').toList(),
      'cancelled': bookings.where((b) => b.bookingStatus.toLowerCase() == 'cancelled').toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passenger Details by Status',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        
        // Confirmed Bookings
        if (bookingsByStatus['confirmed']!.isNotEmpty)
          _buildStatusSection(
            'Confirmed',
            bookingsByStatus['confirmed']!,
            Colors.blue,
            Icons.check_circle,
          ),
        
        // Active Bookings
        if (bookingsByStatus['active']!.isNotEmpty)
          _buildStatusSection(
            'Active',
            bookingsByStatus['active']!,
            Colors.green,
            Icons.directions_bus,
          ),
        
        // Completed Bookings
        if (bookingsByStatus['completed']!.isNotEmpty)
          _buildStatusSection(
            'Completed',
            bookingsByStatus['completed']!,
            Colors.purple,
            Icons.done_all,
          ),
        
        // Cancelled Bookings
        if (bookingsByStatus['cancelled']!.isNotEmpty)
          _buildStatusSection(
            'Cancelled',
            bookingsByStatus['cancelled']!,
            Colors.red,
            Icons.cancel,
          ),
      ],
    );
  }

  Widget _buildStatusSection(String status, List<Booking> bookings, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$status (${bookings.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...bookings.map((booking) => _buildPassengerCard(booking)),
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }

  Widget _buildPassengerCard(Booking booking) {
    final statusColor = _getBookingStatusColor(booking.bookingStatus);
    final statusIcon = _getBookingStatusIcon(booking.bookingStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.passengerDetails.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        booking.passengerDetails.phone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.email, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.passengerDetails.email,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.airline_seat_recline_normal, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Seats: ${booking.seatIds.join(', ')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.confirmation_number, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        booking.eTicketId ?? 'N/A',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    booking.bookingStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${booking.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  booking.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: booking.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getBookingStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'active':
        return Icons.directions_bus;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _exportToPdf(List<Booking> bookings) async {
    final pdf = pw.Document();
    
    // Calculate statistics
    final confirmedCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'confirmed').length;
    final activeCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'active').length;
    final completedCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'completed').length;
    final cancelledCount = bookings.where((b) => b.bookingStatus.toLowerCase() == 'cancelled').length;
    
    final totalRevenue = bookings.where((b) => b.paymentStatus == 'paid').fold<double>(0, (sum, b) => sum + b.totalAmount);
    final pendingRevenue = bookings.where((b) => b.paymentStatus == 'pending').fold<double>(0, (sum, b) => sum + b.totalAmount);
    final totalDiscount = bookings.fold<double>(0, (sum, b) => sum + b.discountAmount);
    final totalSeats = bookings.fold<int>(0, (sum, b) => sum + b.numberOfSeats);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Trip History Report',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Summary Statistics
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Booking Summary',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                  
                  // Status counts
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfSummaryItem('Confirmed', confirmedCount.toString()),
                      _buildPdfSummaryItem('Active', activeCount.toString()),
                      _buildPdfSummaryItem('Completed', completedCount.toString()),
                      _buildPdfSummaryItem('Cancelled', cancelledCount.toString()),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  
                  // Financial summary
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfSummaryItem('Total Revenue', 'PHP ${totalRevenue.toStringAsFixed(2)}'),
                      _buildPdfSummaryItem('Pending', 'PHP ${pendingRevenue.toStringAsFixed(2)}'),
                      _buildPdfSummaryItem('Total Discount', 'PHP ${totalDiscount.toStringAsFixed(2)}'),
                      _buildPdfSummaryItem('Total Seats', totalSeats.toString()),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Bookings Table
            pw.Text(
              'Booking Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Passenger'),
                    _buildTableHeader('Route'),
                    _buildTableHeader('Seats'),
                    _buildTableHeader('Amount'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Payment'),
                  ],
                ),
                // Data rows
                ...bookings.map((booking) => pw.TableRow(
                  children: [
                    _buildTableCell(booking.passengerDetails.name),
                    _buildTableCell('${booking.origin} to ${booking.destination}'),
                    _buildTableCell(booking.numberOfSeats.toString()),
                    _buildTableCell('PHP ${booking.totalAmount.toStringAsFixed(2)}'),
                    _buildTableCell(booking.bookingStatus),
                    _buildTableCell(booking.paymentStatus),
                  ],
                )),
              ],
            ),
          ];
        },
      ),
    );
    
    // Show print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'trip_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  Future<void> _exportReport() async {
    try {
      final pdf = pw.Document();
      
      // Get all data needed for the report
      final DateTimeRange range = _getDateRange();
      final vans = await _vanService.getVansStream().first;
      final activeVans = vans.where((van) => van.isActive).toList();
      
      // Get all bookings for the period
      final bookingsSnapshot = await _bookingService.getBookingsByDateRange(range.start, range.end).first;
      
      // Calculate comprehensive statistics
      final totalBookings = bookingsSnapshot.length;
      final activeBookings = bookingsSnapshot.where((b) => b.bookingStatus.toLowerCase() == 'active').length;
      final completedBookings = bookingsSnapshot.where((b) => b.bookingStatus.toLowerCase() == 'completed').length;
      final cancelledBookings = bookingsSnapshot.where((b) => b.bookingStatus.toLowerCase() == 'cancelled').length;
      final confirmedBookings = bookingsSnapshot.where((b) => b.bookingStatus.toLowerCase() == 'confirmed').length;
      
      final totalRevenue = bookingsSnapshot.where((b) => b.paymentStatus == 'paid').fold<double>(0, (sum, b) => sum + b.totalAmount);
      final pendingRevenue = bookingsSnapshot.where((b) => b.paymentStatus == 'pending').fold<double>(0, (sum, b) => sum + b.totalAmount);
      final totalDiscount = bookingsSnapshot.fold<double>(0, (sum, b) => sum + b.discountAmount);
      final totalSeats = bookingsSnapshot.fold<int>(0, (sum, b) => sum + b.numberOfSeats);
      
      // Revenue by payment method
      final revenueByMethod = <String, double>{};
      for (var booking in bookingsSnapshot.where((b) => b.paymentStatus == 'paid')) {
        revenueByMethod[booking.paymentMethod] = (revenueByMethod[booking.paymentMethod] ?? 0) + booking.totalAmount;
      }
      
      // Top routes by bookings
      final routeBookings = <String, int>{};
      for (var booking in bookingsSnapshot) {
        final routeKey = '${booking.origin} to ${booking.destination}';
        routeBookings[routeKey] = (routeBookings[routeKey] ?? 0) + 1;
      }
      final topRoutes = routeBookings.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Fetch rental listings before entering the PDF builder where
      // pw.Context shadows Flutter's BuildContext.
      final rentalListings =
          Provider.of<RentalVanListingProvider>(context, listen: false)
              .listings;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'UVExpress Analytics Report',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Period: ${_getPeriodLabel()}',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                            ),
                            pw.Text(
                              '${DateFormat('MMM dd, yyyy').format(range.start)} - ${DateFormat('MMM dd, yyyy').format(range.end)}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                        pw.Text(
                          'Generated: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Key Metrics Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Key Metrics',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPdfMetricCard('Total Bookings', totalBookings.toString(), PdfColors.blue),
                        _buildPdfMetricCard('Active Vans', activeVans.length.toString(), PdfColors.orange),
                        _buildPdfMetricCard('Total Users', (_statistics['totalUsers'] ?? 0).toString(), PdfColors.green),
                        _buildPdfMetricCard('New Users Today', (_statistics['newUsersToday'] ?? 0).toString(), PdfColors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Booking Status Breakdown
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Booking Status Breakdown',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPdfSummaryItem('Confirmed', confirmedBookings.toString()),
                        _buildPdfSummaryItem('Active', activeBookings.toString()),
                        _buildPdfSummaryItem('Completed', completedBookings.toString()),
                        _buildPdfSummaryItem('Cancelled', cancelledBookings.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Financial Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Financial Summary',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPdfSummaryItem('Total Revenue (Paid)', 'PHP ${totalRevenue.toStringAsFixed(2)}'),
                        _buildPdfSummaryItem('Pending Revenue', 'PHP ${pendingRevenue.toStringAsFixed(2)}'),
                        _buildPdfSummaryItem('Total Discount', 'PHP ${totalDiscount.toStringAsFixed(2)}'),
                        _buildPdfSummaryItem('Total Seats Sold', totalSeats.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Revenue by Payment Method
              if (revenueByMethod.isNotEmpty) ...[
                pw.Text(
                  'Revenue by Payment Method',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableHeader('Payment Method'),
                        _buildTableHeader('Revenue'),
                        _buildTableHeader('Percentage'),
                      ],
                    ),
                    ...revenueByMethod.entries.map((entry) {
                      final percentage = (entry.value / totalRevenue * 100).toStringAsFixed(1);
                      return pw.TableRow(
                        children: [
                          _buildTableCell(entry.key),
                          _buildTableCell('PHP ${entry.value.toStringAsFixed(2)}'),
                          _buildTableCell('$percentage%'),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
              
              // Top Routes
              if (topRoutes.isNotEmpty) ...[
                pw.Text(
                  'Top Routes (by Bookings)',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableHeader('Rank'),
                        _buildTableHeader('Route'),
                        _buildTableHeader('Bookings'),
                      ],
                    ),
                    ...topRoutes.take(10).toList().asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final route = entry.value;
                      return pw.TableRow(
                        children: [
                          _buildTableCell(rank.toString()),
                          _buildTableCell(route.key),
                          _buildTableCell(route.value.toString()),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
              
              // Active Vehicles Summary
              pw.Text(
                'Active Vehicles Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Plate Number'),
                      _buildTableHeader('Type'),
                      _buildTableHeader('Status'),
                      _buildTableHeader('Capacity'),
                    ],
                  ),
                  ...activeVans.map((van) => pw.TableRow(
                    children: [
                      _buildTableCell(van.plateNumber),
                      _buildTableCell(van.vehicleType),
                      _buildTableCell(van.status),
                      _buildTableCell('${van.capacity} seats'),
                    ],
                  )),
                ],
              ),

              // Rental Vans Summary
              pw.SizedBox(height: 24),
              pw.Text(
                'Rental Vans Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ...() {
                if (rentalListings.isEmpty) {
                  return <pw.Widget>[
                    pw.Text(
                      'No rental van listings configured.',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey700),
                    ),
                  ];
                }
                final statusBreakdown = <String, int>{};
                for (final s in RentalVanListing.rentalStatuses) {
                  statusBreakdown[s] =
                      rentalListings.where((l) => l.rentalStatus == s).length;
                }
                return <pw.Widget>[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.teal50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Total: ${rentalListings.length}  |  '
                          'Visible: ${rentalListings.where((l) => l.isAvailable).length}  |  '
                          'Hidden: ${rentalListings.where((l) => !l.isAvailable).length}',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children:
                              RentalVanListing.rentalStatuses.map((s) {
                            return pw.Column(children: [
                              pw.Text(
                                (statusBreakdown[s] ?? 0).toString(),
                                style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text(
                                s[0].toUpperCase() + s.substring(1),
                                style: const pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.5),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                      5: const pw.FlexColumnWidth(0.8),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableHeader('Plate'),
                          _buildTableHeader('Brand / Model'),
                          _buildTableHeader('Type'),
                          _buildTableHeader('Price / Day'),
                          _buildTableHeader('Rental Status'),
                          _buildTableHeader('Visible'),
                        ],
                      ),
                      ...rentalListings.map(
                        (l) => pw.TableRow(children: [
                          _buildTableCell(l.plateNumber),
                          _buildTableCell(
                              l.brand.isNotEmpty ? l.brand : '—'),
                          _buildTableCell(l.vehicleType[0].toUpperCase() +
                              l.vehicleType.substring(1)),
                          _buildTableCell(
                              '₱${NumberFormat('#,##0', 'en_US').format(l.pricePerDay)}/day'),
                          _buildTableCell(l.rentalStatus[0].toUpperCase() +
                              l.rentalStatus.substring(1)),
                          _buildTableCell(l.isAvailable ? 'Yes' : 'No'),
                        ]),
                      ),
                    ],
                  ),
                ];
              }(),

              // Trip History Section
              pw.SizedBox(height: 24),
              pw.Text(
                'Trip History',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Completed trips during this period',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 12),
              
              // Build trip history
              ...() {
                // Group completed bookings by trip
                final completedBookings = bookingsSnapshot.where((b) => 
                  b.bookingStatus.toLowerCase() == 'completed' && b.vanPlateNumber != null
                ).toList();
                
                Map<String, List<Booking>> tripGroups = {};
                for (var booking in completedBookings) {
                  final tripDate = DateFormat('yyyy-MM-dd').format(booking.departureTime);
                  final tripKey = '${booking.vanPlateNumber}_${tripDate}_${booking.routeId}';
                  
                  if (!tripGroups.containsKey(tripKey)) {
                    tripGroups[tripKey] = [];
                  }
                  tripGroups[tripKey]!.add(booking);
                }
                
                // Convert to sorted list
                final trips = tripGroups.entries.toList()
                  ..sort((a, b) {
                    final aDate = a.value.first.departureTime;
                    final bDate = b.value.first.departureTime;
                    return bDate.compareTo(aDate);
                  });
                
                if (trips.isEmpty) {
                  return [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        'No completed trips found for this period.',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                    ),
                  ];
                }
                
                return trips.take(20).map((trip) {
                  final bookings = trip.value;
                  final firstBooking = bookings.first;
                  final totalPassengers = bookings.length;
                  final tripRevenue = bookings.fold<double>(0, (sum, b) => sum + b.totalAmount);
                  
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Trip header
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    firstBooking.vanPlateNumber ?? 'Unknown Vehicle',
                                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '${firstBooking.origin} to ${firstBooking.destination}',
                                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                                  ),
                                ],
                              ),
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  DateFormat('MMM dd, yyyy').format(firstBooking.departureTime),
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                                pw.Text(
                                  DateFormat('hh:mm a').format(firstBooking.departureTime),
                                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Divider(height: 1, color: PdfColors.grey300),
                        pw.SizedBox(height: 8),
                        
                        // Trip summary
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Passengers: ',
                                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                ),
                                pw.Text(
                                  totalPassengers.toString(),
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                                ),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Revenue: ',
                                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                ),
                                pw.Text(
                                  'PHP ${tripRevenue.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // Passenger details (if space allows, show first few)
                        if (bookings.length <= 5) ...[
                          pw.SizedBox(height: 8),
                          pw.Divider(height: 1, color: PdfColors.grey300),
                          pw.SizedBox(height: 6),
                          ...bookings.map((booking) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    booking.passengerDetails.name,
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ),
                                pw.Text(
                                  '${booking.numberOfSeats} seat${booking.numberOfSeats > 1 ? 's' : ''}',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Text(
                                  'PHP ${booking.totalAmount.toStringAsFixed(2)}',
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          )),
                        ] else ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            '+ ${bookings.length} passenger bookings',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList();
              }(),
              
              // Trip history summary note
              if (bookingsSnapshot.where((b) => 
                b.bookingStatus.toLowerCase() == 'completed' && b.vanPlateNumber != null
              ).length > 20) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    'Note: Only the first 20 trips are shown. Total completed trips: ${bookingsSnapshot.where((b) => b.bookingStatus.toLowerCase() == 'completed' && b.vanPlateNumber != null).length}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900),
                  ),
                ),
              ],
              
              // Footer
              pw.SizedBox(height: 32),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'UVExpress Admin Panel - This report is generated automatically and reflects data as of ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ];
          },
        ),
      );
      
      // Show print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'uvexpress_analytics_${_selectedPeriod}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting report: $e')),
        );
      }
    }
  }

  pw.Widget _buildPdfMetricCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
