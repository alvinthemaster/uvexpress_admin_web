import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rental_van_listing_model.dart';

/// Manages the `rental_vans` Firestore collection.
/// These are van listings configured by the admin so that the mobile app
/// can browse available vans for rental.
class RentalVanListingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'rental_vans';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All listings ordered by creation date (newest first).
  Stream<List<RentalVanListing>> getListingsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RentalVanListing.fromFirestore).toList());
  }

  /// Only listings where isAvailable == true.
  Stream<List<RentalVanListing>> getAvailableListingsStream() {
    return _firestore
        .collection(_collection)
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RentalVanListing.fromFirestore).toList());
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<RentalVanListing?> getListingById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) return RentalVanListing.fromFirestore(doc);
      return null;
    } catch (e) {
      print('RentalVanListingService.getListingById: $e');
      return null;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<String> createListing(RentalVanListing listing) async {
    try {
      final data = listing.toFirestore();
      DocumentReference ref;
      if (listing.id.isNotEmpty) {
        ref = _firestore.collection(_collection).doc(listing.id);
        await ref.set(data);
      } else {
        ref = await _firestore.collection(_collection).add(data);
      }
      return ref.id;
    } catch (e) {
      print('RentalVanListingService.createListing: $e');
      rethrow;
    }
  }

  Future<void> updateListing(String id, RentalVanListing listing) async {
    try {
      final data = listing.toFirestore();
      // Always stamp the updated time
      data['updatedAt'] = DateTime.now();
      await _firestore.collection(_collection).doc(id).update(data);
    } catch (e) {
      print('RentalVanListingService.updateListing: $e');
      rethrow;
    }
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isAvailable': isAvailable,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('RentalVanListingService.toggleAvailability: $e');
      rethrow;
    }
  }

  Future<void> updateRentalStatus(String id, String status) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'rentalStatus': status,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('RentalVanListingService.updateRentalStatus: $e');
      rethrow;
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('RentalVanListingService.deleteListing: $e');
      rethrow;
    }
  }
}
