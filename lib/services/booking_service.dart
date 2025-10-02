import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';

  // Get all bookings stream
  Stream<List<Booking>> getBookingsStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get bookings by status
  Stream<List<Booking>> getBookingsByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('bookingStatus', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get bookings by payment status
  Stream<List<Booking>> getBookingsByPaymentStatus(String paymentStatus) {
    return _firestore
        .collection(_collection)
        .where('paymentStatus', isEqualTo: paymentStatus)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  // Get bookings by date range
  Stream<List<Booking>> getBookingsByDateRange(DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_collection)
        .where('bookingDate', isGreaterThanOrEqualTo: startDate)
        .where('bookingDate', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get bookings by route
  Stream<List<Booking>> getBookingsByRoute(String routeId) {
    return _firestore
        .collection(_collection)
        .where('routeId', isEqualTo: routeId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get booking by ID
  Future<Booking?> getBookingById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String id, String status) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'bookingStatus': status,
      });
    } catch (e) {
      print('Error updating booking status: $e');
      rethrow;
    }
  }

  // Update payment status
  Future<void> updatePaymentStatus(String id, String paymentStatus) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'paymentStatus': paymentStatus,
      });
    } catch (e) {
      print('Error updating payment status: $e');
      rethrow;
    }
  }

  // Cancel booking
  Future<void> cancelBooking(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'bookingStatus': 'cancelled',
      });
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  // Get today's bookings
  Stream<List<Booking>> getTodayBookings() {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return getBookingsByDateRange(startOfDay, endOfDay);
  }

  // Get active bookings (not cancelled or completed)
  Stream<List<Booking>> getActiveBookings() {
    return _firestore
        .collection(_collection)
        .where('bookingStatus', whereIn: ['active', 'confirmed'])
        .orderBy('departureTime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  // Search bookings by passenger name or email
  Stream<List<Booking>> searchBookings(String query) {
    return _firestore
        .collection(_collection)
        .where('userName', isGreaterThanOrEqualTo: query)
        .where('userName', isLessThan: query + 'z')
        .orderBy('userName')
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  // Get booking statistics for a date range
  Future<Map<String, dynamic>> getBookingStatistics(DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startDate)
          .where('bookingDate', isLessThanOrEqualTo: endDate)
          .get();

      List<Booking> bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();

      int totalBookings = bookings.length;
      int activeBookings = bookings.where((b) => b.bookingStatus == 'active').length;
      int cancelledBookings = bookings.where((b) => b.bookingStatus == 'cancelled').length;
      int completedBookings = bookings.where((b) => b.bookingStatus == 'completed').length;

      double totalRevenue = bookings
          .where((b) => b.paymentStatus == 'paid')
          .fold(0.0, (sum, booking) => sum + booking.totalAmount);

      double totalDiscounts = bookings
          .fold(0.0, (sum, booking) => sum + booking.discountAmount);

      int totalPassengers = bookings
          .fold(0, (sum, booking) => sum + booking.numberOfSeats);

      return {
        'totalBookings': totalBookings,
        'activeBookings': activeBookings,
        'cancelledBookings': cancelledBookings,
        'completedBookings': completedBookings,
        'totalRevenue': totalRevenue,
        'totalDiscounts': totalDiscounts,
        'totalPassengers': totalPassengers,
        'averageBookingValue': totalBookings > 0 ? totalRevenue / totalBookings : 0.0,
      };
    } catch (e) {
      print('Error getting booking statistics: $e');
      return {};
    }
  }

  // Get revenue by payment method
  Future<Map<String, double>> getRevenueByPaymentMethod(DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startDate)
          .where('bookingDate', isLessThanOrEqualTo: endDate)
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      List<Booking> bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      Map<String, double> revenueByMethod = {};

      for (Booking booking in bookings) {
        revenueByMethod[booking.paymentMethod] = 
            (revenueByMethod[booking.paymentMethod] ?? 0.0) + booking.totalAmount;
      }

      return revenueByMethod;
    } catch (e) {
      print('Error getting revenue by payment method: $e');
      return {};
    }
  }

  // Get hourly booking distribution
  Future<Map<int, int>> getHourlyBookingDistribution(DateTime date) async {
    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startOfDay)
          .where('bookingDate', isLessThanOrEqualTo: endOfDay)
          .get();

      List<Booking> bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      Map<int, int> hourlyDistribution = {};

      // Initialize all hours with 0
      for (int i = 0; i < 24; i++) {
        hourlyDistribution[i] = 0;
      }

      // Count bookings by hour
      for (Booking booking in bookings) {
        int hour = booking.bookingDate.hour;
        hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
      }

      return hourlyDistribution;
    } catch (e) {
      print('Error getting hourly booking distribution: $e');
      return {};
    }
  }
}