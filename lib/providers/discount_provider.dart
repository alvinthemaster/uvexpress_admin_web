import 'package:flutter/foundation.dart';
import '../models/discount_model.dart';
import '../services/discount_service.dart';

class DiscountProvider with ChangeNotifier {
  final DiscountService _discountService = DiscountService();
  
  List<Discount> _discounts = [];
  List<Discount> _activeDiscounts = [];
  List<Discount> _expiringDiscounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};
  
  List<Discount> get discounts => _discounts;
  List<Discount> get activeDiscounts => _activeDiscounts;
  List<Discount> get expiringDiscounts => _expiringDiscounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get statistics => _statistics;

  DiscountProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    _discountService.getDiscountsStream().listen((discounts) {
      _discounts = discounts;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = error.toString();
      notifyListeners();
    });

    _discountService.getActiveDiscountsStream().listen((activeDiscounts) {
      _activeDiscounts = activeDiscounts;
      notifyListeners();
    });

    _discountService.getExpiringDiscounts().listen((expiringDiscounts) {
      _expiringDiscounts = expiringDiscounts;
      notifyListeners();
    });
  }

  Future<void> addDiscount(Discount discount) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _discountService.addDiscount(discount);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDiscount(String id, Discount discount) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _discountService.updateDiscount(id, discount);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDiscount(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _discountService.deleteDiscount(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleDiscountStatus(String id, bool isActive) async {
    try {
      await _discountService.toggleDiscountStatus(id, isActive);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadStatistics(DateTime startDate, DateTime endDate) async {
    try {
      _isLoading = true;
      notifyListeners();

      _statistics = await _discountService.getDiscountStatistics(startDate, endDate);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> validateDiscount({
    required String discountId,
    required String routeId,
    required List<String> eligibilityTypes,
  }) async {
    try {
      return await _discountService.validateDiscountForBooking(
        discountId: discountId,
        routeId: routeId,
        eligibilityTypes: eligibilityTypes,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Discount? getDiscountById(String id) {
    try {
      return _discounts.firstWhere((discount) => discount.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Discount> getDiscountsByType(String type) {
    return _discounts.where((discount) => discount.type == type).toList();
  }

  List<Discount> getDiscountsByEligibility(String eligibility) {
    return _discounts.where((discount) => 
        discount.eligibility.contains(eligibility) || 
        discount.eligibility.contains('all')
    ).toList();
  }

  List<Discount> searchDiscounts(String query) {
    return _discounts.where((discount) => 
        discount.name.toLowerCase().contains(query.toLowerCase()) ||
        discount.description.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<Discount> getNearLimitDiscounts() {
    return _discounts.where((discount) => 
        discount.isActive && 
        discount.maxUsage > 0 && 
        discount.currentUsage >= (discount.maxUsage * 0.9)
    ).toList();
  }

  List<Discount> getExpiredDiscounts() {
    return _discounts.where((discount) => 
        discount.validTo.isBefore(DateTime.now())
    ).toList();
  }

  // Quick statistics getters
  int get totalDiscounts => _discounts.length;
  int get activeDiscountsCount => _activeDiscounts.length;
  int get expiringDiscountsCount => _expiringDiscounts.length;
  int get nearLimitDiscountsCount => getNearLimitDiscounts().length;
  int get expiredDiscountsCount => getExpiredDiscounts().length;
  
  double get totalDiscountValue => _discounts
      .fold(0.0, (sum, discount) => sum + (discount.currentUsage * 
          (discount.type == 'percentage' ? 0 : discount.value)));
          
  int get totalUsage => _discounts.fold(0, (sum, discount) => sum + discount.currentUsage);
}