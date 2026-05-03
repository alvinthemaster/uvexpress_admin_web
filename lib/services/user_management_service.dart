import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/app_user_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Stream all users ────────────────────────────────────────────────
  Stream<List<AppUser>> getUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  // ── Fetch once ──────────────────────────────────────────────────────
  Future<List<AppUser>> getUsers() async {
    final snap = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(AppUser.fromFirestore).toList();
  }

  Future<AppUser?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  // ── Create user (Firebase Auth + Firestore) ─────────────────────────
  // Uses a secondary Firebase app instance so the admin's auth session is
  // never displaced by signing in as the newly-created user.
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    final appName = 'user_creation_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      // Send email verification before signing out so the link is valid
      await credential.user!.sendEmailVerification();
      await secondaryAuth.signOut();

      final user = AppUser(
        id: uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        isRestricted: false,
        isEmailVerified: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(user.toFirestore());
      return user;
    } finally {
      await secondaryApp?.delete();
    }
  }

  // ── Update user profile ─────────────────────────────────────────────
  Future<void> updateUser({
    required String uid,
    required String name,
    required String phone,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name,
      'phone': phone,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Restrict / Unrestrict ───────────────────────────────────────────
  Future<void> setRestricted(String uid, bool restricted) async {
    await _firestore.collection('users').doc(uid).update({
      'isRestricted': restricted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete user Firestore document ──────────────────────────────────
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // ── Search helpers ──────────────────────────────────────────────────
  Future<List<AppUser>> searchUsers(String query) async {
    final all = await getUsers();
    final q = query.toLowerCase();
    return all
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.contains(q))
        .toList();
  }
}
