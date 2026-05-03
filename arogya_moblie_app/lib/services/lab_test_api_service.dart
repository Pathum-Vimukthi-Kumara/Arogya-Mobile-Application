import 'dart:convert';
import 'package:http/http.dart' as http;

class LabTestApiService {
  static const String _baseUrl = 'http://localhost:8086';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<Map<String, dynamic>>> getByConsultation(
    int consultationId,
  ) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/consultation/$consultationId');
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
      if (body is Map && body['content'] is List) {
        return (body['content'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load lab tests'));
  }

  static Future<List<Map<String, dynamic>>> list({
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final uri = Uri.parse(
      '$_baseUrl/lab-tests',
    ).replace(queryParameters: queryParams);
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
      if (body is Map && body['content'] is List) {
        return (body['content'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load lab tests'));
  }

  static Future<Map<String, dynamic>> get(int id) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to load lab test'));
  }

  static Future<Map<String, dynamic>> create(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/lab-tests');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to create lab test'));
  }

  static Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update lab test'));
  }

  static Future<Map<String, dynamic>> updateStatus(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id/technician-update');
    final response = await http
        .put(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 409) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update lab test status'));
  }

  static Future<void> delete(int id) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_message(response, 'Failed to delete lab test'));
    }
  }

  static Future<List<Map<String, dynamic>>> getByTechnician(
    int technicianId, {
    int page = 0,
    int size = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/lab-tests/technician/dashboard?technicianId=$technicianId&page=$page&size=$size',
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
      if (body is Map && body['content'] is List) {
        return (body['content'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(
      _message(response, 'Failed to load lab tests for technician'),
    );
  }

  static Future<List<Map<String, dynamic>>> getTechnicianDashboard({
    int? technicianId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (technicianId != null) {
      queryParams['technicianId'] = technicianId.toString();
    }
    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$_baseUrl/lab-tests/technician/dashboard',
    ).replace(queryParameters: queryParams);
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
      if (body is Map && body['content'] is List) {
        return (body['content'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load technician dashboard'));
  }

  static Future<List<Map<String, dynamic>>> getPending() async {
    final uri = Uri.parse('$_baseUrl/lab-tests?status=PENDING');
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
      if (body is Map && body['content'] is List) {
        return (body['content'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return [];
    }
    throw Exception(_message(response, 'Failed to load pending lab tests'));
  }

  static Future<Map<String, dynamic>> startTest(int id) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id/start');
    final response = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to start lab test'));
  }

  static Future<Map<String, dynamic>> completeTest(
    int id, {
    Map<String, dynamic>? testResults,
    String? technicianNotes,
  }) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id/complete');
    final body = <String, dynamic>{};
    if (testResults != null) body['testResults'] = testResults;
    if (technicianNotes != null) body['technicianNotes'] = technicianNotes;

    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode(body.isNotEmpty ? body : null),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to complete lab test'));
  }

  static Future<Map<String, dynamic>> cancelTest(int id) async {
    final uri = Uri.parse('$_baseUrl/lab-tests/$id/cancel');
    final response = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to cancel lab test'));
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
