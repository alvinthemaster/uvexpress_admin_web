import 'dart:math' as math;
import 'package:intl/intl.dart';

class AppHelpers {
  // Date and Time Formatting
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Currency Formatting
  static String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(amount);
  }

  static String formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return formatCurrency(amount);
    }
  }

  // Number Formatting
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  static String formatCompactNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  // Duration Formatting
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  // String Utilities
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String capitalizeWords(String text) {
    return text.split(' ').map((word) => capitalizeFirst(word)).join(' ');
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Status Formatting
  static String formatBookingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'confirmed':
        return 'Confirmed';
      default:
        return capitalizeFirst(status);
    }
  }

  static String formatPaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return capitalizeFirst(status);
    }
  }

  static String formatVanStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'maintenance':
        return 'Maintenance';
      case 'in_transit':
        return 'In Transit';
      case 'boarding':
        return 'Boarding';
      case 'in_queue':
        return 'Ready';
      case 'full':
        return 'Full'; // Add full status formatting
      default:
        return capitalizeFirst(status);
    }
  }

  // Validation Helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^[\+]?[0-9]{10,15}$')
        .hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  static bool isValidPlateNumber(String plateNumber) {
    return RegExp(r'^[A-Z0-9\-]{3,10}$').hasMatch(plateNumber.toUpperCase());
  }

  // Color Helpers
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'completed':
        return '#4CAF50'; // Green
      case 'pending':
      case 'in_transit':
        return '#FF9800'; // Orange
      case 'cancelled':
      case 'failed':
      case 'inactive':
        return '#F44336'; // Red
      case 'maintenance':
        return '#2196F3'; // Blue
      default:
        return '#757575'; // Grey
    }
  }

  // File Helpers
  static String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Search Helpers
  static bool matchesSearch(String text, String query) {
    return text.toLowerCase().contains(query.toLowerCase());
  }

  static List<T> filterList<T>(
      List<T> list, String query, List<String> Function(T) getSearchFields) {
    if (query.isEmpty) return list;

    return list.where((item) {
      return getSearchFields(item).any((field) => matchesSearch(field, query));
    }).toList();
  }

  // Data Conversion Helpers
  static Map<String, dynamic> removeNullValues(Map<String, dynamic> data) {
    return Map.fromEntries(
      data.entries.where((entry) => entry.value != null),
    );
  }

  static DateTime? parseDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      return null;
    }
  }

  // Route Helpers
  static String formatRouteDisplay(String origin, String destination) {
    return '$origin → $destination';
  }

  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371; // km

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Booking Helpers
  static String generateBookingReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'UVE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${timestamp.substring(timestamp.length - 4)}';
  }

  static String generateETicketId() {
    final now = DateTime.now();
    final random = (DateTime.now().millisecondsSinceEpoch % 100000)
        .toString()
        .padLeft(5, '0');
    return 'ET-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$random';
  }

  // Analytics Helpers
  static double calculateGrowthRate(double current, double previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous);
  }

  static String formatGrowthRate(double current, double previous) {
    double growth = calculateGrowthRate(current, previous);
    String sign = growth >= 0 ? '+' : '';
    return '$sign${formatPercentage(growth)}';
  }

  // Error Handling
  static String getErrorMessage(dynamic error) {
    if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (error.toString().contains('permission-denied')) {
      return 'Access denied. You don\'t have permission to perform this action.';
    } else if (error.toString().contains('not-found')) {
      return 'The requested item was not found.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }
}
