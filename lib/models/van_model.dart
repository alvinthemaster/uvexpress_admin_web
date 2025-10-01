import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

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
    );
  }
}