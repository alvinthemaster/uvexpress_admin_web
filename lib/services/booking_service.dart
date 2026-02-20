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
  Future<void> updateBookingStatus(String id, String status, {bool allowVerified = false}) async {
    try {
      // Fetch current booking to validate transitions
      Booking? booking = await getBookingById(id);
      if (booking == null) {
        throw Exception('Booking not found');
      }

      final String current = booking.bookingStatus.toLowerCase();
      final String newStatus = status.toLowerCase();

      // Idempotent: if same status, do nothing
      if (current == newStatus) return;

      // Normalize some variants to 'verified'
      final String normalizedNew = (newStatus == 'on-board' || newStatus == 'on board' || newStatus == 'on_board') ? 'verified' : newStatus;

      if (normalizedNew == 'verified') {
        if (!allowVerified) {
          throw Exception('Only conductor/scanner may mark tickets as Verified');
        }
        if (current == 'pending') {
          throw Exception('Cannot mark ticket as Verified: booking is still Pending (requires admin confirmation)');
        }
        if (current == 'verified') {
          throw Exception('Ticket is already marked Verified');
        }
      }

      // If confirming a discounted ticket, allow transition from pending -> confirmed
      if (normalizedNew == 'confirmed' && booking.discountAmount > 0) {
        if (current != 'pending' && current != 'confirmed') {
          // allow, but don't block other explicit flows
        }
      }

      await _firestore.collection(_collection).doc(id).update({
        'bookingStatus': normalizedNew,
      });
    } catch (e) {
      print('Error updating booking status: $e');
      rethrow;
    }
  }

  // Delete booking
  Future<void> deleteBooking(String id) async {
    try {
      // Get the booking before deleting to update van occupancy
      Booking? booking = await getBookingById(id);
      
      // Delete the booking document
      await _firestore.collection(_collection).doc(id).delete();
      
      // If booking was found and has a route, update van occupancy
      if (booking != null && booking.routeId.isNotEmpty) {
        await _updateVanOccupancyForRoute(booking.routeId);
      }
      
      print('Booking $id deleted successfully');
    } catch (e) {
      print('Error deleting booking: $e');
      rethrow;
    }
  }

  // Create a new booking
  Future<String> createBooking(Booking booking) async {
    try {
      // Prepare booking map and enforce initial status rules:
      // - If booking contains discounts (discountAmount > 0) -> start as 'pending'
      // - Otherwise -> start as 'confirmed'
      Map<String, dynamic> bookingMap = booking.toFirestore();
      final double dAmount = (bookingMap['discountAmount'] ?? 0).toDouble();
      bookingMap['bookingStatus'] = dAmount > 0 ? 'pending' : 'confirmed';

      // Add the booking to Firestore
      DocumentReference docRef = await _firestore.collection(_collection).add(bookingMap);
      
      // Update van occupancy for the route and schedule
      await _updateVanOccupancyForRoute(booking.routeId);
      
      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  // Update booking status and handle van occupancy changes
  Future<void> updateBookingStatusWithVanUpdate(String id, String newStatus, {bool allowVerified = false}) async {
    try {
      // Get the current booking
      Booking? booking = await getBookingById(id);
      if (booking == null) {
        throw Exception('Booking not found');
      }
      
      // Update booking status
      await updateBookingStatus(id, newStatus, allowVerified: allowVerified);
      
      // Update van occupancy for the route
      await _updateVanOccupancyForRoute(booking.routeId);
    } catch (e) {
      print('Error updating booking status with van update: $e');
      rethrow;
    }
  }

  // Scan ticket and mark as Verified
  // This enforces that Pending tickets cannot be scanned and prevents duplicate scans
  Future<void> scanAndMarkVerified(String id) async {
    try {
      Booking? booking = await getBookingById(id);
      if (booking == null) throw Exception('Booking not found');

      final String current = booking.bookingStatus.toLowerCase();
      if (current == 'pending') {
        throw Exception('Cannot scan ticket: booking is still Pending (requires admin confirmation)');
      }
      if (current == 'verified') {
        throw Exception('Ticket has already been scanned (Verified)');
      }

      // Proceed to set status to verified and update occupancy (allowed only via scanner)
      await updateBookingStatusWithVanUpdate(id, 'verified', allowVerified: true);
    } catch (e) {
      print('Error scanning ticket: $e');
      rethrow;
    }
  }

  // Calculate and update van occupancy for all vans on a route
  Future<void> _updateVanOccupancyForRoute(String routeId) async {
    try {
      // Get all vans assigned to this route
      List<Van> vansOnRoute = await _vanService.getVansByRoute(routeId);
      
      // ONLY update occupancy for vans with "boarding" status
      // Vans in "ready" status (in queue) should not be affected
      for (Van van in vansOnRoute) {
        if (van.status.toLowerCase() == 'boarding') {
          await _updateVanOccupancyFromBookings(van.id);
          print('✅ Updated occupancy for boarding van: ${van.plateNumber}');
        } else {
          print('⏭️ Skipped van ${van.plateNumber} (Status: ${van.status} - not boarding)');
        }
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

      // Simplified query to avoid Firestore index requirement
      // Filter by route only, then filter in Dart
      QuerySnapshot bookingSnapshot = await _firestore
          .collection(_collection)
          .where('routeId', isEqualTo: van.currentRouteId)
          .get();

      int totalOccupancy = 0;
      for (DocumentSnapshot doc in bookingSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Filter by status - count confirmed and onboard (and legacy 'active') toward occupancy
        String status = (data['bookingStatus'] ?? '').toString().toLowerCase();
        if (status != 'confirmed' && status != 'active' && status != 'verified') continue;
        
        // Filter by today's date
        Timestamp? departureTimestamp = data['departureTime'] as Timestamp?;
        if (departureTimestamp != null) {
          DateTime departureTime = departureTimestamp.toDate();
          if (departureTime.isBefore(startOfDay) || departureTime.isAfter(endOfDay)) {
            continue;
          }
        }
        
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
        .where('bookingStatus', whereIn: ['active', 'confirmed', 'verified'])
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
