import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DiscountManagementScreen extends StatelessWidget {
  const DiscountManagementScreen({super.key});

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
                    'Discount Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement add discount functionality
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Discount'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.largePadding),
            const Expanded(
              child: Center(
                child: Text(
                  'Discount Management Screen\n\nThis will show:\n• All discount rules\n• Student/Senior/PWD discounts\n• Percentage and fixed discounts\n• Usage tracking and limits',
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