import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentDelivery {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhone;
  final String senderEmail;
  final String receiverName;
  final String recipientPhone;
  final String recipientAddress;
  final String documentType;
  final String deliveryStatus; // pending, picked_up, in_transit, delivered, cancelled
  final String paymentStatus;  // pending, paid, failed, refunded
  final String paymentMethod;
  final double bookingFee;
  final double paymentAmount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveryDate;
  final String? trackingNumber;
  final String? notes;
  final String? vanPlateNumber;
  final String? driverName;
  final String? driverContact;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? proofOfPaymentBase64;

  DocumentDelivery({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhone,
    required this.senderEmail,
    required this.receiverName,
    required this.recipientPhone,
    required this.recipientAddress,
    required this.documentType,
    required this.deliveryStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.bookingFee,
    required this.paymentAmount,
    required this.createdAt,
    this.updatedAt,
    this.deliveryDate,
    this.trackingNumber,
    this.notes,
    this.vanPlateNumber,
    this.driverName,
    this.driverContact,
    this.cancelledBy,
    this.cancellationReason,
    this.cancelledAt,
    this.proofOfPaymentBase64,
  });

  factory DocumentDelivery.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime _parseDate(dynamic value, [DateTime? fallback]) {
      if (value == null) return fallback ?? DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    DateTime? _parseDateNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return DocumentDelivery(
      id: doc.id,
      senderId: data['senderId'] ?? data['userId'] ?? '',
      senderName: data['senderName'] ?? data['userName'] ?? data['sender_name'] ?? '',
      senderPhone: data['senderPhone'] ?? data['sender_phone'] ?? data['senderContact'] ?? data['phone'] ?? '',
      senderEmail: data['senderEmail'] ?? data['userEmail'] ?? data['sender_email'] ?? '',
      receiverName: data['receiverName'] ?? data['receiver_name'] ?? '',
      recipientPhone: data['recipientPhone'] ?? data['recipient_phone'] ?? data['receiverContact'] ?? data['recipientContact'] ?? '',
      recipientAddress: data['recipientAddress'] ?? data['recipient_address'] ?? data['address'] ?? '',
      documentType: data['documentType'] ?? data['document_Type'] ?? data['description'] ?? '',
      deliveryStatus: data['deliveryStatus'] ?? data['delivery_status'] ?? data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? data['payment_status'] ?? 'unpaid',
      paymentMethod: data['paymentMethod'] ?? data['payment_method'] ?? '',
      bookingFee: (data['bookingFee'] ?? data['booking_fee'] ?? data['fee'] ?? 0).toDouble(),
      paymentAmount: (data['paymentAmount'] ?? data['payment_amount'] ?? data['amount'] ?? 0).toDouble(),
      createdAt: _parseDate(data['createdAt'] ?? data['created_at'] ?? data['bookingDate']),
      updatedAt: _parseDateNullable(data['updatedAt'] ?? data['updated_at']),
      deliveryDate: _parseDateNullable(data['deliveryDate'] ?? data['delivery_date'] ?? data['scheduledDate']),
      trackingNumber: data['trackingNumber'] ?? data['tracking_number'] ?? data['eTicketId'],
      notes: data['notes'] ?? data['remarks'],
      vanPlateNumber: data['vanPlateNumber'] ?? data['van_plate_number'],
      driverName: data['driverName'] ?? data['driver_name'],
      driverContact: data['driverContact'] ?? data['driver_contact'],
      cancelledBy: data['cancelledBy'] ?? data['cancelled_by'],
      cancellationReason: data['cancellationReason'] ?? data['cancellation_reason'],
      cancelledAt: _parseDateNullable(data['cancelledAt'] ?? data['cancelled_at']),
      proofOfPaymentBase64: data['proofOfPaymentBase64'] ?? data['paymentProofBase64'] ?? data['gcashProofBase64'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'senderContact': senderPhone,
      'senderEmail': senderEmail,
      'receiverName': receiverName,
      'recipientPhone': recipientPhone,
      'receiverContact': recipientPhone,
      'recipientAddress': recipientAddress,
      'documentType': documentType,
      'deliveryStatus': deliveryStatus,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'bookingFee': bookingFee,
      'paymentAmount': paymentAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'trackingNumber': trackingNumber,
      'notes': notes,
      'vanPlateNumber': vanPlateNumber,
      'driverName': driverName,
      'driverContact': driverContact,
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'proofOfPaymentBase64': proofOfPaymentBase64,
    };
  }

  DocumentDelivery copyWith({
    String? deliveryStatus,
    String? paymentStatus,
    String? vanPlateNumber,
    String? driverName,
    String? driverContact,
    String? notes,
    DateTime? deliveryDate,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancellationReason,
    String? proofOfPaymentBase64,
  }) {
    return DocumentDelivery(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderPhone: senderPhone,
      senderEmail: senderEmail,
      receiverName: receiverName,
      recipientPhone: recipientPhone,
      recipientAddress: recipientAddress,
      documentType: documentType,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod,
      bookingFee: bookingFee,
      paymentAmount: paymentAmount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deliveryDate: deliveryDate ?? this.deliveryDate,
      trackingNumber: trackingNumber,
      notes: notes ?? this.notes,
      vanPlateNumber: vanPlateNumber ?? this.vanPlateNumber,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      proofOfPaymentBase64: proofOfPaymentBase64 ?? this.proofOfPaymentBase64,
    );
  }
}
