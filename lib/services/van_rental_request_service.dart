import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/van_rental_request_model.dart';

/// Manages the `van_rental_requests` Firestore collection.
/// Requests are submitted by the mobile app and managed by admins here.
class VanRentalRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'van_rental_requests';

  // ── Stream ───────────────────────────────────────────────────────────────

  /// All requests ordered by creation date (newest first).
  Stream<List<VanRentalRequest>> getRequestsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(VanRentalRequest.fromFirestore).toList());
  }

  // ── Status transitions ────────────────────────────────────────────────────

  Future<void> approveRequest(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'approved',
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> rejectRequest(String id, {String reason = ''}) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'rejected',
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'cancellationReason': reason,
    });
  }

  Future<void> completeRequest(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> cancelRequest(String id, {String reason = ''}) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'cancelled',
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'cancellationReason': reason,
    });
  }

  Future<void> markAsPaid(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'paymentStatus': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateStatus(String id, Map<String, dynamic> fields) async {
    await _firestore.collection(_collection).doc(id).update(fields);
  }
}
