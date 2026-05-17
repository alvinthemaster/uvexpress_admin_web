import 'package:flutter/foundation.dart';
import '../models/van_rental_request_model.dart';
import '../services/van_rental_request_service.dart';

class VanRentalRequestProvider with ChangeNotifier {
  final VanRentalRequestService _service = VanRentalRequestService();

  List<VanRentalRequest> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<VanRentalRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<VanRentalRequest> get pendingRequests =>
      _requests.where((r) => r.status == 'pending').toList();

  VanRentalRequestProvider() {
    _service.getRequestsStream().listen(
      (data) async {
        _requests = data;
        notifyListeners();
        await _service.reconcileListingLocksFromRequests(data);
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> approveRequest(String id) async {
    try {
      await _service.approveRequest(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(String id, {String reason = ''}) async {
    try {
      await _service.rejectRequest(id, reason: reason);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeRequest(
    String id, {
    required Map<String, bool> vehicleChecklist,
    required List<Map<String, dynamic>> damageLineItems,
    required double damageAmount,
    required double depositAmount,
  }) async {
    try {
      await _service.completeRequest(
        id,
        vehicleChecklist: vehicleChecklist,
        damageLineItems: damageLineItems,
        damageAmount: damageAmount,
        depositAmount: depositAmount,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markInUse(String id) async {
    try {
      await _service.approveRequest(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRequest(String id, {String reason = ''}) async {
    try {
      await _service.cancelRequest(id, reason: reason);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsPaid(String id) async {
    try {
      await _service.markAsPaid(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
