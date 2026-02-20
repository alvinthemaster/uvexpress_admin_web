import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/van_rental_model.dart';

/// Handles all Firestore operations for the `van_rentals` collection.
///
/// Firestore document structure (all fields written to Firebase so the
/// mobile app can consume them without extra joins):
///   van_rentals/{id}  →  VanRental.toFirestore()
class VanRentalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'van_rentals';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All rentals ordered by booking date (newest first).
  Stream<List<VanRental>> getRentalsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList());
  }

  /// Rentals filtered by [status].
  Stream<List<VanRental>> getRentalsByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('rentalStatus', isEqualTo: status)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList());
  }

  /// Rentals that overlap a given date range (start or end within range).
  Stream<List<VanRental>> getRentalsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_collection)
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList());
  }

  /// Rentals for a specific van.
  Stream<List<VanRental>> getRentalsByVan(String vanId) {
    return _firestore
        .collection(_collection)
        .where('vanId', isEqualTo: vanId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList());
  }

  /// Rentals for a specific user.
  Stream<List<VanRental>> getRentalsByUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList());
  }

  // ── Single-fetch helpers ──────────────────────────────────────────────────

  Future<VanRental?> getRentalById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) return VanRental.fromFirestore(doc);
      return null;
    } catch (e) {
      print('VanRentalService.getRentalById error: $e');
      return null;
    }
  }

  // ── Write operations ──────────────────────────────────────────────────────

  /// Creates a new rental document.  Returns the generated document ID.
  Future<String> createRental(VanRental rental) async {
    try {
      DocumentReference ref;
      if (rental.id.isNotEmpty) {
        ref = _firestore.collection(_collection).doc(rental.id);
        await ref.set(rental.toFirestore());
      } else {
        ref = await _firestore.collection(_collection).add(rental.toFirestore());
      }
      return ref.id;
    } catch (e) {
      print('VanRentalService.createRental error: $e');
      rethrow;
    }
  }

  /// Full update of an existing rental document.
  Future<void> updateRental(String id, VanRental rental) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(rental.toFirestore());
    } catch (e) {
      print('VanRentalService.updateRental error: $e');
      rethrow;
    }
  }

  /// Partial field update — use for status transitions.
  Future<void> updateRentalFields(
      String id, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection(_collection).doc(id).update(fields);
    } catch (e) {
      print('VanRentalService.updateRentalFields error: $e');
      rethrow;
    }
  }

  /// Permanently removes a rental document.
  Future<void> deleteRental(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('VanRentalService.deleteRental error: $e');
      rethrow;
    }
  }

  // ── Status transition helpers ─────────────────────────────────────────────

  Future<void> confirmRental(String id) async {
    await updateRentalFields(id, {
      'rentalStatus': 'confirmed',
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> activateRental(String id) async {
    await updateRentalFields(id, {
      'rentalStatus': 'active',
      'activatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> completeRental(String id,
      {bool adminCompletion = false}) async {
    await updateRentalFields(id, {
      'rentalStatus': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'adminCompletion': adminCompletion,
    });
  }

  Future<void> cancelRental(String id,
      {String reason = '', String cancelledBy = 'admin'}) async {
    await updateRentalFields(id, {
      'rentalStatus': 'cancelled',
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'cancellationReason': reason,
      'cancelledBy': cancelledBy,
    });
  }

  Future<void> updatePaymentStatus(String id, String paymentStatus,
      {String? paymentReference}) async {
    final fields = <String, dynamic>{'paymentStatus': paymentStatus};
    if (paymentReference != null) fields['paymentReference'] = paymentReference;
    await updateRentalFields(id, fields);
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentalStatistics() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final rentals =
          snapshot.docs.map((d) => VanRental.fromFirestore(d)).toList();

      double totalRevenue = 0;
      int pending = 0, confirmed = 0, active = 0, completed = 0, cancelled = 0;

      for (final r in rentals) {
        switch (r.rentalStatus) {
          case 'pending':
            pending++;
            break;
          case 'confirmed':
            confirmed++;
            break;
          case 'active':
            active++;
            break;
          case 'completed':
            completed++;
            totalRevenue += r.totalAmount;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return {
        'total': rentals.length,
        'pending': pending,
        'confirmed': confirmed,
        'active': active,
        'completed': completed,
        'cancelled': cancelled,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      print('VanRentalService.getRentalStatistics error: $e');
      return {};
    }
  }
}
