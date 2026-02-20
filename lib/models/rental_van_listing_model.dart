import 'package:cloud_firestore/cloud_firestore.dart';

/// A van listing configured by the admin as available for rental.
/// Stored in the `rental_vans` Firestore collection.
///
/// The mobile app reads this collection to show users which vans they
/// can rent, including pricing, availability, features, and pickup location.
class RentalVanListing {
  final String id;

  // ── Van identity (denormalised for fast app-side reads) ───────────────────
  final String vanId; // reference to the vans collection
  final String plateNumber;
  final String vehicleType; // 'van' | 'bus'
  final int capacity;
  final String brand; // e.g. 'Toyota HiAce'
  final String color;

  // ── Driver info ───────────────────────────────────────────────────────────
  final String driverName;
  final String driverContact;
  final String driverLicense;

  // ── Rental pricing ────────────────────────────────────────────────────────
  final double pricePerDay;
  final int minRentalDays; // minimum number of days required
  final int maxRentalDays; // 0 = no limit

  // ── Description & features ────────────────────────────────────────────────
  final String description;
  final List<String> amenities; // e.g. ['AC', 'Wi-Fi', 'GPS', 'First Aid Kit']
  final List<String> imageUrls; // Firebase Storage / external URLs

  // ── Location ──────────────────────────────────────────────────────────────
  final String pickupLocation; // default pickup point shown to the user

  // ── Availability ─────────────────────────────────────────────────────────
  final bool isAvailable; // master toggle: admin can disable a listing
  final DateTime? availableFrom; // null = always available from now
  final DateTime? availableTo; // null = no end date
  final List<String> blockedDates; // ISO-8601 date strings blocked by admin

  // ── Metadata ─────────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime updatedAt;
  final String adminNotes; // internal notes, not shown to users

  const RentalVanListing({
    required this.id,
    required this.vanId,
    required this.plateNumber,
    this.vehicleType = 'van',
    this.capacity = 0,
    this.brand = '',
    this.color = '',
    required this.driverName,
    required this.driverContact,
    this.driverLicense = '',
    required this.pricePerDay,
    this.minRentalDays = 1,
    this.maxRentalDays = 0,
    this.description = '',
    this.amenities = const [],
    this.imageUrls = const [],
    this.pickupLocation = '',
    this.isAvailable = true,
    this.availableFrom,
    this.availableTo,
    this.blockedDates = const [],
    required this.createdAt,
    required this.updatedAt,
    this.adminNotes = '',
  });

  // ── Factory: Firestore → model ────────────────────────────────────────────
  factory RentalVanListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RentalVanListing(
      id: doc.id,
      vanId: data['vanId'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      vehicleType: data['vehicleType'] ?? 'van',
      capacity: data['capacity'] ?? 0,
      brand: data['brand'] ?? '',
      color: data['color'] ?? '',
      driverName: data['driverName'] ?? '',
      driverContact: data['driverContact'] ?? '',
      driverLicense: data['driverLicense'] ?? '',
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      minRentalDays: data['minRentalDays'] ?? 1,
      maxRentalDays: data['maxRentalDays'] ?? 0,
      description: data['description'] ?? '',
      amenities: data['amenities'] != null
          ? List<String>.from(data['amenities'])
          : [],
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      pickupLocation: data['pickupLocation'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      availableFrom: (data['availableFrom'] as Timestamp?)?.toDate(),
      availableTo: (data['availableTo'] as Timestamp?)?.toDate(),
      blockedDates: data['blockedDates'] != null
          ? List<String>.from(data['blockedDates'])
          : [],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminNotes: data['adminNotes'] ?? '',
    );
  }

  // ── Model → Firestore ─────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      // Van identity
      'vanId': vanId,
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'capacity': capacity,
      'brand': brand,
      'color': color,
      // Driver
      'driverName': driverName,
      'driverContact': driverContact,
      'driverLicense': driverLicense,
      // Pricing
      'pricePerDay': pricePerDay,
      'minRentalDays': minRentalDays,
      'maxRentalDays': maxRentalDays,
      // Content
      'description': description,
      'amenities': amenities,
      'imageUrls': imageUrls,
      'pickupLocation': pickupLocation,
      // Availability
      'isAvailable': isAvailable,
      'availableFrom':
          availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableTo':
          availableTo != null ? Timestamp.fromDate(availableTo!) : null,
      'blockedDates': blockedDates,
      // Metadata
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'adminNotes': adminNotes,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  RentalVanListing copyWith({
    String? id,
    String? vanId,
    String? plateNumber,
    String? vehicleType,
    int? capacity,
    String? brand,
    String? color,
    String? driverName,
    String? driverContact,
    String? driverLicense,
    double? pricePerDay,
    int? minRentalDays,
    int? maxRentalDays,
    String? description,
    List<String>? amenities,
    List<String>? imageUrls,
    String? pickupLocation,
    bool? isAvailable,
    DateTime? availableFrom,
    DateTime? availableTo,
    List<String>? blockedDates,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminNotes,
  }) {
    return RentalVanListing(
      id: id ?? this.id,
      vanId: vanId ?? this.vanId,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      capacity: capacity ?? this.capacity,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      driverLicense: driverLicense ?? this.driverLicense,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      minRentalDays: minRentalDays ?? this.minRentalDays,
      maxRentalDays: maxRentalDays ?? this.maxRentalDays,
      description: description ?? this.description,
      amenities: amenities ?? this.amenities,
      imageUrls: imageUrls ?? this.imageUrls,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      isAvailable: isAvailable ?? this.isAvailable,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      blockedDates: blockedDates ?? this.blockedDates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  // ── Common amenity presets (used in the form UI) ──────────────────────────
  static const List<String> amenityPresets = [
    'Air Conditioning',
    'Wi-Fi',
    'GPS Navigation',
    'First Aid Kit',
    'Cooler / Refrigerator',
    'USB Charging Ports',
    'Entertainment System',
    'Reclining Seats',
    'Tinted Windows',
    'CCTV / Dashcam',
    'Fuel Included',
    'Driver Included',
  ];
}
