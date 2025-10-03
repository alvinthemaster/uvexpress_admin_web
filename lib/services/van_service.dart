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

      // Step 4: Update van status based on new occupancy (will likely become "in_queue")
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

      // Query bookings that might be associated with this van
      // Since bookings don't directly reference vanId, we find them by route and active status
      QuerySnapshot bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('routeId', isEqualTo: van.currentRouteId)
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      WriteBatch batch = _firestore.batch();
      int cancelledCount = 0;

      for (QueryDocumentSnapshot bookingDoc in bookingsSnapshot.docs) {
        // Additional filtering can be done here based on schedule/time if needed
        // For now, we'll cancel all confirmed/pending bookings on the same route
        
        batch.update(bookingDoc.reference, {
          'status': 'cancelled_by_admin',
          'cancellationReason': 'Van occupancy reset by administrator - seats released',
          'cancelledAt': FieldValue.serverTimestamp(),
          'adminCancellation': true,
        });
        
        cancelledCount++;
      }

      if (cancelledCount > 0) {
        await batch.commit();
        print('📋 Cancelled $cancelledCount bookings for van ${van.plateNumber} - all seats are now available');
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

  // New method: Progress queue when a van becomes full
  Future<void> _progressQueueAfterVanFull(Van fullVan) async {
    try {
      print('🚀 Processing queue progression after van ${fullVan.plateNumber} became full');
      print('📍 Full van details: Route=${fullVan.currentRouteId}, Position=${fullVan.queuePosition}');
      
      // Find the next van in queue for the same route (if assigned to a route)
      if (fullVan.currentRouteId != null && fullVan.currentRouteId!.isNotEmpty) {
        print('🛣️ Van has route assigned: ${fullVan.currentRouteId}');
        await _progressRouteQueue(fullVan.currentRouteId!, fullVan.queuePosition);
      } else {
        print('🆓 Van has no route - progressing general queue');
        // For unassigned vans, progress the general queue
        await _progressGeneralQueue(fullVan.queuePosition);
      }
    } catch (e) {
      print('❌ Error progressing queue after van became full: $e');
      rethrow;
    }
  }

  // Progress queue for vans on a specific route
  Future<void> _progressRouteQueue(String routeId, int fullVanPosition) async {
    try {
      print('🔍 Searching for next van on route $routeId after position $fullVanPosition');
      
      // Get all vans on the same route (simplified query to avoid index requirement)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('currentRouteId', isEqualTo: routeId)
          .get();

      print('📊 Found ${snapshot.docs.length} vans on route $routeId');

      // Filter and find the next van in queue locally
      List<Van> routeVans = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .where((van) => 
              van.queuePosition > fullVanPosition && 
              van.status == 'in_queue')
          .toList();
      
      // Sort by queue position and get the first one
      routeVans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

      if (routeVans.isNotEmpty) {
        Van nextVan = routeVans.first;
        
        print('✅ Found next van: ${nextVan.plateNumber} at position ${nextVan.queuePosition}');
        
        // Update the next van's status to boarding
        await _firestore.collection(_collection).doc(nextVan.id).update({
          'status': 'boarding',
        });
        
        print('🎯 Queue progressed: Van ${nextVan.plateNumber} automatically updated from "in_queue" to "boarding" on route $routeId');
      } else {
        print('⚠️ No more vans in queue for route $routeId after position $fullVanPosition');
        print('🔄 Implementing queue loop - searching for first van to cycle back to "boarding"');
        
        // LOOPING LOGIC: When no more vans in queue, cycle back to the first van
        await _loopBackToFirstVan(routeId);
      }
    } catch (e) {
      print('❌ Error progressing route queue: $e');
      rethrow;
    }
  }

  // LOOPING LOGIC: Cycle back to the first van when queue is complete
  Future<void> _loopBackToFirstVan(String routeId) async {
    try {
      print('🔄 Starting queue loop for route $routeId');
      
      // Get all vans on the same route
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('currentRouteId', isEqualTo: routeId)
          .get();

      List<Van> allRouteVans = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .toList();
      
      // Sort by queue position to find the first van
      allRouteVans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      
      print('🔍 Found ${allRouteVans.length} vans on route $routeId');
      
      if (allRouteVans.isNotEmpty) {
        Van firstVan = allRouteVans.first;
        
        print('🎯 First van in queue: ${firstVan.plateNumber} at position ${firstVan.queuePosition} with status "${firstVan.status}"');
        
        // Check if the first van is full (indicating we've completed a cycle)
        if (firstVan.status.toLowerCase() == 'full') {
          print('🔄 Queue cycle complete! Resetting first van to "boarding" for continuous loop');
          
          // Reset the first van's occupancy and set status to boarding
          await _firestore.collection(_collection).doc(firstVan.id).update({
            'status': 'boarding',
            'currentOccupancy': 0, // Reset occupancy for new cycle
          });
          
          print('✅ Van ${firstVan.plateNumber} reset to "boarding" status with 0 occupancy - Queue loop completed!');
        } else if (firstVan.status.toLowerCase() == 'in_queue') {
          // If first van is still in queue, set it to boarding
          await _firestore.collection(_collection).doc(firstVan.id).update({
            'status': 'boarding',
          });
          
          print('✅ Van ${firstVan.plateNumber} promoted from "in_queue" to "boarding" - Queue loop initiated!');
        } else {
          print('ℹ️ First van ${firstVan.plateNumber} already has status "${firstVan.status}" - no loop action needed');
        }
      } else {
        print('⚠️ No vans found on route $routeId for queue loop');
      }
    } catch (e) {
      print('❌ Error in queue loop back: $e');
      rethrow;
    }
  }

  // Progress general queue for unassigned vans
  Future<void> _progressGeneralQueue(int fullVanPosition) async {
    try {
      print('🔍 Searching for next unassigned van after position $fullVanPosition');
      
      // Get all vans (simplified query to avoid index requirement)
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .get();

      // Filter and find the next unassigned van in queue locally
      List<Van> unassignedVans = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .where((van) => 
              van.queuePosition > fullVanPosition && 
              van.status == 'in_queue' &&
              (van.currentRouteId == null || van.currentRouteId!.isEmpty))
          .toList();
      
      // Sort by queue position and get the first one
      unassignedVans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

      if (unassignedVans.isNotEmpty) {
        Van nextVan = unassignedVans.first;
        
        print('✅ Found next unassigned van: ${nextVan.plateNumber} at position ${nextVan.queuePosition}');
        
        // Update the next van's status to boarding
        await _firestore.collection(_collection).doc(nextVan.id).update({
          'status': 'boarding',
        });
        
        print('🎯 General queue progressed: Van ${nextVan.plateNumber} automatically updated from "in_queue" to "boarding"');
      } else {
        print('⚠️ No more unassigned vans in queue after position $fullVanPosition');
        print('🔄 Implementing general queue loop - searching for first unassigned van to cycle back');
        
        // LOOPING LOGIC: When no more unassigned vans in queue, cycle back to the first unassigned van
        await _loopBackToFirstUnassignedVan();
      }
    } catch (e) {
      print('Error progressing general queue: $e');
      rethrow;
    }
  }

  // LOOPING LOGIC: Cycle back to the first unassigned van when general queue is complete
  Future<void> _loopBackToFirstUnassignedVan() async {
    try {
      print('🔄 Starting general queue loop for unassigned vans');
      
      // Get all unassigned vans
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .get();

      List<Van> unassignedVans = snapshot.docs
          .map((doc) => Van.fromFirestore(doc))
          .where((van) => van.currentRouteId == null || van.currentRouteId!.isEmpty)
          .toList();
      
      // Sort by queue position to find the first unassigned van
      unassignedVans.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      
      print('🔍 Found ${unassignedVans.length} unassigned vans');
      
      if (unassignedVans.isNotEmpty) {
        Van firstUnassignedVan = unassignedVans.first;
        
        print('🎯 First unassigned van: ${firstUnassignedVan.plateNumber} at position ${firstUnassignedVan.queuePosition} with status "${firstUnassignedVan.status}"');
        
        // Check if the first unassigned van is full (indicating we've completed a cycle)
        if (firstUnassignedVan.status.toLowerCase() == 'full') {
          print('🔄 General queue cycle complete! Resetting first unassigned van to "boarding"');
          
          // Reset the first unassigned van's occupancy and set status to boarding
          await _firestore.collection(_collection).doc(firstUnassignedVan.id).update({
            'status': 'boarding',
            'currentOccupancy': 0, // Reset occupancy for new cycle
          });
          
          print('✅ Van ${firstUnassignedVan.plateNumber} reset to "boarding" status with 0 occupancy - General queue loop completed!');
        } else if (firstUnassignedVan.status.toLowerCase() == 'in_queue') {
          // If first unassigned van is still in queue, set it to boarding
          await _firestore.collection(_collection).doc(firstUnassignedVan.id).update({
            'status': 'boarding',
          });
          
          print('✅ Van ${firstUnassignedVan.plateNumber} promoted from "in_queue" to "boarding" - General queue loop initiated!');
        } else {
          print('ℹ️ First unassigned van ${firstUnassignedVan.plateNumber} already has status "${firstUnassignedVan.status}" - no loop action needed');
        }
      } else {
        print('⚠️ No unassigned vans found for general queue loop');
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
}
