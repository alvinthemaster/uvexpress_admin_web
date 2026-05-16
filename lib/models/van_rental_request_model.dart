import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a van rental request submitted by a user via the mobile app.
/// Stored in the `van_rental_requests` Firestore collection.
class VanRentalRequest {
  final String id;
  final String brand;
  final String pickupLocation;
  final String dropoffLocation;
  final double pricePerDay;
  final String purpose;
  final DateTime rentalStartDate;
  final DateTime rentalEndDate;
  final String specialRequirements;
  final String status; // pending | approved | rejected | cancelled | completed
  final String paymentStatus; // pending | paid
  final double totalAmount;
  final double? depositAmount;
  final int totalDays;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool withDriver;
  final String? driverLicenseFileName;
  final String? driverLicenseBase64;
  final String? proofOfPurposeFileName;
  final String? proofOfPurposeBase64;
  final String? proofOfPaymentFileName;
  final String? proofOfPaymentBase64;

  const VanRentalRequest({
    required this.id,
    required this.brand,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pricePerDay,
    required this.purpose,
    required this.rentalStartDate,
    required this.rentalEndDate,
    required this.specialRequirements,
    required this.status,
    this.paymentStatus = 'pending',
    required this.totalAmount,
    this.depositAmount,
    required this.totalDays,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.withDriver = false,
    this.driverLicenseFileName,
    this.driverLicenseBase64,
    this.proofOfPurposeFileName,
    this.proofOfPurposeBase64,
    this.proofOfPaymentFileName,
    this.proofOfPaymentBase64,
  });

  factory VanRentalRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VanRentalRequest(
      id: doc.id,
      brand: data['brand'] as String? ?? '',
      pickupLocation: data['pickupLocation'] as String? ?? '',
      dropoffLocation: data['dropoffLocation'] as String? ?? '',
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      purpose: data['purpose'] as String? ?? '',
      rentalStartDate:
          (data['rentalStartDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rentalEndDate:
          (data['rentalEndDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      specialRequirements: data['specialRequirements'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      paymentStatus: data['paymentStatus'] as String? ?? 'pending',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: data['depositAmount'] != null
          ? (data['depositAmount'] as num).toDouble()
          : null,
      totalDays: (data['totalDays'] as num?)?.toInt() ?? 0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: data['cancellationReason'] as String?,
      withDriver: (data['withDriver'] ?? false) == true,
      driverLicenseFileName: data['driverLicenseFileName'] as String?,
      driverLicenseBase64: data['driverLicenseBase64'] as String?,
      proofOfPurposeFileName: data['proofOfPurposeFileName'] as String?,
      proofOfPurposeBase64: data['proofOfPurposeBase64'] as String?,
      proofOfPaymentFileName: data['proofOfPaymentFileName'] as String?,
      proofOfPaymentBase64: data['proofOfPaymentBase64'] as String?,
    );
  }

  // Status colour map for UI badges
  static const Map<String, int> statusColors = {
    'pending': 0xFFF57C00,
    'approved': 0xFF1976D2,
    'rejected': 0xFFB00020,
    'cancelled': 0xFF9E9E9E,
    'completed': 0xFF388E3C,
  };

  // Payment status colour map
  static const Map<String, int> paymentColors = {
    'pending': 0xFFF57C00,
    'paid': 0xFF388E3C,
  };
}
