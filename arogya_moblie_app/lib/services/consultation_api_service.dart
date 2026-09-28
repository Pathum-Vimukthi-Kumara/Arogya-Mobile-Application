import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_auth.dart';

class ConsultationApiService {
  static const String _baseUrl = 'http://10.0.2.2:8096';

  static Map<String, String> get _headers => ApiAuth.headers();

  static Future<List<Map<String, dynamic>>> list({
    int? patientId,
    int? doctorId,
    int? clinicId,
    String? status,
    int page = 0,
    int size = 100,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      if (patientId != null) 'patientId': patientId.toString(),
      if (doctorId != null) 'doctorId': doctorId.toString(),
      if (clinicId != null) 'clinicId': clinicId.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final uri = Uri.parse(
      '$_baseUrl/consultations',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List<dynamic> rows;
      if (body is Map<String, dynamic> && body['content'] is List) {
        rows = body['content'] as List<dynamic>;
      } else if (body is List) {
        rows = body;
      } else {
        rows = [];
      }
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    throw Exception(_message(response, 'Failed to load consultations'));
  }

  static Future<Map<String, dynamic>> create(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/consultations');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to create consultation'));
  }

  static Future<Map<String, dynamic>> get(int consultationId) async {
    final uri = Uri.parse('$_baseUrl/consultations/$consultationId');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to load consultation'));
  }

  static Future<Map<String, dynamic>> updateStatus(
    int consultationId,
    String status,
  ) async {
    final uri = Uri.parse('$_baseUrl/consultations/$consultationId');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update consultation'));
  }

  /// Updates any subset of chiefComplaint / presentIllness /
  /// pastMedicalHistory / recommendations for an existing consultation.
  static Future<Map<String, dynamic>> update(
    int consultationId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl/consultations/$consultationId');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update consultation'));
  }

  static Future<void> delete(int consultationId) async {
    final uri = Uri.parse('$_baseUrl/consultations/$consultationId');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_message(response, 'Failed to delete consultation'));
    }
  }

  static Future<void> bulkDelete(List<int> ids) async {
    final uri = Uri.parse('$_baseUrl/consultations/bulk-delete');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(ids))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_message(response, 'Failed to delete consultations'));
    }
  }

  static Future<Map<String, dynamic>> complete(int consultationId) async {
    final uri = Uri.parse('$_baseUrl/consultations/$consultationId/complete');
    final response = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to complete consultation'));
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
