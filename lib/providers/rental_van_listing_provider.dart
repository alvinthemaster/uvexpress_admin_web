import 'package:flutter/foundation.dart';
import '../models/rental_van_listing_model.dart';
import '../services/rental_van_listing_service.dart';

class RentalVanListingProvider with ChangeNotifier {
  final RentalVanListingService _service = RentalVanListingService();

  List<RentalVanListing> _listings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RentalVanListing> get listings => _listings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<RentalVanListing> get availableListings =>
      _listings.where((l) => l.isAvailable).toList();

  RentalVanListingProvider() {
    _service.getListingsStream().listen(
      (data) {
        _listings = data;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> createListing(RentalVanListing listing) async {
    _setLoading(true);
    try {
      await _service.createListing(listing);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateListing(String id, RentalVanListing listing) async {
    _setLoading(true);
    try {
      await _service.updateListing(id, listing);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> toggleAvailability(String id, bool isAvailable) async {
    try {
      await _service.toggleAvailability(id, isAvailable);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateRentalStatus(String id, String status) async {
    try {
      await _service.updateRentalStatus(id, status);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteListing(String id) async {
    _setLoading(true);
    try {
      await _service.deleteListing(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    _errorMessage = null;
    notifyListeners();
  }
}
