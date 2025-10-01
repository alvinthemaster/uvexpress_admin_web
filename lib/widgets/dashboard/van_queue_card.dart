import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/van_provider.dart';
import '../../models/van_model.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class VanQueueCard extends StatelessWidget {
  const VanQueueCard({super.key});

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
                  Icons.queue,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    'Van Queue Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to van management
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Consumer<VanProvider>(
              builder: (context, vanProvider, _) {
                final activeVans = vanProvider.activeVans.take(6).toList();
                
                if (activeVans.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.defaultPadding),
                      child: Text('No active vans in queue'),
                    ),
                  );
                }
                
                return Column(
                  children: [
                    ...activeVans.map((van) => _buildVanQueueItem(context, van)).toList(),
                    if (vanProvider.activeVans.length > 6) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      Text(
                        '+${vanProvider.activeVans.length - 6} more vans',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanQueueItem(BuildContext context, Van van) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: AppConstants.smallPadding,
      ),
      decoration: BoxDecoration(
        color: van.queuePosition <= 3 
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: van.queuePosition <= 3 
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: van.queuePosition <= 3 
                  ? Theme.of(context).primaryColor
                  : Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                van.queuePosition.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  van.plateNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  van.driver.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
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
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(van.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'in_transit':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}