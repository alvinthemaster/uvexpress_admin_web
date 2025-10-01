import 'package:cloud_firestore/cloud_firestore.dart';

class Route {
  final String id;
  final String name;
  final String origin;
  final String destination;
  final double basePrice;
  final int estimatedDuration; // in minutes
  final List<String> waypoints;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Route({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.basePrice,
    required this.estimatedDuration,
    required this.waypoints,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Route.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Route(
      id: doc.id,
      name: data['name'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      estimatedDuration: data['estimatedDuration'] ?? 0,
      waypoints: List<String>.from(data['waypoints'] ?? []),
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'origin': origin,
      'destination': destination,
      'basePrice': basePrice,
      'estimatedDuration': estimatedDuration,
      'waypoints': waypoints,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Route copyWith({
    String? id,
    String? name,
    String? origin,
    String? destination,
    double? basePrice,
    int? estimatedDuration,
    List<String>? waypoints,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      basePrice: basePrice ?? this.basePrice,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      waypoints: waypoints ?? this.waypoints,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}