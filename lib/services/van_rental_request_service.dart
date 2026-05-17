import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/van_rental_request_model.dart';

/// Manages the `van_rental_requests` Firestore collection.
/// Requests are submitted by the mobile app and managed by admins here.
class VanRentalRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'van_rental_requests';
  static const String _listingCollection = 'rental_vans';

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
      'status': 'pending',
      'subStatus': 'in_use',
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
    });
    await _syncListingFromRequestSubStatus(id);
  }

  Future<void> rejectRequest(String id, {String reason = ''}) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'rejected',
      'subStatus': 'none',
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'cancellationReason': reason,
    });
    await _syncListingFromRequestSubStatus(id);
  }

  Future<void> completeRequest(
    String id, {
    required Map<String, bool> vehicleChecklist,
    required List<Map<String, dynamic>> damageLineItems,
    required double damageAmount,
    required double depositAmount,
  }) async {
    final deductedFromDeposit = math.min(damageAmount, depositAmount);
    final refundAmount = math.max(depositAmount - damageAmount, 0);
    final damageExcessAmount = math.max(damageAmount - depositAmount, 0);

    await _firestore.collection(_collection).doc(id).update({
      'status': 'completed',
      'subStatus': 'returned',
      'vehicleChecklist': vehicleChecklist,
      'damageLineItems': damageLineItems,
      'damageAmount': damageAmount,
      'depositDeductedAmount': deductedFromDeposit,
      'refundedAmount': refundAmount,
      'damageExcessAmount': damageExcessAmount,
      'returnedAt': Timestamp.fromDate(DateTime.now()),
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
    await _syncListingFromRequestSubStatus(id);
  }

  Future<void> cancelRequest(String id, {String reason = ''}) async {
    await _firestore.collection(_collection).doc(id).update({
      'status': 'cancelled',
      'subStatus': 'none',
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'cancellationReason': reason,
    });
    await _syncListingFromRequestSubStatus(id);
  }

  Future<void> markAsPaid(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'paymentStatus': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateStatus(String id, Map<String, dynamic> fields) async {
    await _firestore.collection(_collection).doc(id).update(fields);
    if (fields.containsKey('subStatus')) {
      await _syncListingFromRequestSubStatus(id);
    }
  }

  Future<void> _syncListingFromRequestSubStatus(String requestId) async {
    await _reconcileListingLocksFromFirestore();
  }

  /// Reconciles all listing lock states from the latest request list.
  /// Any van with at least one request having subStatus=in_use is locked.
  Future<void> reconcileListingLocksFromRequests(
      List<VanRentalRequest> requests) async {
    await _reconcileListingLocksFromFirestore();
  }

  Future<void> _reconcileListingLocksFromFirestore() async {
    try {
      final requestSnapshot = await _firestore.collection(_collection).get();
      final listingSnapshot = await _firestore.collection(_listingCollection).get();

      final listingById = <String, Map<String, dynamic>>{};
      final listingsByVanId = <String, Set<String>>{};
      final listingsByPlate = <String, Set<String>>{};

      for (final listing in listingSnapshot.docs) {
        final data = listing.data();
        final listingId = listing.id;
        final vanId = (data['vanId'] as String? ?? '').trim();
        final plate = _normalizePlateForMatch(
            (data['plateNumber'] as String? ?? '').trim());

        listingById[listingId] = {
          'vanId': vanId,
          'isAvailable': (data['isAvailable'] ?? true) == true,
          'rentalStatus': data['rentalStatus'] as String? ?? 'available',
        };

        if (vanId.isNotEmpty) {
          listingsByVanId.putIfAbsent(vanId, () => <String>{}).add(listingId);
        }
        if (plate.isNotEmpty) {
          listingsByPlate.putIfAbsent(plate, () => <String>{}).add(listingId);
        }
      }

      final lockedListingIds = <String>{};
      final requestBackfillBatch = _firestore.batch();
      var requestBackfills = 0;

      for (final req in requestSnapshot.docs) {
        final data = req.data();
        if (!_isInUseSubStatus(data['subStatus'] as String?)) continue;

        final matchedListingIds = <String>{};

        final listingId = (data['listingId'] as String? ?? '').trim();
        if (listingId.isNotEmpty && listingById.containsKey(listingId)) {
          matchedListingIds.add(listingId);
        }

        if (matchedListingIds.isEmpty) {
          final vanId = (data['vanId'] as String? ?? '').trim();
          if (vanId.isNotEmpty) {
            matchedListingIds.addAll(listingsByVanId[vanId] ?? const <String>{});
          }
        }

        if (matchedListingIds.isEmpty) {
          final plateRaw =
              ((data['vanPlateNumber'] as String?) ?? (data['plateNumber'] as String?) ?? '')
                  .trim();
          final normalizedPlate = _normalizePlateForMatch(plateRaw);
          if (normalizedPlate.isNotEmpty) {
            matchedListingIds
                .addAll(listingsByPlate[normalizedPlate] ?? const <String>{});
          }
        }

        if (matchedListingIds.isEmpty) continue;
        lockedListingIds.addAll(matchedListingIds);

        final currentVanId = (data['vanId'] as String? ?? '').trim();
        final currentListingId = (data['listingId'] as String? ?? '').trim();
        if (currentListingId.isEmpty || currentVanId.isEmpty) {
          final chosenListingId = matchedListingIds.first;
          final chosenVanId =
              (listingById[chosenListingId]?['vanId'] as String? ?? '').trim();
          final backfill = <String, dynamic>{};
          if (currentListingId.isEmpty) backfill['listingId'] = chosenListingId;
          if (currentVanId.isEmpty && chosenVanId.isNotEmpty) {
            backfill['vanId'] = chosenVanId;
          }
          if (backfill.isNotEmpty) {
            requestBackfillBatch.update(req.reference, backfill);
            requestBackfills++;
          }
        }
      }

      if (requestBackfills > 0) {
        await requestBackfillBatch.commit();
      }

      final listingBatch = _firestore.batch();
      var listingUpdates = 0;

      for (final listing in listingSnapshot.docs) {
        final listingId = listing.id;
        final info = listingById[listingId];
        if (info == null) continue;

        final shouldLock = lockedListingIds.contains(listingId);
        final targetIsAvailable = !shouldLock;
        final targetRentalStatus = shouldLock ? 'rented' : 'available';

        final currentIsAvailable = (info['isAvailable'] ?? true) == true;
        final currentRentalStatus = info['rentalStatus'] as String? ?? 'available';

        if (currentIsAvailable == targetIsAvailable &&
            currentRentalStatus == targetRentalStatus) {
          continue;
        }

        listingBatch.update(listing.reference, {
          'isAvailable': targetIsAvailable,
          'rentalStatus': targetRentalStatus,
          'updatedAt': DateTime.now(),
        });
        listingUpdates++;
      }

      if (listingUpdates > 0) {
        await listingBatch.commit();
      }
    } catch (e) {
      print('VanRentalRequestService.reconcileListingLocksFromRequests: $e');
    }
  }

  bool _isInUseSubStatus(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == 'in_use' || v == 'in use' || v == 'inuse';
  }

  String _normalizePlateForMatch(String plate) {
    return plate.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  Future<void> _setLinkedListingAvailabilityByRequest(
    String requestId, {
    required bool isAvailable,
    required String rentalStatus,
  }) async {
    try {
      final reqRef = _firestore.collection(_collection).doc(requestId);
      final reqDoc = await reqRef.get();
      final data = reqDoc.data();
      if (data == null) return;

      final vanId = await _resolveVanIdForRequest(requestId, data);

      if (vanId == null || vanId.isEmpty) {
        print(
            'VanRentalRequestService._setLinkedListingAvailabilityByRequest: missing vanId for request $requestId');
        return;
      }

      await _setListingAvailabilityByVanId(
        vanId,
        isAvailable: isAvailable,
        rentalStatus: rentalStatus,
      );

      if ((data['vanId'] as String?) != vanId) {
        await reqRef.update({'vanId': vanId});
      }
    } catch (e) {
      // Best-effort sync only; request status transitions should still proceed.
      print('VanRentalRequestService._setLinkedListingAvailabilityByRequest: $e');
    }
  }

  Future<String?> _resolveVanIdForRequest(
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final rawVanId = (requestData['vanId'] as String?)?.trim();
    if (rawVanId != null && rawVanId.isNotEmpty) {
      return rawVanId;
    }

    final listingId = (requestData['listingId'] as String?)?.trim();
    if (listingId != null && listingId.isNotEmpty) {
      final listingDoc =
          await _firestore.collection(_listingCollection).doc(listingId).get();
      final listingData = listingDoc.data();
      final listingVanId = (listingData?['vanId'] as String?)?.trim();
      if (listingVanId != null && listingVanId.isNotEmpty) {
        await _firestore.collection(_collection).doc(requestId).update({
          'vanId': listingVanId,
        });
        return listingVanId;
      }
    }

    final plate =
        ((requestData['vanPlateNumber'] as String?) ?? (requestData['plateNumber'] as String?) ?? '')
            .trim();
    if (plate.isNotEmpty) {
      final listingByPlate = await _firestore
          .collection(_listingCollection)
          .where('plateNumber', isEqualTo: plate)
          .limit(1)
          .get();

      if (listingByPlate.docs.isNotEmpty) {
        final listingDoc = listingByPlate.docs.first;
        final listingVanId = (listingDoc.data()['vanId'] as String?)?.trim();
        if (listingVanId != null && listingVanId.isNotEmpty) {
          await _firestore.collection(_collection).doc(requestId).update({
            'vanId': listingVanId,
            'listingId': listingDoc.id,
          });
          return listingVanId;
        }
      }
    }

    return null;
  }

  Future<void> _setListingAvailabilityByVanId(
    String vanId, {
    required bool isAvailable,
    required String rentalStatus,
  }) async {
    final byVan = await _firestore
        .collection(_listingCollection)
        .where('vanId', isEqualTo: vanId)
        .get();

    for (final doc in byVan.docs) {
      await doc.reference.update({
        'isAvailable': isAvailable,
        'rentalStatus': rentalStatus,
        'updatedAt': DateTime.now(),
      });
    }

    if (byVan.docs.isEmpty) {
      print(
          'VanRentalRequestService._setListingAvailabilityByVanId: no listing found for vanId=$vanId');
    }
  }
}
