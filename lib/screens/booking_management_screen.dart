import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BookingManagementScreen extends StatelessWidget {
  const BookingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Row(
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
                  onPressed: () {
                    // TODO: Implement export functionality
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.largePadding),
            const Expanded(
              child: Center(
                child: Text(
                  'Booking Management Screen\n\nThis will show:\n• All bookings with filters\n• Real-time status updates\n• Payment status management\n• Booking details and actions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}