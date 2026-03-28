import 'dart:convert';
import 'package:http/http.dart' as http;

/// Connects to the Arogya clinic-service (port 8082).
class ClinicApiService {
  static const String _baseUrl = 'http://10.0.2.2:8082';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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
}
