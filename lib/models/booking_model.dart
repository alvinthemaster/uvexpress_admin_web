import 'package:cloud_firestore/cloud_firestore.dart';

class PassengerDetails {
  final String name;
  final String email;
  final String phone;

  PassengerDetails({
    required this.name,
    required this.email,
    required this.phone,
  });

  factory PassengerDetails.fromMap(Map<String, dynamic> data) {
    return PassengerDetails(
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
    };
  }
}

class Booking {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String routeId;
  final String routeName;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime bookingDate;
  final List<String> seatIds;
  final int numberOfSeats;
  final double basePrice;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus; // pending, paid, failed, refunded
  final String bookingStatus; // active, completed, cancelled
  final String? qrCodeData;
  final String? eTicketId;
  final PassengerDetails passengerDetails;
  final String? discountApplied;

  Booking({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.routeId,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.bookingDate,
    required this.seatIds,
    required this.numberOfSeats,
    required this.basePrice,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.bookingStatus,
    this.qrCodeData,
    this.eTicketId,
    required this.passengerDetails,
    this.discountApplied,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      routeId: data['routeId'] ?? '',
      routeName: data['routeName'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      departureTime: (data['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookingDate: (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seatIds: List<String>.from(data['seatIds'] ?? []),
      numberOfSeats: data['numberOfSeats'] ?? 0,
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? '',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      bookingStatus: data['bookingStatus'] ?? 'active',
      qrCodeData: data['qrCodeData'],
      eTicketId: data['eTicketId'],
      passengerDetails: PassengerDetails.fromMap(data['passengerDetails'] ?? {}),
      discountApplied: data['discountApplied'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'routeId': routeId,
      'routeName': routeName,
      'origin': origin,
      'destination': destination,
      'departureTime': Timestamp.fromDate(departureTime),
      'bookingDate': Timestamp.fromDate(bookingDate),
      'seatIds': seatIds,
      'numberOfSeats': numberOfSeats,
      'basePrice': basePrice,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'bookingStatus': bookingStatus,
      'qrCodeData': qrCodeData,
      'eTicketId': eTicketId,
      'passengerDetails': passengerDetails.toMap(),
      'discountApplied': discountApplied,
    };
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? routeId,
    String? routeName,
    String? origin,
    String? destination,
    DateTime? departureTime,
    DateTime? bookingDate,
    List<String>? seatIds,
    int? numberOfSeats,
    double? basePrice,
    double? discountAmount,
    double? totalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? bookingStatus,
    String? qrCodeData,
    String? eTicketId,
    PassengerDetails? passengerDetails,
    String? discountApplied,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureTime: departureTime ?? this.departureTime,
      bookingDate: bookingDate ?? this.bookingDate,
      seatIds: seatIds ?? this.seatIds,
      numberOfSeats: numberOfSeats ?? this.numberOfSeats,
      basePrice: basePrice ?? this.basePrice,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      eTicketId: eTicketId ?? this.eTicketId,
      passengerDetails: passengerDetails ?? this.passengerDetails,
      discountApplied: discountApplied ?? this.discountApplied,
    );
  }
}