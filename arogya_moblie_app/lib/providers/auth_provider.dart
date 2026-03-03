import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/user_api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _userKey = 'arogya_current_user';

  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  // ── Restore session on app start ───────────────────────────────────

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {
        await prefs.remove(_userKey);
      }
    }
  }

  // ── Login ──────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await UserApiService.login(email: email, password: password);
      _user = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      return true;
    } on UserApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    _user = null;
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }

  // ── Refresh user from server ───────────────────────────────────────

  Future<void> refreshUser() async {
    if (_user == null) return;
    try {
      final updated = await UserApiService.getUserById(_user!.id);
      _user = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(updated.toJson()));
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
