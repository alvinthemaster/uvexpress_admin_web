import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time in admin_users collection
      if (result.user != null) {
        await _updateLastLogin(result.user!.uid);
      }

      return result;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('admin_users').doc(uid).get();
      if (doc.exists) {
        AdminUser admin = AdminUser.fromFirestore(doc);
        return admin.isActive;
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get admin user details
  Future<AdminUser?> getAdminUser(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('admin_users').doc(uid).get();
      if (doc.exists) {
        return AdminUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting admin user: $e');
      return null;
    }
  }

  // Update last login time
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('admin_users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Create admin user (only for super admins)
  Future<void> createAdminUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required List<String> permissions,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        AdminUser adminUser = AdminUser(
          id: result.user!.uid,
          email: email,
          name: name,
          role: role,
          permissions: permissions,
          isActive: true,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('admin_users')
            .doc(result.user!.uid)
            .set(adminUser.toFirestore());
      }
    } catch (e) {
      print('Error creating admin user: $e');
      rethrow;
    }
  }

  // Quick setup for initial admin - ONLY USE FOR INITIAL SETUP
  Future<String> createInitialAdmin() async {
    try {
      // First, check if admin already exists
      QuerySnapshot existingAdmins = await _firestore
          .collection('admin_users')
          .where('email', isEqualTo: 'admin@uvexpress.com')
          .get();

      if (existingAdmins.docs.isNotEmpty) {
        // Admin exists, just make sure it's properly formatted
        String adminId = existingAdmins.docs.first.id;
        await _firestore.collection('admin_users').doc(adminId).set({
          'email': 'admin@uvexpress.com',
          'name': 'Admin User',
          'role': 'super_admin',
          'permissions': [
            'all',
            'manage_users',
            'manage_bookings',
            'manage_vans',
            'manage_routes',
            'manage_discounts',
            'view_analytics',
            'export_data',
          ],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': null,
        }, SetOptions(merge: true));

        return 'Admin account updated successfully!\nEmail: admin@uvexpress.com\nPassword: admin123';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: 'admin@uvexpress.com',
        password: 'admin123',
      );

      if (result.user != null) {
        await _firestore.collection('admin_users').doc(result.user!.uid).set({
          'email': 'admin@uvexpress.com',
          'name': 'Admin User',
          'role': 'super_admin',
          'permissions': [
            'all',
            'manage_users',
            'manage_bookings',
            'manage_vans',
            'manage_routes',
            'manage_discounts',
            'view_analytics',
            'export_data',
          ],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': null,
        });

        return 'Admin account created successfully!\nEmail: admin@uvexpress.com\nPassword: admin123';
      } else {
        throw Exception('Failed to create Firebase Auth user');
      }
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        // Try to find existing user and update their admin record
        try {
          User? user = _auth.currentUser;
          if (user?.email == 'admin@uvexpress.com') {
            await _firestore.collection('admin_users').doc(user!.uid).set({
              'email': 'admin@uvexpress.com',
              'name': 'Admin User',
              'role': 'super_admin',
              'permissions': [
                'all',
                'manage_users',
                'manage_bookings',
                'manage_vans',
                'manage_routes',
                'manage_discounts',
                'view_analytics',
                'export_data',
              ],
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLogin': null,
            }, SetOptions(merge: true));
          }
          return 'Admin account exists and updated!\nEmail: admin@uvexpress.com\nPassword: admin123';
        } catch (updateError) {
          return 'Admin account already exists!\nEmail: admin@uvexpress.com\nPassword: admin123\nPlease contact support if you cannot access it.';
        }
      }
      throw Exception('Error creating admin account: $e');
    }
  }
}
