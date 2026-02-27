import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/document_delivery_model.dart';

class DocumentDeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'document_deliveries';

  // --- Streams ---

  Stream<List<DocumentDelivery>> getDeliveriesStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => DocumentDelivery.fromFirestore(doc))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<List<DocumentDelivery>> getDeliveriesByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('deliveryStatus', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => DocumentDelivery.fromFirestore(doc))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<List<DocumentDelivery>> getDeliveriesByPaymentStatus(
      String paymentStatus) {
    return _firestore
        .collection(_collection)
        .where('paymentStatus', isEqualTo: paymentStatus)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => DocumentDelivery.fromFirestore(doc))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<List<DocumentDelivery>> getDeliveriesByDateRange(
      DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => DocumentDelivery.fromFirestore(doc))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  // --- Mutation ---

  Future<void> updateDeliveryStatus(String id, String status) async {
    await _firestore.collection(_collection).doc(id).update({
      'deliveryStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePaymentStatus(String id, String status) async {
    await _firestore.collection(_collection).doc(id).update({
      'paymentStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDelivery(
      String id, String cancelledBy, String reason) async {
    await _firestore.collection(_collection).doc(id).update({
      'deliveryStatus': 'cancelled',
      'cancelledBy': cancelledBy,
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsDelivered(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'deliveryStatus': 'delivered',
      'deliveryDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDelivery(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
