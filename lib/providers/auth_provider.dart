import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/admin_models.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  AdminUser? _adminUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  AdminUser? get adminUser => _adminUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _adminUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        _adminUser = await _authService.getAdminUser(user.uid);
        if (_adminUser == null || !_adminUser!.isActive) {
          await signOut();
        }
      } else {
        _adminUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      UserCredential? result = await _authService.signInWithEmailAndPassword(email, password);
      
      if (result?.user != null) {
        bool isAdmin = await _authService.isAdmin(result!.user!.uid);
        if (!isAdmin) {
          await _authService.signOut();
          _errorMessage = 'Access denied. Admin privileges required.';
          _user = null;
          _adminUser = null;
        } else {
          _adminUser = await _authService.getAdminUser(result.user!.uid);
        }
      }
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      _user = null;
      _adminUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _user = null;
      _adminUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.resetPassword(email);
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ONLY FOR INITIAL SETUP - Create initial admin account
  Future<String> createInitialAdmin() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      String result = await _authService.createInitialAdmin();
      return result;
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool hasPermission(String permission) {
    return _adminUser?.hasPermission(permission) ?? false;
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No user found with this email address.';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address.';
    } else if (error.contains('user-disabled')) {
      return 'This user account has been disabled.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed login attempts. Please try again later.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }
}