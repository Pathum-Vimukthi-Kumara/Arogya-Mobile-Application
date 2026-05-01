import 'dart:convert';
import 'package:http/http.dart' as http;

class QueueApiService {
  static const String _baseUrl = 'http://10.0.2.2:8085';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<dynamic>> getClinicQueue(String clinicId) async {
    final uri = Uri.parse('$_baseUrl/queue/clinics/$clinicId/tokens');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load queue (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> createToken({
    required int clinicId,
    required int patientId,
  }) async {
    final uri = Uri.parse('$_baseUrl/queue/tokens');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'clinicId': clinicId.toString(),
            'patientId': patientId.toString(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to join queue (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> updateStatus(
    int tokenId,
    String status,
  ) async {
    final uri = Uri.parse('$_baseUrl/queue/tokens/$tokenId/status');
    final response = await http
        .patch(uri, headers: _headers, body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update queue token (${response.statusCode})');
  }
}
