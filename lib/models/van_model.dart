import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/van_status_constants.dart';

class Driver {
  final String id;
  final String name;
  final String license;
  final String contact;

  Driver({
    required this.id,
    required this.name,
    required this.license,
    required this.contact,
  });

  factory Driver.fromMap(Map<String, dynamic> data) {
    return Driver(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      license: data['license'] ?? '',
      contact: data['contact'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'license': license,
      'contact': contact,
    };
  }
}

class Van {
  final String id;
  final String plateNumber;
  final int capacity;
  final Driver driver;
  final String status; // active, inactive, maintenance
  final String? currentRouteId;
  final int queuePosition;
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;
  final bool isActive;
  final DateTime createdAt;
  final int currentOccupancy; // Add this field

  Van({
    required this.id,
    required this.plateNumber,
    required this.capacity,
    required this.driver,
    required this.status,
    this.currentRouteId,
    required this.queuePosition,
    this.lastMaintenance,
    this.nextMaintenance,
    required this.isActive,
    required this.createdAt,
    this.currentOccupancy = 0, // Default to 0
  });

  // Comprehensive status mapping for admin-mobile compatibility
  String get statusDisplay {
    // Debug: Print the actual status value
    print('Van ${plateNumber} has status: "$status" (length: ${status.length})');
    
    // Normalize the status for comparison (handle case, spaces, etc.)
    final normalizedStatus = status.toLowerCase().trim();
    
    // Use the status mapping from constants
    if (VanStatus.statusDisplayMap.containsKey(normalizedStatus)) {
      final displayValue = VanStatus.statusDisplayMap[normalizedStatus]!;
      print('Status "$normalizedStatus" mapped to: "$displayValue"');
      return displayValue;
    }
    
    // Handle empty or null status
    if (normalizedStatus.isEmpty || normalizedStatus == 'null') {
      print('Warning: Empty status for van ${plateNumber}, defaulting to Ready');
      return 'Ready';
    }
    
    // Fallback: format the original status
    print('⚠️ Unknown status: "$status" (normalized: "$normalizedStatus") for van ${plateNumber}');
    if (status.isNotEmpty) {
      final formatted = status[0].toUpperCase() + status.substring(1).toLowerCase();
      print('Returning formatted status: "$formatted"');
      return formatted;
    }
    
    return 'Unknown';
  }

  Color get statusColor {
    final normalizedStatus = status.toLowerCase().trim();
    
    switch (normalizedStatus) {
      // Ready/Active states - Green
      case 'in_queue':
      case 'in-queue':
      case 'queue':
      case 'active':
      case 'ready':
      case 'available':
        return const Color(0xFF4CAF50); // Green
        
      // Boarding/Loading states - Blue
      case 'boarding':
      case 'loading':
        return const Color(0xFF2196F3); // Blue
        
      // Transit states - Purple
      case 'in_transit':
      case 'in-transit':
      case 'transit':
      case 'traveling':
      case 'departing':
        return const Color(0xFF9C27B0); // Purple
        
      // Maintenance states - Orange
      case 'maintenance':
      case 'under_maintenance':
      case 'under-maintenance':
        return const Color(0xFFFF9800); // Orange
        
      // Inactive states - Grey
      case 'inactive':
      case 'offline':
      case 'disabled':
        return const Color(0xFF9E9E9E); // Grey
        
      // Busy states - Red
      case 'busy':
      case 'occupied':
      case 'full':
        return const Color(0xFFF44336); // Red
        
      default:
        return const Color(0xFF757575); // Default grey
    }
  }

  bool get canBook {
    final normalizedStatus = status.toLowerCase().trim();
    return isActive && 
           VanStatus.bookableStatuses.contains(normalizedStatus) && 
           currentOccupancy < capacity;
  }

  factory Van.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Van(
      id: doc.id,
      plateNumber: data['plateNumber'] ?? '',
      capacity: data['capacity'] ?? 0,
      driver: Driver.fromMap(data['driver'] ?? {}),
      status: data['status'] ?? 'inactive',
      currentRouteId: data['currentRouteId'],
      queuePosition: data['queuePosition'] ?? 0,
      lastMaintenance: (data['lastMaintenance'] as Timestamp?)?.toDate(),
      nextMaintenance: (data['nextMaintenance'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentOccupancy: data['currentOccupancy'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'plateNumber': plateNumber,
      'capacity': capacity,
      'driver': driver.toMap(),
      'status': status,
      'currentRouteId': currentRouteId,
      'queuePosition': queuePosition,
      'lastMaintenance': lastMaintenance != null ? Timestamp.fromDate(lastMaintenance!) : null,
      'nextMaintenance': nextMaintenance != null ? Timestamp.fromDate(nextMaintenance!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentOccupancy': currentOccupancy,
    };
  }

  Van copyWith({
    String? id,
    String? plateNumber,
    int? capacity,
    Driver? driver,
    String? status,
    String? currentRouteId,
    int? queuePosition,
    DateTime? lastMaintenance,
    DateTime? nextMaintenance,
    bool? isActive,
    DateTime? createdAt,
    int? currentOccupancy,
  }) {
    return Van(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      capacity: capacity ?? this.capacity,
      driver: driver ?? this.driver,
      status: status ?? this.status,
      currentRouteId: currentRouteId ?? this.currentRouteId,
      queuePosition: queuePosition ?? this.queuePosition,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      nextMaintenance: nextMaintenance ?? this.nextMaintenance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
    );
  }
}