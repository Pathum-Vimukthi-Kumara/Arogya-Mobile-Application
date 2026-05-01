import 'dart:convert';
import 'package:http/http.dart' as http;

class LabTestApiService {
  static const String _baseUrl = 'http://10.0.2.2:8086';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<Map<String, dynamic>>> getByConsultation(
    int consultationId,
  ) async {
    final uri =
        Uri.parse('$_baseUrl/lab-tests/consultation/$consultationId');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) {
        return body
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load lab tests'));
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/lab-tests');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to create lab test'));
  }

  static String _message(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message']?.toString() ??
          body['error']?.toString() ??
          '$fallback (${response.statusCode})';
    } catch (_) {
      return response.body.isNotEmpty
          ? response.body
          : '$fallback (${response.statusCode})';
    }
  }
}
