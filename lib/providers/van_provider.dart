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

  Future<void> setMaintenanceStatus(String id, DateTime? lastMaintenance, DateTime? nextMaintenance) async {
    try {
      await _vanService.setMaintenanceStatus(id, lastMaintenance, nextMaintenance);
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
    return _vans.where((van) => 
        van.plateNumber.toLowerCase().contains(query.toLowerCase()) ||
        van.driver.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  int get totalVans => _vans.length;
  int get activeVansCount => _activeVans.length;
  int get inactiveVansCount => _vans.where((van) => !van.isActive).length;
  int get maintenanceVansCount => _vans.where((van) => van.status == 'maintenance').length;
}