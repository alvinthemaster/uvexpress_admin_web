import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';

class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'routes';

  // Get all routes stream
  Stream<List<Route>> getRoutesStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Route.fromFirestore(doc)).toList());
  }

  // Get active routes stream
  Stream<List<Route>> getActiveRoutesStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Route.fromFirestore(doc)).toList());
  }

  // Get route by ID
  Future<Route?> getRouteById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Route.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  // Add new route
  Future<void> addRoute(Route route) async {
    try {
      await _firestore.collection(_collection).add(route.toFirestore());
    } catch (e) {
      print('Error adding route: $e');
      rethrow;
    }
  }

  // Update route
  Future<void> updateRoute(String id, Route route) async {
    try {
      Map<String, dynamic> data = route.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(id).update(data);
    } catch (e) {
      print('Error updating route: $e');
      rethrow;
    }
  }

  // Delete route
  Future<void> deleteRoute(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('Error deleting route: $e');
      rethrow;
    }
  }

  // Toggle route active status
  Future<void> toggleRouteStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling route status: $e');
      rethrow;
    }
  }

  // Search routes
  Stream<List<Route>> searchRoutes(String query) {
    return _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Route.fromFirestore(doc)).toList());
  }

  // Get routes by origin/destination
  Stream<List<Route>> getRoutesByLocation(String location) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Route.fromFirestore(doc))
            .where((route) => 
                route.origin.toLowerCase().contains(location.toLowerCase()) ||
                route.destination.toLowerCase().contains(location.toLowerCase()))
            .toList());
  }
}