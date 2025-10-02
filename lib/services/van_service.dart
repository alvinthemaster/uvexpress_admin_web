import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/van_model.dart';

class VanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'vans';

  // Get all vans stream
  Stream<List<Van>> getVansStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
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
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
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
        await _firestore.collection(_collection).doc(van.id).set(vanWithPosition.toFirestore());
      } else {
        await _firestore.collection(_collection).add(vanWithPosition.toFirestore());
      }
    } catch (e) {
      print('Error adding van: $e');
      rethrow;
    }
  }

  // Update van
  Future<void> updateVan(String id, Van van) async {
    try {
      await _firestore.collection(_collection).doc(id).update(van.toFirestore());
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
  Future<void> setMaintenanceStatus(String id, DateTime? lastMaintenance, DateTime? nextMaintenance) async {
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
      batch.update(doc.reference, {'queuePosition': van.queuePosition + offset});
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
        .map((snapshot) => snapshot.docs.map((doc) => Van.fromFirestore(doc)).toList());
  }
}