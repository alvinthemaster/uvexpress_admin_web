import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  
  List<Booking> _bookings = [];
  List<Booking> _todayBookings = [];
  List<Booking> _activeBookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};
  
  List<Booking> get bookings => _bookings;
  List<Booking> get todayBookings => _todayBookings;
  List<Booking> get activeBookings => _activeBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get statistics => _statistics;

  BookingProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    _bookingService.getBookingsStream().listen((bookings) {
      _bookings = bookings;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = error.toString();
      notifyListeners();
    });

    _bookingService.getTodayBookings().listen((todayBookings) {
      _todayBookings = todayBookings;
      notifyListeners();
    });

    _bookingService.getActiveBookings().listen((activeBookings) {
      _activeBookings = activeBookings;
      notifyListeners();
    });
  }

  Future<void> updateBookingStatus(String id, String status) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookingService.updateBookingStatus(id, status);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePaymentStatus(String id, String paymentStatus) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookingService.updatePaymentStatus(id, paymentStatus);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelBooking(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookingService.cancelBooking(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStatistics(DateTime startDate, DateTime endDate) async {
    try {
      _isLoading = true;
      notifyListeners();

      _statistics = await _bookingService.getBookingStatistics(startDate, endDate);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, double>> getRevenueByPaymentMethod(DateTime startDate, DateTime endDate) async {
    try {
      return await _bookingService.getRevenueByPaymentMethod(startDate, endDate);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {};
    }
  }

  Future<Map<int, int>> getHourlyDistribution(DateTime date) async {
    try {
      return await _bookingService.getHourlyBookingDistribution(date);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {};
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Booking? getBookingById(String id) {
    try {
      return _bookings.firstWhere((booking) => booking.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Booking> getBookingsByStatus(String status) {
    return _bookings.where((booking) => booking.bookingStatus == status).toList();
  }

  List<Booking> getBookingsByPaymentStatus(String paymentStatus) {
    return _bookings.where((booking) => booking.paymentStatus == paymentStatus).toList();
  }

  List<Booking> searchBookings(String query) {
    return _bookings.where((booking) => 
        booking.userName.toLowerCase().contains(query.toLowerCase()) ||
        booking.userEmail.toLowerCase().contains(query.toLowerCase()) ||
        booking.routeName.toLowerCase().contains(query.toLowerCase()) ||
        (booking.eTicketId?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  List<Booking> getBookingsByDateRange(DateTime startDate, DateTime endDate) {
    return _bookings.where((booking) => 
        booking.bookingDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
        booking.bookingDate.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
  }

  // Quick statistics getters
  int get totalBookings => _bookings.length;
  int get todayBookingsCount => _todayBookings.length;
  int get activeBookingsCount => _activeBookings.length;
  int get pendingPaymentsCount => _bookings.where((b) => b.paymentStatus == 'pending').length;
  
  double get todayRevenue => _todayBookings
      .where((b) => b.paymentStatus == 'paid')
      .fold(0.0, (sum, booking) => sum + booking.totalAmount);
      
  double get totalRevenue => _bookings
      .where((b) => b.paymentStatus == 'paid')
      .fold(0.0, (sum, booking) => sum + booking.totalAmount);
}