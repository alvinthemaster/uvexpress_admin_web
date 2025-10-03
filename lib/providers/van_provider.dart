import 'package:flutter/foundation.dart';
import '../models/van_model.dart';
import '../services/van_service.dart';

class VanProvider with ChangeNotifier {
  final VanService _vanService = VanService();

  List<Van> _vans = [];
  List<Van> _activeVans = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Van> get vans => _vans;
  List<Van> get activeVans => _activeVans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  VanProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    _vanService.getVansStream().listen((vans) {
      _vans = vans;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = error.toString();
      notifyListeners();
    });

    _vanService.getActiveVansStream().listen((activeVans) {
      _activeVans = activeVans;
      notifyListeners();
    });
  }

  Future<void> addVan(Van van) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.addVan(van);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVan(String id, Van van) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.updateVan(id, van);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteVan(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.deleteVan(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVanStatus(String id, String status) async {
    try {
      await _vanService.updateVanStatus(id, status);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveVanToNext(String id) async {
    try {
      await _vanService.moveVanToNext(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveVanToEnd(String id) async {
    try {
      await _vanService.moveVanToEnd(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> setMaintenanceStatus(
      String id, DateTime? lastMaintenance, DateTime? nextMaintenance) async {
    try {
      await _vanService.setMaintenanceStatus(
          id, lastMaintenance, nextMaintenance);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Van? getVanById(String id) {
    try {
      return _vans.firstWhere((van) => van.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Van> getVansByStatus(String status) {
    return _vans.where((van) => van.status == status).toList();
  }

  List<Van> searchVans(String query) {
    return _vans
        .where((van) =>
            van.plateNumber.toLowerCase().contains(query.toLowerCase()) ||
            van.driver.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> progressQueue(String vanId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.progressQueueManually(vanId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetVanOccupancy(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.resetVanOccupancy(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enhanced reset with booking cancellation
  Future<void> resetVanOccupancyAndCancelBookings(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.resetVanOccupancyAndCancelBookings(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset with options
  Future<void> resetVanOccupancyWithOptions(String id, {bool cancelBookings = false}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.resetVanOccupancyWithOptions(id, cancelBookings: cancelBookings);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Complete van trip - mark all bookings as completed and reset occupancy
  Future<void> completeVanTrip(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.completeVanTrip(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> progressAllQueues() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.progressAllFullVanQueues();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> triggerQueueLoop(String? routeId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.triggerQueueLoop(routeId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Migrate van statuses from legacy values to mobile app expected values
  Future<void> migrateVanStatuses() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _vanService.migrateVanStatuses();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int get totalVans => _vans.length;
  int get activeVansCount => _activeVans.length;
  int get inactiveVansCount => _vans.where((van) => !van.isActive).length;
  int get maintenanceVansCount =>
      _vans.where((van) => van.status == 'maintenance').length;
}
