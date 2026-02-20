import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a van rental booking submitted by a user.
/// All fields are stored in the Firestore `van_rentals` collection so the
/// mobile app can fetch and display rental details without extra look-ups.
class VanRental {
  final String id;

  // ── Renter information ────────────────────────────────────────────────────
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;

  // ── Van / driver information (denormalised for easy app-side access) ──────
  final String vanId;
  final String vanPlateNumber;
  final String vehicleType; // 'van' | 'bus'
  final int vanCapacity;
  final String driverName;
  final String driverContact;
  final String driverLicense;

  // ── Rental details ────────────────────────────────────────────────────────
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays; // stored explicitly so app doesn't need to compute
  final double pricePerDay;
  final double additionalCharges; // e.g. fuel surcharge, toll fees
  final double discountAmount;
  final double totalAmount;

  // ── Passengers & purpose ─────────────────────────────────────────────────
  final int passengerCount;
  final String purpose; // e.g. 'Family trip', 'Corporate', 'Tourism', etc.
  final String specialRequests;

  // ── Payment ───────────────────────────────────────────────────────────────
  final String paymentMethod; // GCash | Maya | Physical Payment | PayPal
  final String paymentStatus; // pending | paid | failed | refunded
  final String? paymentReference; // transaction reference number

  // ── Status workflow ───────────────────────────────────────────────────────
  /// pending → confirmed → active → completed  (or cancelled at any stage)
  final String rentalStatus;

  // ── Timestamps ────────────────────────────────────────────────────────────
  final DateTime bookingDate;
  final DateTime? confirmedAt;
  final DateTime? activatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // ── Cancellation ─────────────────────────────────────────────────────────
  final String? cancellationReason;
  final String? cancelledBy; // 'user' | 'admin'

  // ── Admin notes ───────────────────────────────────────────────────────────
  final String? adminNotes;
  final bool adminCompletion;

  const VanRental({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.vanId,
    required this.vanPlateNumber,
    this.vehicleType = 'van',
    this.vanCapacity = 0,
    required this.driverName,
    required this.driverContact,
    this.driverLicense = '',
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.pricePerDay,
    this.additionalCharges = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.passengerCount = 1,
    this.purpose = '',
    this.specialRequests = '',
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference,
    required this.rentalStatus,
    required this.bookingDate,
    this.confirmedAt,
    this.activatedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
    this.adminNotes,
    this.adminCompletion = false,
  });

  // ── Factory: Firestore document → model ───────────────────────────────────
  factory VanRental.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VanRental(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userPhone: data['userPhone'] ?? '',
      vanId: data['vanId'] ?? '',
      vanPlateNumber: data['vanPlateNumber'] ?? '',
      vehicleType: data['vehicleType'] ?? 'van',
      vanCapacity: data['vanCapacity'] ?? 0,
      driverName: data['driverName'] ?? '',
      driverContact: data['driverContact'] ?? '',
      driverLicense: data['driverLicense'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      dropoffAddress: data['dropoffAddress'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      numberOfDays: data['numberOfDays'] ?? 1,
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      additionalCharges:
          (data['additionalCharges'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      passengerCount: data['passengerCount'] ?? 1,
      purpose: data['purpose'] ?? '',
      specialRequests: data['specialRequests'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      paymentReference: data['paymentReference'],
      rentalStatus: data['rentalStatus'] ?? 'pending',
      bookingDate:
          (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: data['cancellationReason'],
      cancelledBy: data['cancelledBy'],
      adminNotes: data['adminNotes'],
      adminCompletion: data['adminCompletion'] ?? false,
    );
  }

  // ── Model → Firestore document ────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      // Renter
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      // Van / driver
      'vanId': vanId,
      'vanPlateNumber': vanPlateNumber,
      'vehicleType': vehicleType,
      'vanCapacity': vanCapacity,
      'driverName': driverName,
      'driverContact': driverContact,
      'driverLicense': driverLicense,
      // Rental
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfDays': numberOfDays,
      'pricePerDay': pricePerDay,
      'additionalCharges': additionalCharges,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      // Passengers / purpose
      'passengerCount': passengerCount,
      'purpose': purpose,
      'specialRequests': specialRequests,
      // Payment
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      // Status & timestamps
      'rentalStatus': rentalStatus,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'confirmedAt':
          confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'activatedAt':
          activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      // Admin
      'adminNotes': adminNotes,
      'adminCompletion': adminCompletion,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  VanRental copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? vanId,
    String? vanPlateNumber,
    String? vehicleType,
    int? vanCapacity,
    String? driverName,
    String? driverContact,
    String? driverLicense,
    String? pickupAddress,
    String? dropoffAddress,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfDays,
    double? pricePerDay,
    double? additionalCharges,
    double? discountAmount,
    double? totalAmount,
    int? passengerCount,
    String? purpose,
    String? specialRequests,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentReference,
    String? rentalStatus,
    DateTime? bookingDate,
    DateTime? confirmedAt,
    DateTime? activatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? cancelledBy,
    String? adminNotes,
    bool? adminCompletion,
  }) {
    return VanRental(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      vanId: vanId ?? this.vanId,
      vanPlateNumber: vanPlateNumber ?? this.vanPlateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vanCapacity: vanCapacity ?? this.vanCapacity,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      driverLicense: driverLicense ?? this.driverLicense,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      passengerCount: passengerCount ?? this.passengerCount,
      purpose: purpose ?? this.purpose,
      specialRequests: specialRequests ?? this.specialRequests,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      rentalStatus: rentalStatus ?? this.rentalStatus,
      bookingDate: bookingDate ?? this.bookingDate,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      adminNotes: adminNotes ?? this.adminNotes,
      adminCompletion: adminCompletion ?? this.adminCompletion,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  /// Colour for the current rental status badge.
  static const Map<String, int> statusColors = {
    'pending': 0xFFF57C00, // orange
    'confirmed': 0xFF1976D2, // blue
    'active': 0xFF4CAF50, // green
    'completed': 0xFF607D8B, // blue-grey
    'cancelled': 0xFFB00020, // red
  };

  int get statusColorValue => statusColors[rentalStatus] ?? 0xFF9E9E9E;

  String get statusDisplay {
    switch (rentalStatus) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return rentalStatus[0].toUpperCase() +
            rentalStatus.substring(1).toLowerCase();
    }
  }
}
