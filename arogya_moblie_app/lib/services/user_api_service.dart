import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

/// Connects to the Arogya user-service (port 8081).
/// On Android emulator, 10.0.2.2 maps to host machine's localhost.
/// Change [_baseUrl] to your actual server IP for a physical device.
class UserApiService {
  // ── change this to your server's IP when running on a real device ──
  static const String _baseUrl = 'http://localhost:8081';

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
      throw UserApiException(
        'Cannot connect to server. Check your network.',
        0,
      );
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
    final uri = Uri.parse(
      '$_baseUrl/patient_profile/getPatientProfileByUserId/$userId',
    );
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // Patient profile doesn't exist yet
        return null;
      } else {
        // Log the error for debugging
        print('ERROR: getPatientProfile failed with status ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('ERROR: getPatientProfile exception: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createPatientProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/patient_profile/createPatientProfile');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to create patient profile',
      response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> updatePatientProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/patient_profile/updatePatientProfile');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to update patient profile',
      response.statusCode,
    );
  }

  // ── Doctor profile ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getDoctorProfile(int userId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor_profile/getDoctorProfileByUserId/$userId',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>> createDoctorProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/doctor_profile/createDoctorProfile');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to create doctor profile',
      response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> updateDoctorProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/doctor_profile/updateDoctorProfile');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to update doctor profile',
      response.statusCode,
    );
  }

  // ── Technician profile ─────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getTechnicianProfile(int userId) async {
    final uri = Uri.parse(
      '$_baseUrl/technician_profile/getTechnicianProfileByUserId/$userId',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>> createTechnicianProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/technician_profile/createTechnicianProfile',
    );
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to create technician profile',
      response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> updateTechnicianProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/technician_profile/updateTechnicianProfile',
    );
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to update technician profile',
      response.statusCode,
    );
  }

  // ── Admin profile ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getAdminProfile(int userId) async {
    final uri = Uri.parse(
      '$_baseUrl/admin_profile/getAdminProfileByUserId/$userId',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>> createAdminProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/admin_profile/createAdminProfile');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to create admin profile',
      response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> updateAdminProfile(
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.parse('$_baseUrl/admin_profile/updateAdminProfile');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(profile))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw UserApiException(
      'Failed to update admin profile',
      response.statusCode,
    );
  }

  // ── Bulk list endpoints (for dashboard stats) ─────────────────────

  static Future<List<dynamic>> getAllPatientProfiles() async {
    final uri = Uri.parse('$_baseUrl/patient_profile/getAllPatientProfiles');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw UserApiException('Failed to load patients', response.statusCode);
  }

  static Future<List<dynamic>> getAllDoctorProfiles() async {
    final uri = Uri.parse('$_baseUrl/doctor_profile/getAllDoctorProfiles');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw UserApiException('Failed to load doctors', response.statusCode);
  }

  // ── Register ───────────────────────────────────────────────────────

  /// Register a new user account.
  /// [roleId] and [roleName] must correspond to a valid role on the server.
  /// [secretKey] is required for DOCTOR, ADMIN, and TECHNICIAN roles.
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required int roleId,
    required String roleName,
    String? secretKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/addUser');

    final Map<String, dynamic> body = {
      'username': username,
      'email': email,
      'password': password,
      'userRole': {'id': roleId, 'roleName': roleName},
    };
    if (secretKey != null && secretKey.isNotEmpty) {
      body['secretKey'] = secretKey;
    }

    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final json = _tryDecode(response.body);
        String msg;
        if (response.statusCode == 409) {
          msg = 'An account with this email already exists.';
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          msg = 'Invalid secret key. Please check your credentials.';
        } else if (response.statusCode == 400) {
          msg =
              json?['message'] ??
              'Invalid registration data. Please check your information.';
        } else {
          msg =
              json?['message'] ??
              'Registration failed (${response.statusCode})';
        }
        throw UserApiException(msg, response.statusCode);
      }
    } on UserApiException {
      rethrow;
    } catch (e) {
      throw UserApiException(
        'Cannot connect to server. Check your network.',
        0,
      );
    }
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
