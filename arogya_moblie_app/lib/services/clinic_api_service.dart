import 'dart:convert';
import 'package:http/http.dart' as http;

/// Connects to the Arogya clinic-service (port 8082).
class ClinicApiService {
  static const String _baseUrl = 'http://localhost:8082';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Clinics ────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAllClinics() async {
    final uri = Uri.parse('$_baseUrl/clinics/getAllClinics');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load clinics (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> getClinicById(int id) async {
    final uri = Uri.parse('$_baseUrl/clinics/getClinic/$id');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load clinic (${response.statusCode})');
  }

  static Future<void> createClinic(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/clinics/createClinic');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create clinic (${response.statusCode})');
    }
  }

  static Future<void> updateClinic(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/clinics/updateClinic');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to update clinic (${response.statusCode})');
    }
  }

  static Future<void> deleteClinic(int id) async {
    final uri = Uri.parse('$_baseUrl/clinics/deleteClinic/$id');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete clinic (${response.statusCode})');
    }
  }

  // ── Clinic Doctors ─────────────────────────────────────────────────

  static Future<List<dynamic>> getClinicDoctorsByClinicId(int clinicId) async {
    final uri = Uri.parse(
      '$_baseUrl/clinic_doctors/getClinicDoctorsByClinicId/$clinicId',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load clinic doctors (${response.statusCode})');
  }
}
