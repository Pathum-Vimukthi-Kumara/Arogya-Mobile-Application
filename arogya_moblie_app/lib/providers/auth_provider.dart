import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_auth.dart';
import '../services/user_api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _userKey = 'arogya_current_user';
  static const String _tokenKey = 'arogya_auth_token';

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
    final token = prefs.getString(_tokenKey);
    if (raw != null && token != null) {
      try {
        _user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        ApiAuth.token = token;
        notifyListeners();
      } catch (_) {
        await prefs.remove(_userKey);
        await prefs.remove(_tokenKey);
      }
    }
  }

  // ── Login ──────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await UserApiService.login(email: email, password: password);
      _user = result.user;
      ApiAuth.token = result.token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(result.user.toJson()));
      await prefs.setString(_tokenKey, result.token);
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
    ApiAuth.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
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
