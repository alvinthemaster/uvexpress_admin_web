import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van_model.dart';
import '../models/route_model.dart' as route_model;
import '../services/van_service.dart';
import '../services/route_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class VanManagementScreen extends StatefulWidget {
  const VanManagementScreen({super.key});

  @override
  State<VanManagementScreen> createState() => _VanManagementScreenState();
}

class _VanManagementScreenState extends State<VanManagementScreen> 
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _statusFilter = 'all';
  
  late TabController _tabController;
  
  // Days of the week for tabs
  static const List<Map<String, String>> _weekDays = [
    {'value': 'monday', 'label': 'Monday', 'short': 'MON'},
    {'value': 'tuesday', 'label': 'Tuesday', 'short': 'TUE'},
    {'value': 'wednesday', 'label': 'Wednesday', 'short': 'WED'},
    {'value': 'thursday', 'label': 'Thursday', 'short': 'THU'},
    {'value': 'friday', 'label': 'Friday', 'short': 'FRI'},
    {'value': 'saturday', 'label': 'Saturday', 'short': 'SAT'},
    {'value': 'sunday', 'label': 'Sunday', 'short': 'SUN'},
  ];
  
  // Get current day index (0 = Monday, 6 = Sunday)
  int _getCurrentDayIndex() {
    final now = DateTime.now();
    // DateTime.weekday returns 1-7 (Monday-Sunday), convert to 0-6
    return now.weekday - 1;
  }
  
  String get _selectedDay => _weekDays[_tabController.index]['value']!;

  @override
  void initState() {
    super.initState();
    // Initialize TabController with current day
    _tabController = TabController(
      length: _weekDays.length,
      vsync: this,
      initialIndex: _getCurrentDayIndex(),
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild when tab changes
      }
    });
    // Debug van data after a short delay to let providers initialize
    Future.delayed(Duration(seconds: 2), () {
      _debugVanData();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Update all van statuses based on current occupancy
  Future<void> _updateAllVanStatuses() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating all van statuses...'),
          backgroundColor: Colors.blue,
        ),
      );

      final vanService = VanService();
      final vans = context.read<VanProvider>().vans;
      
      int updatedCount = 0;
      for (Van van in vans) {
        // This will automatically check and update the status if needed
        await vanService.updateVanOccupancy(van.id, van.currentOccupancy);
        updatedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $updatedCount van statuses successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating van statuses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Progress all queues for full vans
  Future<void> _progressAllQueues() async {
    try {
      final vanService = VanService();
      await vanService.progressAllFullVanQueues();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Queue progression completed for all full vans'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error progressing queues: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Complete all van trips with occupancy > 0
  Future<void> _completeAllTrips() async {
    try {
      // Show confirmation dialog first
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.flag, color: Colors.green),
                const SizedBox(width: AppConstants.smallPadding),
                const Expanded(child: Text('Complete All Trips')),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This will complete trips for all vans with passengers.'),
                SizedBox(height: AppConstants.smallPadding),
                Text('• All active bookings will be marked as "Completed"'),
                Text('• Van occupancies will be reset to 0'),
                Text('• Van statuses will be updated to "In Queue"'),
                Text('• Booking history will be preserved'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.flag),
                label: const Text('Complete All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completing all trips...'),
          backgroundColor: Colors.blue,
        ),
      );

      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      final vansWithPassengers = vanProvider.vans.where((van) => van.currentOccupancy > 0).toList();
      
      int completedCount = 0;
      for (Van van in vansWithPassengers) {
        await vanProvider.completeVanTrip(van.id);
        completedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed trips for $completedCount vans successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing trips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Test queue loop functionality
  Future<void> _testQueueLoop() async {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      
      // Show dialog to select route or general queue
      final String? selectedOption = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Test Queue Loop'),
            content: const Text('Which queue would you like to test the loop for?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('route'),
                child: const Text('Route Queue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('general'),
                child: const Text('General Queue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (selectedOption == null) return;

      String? routeId;
      if (selectedOption == 'route') {
        // For demonstration, use the first van's route if available
        if (vanProvider.vans.isNotEmpty) {
          Van firstVan = vanProvider.vans.first;
          routeId = firstVan.currentRouteId;
        }
      }

      await vanProvider.triggerQueueLoop(routeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Queue loop test completed for ${selectedOption == 'route' ? 'route queue' : 'general queue'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing queue loop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _debugVanData() {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      print('=== VAN DEBUG INFO ===');
      print('Total vans: ${vanProvider.vans.length}');
      for (var van in vanProvider.vans) {
        print(
            'Van: ${van.plateNumber}, Status: "${van.status}", StatusDisplay: "${van.statusDisplay}"');
      }
      print('=== END VAN DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  // Fix queue positions to ensure uniqueness and consistency
  Future<void> _fixQueuePositions() async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.build, color: Colors.red),
                const SizedBox(width: AppConstants.smallPadding),
                const Expanded(child: Text('Fix Queue Positions')),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This will resequence all vehicle queue positions to ensure:'),
                SizedBox(height: AppConstants.smallPadding),
                Text('• Each vehicle has a unique position'),
                Text('• Positions are sequential (1, 2, 3, ...)'),
                Text('• No duplicate or missing positions'),
                SizedBox(height: AppConstants.smallPadding),
                Text('This is safe and will not affect vehicle status or bookings.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.build),
                label: const Text('Fix Positions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fixing queue positions...'),
          backgroundColor: Colors.blue,
        ),
      );

      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      await vanProvider.fixQueuePositions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Queue positions fixed successfully! All vehicles now have unique sequential positions.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing queue positions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Initialize day-specific queue positions for all vehicles
  Future<void> _initializeDayQueuePositions() async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue[700]),
                const SizedBox(width: AppConstants.smallPadding),
                const Expanded(child: Text('Initialize Day Queue Positions')),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This will assign day-specific queue positions to all vehicles based on their weekly schedules.'),
                SizedBox(height: AppConstants.smallPadding),
                Text('• Vehicles with no schedule will get positions for all days'),
                Text('• Existing day positions will be preserved'),
                Text('• New positions will be assigned sequentially'),
                SizedBox(height: AppConstants.smallPadding),
                Text('This is safe and recommended for the new day-based queue system.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check),
                label: const Text('Initialize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Initializing day-specific queue positions...'),
          backgroundColor: Colors.blue,
        ),
      );

      final vanService = VanService();
      await vanService.initializeDayQueuePositions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day-specific queue positions initialized successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing day positions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            Expanded(child: _buildVansList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fleet Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                'Manage your fleet of vans and buses - track their status and performance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppConstants.smallPadding,
          runSpacing: AppConstants.smallPadding,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddVanDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Van'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddBusDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Bus'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showRouteManagementDialog(),
              icon: const Icon(Icons.map),
              label: const Text('View Routes'),
            ),
            OutlinedButton.icon(
              onPressed: _updateAllVanStatuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Update All Statuses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _progressAllQueues,
              icon: const Icon(Icons.queue),
              label: const Text('Progress All Queues'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _completeAllTrips,
              icon: const Icon(Icons.flag),
              label: const Text('Complete All Trips'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _testQueueLoop,
              icon: const Icon(Icons.loop),
              label: const Text('Test Queue Loop'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _fixQueuePositions,
              icon: const Icon(Icons.build),
              label: const Text('Fix Queue Positions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _initializeDayQueuePositions,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Initialize Day Positions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search vehicles by plate number or driver name...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status Filter',
                  prefixIcon: Icon(Icons.filter_list),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'boarding', child: Text('Boarding')),
                  DropdownMenuItem(
                      value: 'in_queue', child: Text('In Queue (Ready)')),
                  DropdownMenuItem(value: 'full', child: Text('Full')), // Add full filter
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _statusFilter = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        // Day-based TabBar Navigation
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                    const SizedBox(width: AppConstants.smallPadding),
                    Text(
                      'Weekly Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Today: ${_weekDays[_getCurrentDayIndex()]['label']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // TabBar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[700],
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                tabs: _weekDays.map((day) {
                  final isToday = _weekDays.indexOf(day) == _getCurrentDayIndex();
                  return Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(day['short']!),
                          if (isToday)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVansList() {
    return Consumer<VanProvider>(
      builder: (context, vanProvider, _) {
        List<Van> filteredVans = vanProvider.vans;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filteredVans = filteredVans
              .where((van) =>
                  van.plateNumber
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  van.driver.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
              .toList();
        }

        // Apply status filter
        if (_statusFilter != 'all') {
          filteredVans =
              filteredVans.where((van) => van.status == _statusFilter).toList();
        }

        // Apply day filter based on selected tab
        final selectedDay = _selectedDay;
        filteredVans = filteredVans.where((van) {
          // If weeklySchedule is empty, it means the vehicle operates all days
          if (van.weeklySchedule.isEmpty) return true;
          // Otherwise check if the selected day is in the schedule
          return van.weeklySchedule.contains(selectedDay);
        }).toList();

        // CRITICAL: Sort by day-specific queue position for the selected day
        filteredVans.sort((a, b) {
          final aPosition = a.dayQueuePositions[selectedDay] ?? a.queuePosition;
          final bPosition = b.dayQueuePositions[selectedDay] ?? b.queuePosition;
          return aPosition.compareTo(bPosition);
        });

        if (filteredVans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  'No vehicles scheduled for ${_weekDays[_tabController.index]['label']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Text(
                  'Use the "Weekly Schedule" option in the vehicle menu to add vehicles to this day',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredVans.length,
          itemBuilder: (context, index) {
            final van = filteredVans[index];
            return _buildVanCard(van);
          },
        );
      },
    );
  }

  Widget _buildVanCard(Van van) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            // Van Status Indicator
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: _getStatusColor(van.status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),

            // Van Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Vehicle Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: van.vehicleType == 'bus' ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              van.vehicleType == 'bus' ? Icons.directions_bus : Icons.local_shipping,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              van.vehicleType == 'bus' ? 'BUS' : 'VAN',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.smallPadding),
                      Text(
                        van.plateNumber,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(width: AppConstants.smallPadding),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.smallPadding,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(van.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppHelpers.formatVanStatus(van.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(van.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  Text('Driver: ${van.driver.name}'),
                  Text('Capacity: ${van.capacity} seats'),
                  Row(
                    children: [
                      Text('Queue Position: #${van.dayQueuePositions[_selectedDay] ?? van.queuePosition}'),
                      const SizedBox(width: AppConstants.smallPadding),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _weekDays[_tabController.index]['short']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Occupancy display with visual indicator
                  Row(
                    children: [
                      Text('Occupancy: ${van.currentOccupancy}/${van.capacity}'),
                      const SizedBox(width: AppConstants.smallPadding),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: van.capacity > 0 ? van.currentOccupancy / van.capacity : 0.0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            van.currentOccupancy >= van.capacity 
                                ? Colors.red 
                                : van.currentOccupancy > van.capacity * 0.8 
                                    ? Colors.orange 
                                    : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (van.currentRouteId != null &&
                      van.currentRouteId!.isNotEmpty)
                    FutureBuilder<route_model.Route?>(
                      future: RouteService().getRouteById(van.currentRouteId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final route = snapshot.data!;
                          return Text(
                            'Route: ${route.name} (${route.origin} → ${route.destination})',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        } else if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(
                            'Route: Loading...',
                            style: TextStyle(color: Colors.grey.shade600),
                          );
                        } else {
                          return Text(
                            'Route: Not found',
                            style: TextStyle(color: Colors.red.shade600),
                          );
                        }
                      },
                    )
                  else
                    Text(
                      'Route: Unassigned',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  // Weekly Schedule Display
                  const SizedBox(height: AppConstants.smallPadding),
                  _buildScheduleChips(van.weeklySchedule),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleVanAction(value, van),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'assign_route', child: Text('Route & Status')),
                const PopupMenuItem(
                    value: 'weekly_schedule', child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text('Weekly Schedule'),
                      ],
                    )),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'move_up', child: Text('Move Up in Queue')),
                const PopupMenuItem(
                    value: 'move_down', child: Text('Move to End')),
                const PopupMenuItem(
                    value: 'queue_management', child: Text('Queue Management')),
                if (van.status.toLowerCase() == 'full') // Show only for full vans
                  const PopupMenuItem(
                      value: 'progress_queue', child: Text('Progress Queue')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'occupancy_adjust', child: Text('Adjust Occupancy')),
                PopupMenuItem(
                  value: 'occupancy_reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Reset Occupancy'),
                    ],
                  ),
                ), // Enhanced reset with options
                PopupMenuItem(
                  value: 'trip_complete',
                  child: Row(
                    children: [
                      Icon(Icons.flag, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Trip Complete'),
                    ],
                  ),
                ), // Trip complete option
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'maintenance', child: Text('Set Maintenance')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'boarding':
        return Colors.green; // Swapped: was blue, now green
      case 'in_queue':
        return Colors.blue; // Swapped: was green, now blue  
      case 'full':
        return Colors.red; // Add color for full status
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildScheduleChips(List<String> schedule) {
    if (schedule.isEmpty) {
      return Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            'Schedule: All Days',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.blue[700]),
        const SizedBox(width: 4),
        ...schedule.map((day) {
          // Get short day name (first 3 letters)
          final shortDay = day.substring(0, 3).toUpperCase();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Text(
              shortDay,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _handleVanAction(String action, Van van) {
    final vanProvider = Provider.of<VanProvider>(context, listen: false);

    switch (action) {
      case 'edit':
        _showEditVanDialog(van);
        break;
      case 'assign_route':
        _showRouteAssignmentDialog(van);
        break;
      case 'weekly_schedule':
        _showWeeklyScheduleDialog(van);
        break;
      case 'move_up':
        vanProvider.moveVanToNext(van.id);
        break;
      case 'move_down':
        vanProvider.moveVanToEnd(van.id);
        break;
      case 'queue_management':
        _showQueueManagementDialog(van);
        break;
      case 'progress_queue': // Add new action
        _progressQueueManually(van);
        break;
      case 'occupancy_adjust':
        _showOccupancyAdjustmentDialog(van);
        break;
      case 'occupancy_reset':
        _showResetOptionsDialog(van); // Changed to show options
        break;
      case 'occupancy_reset_simple':
        _resetVanOccupancy(van);
        break;
      case 'occupancy_reset_full':
        _resetVanOccupancyAndCancelBookings(van);
        break;
      case 'trip_complete':
        _showTripCompleteConfirmation(van);
        break;
      case 'maintenance':
        _showMaintenanceDialog(van);
        break;
      case 'delete':
        _showDeleteConfirmation(van);
        break;
    }
  }

  void _showAddVanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddVanDialog(vehicleType: 'van'),
    );
  }

  void _showAddBusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddVanDialog(vehicleType: 'bus'),
    );
  }

  void _showRouteManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => const RouteManagementDialog(),
    );
  }

  void _showEditVanDialog(Van van) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditVanDialog(van: van),
    );
  }

  void _showRouteAssignmentDialog(Van van) {
    showDialog(
      context: context,
      builder: (context) => RouteAssignmentDialog(van: van),
    );
  }

  void _showWeeklyScheduleDialog(Van van) {
    showDialog(
      context: context,
      builder: (context) => WeeklyScheduleDialog(van: van),
    );
  }

  void _showMaintenanceDialog(Van van) {
    // TODO: Implement maintenance dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Maintenance Schedule'),
        content: Text(
            'Maintenance schedule for ${van.plateNumber} will be set here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Van van) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Van'),
        content:
            Text('Are you sure you want to delete van ${van.plateNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<VanProvider>(context, listen: false)
                  .deleteVan(van.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showQueueManagementDialog(Van van) {
    showDialog(
      context: context,
      builder: (context) => QueueManagementDialog(van: van),
    );
  }

  void _showOccupancyAdjustmentDialog(Van van) {
    showDialog(
      context: context,
      builder: (context) => OccupancyAdjustmentDialog(van: van),
    );
  }

  // Add method to manually progress queue
  Future<void> _progressQueueManually(Van van) async {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      await vanProvider.progressQueue(van.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Queue progressed after van ${van.plateNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error progressing queue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetVanOccupancy(Van van) async {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      await vanProvider.resetVanOccupancy(van.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Occupancy reset for van ${van.plateNumber} and status updated to "In Queue"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting occupancy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show dialog with reset options
  void _showResetOptionsDialog(Van van) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.refresh, color: Theme.of(context).primaryColor),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(child: Text('Reset Occupancy - ${van.plateNumber}')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Occupancy: ${van.currentOccupancy}/${van.capacity}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              const Text('Choose reset option:'),
              const SizedBox(height: AppConstants.smallPadding),
              
              // Option 1: Simple reset
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue, size: 20),
                        const SizedBox(width: AppConstants.smallPadding),
                        const Text('Simple Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Only resets occupancy count. Existing bookings remain active.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppConstants.smallPadding),
              
              // Option 2: Full reset
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel_schedule_send, color: Colors.orange, size: 20),
                        const SizedBox(width: AppConstants.smallPadding),
                        const Text('Full Reset + Cancel Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Resets occupancy AND cancels all active bookings. All seats become available.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.smallPadding),
              
              // Option 3: Trip complete
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, color: Colors.green, size: 20),
                        const SizedBox(width: AppConstants.smallPadding),
                        const Text('Trip Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Marks all active bookings as "Completed" and resets occupancy. Preserves booking history.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _handleVanAction('occupancy_reset_simple', van);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Simple Reset'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _handleVanAction('trip_complete', van);
              },
              icon: const Icon(Icons.flag),
              label: const Text('Trip Complete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _handleVanAction('occupancy_reset_full', van);
              },
              icon: const Icon(Icons.cancel_schedule_send),
              label: const Text('Full Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // New method for full reset with booking cancellation
  Future<void> _resetVanOccupancyAndCancelBookings(Van van) async {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      await vanProvider.resetVanOccupancyAndCancelBookings(van.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Full reset completed for van ${van.plateNumber} - all seats are now available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error in full reset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show trip complete confirmation dialog
  void _showTripCompleteConfirmation(Van van) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flag, color: Colors.green),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(child: Text('Complete Trip - ${van.plateNumber}')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Occupancy: ${van.currentOccupancy}/${van.capacity}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text('Trip Complete Action:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• All active bookings will be marked as "Completed"'),
                    const Text('• Booking history will be preserved'),
                    const Text('• Van occupancy will be reset to 0'),
                    const Text('• Van status will be updated to "In Queue"'),
                    const Text('• All seats will become available for new bookings'),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                'This action is ideal when a trip has finished successfully and you want to maintain booking records.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _completeVanTrip(van);
              },
              icon: const Icon(Icons.flag),
              label: const Text('Complete Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Complete van trip method
  Future<void> _completeVanTrip(Van van) async {
    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      await vanProvider.completeVanTrip(van.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip completed for van ${van.plateNumber} - all bookings marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AddVanDialog extends StatefulWidget {
  final String vehicleType; // 'van' or 'bus'
  
  const AddVanDialog({super.key, this.vehicleType = 'van'});

  @override
  State<AddVanDialog> createState() => _AddVanDialogState();
}

class _AddVanDialogState extends State<AddVanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();
  late TextEditingController _capacityController;
  final _driverNameController = TextEditingController();
  final _driverContactController = TextEditingController();

  String _selectedStatus = 'in_queue'; // Default to in queue status
  String? _selectedRouteId; // Route selection
  bool _isLoading = false;
  List<route_model.Route> _availableRoutes = [];
  Set<String> _selectedDays = {}; // Weekly schedule selection

  final List<Map<String, String>> _daysOfWeek = const [
    {'value': 'monday', 'label': 'Monday', 'short': 'MON'},
    {'value': 'tuesday', 'label': 'Tuesday', 'short': 'TUE'},
    {'value': 'wednesday', 'label': 'Wednesday', 'short': 'WED'},
    {'value': 'thursday', 'label': 'Thursday', 'short': 'THU'},
    {'value': 'friday', 'label': 'Friday', 'short': 'FRI'},
    {'value': 'saturday', 'label': 'Saturday', 'short': 'SAT'},
    {'value': 'sunday', 'label': 'Sunday', 'short': 'SUN'},
  ];

  @override
  void initState() {
    super.initState();
    // Set default capacity based on vehicle type
    final defaultCapacity = widget.vehicleType == 'bus' ? '22' : '18';
    _capacityController = TextEditingController(text: defaultCapacity);
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routeService = RouteService();
      final routesStream = routeService.getActiveRoutesStream();
      routesStream.listen((routes) {
        if (mounted) {
          setState(() {
            _availableRoutes = routes;
          });
        }
      });
    } catch (e) {
      print('Error loading routes: $e');
    }
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _capacityController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  topRight: Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.vehicleType == 'bus' ? Icons.directions_bus : Icons.local_shipping,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Add New ${widget.vehicleType == 'bus' ? 'Bus' : 'Van'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Van Information Section
                      Text(
                        'Van Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Plate Number
                      TextFormField(
                        controller: _plateNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Plate Number *',
                          hintText: 'Enter van plate number (e.g., ABC-1234)',
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Plate number is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Plate number must be at least 3 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Capacity
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Passenger Capacity *',
                          hintText: 'Enter maximum passenger capacity',
                          prefixIcon: Icon(Icons.people),
                          suffixText: 'passengers',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Capacity is required';
                          }
                          int? capacity = int.tryParse(value.trim());
                          if (capacity == null || capacity <= 0) {
                            return 'Enter a valid capacity greater than 0';
                          }
                          // Different max capacity based on vehicle type
                          final maxCapacity = widget.vehicleType == 'bus' ? 22 : 18;
                          if (capacity > maxCapacity) {
                            return 'Capacity cannot exceed $maxCapacity seats';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.largePadding),

                      // Driver Information Section
                      Text(
                        'Driver Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Driver Name
                      TextFormField(
                        controller: _driverNameController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Name *',
                          hintText: 'Enter driver full name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Driver name must be at least 2 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      TextFormField(
                        controller: _driverContactController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Contact Number *',
                          hintText: 'Enter driver phone number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver contact is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Contact number must be at least 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Route Assignment
                      Text(
                        'Route Assignment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Route Selection
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedRouteId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to Route (Optional)',
                          hintText: 'Select a route for this van',
                          prefixIcon: Icon(Icons.route),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No Route (Unassigned)'),
                          ),
                          // Filter out routes with empty or null IDs and ensure unique route IDs
                          ..._availableRoutes
                              .where((route) => route.id.isNotEmpty)
                              .fold<Map<String, route_model.Route>>({}, (map, route) {
                                // Keep only the first route for each unique ID
                                if (!map.containsKey(route.id)) {
                                  map[route.id] = route;
                                }
                                return map;
                              })
                              .values
                              .map((route) => DropdownMenuItem<String?>(
                                value: route.id,
                                child: Text('${route.name} (${route.origin} → ${route.destination})'),
                              ))
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRouteId = value;
                          });
                        },
                      ),
                      
                      if (_availableRoutes.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: AppConstants.smallPadding),
                          padding: const EdgeInsets.all(AppConstants.smallPadding),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: AppConstants.smallPadding),
                              Expanded(
                                child: Text(
                                  'No routes available. Create routes in Route Management first.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppConstants.largePadding),

                      // Van Status
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Van Status *',
                          hintText: 'Select van status',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'boarding',
                            child: Text('Boarding'),
                          ),
                          DropdownMenuItem(
                            value: 'in_queue',
                            child: Text('In Queue (Ready)'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value ?? 'boarding';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a van status';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer with Actions
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  bottomRight:
                      Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addVan,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isLoading 
                        ? 'Adding...' 
                        : widget.vehicleType == 'bus' ? 'Add Bus' : 'Add Van'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                        vertical: AppConstants.smallPadding,
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

  Future<void> _addVan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);

      // Create driver object
      final driver = Driver(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _driverNameController.text.trim(),
        license: 'N/A', // Not collecting license anymore
        contact: _driverContactController.text.trim(),
      );

      // Create van object
      final van = Van(
        id: '', // Will be set by Firestore
        plateNumber: _plateNumberController.text.trim().toUpperCase(),
        capacity: int.parse(_capacityController.text.trim()),
        driver: driver,
        status: _selectedStatus,
        currentRouteId: _selectedRouteId, // Assign selected route
        queuePosition: 0, // Will be set by service
        isActive: ['boarding', 'in_queue']
            .contains(_selectedStatus), // Active if bookable
        createdAt: DateTime.now(),
        currentOccupancy: 0, // Initialize with 0 occupancy
        vehicleType: widget.vehicleType, // Set vehicle type (van or bus)
        weeklySchedule: _selectedDays.toList(), // Set weekly schedule
      );

      // Add the van
      await vanProvider.addVan(van);

      if (!mounted) return;

      // Show success message
      final vehicleName = widget.vehicleType == 'bus' ? 'Bus' : 'Van';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('$vehicleName ${van.plateNumber} added successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('Error adding van: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class EditVanDialog extends StatefulWidget {
  final Van van;

  const EditVanDialog({super.key, required this.van});

  @override
  State<EditVanDialog> createState() => _EditVanDialogState();
}

class _EditVanDialogState extends State<EditVanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _driverContactController = TextEditingController();

  String _selectedStatus = 'boarding';
  String? _selectedRouteId;
  bool _isLoading = false;
  List<route_model.Route> _availableRoutes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _initializeFields();
  }

  void _initializeFields() {
    // Pre-populate form fields with current van data
    _plateNumberController.text = widget.van.plateNumber;
    _capacityController.text = widget.van.capacity.toString();
    _driverNameController.text = widget.van.driver.name;
    _driverLicenseController.text = widget.van.driver.license;
    _driverContactController.text = widget.van.driver.contact;
    _selectedStatus = widget.van.status;
    
    // DON'T set _selectedRouteId here - it will be set when routes are loaded
    _selectedRouteId = null;
  }

  Future<void> _loadRoutes() async {
    try {
      final routeService = RouteService();
      final routesStream = routeService.getActiveRoutesStream();
      routesStream.listen((routes) {
        if (mounted) {
          setState(() {
            _availableRoutes = routes;
            _validateSelectedRoute();
          });
        }
      });
    } catch (e) {
      print('Error loading routes: $e');
    }
  }

  void _validateSelectedRoute() {
    // Set the selected route ID based on the van's current route, but only if it exists in available routes
    if (widget.van.currentRouteId != null && widget.van.currentRouteId!.isNotEmpty) {
      final routeExists = _availableRoutes.any((route) => 
          route.id.isNotEmpty && route.id == widget.van.currentRouteId);
      if (routeExists) {
        _selectedRouteId = widget.van.currentRouteId;
      } else {
        _selectedRouteId = null; // Route doesn't exist, reset to null
      }
    } else {
      _selectedRouteId = null; // Van has no route assigned
    }
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _capacityController.dispose();
    _driverNameController.dispose();
    _driverLicenseController.dispose();
    _driverContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  topRight: Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Edit Van ${widget.van.plateNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Van Information Section
                      Text(
                        'Van Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Plate Number
                      TextFormField(
                        controller: _plateNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Plate Number *',
                          hintText: 'Enter van plate number (e.g., ABC-1234)',
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Plate number is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Plate number must be at least 3 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Capacity
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Passenger Capacity *',
                          hintText: 'Enter maximum passenger capacity',
                          prefixIcon: Icon(Icons.people),
                          suffixText: 'passengers',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Capacity is required';
                          }
                          int? capacity = int.tryParse(value.trim());
                          if (capacity == null || capacity <= 0) {
                            return 'Enter a valid capacity greater than 0';
                          }
                          if (capacity > 18) {
                            return 'Capacity cannot exceed 18 seats';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.largePadding),

                      // Driver Information Section
                      Text(
                        'Driver Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Driver Name
                      TextFormField(
                        controller: _driverNameController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Name *',
                          hintText: 'Enter driver full name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Driver name must be at least 2 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Driver License
                      TextFormField(
                        controller: _driverLicenseController,
                        decoration: const InputDecoration(
                          labelText: 'Driver License Number *',
                          hintText: 'Enter driver license number',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver license is required';
                          }
                          if (value.trim().length < 5) {
                            return 'License number must be at least 5 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Driver Contact
                      TextFormField(
                        controller: _driverContactController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Contact Number *',
                          hintText: 'Enter driver phone number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver contact is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Contact number must be at least 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Route Assignment
                      Text(
                        'Route Assignment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),

                      // Route Selection
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedRouteId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to Route',
                          hintText: 'Select a route for this van',
                          prefixIcon: Icon(Icons.route),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No Route (Unassigned)'),
                          ),
                          // Filter out routes with empty or null IDs and ensure unique route IDs
                          ..._availableRoutes
                              .where((route) => route.id.isNotEmpty)
                              .fold<Map<String, route_model.Route>>({}, (map, route) {
                                // Keep only the first route for each unique ID
                                if (!map.containsKey(route.id)) {
                                  map[route.id] = route;
                                }
                                return map;
                              })
                              .values
                              .map((route) => DropdownMenuItem<String?>(
                                value: route.id,
                                child: Text('${route.name} (${route.origin} → ${route.destination})'),
                              ))
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRouteId = value;
                          });
                        },
                      ),
                      
                      if (_availableRoutes.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: AppConstants.smallPadding),
                          padding: const EdgeInsets.all(AppConstants.smallPadding),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: AppConstants.smallPadding),
                              Expanded(
                                child: Text(
                                  'No routes available. Create routes in Route Management first.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppConstants.largePadding),

                      // Van Status
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Van Status *',
                          hintText: 'Select van status',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'boarding',
                            child: Text('Boarding'),
                          ),
                          DropdownMenuItem(
                            value: 'in_queue',
                            child: Text('In Queue (Ready)'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value ?? 'boarding';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a van status';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Additional Info Section
                      Container(
                        padding: const EdgeInsets.all(AppConstants.smallPadding),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Information',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppConstants.smallPadding),
                            Text('Van ID: ${widget.van.id}'),
                            Text('Created: ${AppHelpers.formatDateTime(widget.van.createdAt)}'),
                            Text('Current Occupancy: ${widget.van.currentOccupancy}/${widget.van.capacity}'),
                            Text('Queue Position: #${widget.van.queuePosition}'),
                            Text('Active: ${widget.van.isActive ? 'Yes' : 'No'}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer with Actions
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  bottomRight: Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateVan,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Updating...' : 'Update Van'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                        vertical: AppConstants.smallPadding,
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

  Future<void> _updateVan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);

      // Create updated driver object
      final updatedDriver = Driver(
        id: widget.van.driver.id, // Keep the same driver ID
        name: _driverNameController.text.trim(),
        license: _driverLicenseController.text.trim(),
        contact: _driverContactController.text.trim(),
      );

      // Create updated van object
      final updatedVan = widget.van.copyWith(
        plateNumber: _plateNumberController.text.trim().toUpperCase(),
        capacity: int.parse(_capacityController.text.trim()),
        driver: updatedDriver,
        status: _selectedStatus,
        currentRouteId: _selectedRouteId,
        isActive: ['boarding', 'in_queue'].contains(_selectedStatus),
      );

      // Update the van
      await vanProvider.updateVan(widget.van.id, updatedVan);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('Van ${updatedVan.plateNumber} updated successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('Error updating van: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class RouteAssignmentDialog extends StatefulWidget {
  final Van van;

  const RouteAssignmentDialog({super.key, required this.van});

  @override
  State<RouteAssignmentDialog> createState() => _RouteAssignmentDialogState();
}

class _RouteAssignmentDialogState extends State<RouteAssignmentDialog> {
  final RouteService _routeService = RouteService();
  final VanService _vanService = VanService();

  String? _selectedRouteId;
  String _selectedStatus = 'in_queue';
  bool _isLoading = false;
  List<route_model.Route> _routes = [];
  route_model.Route? _currentRoute;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadCurrentRoute();
  }

  Future<void> _loadRoutes() async {
    try {
      final routesStream = _routeService.getActiveRoutesStream();
      routesStream.listen((routes) {
        if (mounted) {
          setState(() {
            _routes = routes;
            // Only set selected route ID after routes are loaded
            _validateAndSetCurrentRoute();
          });
        }
      });
    } catch (e) {
      print('Error loading routes: $e');
    }
  }

  void _validateAndSetCurrentRoute() {
    // Only set _selectedRouteId if the van has a current route AND it exists in the loaded routes
    if (widget.van.currentRouteId != null && 
        widget.van.currentRouteId!.isNotEmpty &&
        _routes.any((route) => route.id == widget.van.currentRouteId)) {
      _selectedRouteId = widget.van.currentRouteId;
    } else {
      _selectedRouteId = null; // Reset to null if route doesn't exist
    }
  }

  Future<void> _loadCurrentRoute() async {
    if (widget.van.currentRouteId != null &&
        widget.van.currentRouteId!.isNotEmpty) {
      try {
        final route =
            await _routeService.getRouteById(widget.van.currentRouteId!);
        if (mounted) {
          setState(() {
            _currentRoute = route;
            // Don't set _selectedRouteId here - it will be set in _validateAndSetCurrentRoute
          });
        }
      } catch (e) {
        print('Error loading current route: $e');
      }
    }
  }

  Future<void> _assignRouteToVan() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update van with new route and status
      final updatedVan = widget.van.copyWith(
        currentRouteId: _selectedRouteId,
        status: _selectedStatus,
      );

      await _vanService.updateVan(widget.van.id, updatedVan);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedRouteId != null
                ? 'Van ${widget.van.plateNumber} assigned to route successfully!'
                : 'Van ${widget.van.plateNumber} unassigned from route successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Assign Route to Van ${widget.van.plateNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Current assignment info
            if (_currentRoute != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently Assigned Route:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${_currentRoute!.name} (${_currentRoute!.origin} → ${_currentRoute!.destination})'),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],

            // Route selection
            Text(
              'Select Route:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            DropdownButtonFormField<String?>(
              initialValue: _selectedRouteId,
              decoration: const InputDecoration(
                labelText: 'Route',
                hintText: 'Select a route for this van',
                prefixIcon: Icon(Icons.route),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned (No Route)'),
                ),
                ..._routes.map((route) => DropdownMenuItem<String?>(
                      value: route.id,
                      child: Text(
                          '${route.name} (${route.origin} → ${route.destination})'),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRouteId = value;
                });
              },
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Status selection
            Text(
              'Van Status:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                hintText: 'Select van status',
                prefixIcon: Icon(Icons.info),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'in_queue', child: Text('In Queue (Ready)')),
                DropdownMenuItem(value: 'boarding', child: Text('Boarding')),
                DropdownMenuItem(
                    value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'in_queue';
                });
              },
            ),

            const SizedBox(height: AppConstants.largePadding),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _assignRouteToVan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Assigning...' : 'Assign Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RouteManagementDialog extends StatefulWidget {
  const RouteManagementDialog({super.key});

  @override
  State<RouteManagementDialog> createState() => _RouteManagementDialogState();
}

class _RouteManagementDialogState extends State<RouteManagementDialog> {
  final RouteService _routeService = RouteService();
  final VanService _vanService = VanService();
  List<route_model.Route> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routesStream = _routeService.getActiveRoutesStream();
      routesStream.listen((routes) {
        if (mounted) {
          setState(() {
            _routes = routes;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading routes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.map, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Route Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _routes.isEmpty
                      ? const Center(
                          child: Text(
                            'No routes available. Create some routes first.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _routes.length,
                          itemBuilder: (context, index) {
                            final route = _routes[index];
                            return Card(
                              child: ExpansionTile(
                                title: Text(
                                  route.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                    '${route.origin} → ${route.destination}'),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(
                                        AppConstants.defaultPadding),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Price: ${AppConstants.currencySymbol}${route.basePrice.toStringAsFixed(2)}'),
                                        Text(
                                            'Duration: ${route.estimatedDuration} minutes'),
                                        Text(
                                            'Waypoints: ${route.waypoints.join(', ')}'),
                                        const SizedBox(
                                            height:
                                                AppConstants.defaultPadding),

                                        // Assigned vans
                                        FutureBuilder<List<Van>>(
                                          future: _vanService
                                              .getVansByRoute(route.id),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) {
                                              final assignedVans =
                                                  snapshot.data!;
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Assigned Vans (${assignedVans.length}):',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  if (assignedVans.isEmpty)
                                                    const Text(
                                                        'No vans assigned to this route')
                                                  else
                                                    ...assignedVans
                                                        .map((van) => Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 16,
                                                                      top: 4),
                                                              child: Text(
                                                                '• ${van.plateNumber} (${van.statusDisplay}) - Driver: ${van.driver.name}',
                                                              ),
                                                            )),
                                                ],
                                              );
                                            } else if (snapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const Text(
                                                  'Loading assigned vans...');
                                            } else {
                                              return const Text(
                                                  'Error loading assigned vans');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class QueueManagementDialog extends StatefulWidget {
  final Van van;

  const QueueManagementDialog({super.key, required this.van});

  @override
  State<QueueManagementDialog> createState() => _QueueManagementDialogState();
}

class _QueueManagementDialogState extends State<QueueManagementDialog> {
  final VanService _vanService = VanService();
  List<Van> _vansOnRoute = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVansOnRoute();
  }

  Future<void> _loadVansOnRoute() async {
    try {
      if (widget.van.currentRouteId != null && widget.van.currentRouteId!.isNotEmpty) {
        final vans = await _vanService.getVansByRoute(widget.van.currentRouteId!);
        if (mounted) {
          setState(() {
            _vansOnRoute = vans..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _vansOnRoute = [widget.van];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading vans on route: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQueuePosition(Van van, int newPosition) async {
    try {
      final updatedVan = van.copyWith(queuePosition: newPosition);
      await _vanService.updateVan(van.id, updatedVan);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Queue position updated for ${van.plateNumber}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadVansOnRoute(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating queue position: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.queue, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Queue Management - ${widget.van.plateNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Route info
            if (widget.van.currentRouteId != null && widget.van.currentRouteId!.isNotEmpty)
              FutureBuilder<route_model.Route?>(
                future: RouteService().getRouteById(widget.van.currentRouteId!),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final route = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.all(AppConstants.smallPadding),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.route, color: Colors.blue.shade700),
                          const SizedBox(width: AppConstants.smallPadding),
                          Expanded(
                            child: Text(
                              'Route: ${route.name} (${route.origin} → ${route.destination})',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: AppConstants.smallPadding),
                    const Expanded(
                      child: Text('Van is not assigned to any route'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Vans list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _vansOnRoute.isEmpty
                      ? const Center(child: Text('No vans found on this route'))
                      : ListView.builder(
                          itemCount: _vansOnRoute.length,
                          itemBuilder: (context, index) {
                            final van = _vansOnRoute[index];
                            final isCurrentVan = van.id == widget.van.id;
                            
                            return Card(
                              color: isCurrentVan ? Colors.blue.shade50 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCurrentVan 
                                      ? Colors.blue 
                                      : Colors.grey.shade400,
                                  child: Text(
                                    '${van.queuePosition}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  van.plateNumber,
                                  style: TextStyle(
                                    fontWeight: isCurrentVan 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Driver: ${van.driver.name}'),
                                    Text('Status: ${van.statusDisplay}'),
                                    Text('Occupancy: ${van.currentOccupancy}/${van.capacity}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: van.queuePosition > 1 
                                          ? () => _updateQueuePosition(van, van.queuePosition - 1)
                                          : null,
                                      icon: const Icon(Icons.keyboard_arrow_up),
                                      tooltip: 'Move Up',
                                    ),
                                    IconButton(
                                      onPressed: van.queuePosition < _vansOnRoute.length 
                                          ? () => _updateQueuePosition(van, van.queuePosition + 1)
                                          : null,
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      tooltip: 'Move Down',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class OccupancyAdjustmentDialog extends StatefulWidget {
  final Van van;

  const OccupancyAdjustmentDialog({super.key, required this.van});

  @override
  State<OccupancyAdjustmentDialog> createState() => _OccupancyAdjustmentDialogState();
}

class _OccupancyAdjustmentDialogState extends State<OccupancyAdjustmentDialog> {
  final _occupancyController = TextEditingController();
  bool _isLoading = false;
  late int _currentOccupancy;

  @override
  void initState() {
    super.initState();
    _currentOccupancy = widget.van.currentOccupancy;
    _occupancyController.text = widget.van.currentOccupancy.toString();
    _occupancyController.addListener(_onOccupancyChanged);
  }

  void _onOccupancyChanged() {
    final newValue = int.tryParse(_occupancyController.text);
    if (newValue != null && newValue != _currentOccupancy) {
      setState(() {
        _currentOccupancy = newValue;
      });
    }
  }

  @override
  void dispose() {
    _occupancyController.removeListener(_onOccupancyChanged);
    _occupancyController.dispose();
    super.dispose();
  }

  Future<void> _updateOccupancy() async {
    final newOccupancy = int.tryParse(_occupancyController.text);
    if (newOccupancy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newOccupancy < 0 || newOccupancy > widget.van.capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Occupancy must be between 0 and ${widget.van.capacity}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vanService = VanService();
      
      // Update occupancy and automatically check status
      await vanService.updateVanOccupancy(widget.van.id, newOccupancy);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Occupancy updated for van ${widget.van.plateNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating occupancy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupancyPercentage = widget.van.capacity > 0 
        ? _currentOccupancy / widget.van.capacity 
        : 0.0;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Adjust Occupancy - ${widget.van.plateNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Current occupancy display
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Occupancy:'),
                      Text(
                        '$_currentOccupancy/${widget.van.capacity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  LinearProgressIndicator(
                    value: occupancyPercentage,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      occupancyPercentage >= 1.0 
                          ? Colors.red 
                          : occupancyPercentage > 0.8 
                              ? Colors.orange 
                              : Colors.green,
                    ),
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  Text(
                    '${(occupancyPercentage * 100).toStringAsFixed(1)}% Full',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Occupancy input
            TextFormField(
              controller: _occupancyController,
              decoration: InputDecoration(
                labelText: 'New Occupancy',
                hintText: 'Enter number of passengers (0-${widget.van.capacity})',
                prefixIcon: const Icon(Icons.people),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Quick action buttons
            Wrap(
              spacing: AppConstants.smallPadding,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    _occupancyController.text = '0';
                  },
                  child: const Text('Empty'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    _occupancyController.text = widget.van.capacity.toString();
                  },
                  child: const Text('Full'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    final halfCapacity = (widget.van.capacity / 2).round();
                    _occupancyController.text = halfCapacity.toString();
                  },
                  child: const Text('Half'),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateOccupancy,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Updating...' : 'Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Weekly Schedule Dialog
class WeeklyScheduleDialog extends StatefulWidget {
  final Van van;

  const WeeklyScheduleDialog({super.key, required this.van});

  @override
  State<WeeklyScheduleDialog> createState() => _WeeklyScheduleDialogState();
}

class _WeeklyScheduleDialogState extends State<WeeklyScheduleDialog> {
  final VanService _vanService = VanService();
  late Set<String> _selectedDays;
  bool _isLoading = false;

  final List<Map<String, String>> _daysOfWeek = const [
    {'value': 'monday', 'label': 'Monday', 'short': 'MON'},
    {'value': 'tuesday', 'label': 'Tuesday', 'short': 'TUE'},
    {'value': 'wednesday', 'label': 'Wednesday', 'short': 'WED'},
    {'value': 'thursday', 'label': 'Thursday', 'short': 'THU'},
    {'value': 'friday', 'label': 'Friday', 'short': 'FRI'},
    {'value': 'saturday', 'label': 'Saturday', 'short': 'SAT'},
    {'value': 'sunday', 'label': 'Sunday', 'short': 'SUN'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with current schedule
    _selectedDays = Set<String>.from(widget.van.weeklySchedule);
  }

  Future<void> _updateSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get old schedule for comparison
      List<String> oldSchedule = widget.van.weeklySchedule;
      List<String> newSchedule = _selectedDays.toList();

      // Update day-specific queue positions
      await _vanService.updateDayQueuePositions(
        widget.van.id,
        newSchedule,
        oldSchedule,
      );

      if (mounted) {
        Navigator.of(context).pop();
        
        // Show detailed feedback
        String message;
        if (newSchedule.isEmpty) {
          message = 'Vehicle ${widget.van.plateNumber} now operates all days with assigned queue positions';
        } else {
          List<String> addedDays = newSchedule.where((d) => !oldSchedule.contains(d)).toList();
          List<String> removedDays = oldSchedule.where((d) => !newSchedule.contains(d)).toList();
          
          if (addedDays.isNotEmpty && removedDays.isNotEmpty) {
            message = 'Schedule updated for ${widget.van.plateNumber}\nAdded: ${addedDays.join(", ")}\nRemoved: ${removedDays.join(", ")}';
          } else if (addedDays.isNotEmpty) {
            message = 'Added ${widget.van.plateNumber} to: ${addedDays.join(", ")}';
          } else if (removedDays.isNotEmpty) {
            message = 'Removed ${widget.van.plateNumber} from: ${removedDays.join(", ")}';
          } else {
            message = 'Schedule updated for ${widget.van.plateNumber}';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Schedule',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        widget.van.plateNumber,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Info banner
            Container(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Select the days this vehicle operates. Leave empty to operate all days.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Current schedule display
            if (_selectedDays.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: AppConstants.smallPadding),
                    const Text(
                      'Operating all days of the week',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available, color: Colors.orange[700], size: 20),
                    const SizedBox(width: AppConstants.smallPadding),
                    Text(
                      'Operating ${_selectedDays.length} day(s) per week',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Quick select buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDays = _daysOfWeek
                            .map((day) => day['value']!)
                            .toSet();
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('All Days'),
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDays = _daysOfWeek
                            .take(5) // Monday to Friday
                            .map((day) => day['value']!)
                            .toSet();
                      });
                    },
                    icon: const Icon(Icons.business_center, size: 16),
                    label: const Text('Weekdays'),
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDays = _daysOfWeek
                            .skip(5) // Saturday and Sunday
                            .map((day) => day['value']!)
                            .toSet();
                      });
                    },
                    icon: const Icon(Icons.weekend, size: 16),
                    label: const Text('Weekend'),
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDays.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Day selection grid
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _daysOfWeek.length,
              itemBuilder: (context, index) {
                final day = _daysOfWeek[index];
                final isSelected = _selectedDays.contains(day['value']);

                return InkWell(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            if (isSelected) {
                              _selectedDays.remove(day['value']);
                            } else {
                              _selectedDays.add(day['value']!);
                            }
                          });
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[600] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                      border: Border.all(
                        color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day['short']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day['label']!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppConstants.largePadding),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateSchedule,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

