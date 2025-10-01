import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final List<String> permissions;
  final DateTime? lastLogin;
  final bool isActive;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    this.lastLogin,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle permissions array safely
    List<String> permissions = [];
    if (data['permissions'] != null) {
      if (data['permissions'] is List) {
        permissions = List<String>.from(data['permissions']);
      } else if (data['permissions'] is String) {
        // Handle case where permissions might be stored as a string
        String permString = data['permissions'] as String;
        if (permString.startsWith('[') && permString.endsWith(']')) {
          // Try to parse as JSON array
          try {
            permissions = List<String>.from(
              permString.substring(1, permString.length - 1)
                  .split(',')
                  .map((s) => s.trim().replaceAll('"', ''))
            );
          } catch (e) {
            permissions = ['all']; // Default fallback
          }
        } else {
          permissions = [permString]; // Single permission
        }
      }
    }

    return AdminUser(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      permissions: permissions,
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      isActive: _parseBool(data['isActive']) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Helper method to safely parse boolean values
  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'permissions': permissions,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool hasPermission(String permission) {
    return permissions.contains(permission) || permissions.contains('all');
  }
}

class Analytics {
  final String id;
  final DateTime date;
  final int totalBookings;
  final double discountsGiven;
  final double averageFare;
  final int passengerCount;
  final String peakHour;
  final DateTime createdAt;

  Analytics({
    required this.id,
    required this.date,
    required this.totalBookings,
    required this.discountsGiven,
    required this.averageFare,
    required this.passengerCount,
    required this.peakHour,
    required this.createdAt,
  });

  factory Analytics.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Analytics(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalBookings: data['totalBookings'] ?? 0,
      discountsGiven: (data['discountsGiven'] ?? 0).toDouble(),
      averageFare: (data['averageFare'] ?? 0).toDouble(),
      passengerCount: data['passengerCount'] ?? 0,
      peakHour: data['peakHour'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'totalBookings': totalBookings,
      'discountsGiven': discountsGiven,
      'averageFare': averageFare,
      'passengerCount': passengerCount,
      'peakHour': peakHour,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}