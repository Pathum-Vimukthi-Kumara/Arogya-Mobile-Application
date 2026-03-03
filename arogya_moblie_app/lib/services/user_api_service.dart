import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

/// Connects to the Arogya user-service (port 8081).
/// On Android emulator, 10.0.2.2 maps to host machine's localhost.
/// Change [_baseUrl] to your actual server IP for a physical device.
class UserApiService {
  // ── change this to your server's IP when running on a real device ──
  static const String _baseUrl = 'http://10.0.2.2:8081';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Auth ───────────────────────────────────────────────────────────

  /// Login with email + password.
  /// Throws [UserApiException] on error.
  static Future<User> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/login');
    final body = jsonEncode({'email': email, 'password': password});

    try {
      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(json);
      } else {
        final json = _tryDecode(response.body);
        final msg = json?['message'] ?? 'Login failed (${response.statusCode})';
        throw UserApiException(msg, response.statusCode);
      }
    } on UserApiException {
      rethrow;
    } catch (e) {
      throw UserApiException('Cannot connect to server. Check your network.', 0);
    }
  }

  // ── Users ──────────────────────────────────────────────────────────

  static Future<User> getUserById(int id) async {
    final uri = Uri.parse('$_baseUrl/users/getUser/$id');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw UserApiException('Failed to load user', response.statusCode);
  }

  static Future<User> getUserByEmail(String email) async {
    final uri = Uri.parse('$_baseUrl/users/getUserByEmail/$email');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw UserApiException('Failed to load user', response.statusCode);
  }

  static Future<List<User>> getAllUsers() async {
    final uri = Uri.parse('$_baseUrl/users/getAllUsers');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw UserApiException('Failed to load users', response.statusCode);
  }

  static Future<User> updateUser(User user) async {
    final uri = Uri.parse('$_baseUrl/users/updateUser');
    final body = jsonEncode(user.toJson());
    final response = await http
        .put(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw UserApiException('Failed to update user', response.statusCode);
  }

  // ── Patient profile ────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getPatientProfile(int userId) async {
    final uri =
        Uri.parse('$_baseUrl/patient_profile/getPatientProfileByUserId/$userId');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // ── helpers ────────────────────────────────────────────────────────

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}

class UserApiException implements Exception {
  final String message;
  final int statusCode;
  const UserApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
