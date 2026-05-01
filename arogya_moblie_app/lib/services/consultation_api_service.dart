import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultationApiService {
  static const String _baseUrl = 'http://10.0.2.2:8086';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<Map<String, dynamic>>> list({
    int? patientId,
    int? doctorId,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (patientId != null) queryParams['patientId'] = patientId.toString();
    if (doctorId != null) queryParams['doctorId'] = doctorId.toString();

    final uri = Uri.parse('$_baseUrl/consultations').replace(
      queryParameters: queryParams,
    );
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
      if (body is Map<String, dynamic> && body['content'] is List) {
        final content = body['content'] as List<dynamic>;
        return content
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load consultations'));
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/consultations');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to create consultation'));
  }

  static Future<Map<String, dynamic>> updateStatus(
    int consultationId,
    String status,
  ) async {
    final uri =
        Uri.parse('$_baseUrl/consultations/$consultationId/status');
    final response = await http
        .patch(uri, headers: _headers, body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update consultation'));
  }

  static Future<void> complete(int consultationId) async {
    final uri =
        Uri.parse('$_baseUrl/consultations/$consultationId/complete');
    final response = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_message(response, 'Failed to complete consultation'));
    }
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
