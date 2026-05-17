import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a van rental request submitted by a user via the mobile app.
/// Stored in the `van_rental_requests` Firestore collection.
class VanRentalRequest {
  final String id;
  final String? listingId;
  final String? vanId;
  final String vanPlateNumber;
  final String brand;
  final String pickupLocation;
  final String dropoffLocation;
  final double pricePerDay;
  final String purpose;
  final DateTime rentalStartDate;
  final DateTime rentalEndDate;
  final String specialRequirements;
  final String status; // pending | rejected | cancelled | completed
  final String subStatus; // in_use | returned | none
  final String paymentStatus; // pending | paid
  final double totalAmount;
  final double? depositAmount;
  final int totalDays;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? returnedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final Map<String, bool>? vehicleChecklist;
  final double? damageAmount;
  final List<Map<String, dynamic>>? damageLineItems;
  final double? depositDeductedAmount;
  final double? refundedAmount;
  final double? damageExcessAmount;
  final bool withDriver;
  final String? driverLicenseFileName;
  final String? driverLicenseBase64;
  final String? proofOfPurposeFileName;
  final String? proofOfPurposeBase64;
  final String? proofOfPaymentFileName;
  final String? proofOfPaymentBase64;

  const VanRentalRequest({
    required this.id,
    this.listingId,
    this.vanId,
    this.vanPlateNumber = '',
    required this.brand,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pricePerDay,
    required this.purpose,
    required this.rentalStartDate,
    required this.rentalEndDate,
    required this.specialRequirements,
    required this.status,
    this.subStatus = 'none',
    this.paymentStatus = 'pending',
    required this.totalAmount,
    this.depositAmount,
    required this.totalDays,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
    this.returnedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.vehicleChecklist,
    this.damageAmount,
    this.damageLineItems,
    this.depositDeductedAmount,
    this.refundedAmount,
    this.damageExcessAmount,
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
      listingId: data['listingId'] as String?,
      vanId: data['vanId'] as String?,
      vanPlateNumber: (data['vanPlateNumber'] as String?) ??
          (data['plateNumber'] as String?) ??
          '',
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
      subStatus: data['subStatus'] as String? ?? 'none',
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
      returnedAt: (data['returnedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: data['cancellationReason'] as String?,
      vehicleChecklist: (data['vehicleChecklist'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value == true)),
      damageAmount: (data['damageAmount'] as num?)?.toDouble(),
      damageLineItems: (data['damageLineItems'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((item) => {
                  'description': (item['description'] as String? ?? '').trim(),
                  'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
                })
            .toList(),
      depositDeductedAmount:
          (data['depositDeductedAmount'] as num?)?.toDouble(),
      refundedAmount: (data['refundedAmount'] as num?)?.toDouble(),
      damageExcessAmount: (data['damageExcessAmount'] as num?)?.toDouble(),
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
    'rejected': 0xFFB00020,
    'cancelled': 0xFF9E9E9E,
    'completed': 0xFF388E3C,
  };

  // Sub-status colour map for ongoing rental state
  static const Map<String, int> subStatusColors = {
    'in_use': 0xFF1976D2,
    'returned': 0xFF388E3C,
    'none': 0xFF9E9E9E,
  };

  // Payment status colour map
  static const Map<String, int> paymentColors = {
    'pending': 0xFFF57C00,
    'paid': 0xFF388E3C,
  };
}
