import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../providers/van_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard/stats_card.dart';
import '../widgets/dashboard/recent_bookings_card.dart';
import '../widgets/dashboard/van_queue_card.dart';
import '../widgets/dashboard/user_activity_chart_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    Provider.of<BookingProvider>(context, listen: false)
        .loadStatistics(startOfDay, endOfDay);
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: const Text('Choose what you would like to export:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportTodayReport();
            },
            child: const Text('Today\'s Report'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportUserData();
            },
            child: const Text('User Data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportTodayReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Today\'s report export functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportUserData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User data export functionality coming soon'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeHeader(),
            const SizedBox(height: AppConstants.largePadding),

            // Stats Overview
            _buildStatsOverview(),
            const SizedBox(height: AppConstants.largePadding),

            // Charts and Recent Data
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const UserActivityChartCard(),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildHourlyBookingsChart(),
                    ],
                  ),
                ),

                const SizedBox(width: AppConstants.defaultPadding),

                // Right Column
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      const VanQueueCard(),
                      const SizedBox(height: AppConstants.defaultPadding),
                      const RecentBookingsCard(),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultBorderRadius),
              ),
              child: Icon(
                Icons.dashboard,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  Text(
                    'Monitor your e-ticket operations and performance metrics',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            _buildQuickRefreshButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRefreshButton() {
    return IconButton(
      onPressed: _loadDashboardData,
      icon: const Icon(Icons.refresh),
      tooltip: 'Refresh dashboard data',
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        foregroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Consumer2<BookingProvider, VanProvider>(
      builder: (context, bookingProvider, vanProvider, _) {
        return Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Today\'s Bookings',
                value: bookingProvider.todayBookingsCount.toString(),
                icon: Icons.book_online,
                color: Colors.blue,
                subtitle:
                    '+${AppHelpers.formatPercentage(0.12)} from yesterday',
                isPositive: true,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: StatsCard(
                title: 'Total User Accounts',
                value: bookingProvider.totalUserAccounts.toString(),
                icon: Icons.account_circle,
                color: Colors.green,
                subtitle: '${bookingProvider.todayNewUsers} new today',
                isPositive: bookingProvider.todayNewUsers > 0,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: StatsCard(
                title: 'Active Vans',
                value: vanProvider.activeVansCount.toString(),
                icon: Icons.directions_bus,
                color: Colors.orange,
                subtitle: '${vanProvider.totalVans} total vans',
                isPositive: null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHourlyBookingsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Hourly Booking Distribution',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 200,
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, _) {
                  return FutureBuilder<Map<int, int>>(
                    future:
                        bookingProvider.getHourlyDistribution(DateTime.now()),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snapshot.data!;
                      return BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: data.values.isNotEmpty
                              ? data.values
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble() +
                                  1
                              : 10,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.black87,
                              tooltipRoundedRadius: 4,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${group.x}:00\n${rod.toY.round()} bookings',
                                  const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 4,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}h',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey[300],
                                strokeWidth: 0.5,
                              );
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(24, (index) {
                            final count = data[index] ?? 0;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: count.toDouble(),
                                  color: Theme.of(context).primaryColor,
                                  width: 12,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildQuickActionButton(
              icon: Icons.add_box,
              label: 'Add New Van',
              onTap: () {
                context.go(AppConstants.vansRoute);
              },
            ),
            const SizedBox(height: AppConstants.smallPadding),
            _buildQuickActionButton(
              icon: Icons.route,
              label: 'Manage Routes',
              onTap: () {
                context.go(AppConstants.routesRoute);
              },
            ),
            const SizedBox(height: AppConstants.smallPadding),
            _buildQuickActionButton(
              icon: Icons.book_online,
              label: 'View Bookings',
              onTap: () {
                context.go(AppConstants.bookingsRoute);
              },
            ),
            const SizedBox(height: AppConstants.smallPadding),
            _buildQuickActionButton(
              icon: Icons.analytics,
              label: 'View Analytics',
              onTap: () {
                context.go(AppConstants.analyticsRoute);
              },
            ),
            const SizedBox(height: AppConstants.smallPadding),
            _buildQuickActionButton(
              icon: Icons.file_download,
              label: 'Export Data',
              onTap: _showExportOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.smallPadding,
            vertical: AppConstants.smallPadding,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
