import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_auth.dart';

/// Connects to the Arogya medical-records-service (port 8087).
class TestResultsApiService {
  static const String _baseUrl = 'http://10.0.2.2:8087';

  /// Submits a lab test result. The backend consumes multipart/form-data,
  /// so this must not set a JSON Content-Type header.
  ///
  /// Pass [fileBytes] + [fileName] (and optionally [mimeType]) to attach a
  /// report file, matching the web app's PDF/DOC/DOCX/JPG/PNG support.
  static Future<Map<String, dynamic>> create({
    required int labTestId,
    required int patientId,
    required int technicianId,
    required String testResultDescription,
    String? technicianNotes,
    List<int>? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$_baseUrl/test-results');
    final request = http.MultipartRequest('POST', uri);

    final headers = ApiAuth.headers();
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.fields['labTestId'] = labTestId.toString();
    request.fields['patientId'] = patientId.toString();
    request.fields['technicianId'] = technicianId.toString();
    request.fields['testResultDescription'] = testResultDescription;
    if (technicianNotes != null && technicianNotes.isNotEmpty) {
      request.fields['technicianNotes'] = technicianNotes;
    }
    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to submit test result'));
  }

  /// Returns the existing result for a lab test, or null if none exists yet
  /// (a 404 from the backend).
  static Future<Map<String, dynamic>?> getByLabTestId(int labTestId) async {
    final uri = Uri.parse('$_baseUrl/test-results/lab-test/$labTestId');
    final response = await http
        .get(uri, headers: ApiAuth.headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
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
