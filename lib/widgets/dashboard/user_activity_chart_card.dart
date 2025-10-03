import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/booking_provider.dart';
import '../../utils/constants.dart';

class UserActivityChartCard extends StatelessWidget {
  const UserActivityChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'User Activity Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Consumer<BookingProvider>(
                  builder: (context, bookingProvider, _) {
                    return Text(
                      '${bookingProvider.totalUserAccounts} Total Users',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 200,
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, _) {
                  return _buildUserActivityChart(bookingProvider);
                },
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildUserActivityLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart(BookingProvider bookingProvider) {
    final int totalUsers = bookingProvider.totalUserAccounts;
    final int activeUsers = bookingProvider.activeBookings.map((b) => b.userId).toSet().length;
    final int newUsersToday = bookingProvider.todayNewUsers;

    if (totalUsers == 0) {
      return const Center(
        child: Text(
          'No user activity data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: totalUsers.toDouble() * 1.2,
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: totalUsers.toDouble(),
                color: Colors.blue,
                width: 30,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: activeUsers.toDouble(),
                color: Colors.green,
                width: 30,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: newUsersToday.toDouble(),
                color: Colors.orange,
                width: 30,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('Total', style: TextStyle(fontSize: 11));
                  case 1:
                    return const Text('Active', style: TextStyle(fontSize: 11));
                  case 2:
                    return const Text('New Today', style: TextStyle(fontSize: 11));
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
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildUserActivityLegend() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, _) {
        final legendItems = [
          _LegendItem('Total Users', Colors.blue, bookingProvider.totalUserAccounts),
          _LegendItem('Active Users', Colors.green, 
              bookingProvider.activeBookings.map((b) => b.userId).toSet().length),
          _LegendItem('New Today', Colors.orange, bookingProvider.todayNewUsers),
        ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: legendItems.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.label}: ${item.value}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  final int value;

  _LegendItem(this.label, this.color, this.value);
}