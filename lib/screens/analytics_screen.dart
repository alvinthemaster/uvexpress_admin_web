import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../services/van_service.dart';
import '../models/van_model.dart';
import '../utils/constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final BookingService _bookingService = BookingService();
  final VanService _vanService = VanService();
  
  String _selectedPeriod = 'week';
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _statistics = {};
  Map<int, int> _hourlyDistribution = {};
  bool _isLoading = true;

  final List<String> _periodOptions = ['day', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
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

      setState(() {
        _statistics = statistics;
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
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildPeriodSelector(),
            const SizedBox(height: AppConstants.defaultPadding),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAnalytics(),
            ),
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
        Expanded(child: _buildStatCard(
          'Active Users',
          _statistics['activeUsers']?.toString() ?? '0',
          Icons.people,
          Colors.orange,
        )),
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
    final List<BarChartGroupData> barGroups = [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: _statistics['totalUsers']?.toDouble() ?? 0.0,
            color: Colors.blue,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: _statistics['activeUsers']?.toDouble() ?? 0.0,
            color: Colors.green,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: _statistics['newUsersToday']?.toDouble() ?? 0.0,
            color: Colors.orange,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_statistics['totalUsers']?.toDouble() ?? 100.0) * 1.2,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('Total Users');
                  case 1:
                    return const Text('Active Users');
                  case 2:
                    return const Text('New Today');
                  default:
                    return const Text('');
                }
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
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
      'Active Users': _statistics['activeUsers'] ?? 0,
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
      'Active Users': _statistics['activeUsers'] ?? 0,
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

  void _exportReport() {
    // TODO: Implement PDF/Excel export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }
}
