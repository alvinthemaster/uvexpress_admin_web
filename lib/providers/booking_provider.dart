import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/van_model.dart';
import '../services/booking_service.dart';
import '../services/van_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  final VanService _vanService = VanService();

  List<Booking> _bookings = [];
  List<Booking> _todayBookings = [];
  List<Booking> _activeBookings = [];
  List<Van> _vans = []; // Add van list for mobile app compatibility
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};

  List<Booking> get bookings => _bookings;
  List<Booking> get todayBookings => _todayBookings;
  List<Booking> get activeBookings => _activeBookings;
  List<Van> get vans => _vans; // Add van getter for mobile app
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

    // Add van stream for mobile app compatibility
    _vanService.getActiveVansStream().listen((vans) {
      _vans = vans;
      notifyListeners();
    }, onError: (error) {
      print('Error loading vans: $error');
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

      _statistics =
          await _bookingService.getBookingStatistics(startDate, endDate);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, double>> getRevenueByPaymentMethod(
      DateTime startDate, DateTime endDate) async {
    try {
      return await _bookingService.getRevenueByPaymentMethod(
          startDate, endDate);
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
    return _bookings
        .where((booking) => booking.bookingStatus == status)
        .toList();
  }

  List<Booking> getBookingsByPaymentStatus(String paymentStatus) {
    return _bookings
        .where((booking) => booking.paymentStatus == paymentStatus)
        .toList();
  }

  List<Booking> searchBookings(String query) {
    return _bookings
        .where((booking) =>
            booking.userName.toLowerCase().contains(query.toLowerCase()) ||
            booking.userEmail.toLowerCase().contains(query.toLowerCase()) ||
            booking.routeName.toLowerCase().contains(query.toLowerCase()) ||
            (booking.eTicketId?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .toList();
  }

  List<Booking> getBookingsByDateRange(DateTime startDate, DateTime endDate) {
    return _bookings
        .where((booking) =>
            booking.bookingDate
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            booking.bookingDate.isBefore(endDate.add(const Duration(days: 1))))
        .toList();
  }

  // Quick statistics getters
  int get totalBookings => _bookings.length;
  int get todayBookingsCount => _todayBookings.length;
  int get activeBookingsCount => _activeBookings.length;
  int get pendingPaymentsCount =>
      _bookings.where((b) => b.paymentStatus == 'pending').length;

  // User account statistics
  int get totalUserAccounts {
    Set<String> uniqueUserIds = {};
    for (Booking booking in _bookings) {
      if (booking.userId.isNotEmpty) {
        uniqueUserIds.add(booking.userId);
      }
    }
    return uniqueUserIds.length;
  }

  int get todayNewUsers {
    DateTime today = DateTime.now();
    DateTime startOfToday = DateTime(today.year, today.month, today.day);
    
    Set<String> todayUserIds = {};
    for (Booking booking in _todayBookings) {
      if (booking.userId.isNotEmpty && booking.bookingDate.isAfter(startOfToday)) {
        todayUserIds.add(booking.userId);
      }
    }
    return todayUserIds.length;
  }

  double get todayRevenue => _todayBookings
      .where((b) => b.paymentStatus == 'paid')
      .fold(0.0, (sum, booking) => sum + booking.totalAmount);

  double get totalRevenue => _bookings
      .where((b) => b.paymentStatus == 'paid')
      .fold(0.0, (sum, booking) => sum + booking.totalAmount);

  // Van-related methods for mobile app compatibility
  Future<void> loadVans() async {
    try {
      _isLoading = true;
      notifyListeners();

      // The vans are already loaded through the stream in _initializeStreams
      // This method is kept for mobile app compatibility
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initializeSampleVans() async {
    try {
      print('Starting initializeSampleVans...');

      // Generate unique IDs with timestamp to avoid duplicates
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create sample vans with exact mobile app status values
      final sampleVans = [
        Van(
          id: 'TEST1_$timestamp',
          plateNumber: 'TEST1',
          capacity: 18,
          driver: Driver(
            id: 'driver_test1_$timestamp',
            name: 'Juan Dela Cruz',
            license: 'N03-12-123456',
            contact: '09123456789',
          ),
          status: 'boarding', // Mobile app expected status
          queuePosition: 1,
          isActive: true,
          createdAt: DateTime.now(),
          currentOccupancy: 0,
        ),
        Van(
          id: 'TEST2_$timestamp',
          plateNumber: 'TEST2',
          capacity: 18,
          driver: Driver(
            id: 'driver_test2_$timestamp',
            name: 'Maria Santos',
            license: 'N03-12-123457',
            contact: '09123456790',
          ),
          status: 'in_queue', // Mobile app expected status
          queuePosition: 2,
          isActive: true,
          createdAt: DateTime.now(),
          currentOccupancy: 0,
        ),
      ];

      print('Created ${sampleVans.length} sample vans');

      // Add each van to Firestore
      for (final van in sampleVans) {
        print('Adding van ${van.plateNumber} with status: "${van.status}"');
        try {
          await _vanService.addVan(van);
          print('Van ${van.plateNumber} added successfully');
        } catch (vanError) {
          print('Error adding van ${van.plateNumber}: $vanError');
        }
      }

      print('Sample vans initialization completed');
    } catch (e) {
      print('Error initializing sample vans: $e');
      rethrow; // Re-throw so the UI can handle the error
    }
  }

  // Add routes-related methods for mobile app compatibility
  List<dynamic> get routes => []; // Placeholder for routes

  Future<void> loadRoutes() async {
    // Placeholder method for mobile app compatibility
  }

  Future<void> initializeSampleData() async {
    // Placeholder method for mobile app compatibility
  }
}
