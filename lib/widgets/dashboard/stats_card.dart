import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool? isPositive;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.isPositive,
  });

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
                Container(
                  padding: const EdgeInsets.all(AppConstants.smallPadding),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultBorderRadius),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                if (isPositive != null)
                  Icon(
                    isPositive! ? Icons.trending_up : Icons.trending_down,
                    color: isPositive! ? Colors.green : Colors.red,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isPositive == null
                          ? Colors.grey[600]
                          : (isPositive! ? Colors.green : Colors.red),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
