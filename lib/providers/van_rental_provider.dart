import 'package:flutter/foundation.dart';
import '../models/van_rental_model.dart';
import '../services/van_rental_service.dart';

class VanRentalProvider with ChangeNotifier {
  final VanRentalService _service = VanRentalService();

  List<VanRental> _rentals = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};

  List<VanRental> get rentals => _rentals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get statistics => _statistics;

  // Filtered convenience getters
  List<VanRental> get pendingRentals =>
      _rentals.where((r) => r.rentalStatus == 'pending').toList();
  List<VanRental> get confirmedRentals =>
      _rentals.where((r) => r.rentalStatus == 'confirmed').toList();
  List<VanRental> get activeRentals =>
      _rentals.where((r) => r.rentalStatus == 'active').toList();
  List<VanRental> get completedRentals =>
      _rentals.where((r) => r.rentalStatus == 'completed').toList();
  List<VanRental> get cancelledRentals =>
      _rentals.where((r) => r.rentalStatus == 'cancelled').toList();

  VanRentalProvider() {
    _initStreams();
  }

  void _initStreams() {
    _service.getRentalsStream().listen(
      (rentals) {
        _rentals = rentals;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String?> createRental(VanRental rental) async {
    _setLoading(true);
    try {
      final id = await _service.createRental(rental);
      return id;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateRental(String id, VanRental rental) async {
    _setLoading(true);
    try {
      await _service.updateRental(id, rental);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteRental(String id) async {
    _setLoading(true);
    try {
      await _service.deleteRental(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Status transitions ────────────────────────────────────────────────────

  Future<bool> confirmRental(String id) async {
    _setLoading(true);
    try {
      await _service.confirmRental(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> activateRental(String id) async {
    _setLoading(true);
    try {
      await _service.activateRental(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completeRental(String id) async {
    _setLoading(true);
    try {
      await _service.completeRental(id, adminCompletion: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelRental(String id,
      {String reason = '', String cancelledBy = 'admin'}) async {
    _setLoading(true);
    try {
      await _service.cancelRental(id,
          reason: reason, cancelledBy: cancelledBy);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePaymentStatus(String id, String paymentStatus,
      {String? paymentReference}) async {
    _setLoading(true);
    try {
      await _service.updatePaymentStatus(id, paymentStatus,
          paymentReference: paymentReference);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadStatistics() async {
    _statistics = await _service.getRentalStatistics();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _errorMessage = null;
    notifyListeners();
  }
}
