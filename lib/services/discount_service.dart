import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discount_model.dart';

class DiscountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'discounts';

  // Get all discounts stream
  Stream<List<Discount>> getDiscountsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  // Get active discounts stream
  Stream<List<Discount>> getActiveDiscountsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('validTo', isGreaterThan: DateTime.now())
        .orderBy('validTo')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  // Get discount by ID
  Future<Discount?> getDiscountById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Discount.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting discount: $e');
      return null;
    }
  }

  // Add new discount
  Future<void> addDiscount(Discount discount) async {
    try {
      await _firestore.collection(_collection).add(discount.toFirestore());
    } catch (e) {
      print('Error adding discount: $e');
      rethrow;
    }
  }

  // Update discount
  Future<void> updateDiscount(String id, Discount discount) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(discount.toFirestore());
    } catch (e) {
      print('Error updating discount: $e');
      rethrow;
    }
  }

  // Delete discount
  Future<void> deleteDiscount(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('Error deleting discount: $e');
      rethrow;
    }
  }

  // Toggle discount active status
  Future<void> toggleDiscountStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      print('Error toggling discount status: $e');
      rethrow;
    }
  }

  // Increment discount usage
  Future<void> incrementDiscountUsage(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'currentUsage': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing discount usage: $e');
      rethrow;
    }
  }

  // Get discounts by eligibility type
  Stream<List<Discount>> getDiscountsByEligibility(String eligibilityType) {
    return _firestore
        .collection(_collection)
        .where('eligibility', arrayContains: eligibilityType)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  // Get discounts applicable to a route
  Stream<List<Discount>> getDiscountsForRoute(String routeId) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Discount.fromFirestore(doc))
            .where((discount) =>
                discount.applicableRoutes.contains('all') ||
                discount.applicableRoutes.contains(routeId))
            .toList());
  }

  // Get expiring discounts (within next 7 days)
  Stream<List<Discount>> getExpiringDiscounts() {
    DateTime nextWeek = DateTime.now().add(const Duration(days: 7));

    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('validTo', isLessThanOrEqualTo: nextWeek)
        .where('validTo', isGreaterThan: DateTime.now())
        .orderBy('validTo')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  // Get discount usage statistics
  Future<Map<String, dynamic>> getDiscountStatistics(
      DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      List<Discount> discounts =
          snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList();

      int totalDiscounts = discounts.length;
      int activeDiscounts = discounts.where((d) => d.isActive).length;
      int expiredDiscounts =
          discounts.where((d) => d.validTo.isBefore(DateTime.now())).length;

      double totalDiscountValue = discounts.fold(
          0.0,
          (sum, discount) =>
              sum +
              (discount.currentUsage *
                  (discount.type == 'percentage' ? 0 : discount.value)));

      int totalUsage =
          discounts.fold(0, (sum, discount) => sum + discount.currentUsage);

      return {
        'totalDiscounts': totalDiscounts,
        'activeDiscounts': activeDiscounts,
        'expiredDiscounts': expiredDiscounts,
        'totalDiscountValue': totalDiscountValue,
        'totalUsage': totalUsage,
      };
    } catch (e) {
      print('Error getting discount statistics: $e');
      return {};
    }
  }

  // Search discounts by name
  Stream<List<Discount>> searchDiscounts(String query) {
    return _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  // Get near-limit discounts (usage close to maxUsage)
  Stream<List<Discount>> getNearLimitDiscounts() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Discount.fromFirestore(doc))
            .where((discount) =>
                discount.maxUsage > 0 &&
                discount.currentUsage >= (discount.maxUsage * 0.9))
            .toList());
  }

  // Validate discount for booking
  Future<bool> validateDiscountForBooking({
    required String discountId,
    required String routeId,
    required List<String> eligibilityTypes,
  }) async {
    try {
      Discount? discount = await getDiscountById(discountId);

      if (discount == null || !discount.isActive) {
        return false;
      }

      // Check if discount is still valid
      if (discount.validTo.isBefore(DateTime.now())) {
        return false;
      }

      // Check usage limit
      if (discount.maxUsage > 0 && discount.currentUsage >= discount.maxUsage) {
        return false;
      }

      // Check route applicability
      if (!discount.applicableRoutes.contains('all') &&
          !discount.applicableRoutes.contains(routeId)) {
        return false;
      }

      // Check eligibility
      bool hasEligibility = discount.eligibility
          .any((elig) => eligibilityTypes.contains(elig) || elig == 'all');

      return hasEligibility;
    } catch (e) {
      print('Error validating discount: $e');
      return false;
    }
  }
}
