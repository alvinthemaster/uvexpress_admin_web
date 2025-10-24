import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/van_model.dart';

class VanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'vans';

  // Get all vans stream
  Stream<List<Van>> getVansStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final vans = snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
      vans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      return vans;
    });
  }

  // Get active vans stream
  Stream<List<Van>> getActiveVansStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final vans = snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
      vans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      return vans;
    });
  }

  // Get vans by status
  Stream<List<Van>> getVansByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      final vans = snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
      vans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      return vans;
    });
  }

  // Get van by ID
  Future<Van?> getVanById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Van.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting van: $e');
      return null;
    }
  }

  // Add new van
  Future<void> addVan(Van van) async {
    try {
      // Get the next queue position
      int nextPosition = await _getNextQueuePosition();
      Van vanWithPosition = van.copyWith(queuePosition: nextPosition);

      // Use the van's ID as the document ID, or auto-generate if empty
      if (van.id.isNotEmpty) {
        await _firestore
            .collection(_collection)
            .doc(van.id)
            .set(vanWithPosition.toFirestore());
      } else {
        await _firestore
            .collection(_collection)
            .add(vanWithPosition.toFirestore());
      }
    } catch (e) {
      print('Error adding van: $e');
      rethrow;
    }
  }

  // Update van
  Future<void> updateVan(String id, Van van) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(van.toFirestore());
    } catch (e) {
      print('Error updating van: $e');
      rethrow;
    }
  }

  // Delete van
  Future<void> deleteVan(String id) async {
    try {
      // Get the van to be deleted
      Van? van = await getVanById(id);
      if (van != null) {
        // Delete the van
        await _firestore.collection(_collection).doc(id).delete();

        // Reorder queue positions
        await _reorderQueueAfterDeletion(van.queuePosition);
      }
    } catch (e) {
      print('Error deleting van: $e');
      rethrow;
    }
  }

  // Update van status
  Future<void> updateVanStatus(String id, String status) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'status': status,
      });
    } catch (e) {
      print('Error updating van status: $e');
      rethrow;
    }
  }

  // Assign van to route
  Future<void> assignVanToRoute(
      String vanId, String? routeId, String status) async {
    try {
      Map<String, dynamic> updates = {
        'currentRouteId': routeId,
        'status': status,
      };

      await _firestore.collection(_collection).doc(vanId).update(updates);
      print('Van $vanId assigned to route: $routeId with status: $status');
    } catch (e) {
      print('Error assigning van to route: $e');
      rethrow;
    }
  }

  // Get vans by route
  Future<List<Van>> getVansByRoute(String routeId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('currentRouteId', isEqualTo: routeId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting vans by route: $e');
      return [];
    }
  }

  // Get unassigned vans
  Stream<List<Van>> getUnassignedVansStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final allVans =
          snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
      return allVans
          .where((van) =>
              van.currentRouteId == null || van.currentRouteId!.isEmpty)
          .toList();
    });
  }

  // Move van to next in queue
  Future<void> moveVanToNext(String id) async {
    try {
      Van? van = await getVanById(id);
      if (van != null && van.queuePosition > 1) {
        // Swap positions with the van ahead
        await _swapQueuePositions(van.queuePosition, van.queuePosition - 1);
      }
    } catch (e) {
      print('Error moving van in queue: $e');
      rethrow;
    }
  }

  // Move van to end of queue
  Future<void> moveVanToEnd(String id) async {
    try {
      Van? van = await getVanById(id);
      if (van != null) {
        int lastPosition = await _getLastQueuePosition();
        if (van.queuePosition != lastPosition) {
          // Move all vans between current position and end up by 1
          await _moveVansInRange(van.queuePosition + 1, lastPosition, -1);

          // Move this van to the end
          await _firestore.collection(_collection).doc(id).update({
            'queuePosition': lastPosition,
          });
        }
      }
    } catch (e) {
      print('Error moving van to end: $e');
      rethrow;
    }
  }

  // Move van up by one position in day-specific queue
  Future<void> moveVanUpByDay(String id, String day) async {
    try {
      Van? van = await getVanById(id);
      if (van == null) return;
      
      final currentPosition = van.dayQueuePositions[day] ?? van.queuePosition;
      if (currentPosition <= 1) return; // Already at the top
      
      final targetPosition = currentPosition - 1;
      
      // Find the van at the target position for this day
      final vansSnapshot = await _firestore
          .collection(_collection)
          .where('weeklySchedule', arrayContains: day)
          .get();
      
      Van? targetVan;
      for (var doc in vansSnapshot.docs) {
        final otherVan = Van.fromFirestore(doc);
        final otherPosition = otherVan.dayQueuePositions[day] ?? otherVan.queuePosition;
        if (otherPosition == targetPosition && otherVan.id != van.id) {
          targetVan = otherVan;
          break;
        }
      }
      
      if (targetVan != null) {
        // Swap positions for this day
        final updatedCurrentDayPos = Map<String, int>.from(van.dayQueuePositions);
        updatedCurrentDayPos[day] = targetPosition;
        
        final updatedTargetDayPos = Map<String, int>.from(targetVan.dayQueuePositions);
        updatedTargetDayPos[day] = currentPosition;
        
        // Update both vans
        await _firestore.collection(_collection).doc(van.id).update({
          'dayQueuePositions': updatedCurrentDayPos,
        });
        
        await _firestore.collection(_collection).doc(targetVan.id).update({
          'dayQueuePositions': updatedTargetDayPos,
        });
      }
    } catch (e) {
      print('Error moving van up by day: $e');
      rethrow;
    }
  }

  // Move van down by one position in day-specific queue
  Future<void> moveVanDownByDay(String id, String day) async {
    try {
      Van? van = await getVanById(id);
      if (van == null) return;
      
      final currentPosition = van.dayQueuePositions[day] ?? van.queuePosition;
      final targetPosition = currentPosition + 1;
      
      // Find the van at the target position for this day
      final vansSnapshot = await _firestore
          .collection(_collection)
          .where('weeklySchedule', arrayContains: day)
          .get();
      
      Van? targetVan;
      for (var doc in vansSnapshot.docs) {
        final otherVan = Van.fromFirestore(doc);
        final otherPosition = otherVan.dayQueuePositions[day] ?? otherVan.queuePosition;
        if (otherPosition == targetPosition && otherVan.id != van.id) {
          targetVan = otherVan;
          break;
        }
      }
      
      if (targetVan != null) {
        // Swap positions for this day
        final updatedCurrentDayPos = Map<String, int>.from(van.dayQueuePositions);
        updatedCurrentDayPos[day] = targetPosition;
        
        final updatedTargetDayPos = Map<String, int>.from(targetVan.dayQueuePositions);
        updatedTargetDayPos[day] = currentPosition;
        
        // Update both vans
        await _firestore.collection(_collection).doc(van.id).update({
          'dayQueuePositions': updatedCurrentDayPos,
        });
        
        await _firestore.collection(_collection).doc(targetVan.id).update({
          'dayQueuePositions': updatedTargetDayPos,
        });
      }
    } catch (e) {
      print('Error moving van down by day: $e');
      rethrow;
    }
  }

  // Set maintenance status
  Future<void> setMaintenanceStatus(
      String id, DateTime? lastMaintenance, DateTime? nextMaintenance) async {
    try {
      Map<String, dynamic> updates = {};
      if (lastMaintenance != null) {
        updates['lastMaintenance'] = Timestamp.fromDate(lastMaintenance);
      }
      if (nextMaintenance != null) {
        updates['nextMaintenance'] = Timestamp.fromDate(nextMaintenance);
      }

      await _firestore.collection(_collection).doc(id).update(updates);
    } catch (e) {
      print('Error setting maintenance status: $e');
      rethrow;
    }
  }

  // Update van occupancy
  Future<void> updateVanOccupancy(String vanId, int newOccupancy) async {
    try {
      await _firestore.collection(_collection).doc(vanId).update({
        'currentOccupancy': newOccupancy,
      });
      
      // Check if van should be marked as full and update status automatically
      await _checkAndUpdateVanStatus(vanId);
    } catch (e) {
      print('Error updating van occupancy: $e');
      rethrow;
    }
  }

  // Increment van occupancy (for new bookings)
  Future<void> incrementVanOccupancy(String vanId, int seatCount) async {
    try {
      Van? van = await getVanById(vanId);
      if (van != null) {
        int newOccupancy = van.currentOccupancy + seatCount;
        await updateVanOccupancy(vanId, newOccupancy);
      }
    } catch (e) {
      print('Error incrementing van occupancy: $e');
      rethrow;
    }
  }

  // Decrement van occupancy (for cancelled bookings)
  Future<void> decrementVanOccupancy(String vanId, int seatCount) async {
    try {
      Van? van = await getVanById(vanId);
      if (van != null) {
        int newOccupancy = (van.currentOccupancy - seatCount).clamp(0, van.capacity);
        await updateVanOccupancy(vanId, newOccupancy);
      }
    } catch (e) {
      print('Error decrementing van occupancy: $e');
      rethrow;
    }
  }

  // Reset van occupancy to 0 and automatically set status to 'in_queue'
  Future<void> resetVanOccupancy(String vanId) async {
    try {
      Van? van = await getVanById(vanId);
      if (van != null) {
        print('🔄 Resetting occupancy for van ${van.plateNumber} from ${van.currentOccupancy} to 0');
        await updateVanOccupancy(vanId, 0);
        print('✅ Van ${van.plateNumber} occupancy reset and status automatically updated to "in_queue"');
      }
    } catch (e) {
      print('Error resetting van occupancy: $e');
      rethrow;
    }
  }

  // Public method to sync van occupancy with actual booking counts
  Future<void> syncVanOccupancyWithBookings(String vanId) async {
    try {
      await _syncVanOccupancyWithBookings(vanId);
    } catch (e) {
      print('Error syncing van occupancy: $e');
      rethrow;
    }
  }

  // Enhanced reset method that also handles seat reservations/bookings
  Future<void> resetVanOccupancyAndCancelBookings(String vanId) async {
    try {
      print('🔄 Starting comprehensive reset for van $vanId - cancelling all bookings and resetting occupancy');
      
      // Step 1: Get the van details
      Van? van = await getVanById(vanId);
      if (van == null) {
        throw Exception('Van not found');
      }

      // Step 2: Cancel all active bookings for this van
      await _cancelAllBookingsForVan(vanId);
      
      // Step 3: Reset van occupancy to 0
      await _firestore.collection(_collection).doc(vanId).update({
        'currentOccupancy': 0,
      });

      // Step 4: Verify occupancy is in sync with actual bookings
      await _syncVanOccupancyWithBookings(vanId);

      // Step 5: Update van status based on new occupancy (will likely become "in_queue")
      await _checkAndUpdateVanStatus(vanId);

      print('✅ Comprehensive reset completed for van ${van.plateNumber} - all seats are now available');
    } catch (e) {
      print('❌ Error in comprehensive van reset: $e');
      rethrow;
    }
  }

  // Cancel all active bookings for a specific van
  Future<void> _cancelAllBookingsForVan(String vanId) async {
    try {
      // Get van details to find associated route
      Van? van = await getVanById(vanId);
      if (van == null) return;

      print('📋 Searching for active bookings to cancel for van ${van.plateNumber} on route ${van.currentRouteId}');

      if (van.currentRouteId == null || van.currentRouteId!.isEmpty) {
        print('📋 Van ${van.plateNumber} has no route assigned - no bookings to cancel');
        return;
      }

      // Query bookings that might be associated with this van
      // Fix: Use correct field names - bookingStatus instead of status
      QuerySnapshot bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('bookingStatus', whereIn: ['active', 'pending'])
          .get();

      WriteBatch batch = _firestore.batch();
      int cancelledCount = 0;
      int totalSeatsReleased = 0;

      for (QueryDocumentSnapshot bookingDoc in bookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
        int numberOfSeats = bookingData['numberOfSeats'] ?? 0;
        
        // Update booking status to cancelled
        batch.update(bookingDoc.reference, {
          'bookingStatus': 'cancelled', // Fix: Use correct field name
          'cancellationReason': 'Van occupancy reset by administrator - seats released',
          'cancelledAt': FieldValue.serverTimestamp(),
          'adminCancellation': true,
        });
        
        cancelledCount++;
        totalSeatsReleased += numberOfSeats;
      }

      if (cancelledCount > 0) {
        await batch.commit();
        print('📋 Cancelled $cancelledCount bookings for van ${van.plateNumber} - $totalSeatsReleased seats are now available');
      } else {
        print('📋 No active bookings found to cancel for van ${van.plateNumber}');
      }
    } catch (e) {
      print('❌ Error cancelling bookings for van: $e');
      rethrow;
    }
  }

  // Alternative method: Reset occupancy with booking cancellation option
  Future<void> resetVanOccupancyWithOptions(String vanId, {bool cancelBookings = false}) async {
    try {
      if (cancelBookings) {
        await resetVanOccupancyAndCancelBookings(vanId);
      } else {
        await resetVanOccupancy(vanId);
      }
    } catch (e) {
      print('Error resetting van occupancy with options: $e');
      rethrow;
    }
  }

  // Complete trip: Mark all active bookings as completed and reset occupancy
  Future<void> completeVanTrip(String vanId) async {
    try {
      print('🏁 Starting trip completion for van $vanId - marking all bookings as completed and resetting occupancy');
      
      // Step 1: Get the van details
      Van? van = await getVanById(vanId);
      if (van == null) {
        throw Exception('Van not found');
      }

      print('🚐 Van ${van.plateNumber}: Current occupancy ${van.currentOccupancy}/${van.capacity}, Status: ${van.status}');

      // Step 2: Mark all active bookings for this van as completed
      await _completeAllBookingsForVan(vanId);
      
      // Step 3: Force reset van occupancy to 0 and status to "in_queue"
      // This is done in a single atomic update to avoid race conditions
      await _firestore.collection(_collection).doc(vanId).update({
        'currentOccupancy': 0,
        'status': 'in_queue', // Force status to in_queue immediately
      });

      print('🔄 Van ${van.plateNumber}: Occupancy reset from ${van.currentOccupancy} to 0, Status forced to "in_queue"');

      // Step 4: Verify occupancy is in sync with actual bookings (should confirm 0)
      await _syncVanOccupancyWithBookings(vanId);

      // Step 5: Double-check status is correct (redundant safety check)
      await _checkAndUpdateVanStatus(vanId);

      print('✅ Trip completion finished for van ${van.plateNumber} - all seats available, status="in_queue", queue position unchanged');
    } catch (e) {
      print('❌ Error completing van trip: $e');
      rethrow;
    }
  }

  // Mark all active bookings for a specific van as completed
  Future<void> _completeAllBookingsForVan(String vanId) async {
    try {
      // Get van details to find associated route and plate number
      Van? van = await getVanById(vanId);
      if (van == null) return;

      print('📋 Searching for active bookings to mark as completed for van ${van.plateNumber} on route ${van.currentRouteId}');

      if (van.currentRouteId == null || van.currentRouteId!.isEmpty) {
        print('📋 Van ${van.plateNumber} has no route assigned - no bookings to complete');
        return;
      }

      // Query confirmed/active bookings for this SPECIFIC van
      QuerySnapshot confirmedBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('vanPlateNumber', isEqualTo: van.plateNumber) // CRITICAL: Filter by specific van
          .where('bookingStatus', whereIn: ['confirmed', 'active'])
          .get();

      // Query pending bookings for this SPECIFIC van
      QuerySnapshot pendingBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('vanPlateNumber', isEqualTo: van.plateNumber) // CRITICAL: Filter by specific van
          .where('bookingStatus', isEqualTo: 'pending')
          .get();

      WriteBatch batch = _firestore.batch();
      int completedCount = 0;
      int failedCount = 0;
      int totalSeatsReleased = 0;
      List<String> releasedSeats = [];

      // Process confirmed/active bookings - mark as completed
      for (QueryDocumentSnapshot bookingDoc in confirmedBookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
        int numberOfSeats = bookingData['numberOfSeats'] ?? 0;
        List<String> seatIds = List<String>.from(bookingData['seatIds'] ?? []);
        
        // Mark booking as completed
        batch.update(bookingDoc.reference, {
          'bookingStatus': 'completed',
          'completionReason': 'Trip completed by administrator',
          'completedAt': FieldValue.serverTimestamp(),
          'adminCompletion': true,
        });
        
        completedCount++;
        totalSeatsReleased += numberOfSeats;
        releasedSeats.addAll(seatIds);
      }

      // Process pending bookings - mark as failed
      for (QueryDocumentSnapshot bookingDoc in pendingBookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
        int numberOfSeats = bookingData['numberOfSeats'] ?? 0;
        List<String> seatIds = List<String>.from(bookingData['seatIds'] ?? []);
        
        // Mark booking as failed
        batch.update(bookingDoc.reference, {
          'bookingStatus': 'failed',
          'cancellationReason': 'Trip completed before payment confirmation',
          'cancelledAt': FieldValue.serverTimestamp(),
          'adminCancellation': true,
        });
        
        failedCount++;
        totalSeatsReleased += numberOfSeats;
        releasedSeats.addAll(seatIds);
      }

      if (completedCount > 0 || failedCount > 0) {
        await batch.commit();
        if (completedCount > 0) {
          print('📋 Marked $completedCount bookings as completed for van ${van.plateNumber}');
        }
        if (failedCount > 0) {
          print('❌ Marked $failedCount pending bookings as failed for van ${van.plateNumber}');
        }
        print('💺 Released $totalSeatsReleased seats: ${releasedSeats.join(", ")}');
        print('✅ All reserved seats for van ${van.plateNumber} are now available for new bookings');
      } else {
        print('📋 No active bookings found to complete for van ${van.plateNumber}');
      }
    } catch (e) {
      print('❌ Error completing bookings for van: $e');
      rethrow;
    }
  }

  // Sync van occupancy with actual active bookings count
  Future<void> _syncVanOccupancyWithBookings(String vanId) async {
    try {
      Van? van = await getVanById(vanId);
      if (van == null) return;

      if (van.currentRouteId == null || van.currentRouteId!.isEmpty) {
        print('🔄 Van ${van.plateNumber} has no route - setting occupancy to 0');
        await _firestore.collection(_collection).doc(vanId).update({'currentOccupancy': 0});
        return;
      }

      // Count actual active bookings for THIS SPECIFIC VAN using vanPlateNumber
      // This ensures we only count bookings for this van, not other vans on the same route
      QuerySnapshot activeBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('vanPlateNumber', isEqualTo: van.plateNumber) // CRITICAL: Filter by specific van
          .where('bookingStatus', whereIn: ['confirmed', 'active', 'pending'])
          .get();

      int actualOccupancy = 0;
      for (QueryDocumentSnapshot doc in activeBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        actualOccupancy += (data['numberOfSeats'] ?? 0) as int;
      }

      // Update van occupancy if it doesn't match
      if (actualOccupancy != van.currentOccupancy) {
        print('🔄 Syncing van ${van.plateNumber}: Recorded occupancy ${van.currentOccupancy} -> Actual occupancy $actualOccupancy');
        await _firestore.collection(_collection).doc(vanId).update({
          'currentOccupancy': actualOccupancy,
        });
      } else {
        print('✅ Van ${van.plateNumber} occupancy is in sync: $actualOccupancy seats');
      }
    } catch (e) {
      print('❌ Error syncing van occupancy with bookings: $e');
      rethrow;
    }
  }

  // Check and automatically update van status based on occupancy
  Future<void> _checkAndUpdateVanStatus(String vanId) async {
    try {
      Van? van = await getVanById(vanId);
      if (van == null) return;

      String newStatus = van.status;
      bool shouldProgressQueue = false;
      
      // If occupancy is reset to 0, set status to 'in_queue'
      if (van.currentOccupancy == 0) {
        newStatus = 'in_queue';
        print('🔄 Van ${van.plateNumber} occupancy reset to 0, setting status to "in_queue"');
      }
      // If van is full, update status to 'full'
      else if (van.currentOccupancy >= van.capacity) {
        if (van.status.toLowerCase() != 'full') {
          newStatus = 'full';
          shouldProgressQueue = true; // Trigger queue progression
        }
      } 
      // If van was full but now has available seats, update to appropriate status
      else if (van.status.toLowerCase() == 'full' && van.currentOccupancy < van.capacity) {
        // Return to a bookable status
        if (van.currentRouteId != null && van.currentRouteId!.isNotEmpty) {
          newStatus = 'boarding'; // If assigned to route, set to boarding
        } else {
          newStatus = 'in_queue'; // If not assigned, set to queue
        }
      }

      // Update status if it changed
      if (newStatus != van.status) {
        await _firestore.collection(_collection).doc(vanId).update({
          'status': newStatus,
        });
        
        print('Van ${van.plateNumber} status automatically updated from "${van.status}" to "$newStatus" (occupancy: ${van.currentOccupancy}/${van.capacity})');
        
        // If van became full, progress the queue
        if (shouldProgressQueue) {
          await _progressQueueAfterVanFull(van);
        }
      }
    } catch (e) {
      print('Error checking and updating van status: $e');
      rethrow;
    }
  }

  // New method: Progress queue when a vehicle becomes full
  Future<void> _progressQueueAfterVanFull(Van fullVan) async {
    try {
      print('🚀 Processing queue progression after vehicle ${fullVan.plateNumber} (${fullVan.vehicleType}) became full');
      print('📍 Full vehicle details: Route=${fullVan.currentRouteId}, Position=${fullVan.queuePosition}');
      
      // Find the next vehicle in queue for the same route (if assigned to a route)
      if (fullVan.currentRouteId != null && fullVan.currentRouteId!.isNotEmpty) {
        print('🛣️ Vehicle has route assigned: ${fullVan.currentRouteId}');
        await _progressRouteQueue(fullVan.currentRouteId!, fullVan.queuePosition);
      } else {
        print('🆓 Vehicle has no route - progressing general queue');
        // For unassigned vehicles, progress the general queue
        await _progressGeneralQueue(fullVan.queuePosition);
      }
    } catch (e) {
      print('❌ Error progressing queue after vehicle became full: $e');
      rethrow;
    }
  }

  // Progress queue for vans on a specific route
  Future<void> _progressRouteQueue(String routeId, int fullVanPosition) async {
    try {
      print('🔍 Searching for next vehicle on route $routeId after position $fullVanPosition');
      
      // Get all vehicles on the same route (both vans and buses)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('currentRouteId', isEqualTo: routeId)
          .get();

      print('📊 Found ${snapshot.docs.length} vehicles on route $routeId');

      // Filter and find the next vehicle in queue locally (CRITICAL: Based on position, not vehicle type)
      List<Van> routeVehicles = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .where((vehicle) => 
              vehicle.queuePosition > fullVanPosition && 
              vehicle.status == 'in_queue')
          .toList();
      
      // Sort by queue position and get the first one (CRITICAL: This ensures proper queue order)
      routeVehicles.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

      if (routeVehicles.isNotEmpty) {
        Van nextVehicle = routeVehicles.first;
        
        print('✅ Found next vehicle: ${nextVehicle.plateNumber} (${nextVehicle.vehicleType}) at position ${nextVehicle.queuePosition}');
        
        // Update the next vehicle's status to boarding
        await _firestore.collection(_collection).doc(nextVehicle.id).update({
          'status': 'boarding',
        });
        
        print('🎯 Queue progressed: Vehicle ${nextVehicle.plateNumber} (${nextVehicle.vehicleType}) automatically updated from "in_queue" to "boarding" on route $routeId');
      } else {
        print('⚠️ No more vehicles in queue for route $routeId after position $fullVanPosition');
        print('🔄 Implementing queue loop - searching for first vehicle to cycle back to "boarding"');
        
        // LOOPING LOGIC: When no more vehicles in queue, cycle back to the first vehicle
        await _loopBackToFirstVan(routeId);
      }
    } catch (e) {
      print('❌ Error progressing route queue: $e');
      rethrow;
    }
  }

  // LOOPING LOGIC: Cycle back to the first vehicle when queue is complete
  Future<void> _loopBackToFirstVan(String routeId) async {
    try {
      print('🔄 Starting queue loop for route $routeId');
      
      // Get current day of week for filtering
      final now = DateTime.now();
      final dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      final currentDay = dayNames[now.weekday % 7]; // weekday: 1=Monday, 7=Sunday
      
      print('📅 Current day: $currentDay');
      
      // Get all vehicles on the same route (both vans and buses)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('currentRouteId', isEqualTo: routeId)
          .get();

      // Find the vehicle at position 1 for today's queue
      Van? firstVehicle;
      for (var doc in snapshot.docs) {
        Van vehicle = Van.fromFirestore(doc);
        
        // Check if vehicle is scheduled for today
        bool isScheduledToday = vehicle.weeklySchedule.isEmpty || vehicle.weeklySchedule.contains(currentDay);
        
        // Check if this vehicle is at position 1 for today
        if (isScheduledToday && vehicle.dayQueuePositions[currentDay] == 1) {
          firstVehicle = vehicle;
          break;
        }
      }
      
      if (firstVehicle != null) {
        print('🎯 Found vehicle at position 1 for $currentDay: ${firstVehicle.plateNumber} (${firstVehicle.vehicleType}) with status "${firstVehicle.status}"');
        
        // Check if the first vehicle is full (indicating we've completed a cycle)
        if (firstVehicle.status.toLowerCase() == 'full') {
          print('🔄 Queue cycle complete! Resetting first vehicle to "boarding" for continuous loop');
          
          // Reset the first vehicle's occupancy and set status to boarding
          await _firestore.collection(_collection).doc(firstVehicle.id).update({
            'status': 'boarding',
            'currentOccupancy': 0, // Reset occupancy for new cycle
          });
          
          print('✅ Vehicle ${firstVehicle.plateNumber} (${firstVehicle.vehicleType}) reset to "boarding" status with 0 occupancy - Queue loop completed!');
        } else if (firstVehicle.status.toLowerCase() == 'in_queue') {
          // If first vehicle is still in queue, set it to boarding
          await _firestore.collection(_collection).doc(firstVehicle.id).update({
            'status': 'boarding',
          });
          
          print('✅ Vehicle ${firstVehicle.plateNumber} (${firstVehicle.vehicleType}) promoted from "in_queue" to "boarding" - Queue loop initiated!');
        } else {
          print('ℹ️ First vehicle ${firstVehicle.plateNumber} (${firstVehicle.vehicleType}) already has status "${firstVehicle.status}" - no loop action needed');
        }
      } else {
        print('⚠️ No vehicle found at position 1 on route $routeId for $currentDay');
      }
    } catch (e) {
      print('❌ Error in queue loop back: $e');
      rethrow;
    }
  }

  // Progress general queue for unassigned vehicles
  Future<void> _progressGeneralQueue(int fullVanPosition) async {
    try {
      print('🔍 Searching for next unassigned vehicle after position $fullVanPosition');
      
      // Get current day of week for filtering
      final now = DateTime.now();
      final dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      final currentDay = dayNames[now.weekday % 7];
      
      print('📅 Current day: $currentDay');
      
      // Get all vehicles (both vans and buses)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .get();

      // Filter by day schedule and find the next unassigned vehicle in queue locally
      List<Van> unassignedVehicles = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .where((vehicle) {
            // Must be unassigned
            if (vehicle.currentRouteId != null && vehicle.currentRouteId!.isNotEmpty) return false;
            // Must be in queue
            if (vehicle.status != 'in_queue') return false;
            // Must be scheduled for today (empty schedule = operates all days)
            if (vehicle.weeklySchedule.isNotEmpty && !vehicle.weeklySchedule.contains(currentDay)) return false;
            // Get day-specific position
            final dayPos = vehicle.dayQueuePositions[currentDay];
            if (dayPos == null) return false;
            return dayPos > fullVanPosition;
          })
          .toList();
      
      // Sort by day-specific queue position
      unassignedVehicles.sort((a, b) {
        final aPos = a.dayQueuePositions[currentDay] ?? 999999;
        final bPos = b.dayQueuePositions[currentDay] ?? 999999;
        return aPos.compareTo(bPos);
      });

      if (unassignedVehicles.isNotEmpty) {
        Van nextVehicle = unassignedVehicles.first;
        final nextPos = nextVehicle.dayQueuePositions[currentDay] ?? 0;
        
        print('✅ Found next unassigned vehicle: ${nextVehicle.plateNumber} (${nextVehicle.vehicleType}) at position $nextPos for $currentDay');
        
        // Update the next vehicle's status to boarding
        await _firestore.collection(_collection).doc(nextVehicle.id).update({
          'status': 'boarding',
        });
        
        print('🎯 General queue progressed: Vehicle ${nextVehicle.plateNumber} (${nextVehicle.vehicleType}) automatically updated from "in_queue" to "boarding"');
      } else {
        print('⚠️ No more unassigned vehicles in queue after position $fullVanPosition for $currentDay');
        print('🔄 Implementing general queue loop - searching for first unassigned vehicle to cycle back');
        
        // LOOPING LOGIC: When no more unassigned vehicles in queue, cycle back to the first unassigned vehicle
        await _loopBackToFirstUnassignedVan();
      }
    } catch (e) {
      print('Error progressing general queue: $e');
      rethrow;
    }
  }

  // LOOPING LOGIC: Cycle back to the first unassigned vehicle when general queue is complete
  Future<void> _loopBackToFirstUnassignedVan() async {
    try {
      print('🔄 Starting general queue loop for unassigned vehicles');
      
      // Get current day of week for filtering
      final now = DateTime.now();
      final dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      final currentDay = dayNames[now.weekday % 7];
      
      print('📅 Current day: $currentDay');
      
      // Get all unassigned vehicles (both vans and buses)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .get();

      // Find the unassigned vehicle at position 1 for today's queue
      Van? firstUnassignedVehicle;
      for (var doc in snapshot.docs) {
        Van vehicle = Van.fromFirestore(doc);
        
        // Must be unassigned
        if (vehicle.currentRouteId != null && vehicle.currentRouteId!.isNotEmpty) continue;
        
        // Check if vehicle is scheduled for today
        bool isScheduledToday = vehicle.weeklySchedule.isEmpty || vehicle.weeklySchedule.contains(currentDay);
        
        // Check if this vehicle is at position 1 for today
        if (isScheduledToday && vehicle.dayQueuePositions[currentDay] == 1) {
          firstUnassignedVehicle = vehicle;
          break;
        }
      }
      
      if (firstUnassignedVehicle != null) {
        print('🎯 Found unassigned vehicle at position 1 for $currentDay: ${firstUnassignedVehicle.plateNumber} (${firstUnassignedVehicle.vehicleType}) with status "${firstUnassignedVehicle.status}"');
        
        // Check if the first unassigned vehicle is full (indicating we've completed a cycle)
        if (firstUnassignedVehicle.status.toLowerCase() == 'full') {
          print('🔄 General queue cycle complete! Resetting first unassigned vehicle to "boarding"');
          
          // Reset the first unassigned vehicle's occupancy and set status to boarding
          await _firestore.collection(_collection).doc(firstUnassignedVehicle.id).update({
            'status': 'boarding',
            'currentOccupancy': 0, // Reset occupancy for new cycle
          });
          
          print('✅ Vehicle ${firstUnassignedVehicle.plateNumber} (${firstUnassignedVehicle.vehicleType}) reset to "boarding" status with 0 occupancy - General queue loop completed!');
        } else if (firstUnassignedVehicle.status.toLowerCase() == 'in_queue') {
          // If first unassigned vehicle is still in queue, set it to boarding
          await _firestore.collection(_collection).doc(firstUnassignedVehicle.id).update({
            'status': 'boarding',
          });
          
          print('✅ Vehicle ${firstUnassignedVehicle.plateNumber} (${firstUnassignedVehicle.vehicleType}) promoted from "in_queue" to "boarding" - General queue loop initiated!');
        } else {
          print('ℹ️ First unassigned vehicle ${firstUnassignedVehicle.plateNumber} (${firstUnassignedVehicle.vehicleType}) already has status "${firstUnassignedVehicle.status}" - no loop action needed');
        }
      } else {
        print('⚠️ No unassigned vehicle found at position 1 for $currentDay');
      }
    } catch (e) {
      print('❌ Error in general queue loop back: $e');
      rethrow;
    }
  }

  // Public method to manually trigger queue progression (for admin use)
  Future<void> progressQueueManually(String vanId) async {
    try {
      Van? van = await getVanById(vanId);
      if (van != null) {
        print('🚀 Manual queue progression triggered for van ${van.plateNumber}');
        await _progressQueueAfterVanFull(van);
      }
    } catch (e) {
      print('❌ Error manually progressing queue: $e');
      rethrow;
    }
  }

  // Manual method to trigger queue loop for testing (for admin use)
  Future<void> triggerQueueLoop(String? routeId) async {
    try {
      if (routeId != null && routeId.isNotEmpty) {
        print('🔄 Manual trigger: Starting queue loop for route $routeId');
        await _loopBackToFirstVan(routeId);
      } else {
        print('🔄 Manual trigger: Starting general queue loop for unassigned vans');
        await _loopBackToFirstUnassignedVan();
      }
    } catch (e) {
      print('❌ Error manually triggering queue loop: $e');
      rethrow;
    }
  }

  // Method to check all full vans and progress their queues (useful for fixing stuck queues)
  Future<void> progressAllFullVanQueues() async {
    try {
      print('🔄 Checking all full vans and progressing their queues...');
      
      // Get all full vans
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'full')
          .get();
      
      print('📊 Found ${snapshot.docs.length} full vans');
      
      for (var doc in snapshot.docs) {
        Van fullVan = Van.fromFirestore(doc);
        print('🚗 Processing full van: ${fullVan.plateNumber}');
        await _progressQueueAfterVanFull(fullVan);
      }
      
      print('✅ Completed queue progression for all full vans');
    } catch (e) {
      print('❌ Error progressing all full van queues: $e');
      rethrow;
    }
  }

  // Get available vans for booking (excludes full vans)
  Stream<List<Van>> getAvailableVansForBooking() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final vans = snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList();
      // Filter out full vans and only return bookable ones
      return vans.where((van) => van.canBook).toList()
        ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
    });
  }

  // Public method to update van status after booking changes
  Future<void> checkAndUpdateVanStatusAfterBooking(String vanId) async {
    await _checkAndUpdateVanStatus(vanId);
  }

  // Update all van statuses based on current occupancy
  Future<void> updateAllVanStatusesBasedOnOccupancy() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      
      for (DocumentSnapshot doc in snapshot.docs) {
        await _checkAndUpdateVanStatus(doc.id);
      }
    } catch (e) {
      print('Error updating all van statuses: $e');
      rethrow;
    }
  }

  // Fix and resequence all queue positions to ensure uniqueness and consistency
  Future<void> fixQueuePositions() async {
    try {
      print('🔧 Starting queue position fix...');
      
      // Get all vehicles sorted by their current queue position
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('queuePosition')
          .get();

      if (snapshot.docs.isEmpty) {
        print('✅ No vehicles found - nothing to fix');
        return;
      }

      List<DocumentSnapshot> vehicles = snapshot.docs;
      print('📊 Found ${vehicles.length} vehicles to resequence');

      // Create a batch update
      WriteBatch batch = _firestore.batch();
      int correctPosition = 1;

      for (DocumentSnapshot doc in vehicles) {
        Van vehicle = Van.fromFirestore(doc);
        
        if (vehicle.queuePosition != correctPosition) {
          print('🔄 Fixing ${vehicle.plateNumber}: Position ${vehicle.queuePosition} → $correctPosition');
          batch.update(doc.reference, {'queuePosition': correctPosition});
        } else {
          print('✓ ${vehicle.plateNumber}: Position $correctPosition (already correct)');
        }
        
        correctPosition++;
      }

      // Commit all changes
      await batch.commit();
      print('✅ Queue positions fixed! All vehicles now have unique sequential positions (1-${vehicles.length})');
      
    } catch (e) {
      print('❌ Error fixing queue positions: $e');
      rethrow;
    }
  }

  // Private helper methods
  Future<int> _getNextQueuePosition() async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .orderBy('queuePosition', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 1;
    }

    Van lastVan = Van.fromFirestore(snapshot.docs.first);
    return lastVan.queuePosition + 1;
  }

  Future<int> _getLastQueuePosition() async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .orderBy('queuePosition', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 1;
    }

    Van lastVan = Van.fromFirestore(snapshot.docs.first);
    return lastVan.queuePosition;
  }

  Future<void> _swapQueuePositions(int pos1, int pos2) async {
    WriteBatch batch = _firestore.batch();

    // Get vans at both positions
    QuerySnapshot snapshot1 = await _firestore
        .collection(_collection)
        .where('queuePosition', isEqualTo: pos1)
        .get();

    QuerySnapshot snapshot2 = await _firestore
        .collection(_collection)
        .where('queuePosition', isEqualTo: pos2)
        .get();

    if (snapshot1.docs.isNotEmpty && snapshot2.docs.isNotEmpty) {
      DocumentReference doc1 = snapshot1.docs.first.reference;
      DocumentReference doc2 = snapshot2.docs.first.reference;

      batch.update(doc1, {'queuePosition': pos2});
      batch.update(doc2, {'queuePosition': pos1});

      await batch.commit();
    }
  }

  Future<void> _moveVansInRange(int startPos, int endPos, int offset) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('queuePosition', isGreaterThanOrEqualTo: startPos)
        .where('queuePosition', isLessThanOrEqualTo: endPos)
        .get();

    WriteBatch batch = _firestore.batch();

    for (DocumentSnapshot doc in snapshot.docs) {
      Van van = Van.fromFirestore(doc);
      batch
          .update(doc.reference, {'queuePosition': van.queuePosition + offset});
    }

    await batch.commit();
  }

  Future<void> _reorderQueueAfterDeletion(int deletedPosition) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('queuePosition', isGreaterThan: deletedPosition)
        .get();

    WriteBatch batch = _firestore.batch();

    for (DocumentSnapshot doc in snapshot.docs) {
      Van van = Van.fromFirestore(doc);
      batch.update(doc.reference, {'queuePosition': van.queuePosition - 1});
    }

    await batch.commit();
  }

  // Search vans by plate number
  Stream<List<Van>> searchVansByPlateNumber(String plateNumber) {
    return _firestore
        .collection(_collection)
        .where('plateNumber', isGreaterThanOrEqualTo: plateNumber.toUpperCase())
        .where('plateNumber', isLessThan: plateNumber.toUpperCase() + 'z')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList());
  }

  // Migrate van statuses from legacy admin values to mobile app expected values
  Future<void> migrateVanStatuses() async {
    try {
      print('Starting van status migration...');

      // Status migration mapping
      final Map<String, String> statusMigrationMap = {
        'active': 'in_queue', // active -> in_queue (Ready)
        'ready': 'in_queue', // ready -> in_queue
        'available': 'in_queue', // available -> in_queue
        'loading': 'boarding', // loading -> boarding
        'offline': 'inactive', // offline -> inactive
        'disabled': 'inactive', // disabled -> inactive
        'busy': 'boarding', // busy -> boarding (assuming busy means boarding)
        'occupied': 'boarding', // occupied -> boarding
        'full': 'boarding', // full -> boarding
      };

      // Get all vans with error handling
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore.collection(_collection).get();
      } catch (firestoreError) {
        print('Error fetching vans from Firestore: $firestoreError');
        throw Exception('Failed to fetch vans from database: $firestoreError');
      }

      if (snapshot.docs.isEmpty) {
        print('No vans found in database.');
        return;
      }

      WriteBatch batch = _firestore.batch();
      int migratedCount = 0;

      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            print('Skipping van ${doc.id}: No data found');
            continue;
          }

          String currentStatus = data['status']?.toString() ?? '';

          if (currentStatus.isEmpty) {
            print('Skipping van ${doc.id}: Empty status');
            continue;
          }

          // Check if status needs migration
          if (statusMigrationMap.containsKey(currentStatus.toLowerCase())) {
            String newStatus = statusMigrationMap[currentStatus.toLowerCase()]!;
            print(
                'Migrating van ${doc.id}: "${currentStatus}" -> "${newStatus}"');

            batch.update(doc.reference, {'status': newStatus});
            migratedCount++;
          } else {
            print(
                'Van ${doc.id} status "${currentStatus}" does not need migration');
          }
        } catch (docError) {
          print('Error processing van ${doc.id}: $docError');
          // Continue with other vans instead of failing completely
        }
      }

      if (migratedCount > 0) {
        try {
          await batch.commit();
          print(
              'Van status migration completed. Migrated $migratedCount vans.');
        } catch (commitError) {
          print('Error committing batch update: $commitError');
          throw Exception('Failed to save changes to database: $commitError');
        }
      } else {
        print('No vans needed status migration.');
      }
    } catch (e) {
      print('Error during van status migration: $e');
      rethrow;
    }
  }

  // Day-specific queue position management
  
  /// Get the next available queue position for a specific day
  Future<int> getNextQueuePositionForDay(String day) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1;
      }

      // Find the highest position for this day
      int maxPosition = 0;
      for (var doc in snapshot.docs) {
        Van van = Van.fromFirestore(doc);
        
        // Only consider vans that are scheduled for this day
        if (van.weeklySchedule.isEmpty || van.weeklySchedule.contains(day)) {
          int dayPosition = van.dayQueuePositions[day] ?? 0;
          if (dayPosition > maxPosition) {
            maxPosition = dayPosition;
          }
        }
      }

      return maxPosition + 1;
    } catch (e) {
      print('Error getting next queue position for day $day: $e');
      return 1;
    }
  }

  /// Update day-specific queue positions when adding/removing days from a van's schedule
  Future<void> updateDayQueuePositions(String vanId, List<String> newSchedule, List<String> oldSchedule) async {
    try {
      Van? van = await getVanById(vanId);
      if (van == null) return;

      Map<String, int> updatedPositions = Map.from(van.dayQueuePositions);

      // Add positions for new days
      for (String day in newSchedule) {
        if (!oldSchedule.contains(day)) {
          // Day was added, assign next available position
          int nextPosition = await getNextQueuePositionForDay(day);
          updatedPositions[day] = nextPosition;
          print('Van ${van.plateNumber}: Assigned position $nextPosition for $day');
        }
      }

      // Remove positions for removed days
      for (String day in oldSchedule) {
        if (!newSchedule.contains(day)) {
          // Day was removed, remove its position
          updatedPositions.remove(day);
          print('Van ${van.plateNumber}: Removed position for $day');
          
          // Reorder remaining vans for this day
          await _reorderDayQueueAfterRemoval(day, van.dayQueuePositions[day] ?? 0);
        }
      }

      // Update the van with new positions
      await updateVan(vanId, van.copyWith(
        weeklySchedule: newSchedule,
        dayQueuePositions: updatedPositions,
      ));
    } catch (e) {
      print('Error updating day queue positions: $e');
      rethrow;
    }
  }

  /// Reorder queue positions for a specific day after a van is removed
  Future<void> _reorderDayQueueAfterRemoval(String day, int removedPosition) async {
    try {
      if (removedPosition <= 0) return;

      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      WriteBatch batch = _firestore.batch();
      int updatedCount = 0;

      for (DocumentSnapshot doc in snapshot.docs) {
        Van van = Van.fromFirestore(doc);
        
        // Only process vans scheduled for this day with higher positions
        if ((van.weeklySchedule.isEmpty || van.weeklySchedule.contains(day)) &&
            (van.dayQueuePositions[day] ?? 0) > removedPosition) {
          
          Map<String, int> updatedPositions = Map.from(van.dayQueuePositions);
          updatedPositions[day] = updatedPositions[day]! - 1;
          
          batch.update(doc.reference, {'dayQueuePositions': updatedPositions});
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('Reordered $updatedCount vans for $day after position $removedPosition was removed');
      }
    } catch (e) {
      print('Error reordering day queue: $e');
    }
  }

  /// Check for and fix position conflicts on a specific day
  Future<void> fixDayQueuePositions(String day) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      
      // Collect all vans for this day with their positions
      List<Van> vansForDay = [];
      for (var doc in snapshot.docs) {
        Van van = Van.fromFirestore(doc);
        if (van.weeklySchedule.isEmpty || van.weeklySchedule.contains(day)) {
          vansForDay.add(van);
        }
      }

      // Sort by their day-specific position (or general position if not set)
      vansForDay.sort((a, b) {
        int aPos = a.dayQueuePositions[day] ?? a.queuePosition;
        int bPos = b.dayQueuePositions[day] ?? b.queuePosition;
        return aPos.compareTo(bPos);
      });

      // Reassign sequential positions
      WriteBatch batch = _firestore.batch();
      for (int i = 0; i < vansForDay.length; i++) {
        Van van = vansForDay[i];
        Map<String, int> updatedPositions = Map.from(van.dayQueuePositions);
        updatedPositions[day] = i + 1;

        DocumentReference docRef = _firestore.collection(_collection).doc(van.id);
        batch.update(docRef, {'dayQueuePositions': updatedPositions});
      }

      await batch.commit();
      print('Fixed queue positions for $day: ${vansForDay.length} vans reordered');
    } catch (e) {
      print('Error fixing day queue positions for $day: $e');
      rethrow;
    }
  }

  /// Initialize day queue positions for existing vans that don't have them
  Future<void> initializeDayQueuePositions() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      WriteBatch batch = _firestore.batch();
      int updatedCount = 0;

      // Group vans by day
      Map<String, List<Van>> vansByDay = {};
      List<String> allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

      for (var doc in snapshot.docs) {
        Van van = Van.fromFirestore(doc);
        
        // If van has empty schedule, it operates all days
        List<String> operatingDays = van.weeklySchedule.isEmpty ? allDays : van.weeklySchedule;
        
        for (String day in operatingDays) {
          vansByDay.putIfAbsent(day, () => []);
          vansByDay[day]!.add(van);
        }
      }

      // Assign positions for each day
      for (String day in vansByDay.keys) {
        List<Van> vans = vansByDay[day]!;
        vans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

        for (int i = 0; i < vans.length; i++) {
          Van van = vans[i];
          
          // Only update if this day doesn't have a position yet
          if (!van.dayQueuePositions.containsKey(day)) {
            Map<String, int> updatedPositions = Map.from(van.dayQueuePositions);
            updatedPositions[day] = i + 1;

            DocumentReference docRef = _firestore.collection(_collection).doc(van.id);
            batch.update(docRef, {'dayQueuePositions': updatedPositions});
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('Initialized day queue positions for $updatedCount van-day combinations');
      }
    } catch (e) {
      print('Error initializing day queue positions: $e');
      rethrow;
    }
  }
}
