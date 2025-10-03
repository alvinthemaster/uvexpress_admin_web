import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/van_model.dart';
import 'van_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';
  final VanService _vanService = VanService();

  // Get all bookings stream
  Stream<List<Booking>> getBookingsStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
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
      final bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  // Get bookings by date range
  Stream<List<Booking>> getBookingsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_collection)
        .where('bookingDate', isGreaterThanOrEqualTo: startDate)
        .where('bookingDate', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) {
      final bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
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
      final bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
      return bookings;
    });
  }

  // Get booking by ID
  Future<Booking?> getBookingById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(id).get();
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

  // Create a new booking
  Future<String> createBooking(Booking booking) async {
    try {
      // Add the booking to Firestore
      DocumentReference docRef = await _firestore.collection(_collection).add(booking.toFirestore());
      
      // Update van occupancy for the route and schedule
      await _updateVanOccupancyForRoute(booking.routeId);
      
      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  // Update booking status and handle van occupancy changes
  Future<void> updateBookingStatusWithVanUpdate(String id, String newStatus) async {
    try {
      // Get the current booking
      Booking? booking = await getBookingById(id);
      if (booking == null) {
        throw Exception('Booking not found');
      }
      
      // Update booking status
      await updateBookingStatus(id, newStatus);
      
      // Update van occupancy for the route
      await _updateVanOccupancyForRoute(booking.routeId);
    } catch (e) {
      print('Error updating booking status with van update: $e');
      rethrow;
    }
  }

  // Calculate and update van occupancy for all vans on a route
  Future<void> _updateVanOccupancyForRoute(String routeId) async {
    try {
      // Get all vans assigned to this route
      List<Van> vansOnRoute = await _vanService.getVansByRoute(routeId);
      
      for (Van van in vansOnRoute) {
        await _updateVanOccupancyFromBookings(van.id);
      }
    } catch (e) {
      print('Error updating van occupancy for route: $e');
      rethrow;
    }
  }

  // Calculate current occupancy for a van based on active bookings
  Future<void> _updateVanOccupancyFromBookings(String vanId) async {
    try {
      // For now, we'll calculate based on route bookings
      // In a more complex system, you might have schedule/trip specific bookings
      Van? van = await _vanService.getVanById(vanId);
      if (van == null || van.currentRouteId == null) return;

      // Get all confirmed bookings for this route for today
      DateTime today = DateTime.now();
      DateTime startOfDay = DateTime(today.year, today.month, today.day);
      DateTime endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      QuerySnapshot bookingSnapshot = await _firestore
          .collection(_collection)
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('bookingStatus', whereIn: ['confirmed', 'active'])
          .where('departureTime', isGreaterThanOrEqualTo: startOfDay)
          .where('departureTime', isLessThanOrEqualTo: endOfDay)
          .get();

      int totalOccupancy = 0;
      for (DocumentSnapshot doc in bookingSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalOccupancy += (data['numberOfSeats'] ?? 0) as int;
      }

      // Update van occupancy
      await _vanService.updateVanOccupancy(vanId, totalOccupancy);
    } catch (e) {
      print('Error updating van occupancy from bookings: $e');
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  // Get booking statistics for a date range
  Future<Map<String, dynamic>> getBookingStatistics(
      DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startDate)
          .where('bookingDate', isLessThanOrEqualTo: endDate)
          .get();

      List<Booking> bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();

      int totalBookings = bookings.length;
      int activeBookings =
          bookings.where((b) => b.bookingStatus == 'active').length;
      int cancelledBookings =
          bookings.where((b) => b.bookingStatus == 'cancelled').length;
      int completedBookings =
          bookings.where((b) => b.bookingStatus == 'completed').length;

      // Get user account statistics
      Map<String, dynamic> userStats = await getUserAccountStatistics(startDate, endDate);

      int totalPassengers =
          bookings.fold(0, (sum, booking) => sum + booking.numberOfSeats);

      return {
        'totalBookings': totalBookings,
        'activeBookings': activeBookings,
        'cancelledBookings': cancelledBookings,
        'completedBookings': completedBookings,
        'totalPassengers': totalPassengers,
        'totalUsers': userStats['totalUsers'] ?? 0,
        'activeUsers': userStats['activeUsers'] ?? 0,
        'newUsersToday': userStats['newUsersToday'] ?? 0,
      };
    } catch (e) {
      print('Error getting booking statistics: $e');
      return {};
    }
  }

  // Get user account statistics
  Future<Map<String, dynamic>> getUserAccountStatistics(DateTime startDate, DateTime endDate) async {
    try {
      // Get unique users from bookings in the date range
      QuerySnapshot bookingSnapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startDate)
          .where('bookingDate', isLessThanOrEqualTo: endDate)
          .get();

      Set<String> uniqueUserIds = {};
      Set<String> todayUserIds = {};
      DateTime today = DateTime.now();
      DateTime startOfToday = DateTime(today.year, today.month, today.day);

      for (DocumentSnapshot doc in bookingSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'] ?? '';
        DateTime bookingDate = (data['bookingDate'] as Timestamp).toDate();
        
        if (userId.isNotEmpty) {
          uniqueUserIds.add(userId);
          
          // Check if booking was made today
          if (bookingDate.isAfter(startOfToday)) {
            todayUserIds.add(userId);
          }
        }
      }

      // Get all unique users who have made bookings (total users)
      QuerySnapshot allBookingsSnapshot = await _firestore
          .collection(_collection)
          .get();

      Set<String> allUniqueUserIds = {};
      for (DocumentSnapshot doc in allBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'] ?? '';
        if (userId.isNotEmpty) {
          allUniqueUserIds.add(userId);
        }
      }

      // Active users are those who made bookings in the last 30 days
      DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      QuerySnapshot recentBookingsSnapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();

      Set<String> activeUserIds = {};
      for (DocumentSnapshot doc in recentBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'] ?? '';
        if (userId.isNotEmpty) {
          activeUserIds.add(userId);
        }
      }

      return {
        'totalUsers': allUniqueUserIds.length,
        'activeUsers': activeUserIds.length,
        'newUsersToday': todayUserIds.length,
      };
    } catch (e) {
      print('Error getting user account statistics: $e');
      return {
        'totalUsers': 0,
        'activeUsers': 0,
        'newUsersToday': 0,
      };
    }
  }

  // Get revenue by payment method
  Future<Map<String, double>> getRevenueByPaymentMethod(
      DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('bookingDate', isGreaterThanOrEqualTo: startDate)
          .where('bookingDate', isLessThanOrEqualTo: endDate)
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      List<Booking> bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      Map<String, double> revenueByMethod = {};

      for (Booking booking in bookings) {
        revenueByMethod[booking.paymentMethod] =
            (revenueByMethod[booking.paymentMethod] ?? 0.0) +
                booking.totalAmount;
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

      List<Booking> bookings =
          snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
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
