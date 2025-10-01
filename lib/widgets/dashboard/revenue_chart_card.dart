import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/booking_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class RevenueChartCard extends StatelessWidget {
  const RevenueChartCard({super.key});

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
                  Icons.trending_up,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Revenue Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Consumer<BookingProvider>(
                  builder: (context, bookingProvider, _) {
                    return Text(
                      AppHelpers.formatCurrency(bookingProvider.totalRevenue),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
                  return FutureBuilder<Map<String, double>>(
                    future: _getRevenueData(bookingProvider),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snapshot.data!;
                      if (data.isEmpty) {
                        return const Center(
                          child: Text('No revenue data available'),
                        );
                      }

                      return PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(data, context),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> _getRevenueData(BookingProvider bookingProvider) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return await bookingProvider.getRevenueByPaymentMethod(startOfWeek, endOfWeek);
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> data, BuildContext context) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);
    final colors = [
      Theme.of(context).primaryColor,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    
    int index = 0;
    return data.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0;
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, _) {
        return FutureBuilder<Map<String, double>>(
          future: _getRevenueData(bookingProvider),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final data = snapshot.data!;
            final colors = [
              Theme.of(context).primaryColor,
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.red,
            ];
            
            int index = 0;
            return Wrap(
              spacing: AppConstants.defaultPadding,
              runSpacing: AppConstants.smallPadding,
              children: data.entries.map((entry) {
                final color = colors[index % colors.length];
                index++;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppConstants.smallPadding),
                    Text(
                      '${entry.key}: ${AppHelpers.formatCurrency(entry.value)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}