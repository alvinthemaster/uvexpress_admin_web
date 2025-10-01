import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;
  final String routeId;
  final String vanId;
  final DateTime departureTime;
  final DateTime? arrivalEstimate;
  final int availableSeats;
  final List<String> seatIds;
  final String status; // scheduled, in_transit, completed, cancelled

  Schedule({
    required this.id,
    required this.routeId,
    required this.vanId,
    required this.departureTime,
    this.arrivalEstimate,
    required this.availableSeats,
    required this.seatIds,
    required this.status,
  });

  factory Schedule.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Schedule(
      id: doc.id,
      routeId: data['routeId'] ?? '',
      vanId: data['vanId'] ?? '',
      departureTime: (data['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      arrivalEstimate: (data['arrivalEstimate'] as Timestamp?)?.toDate(),
      availableSeats: data['availableSeats'] ?? 0,
      seatIds: List<String>.from(data['seatIds'] ?? []),
      status: data['status'] ?? 'scheduled',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'routeId': routeId,
      'vanId': vanId,
      'departureTime': Timestamp.fromDate(departureTime),
      'arrivalEstimate': arrivalEstimate != null ? Timestamp.fromDate(arrivalEstimate!) : null,
      'availableSeats': availableSeats,
      'seatIds': seatIds,
      'status': status,
    };
  }

  Schedule copyWith({
    String? id,
    String? routeId,
    String? vanId,
    DateTime? departureTime,
    DateTime? arrivalEstimate,
    int? availableSeats,
    List<String>? seatIds,
    String? status,
  }) {
    return Schedule(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      vanId: vanId ?? this.vanId,
      departureTime: departureTime ?? this.departureTime,
      arrivalEstimate: arrivalEstimate ?? this.arrivalEstimate,
      availableSeats: availableSeats ?? this.availableSeats,
      seatIds: seatIds ?? this.seatIds,
      status: status ?? this.status,
    );
  }
}