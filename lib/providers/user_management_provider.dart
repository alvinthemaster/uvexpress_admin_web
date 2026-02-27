import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_user_model.dart';
import '../services/user_management_service.dart';

class UserManagementProvider extends ChangeNotifier {
  final UserManagementService _service = UserManagementService();

  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<AppUser>>? _subscription;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalCount => _users.length;
  int get restrictedCount => _users.where((u) => u.isRestricted).length;
  int get activeCount => _users.where((u) => !u.isRestricted).length;

  // ── Subscribe to real-time updates ──────────────────────────────────
  void startListening() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getUsersStream().listen(
      (users) {
        _users = users;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  // ── Create ───────────────────────────────────────────────────────────
  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      await _service.createUser(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Update ───────────────────────────────────────────────────────────
  Future<void> updateUser({
    required String uid,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      await _service.updateUser(uid: uid, name: name, phone: phone, role: role);
    } catch (e) {
      rethrow;
    }
  }

  // ── Restrict / Unrestrict ────────────────────────────────────────────
  Future<void> restrictUser(String uid) async {
    await _service.setRestricted(uid, true);
  }

  Future<void> unrestrictUser(String uid) async {
    await _service.setRestricted(uid, false);
  }

  // ── Delete ───────────────────────────────────────────────────────────
  Future<void> deleteUser(String uid) async {
    await _service.deleteUser(uid);
  }
}
