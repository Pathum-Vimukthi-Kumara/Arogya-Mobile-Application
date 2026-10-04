import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_auth.dart';

/// Represents a file payload for test result uploads.
class TestResultUploadFile {
  final List<int> bytes;
  final String name;
  final String? mimeType;

  const TestResultUploadFile({
    required this.bytes,
    required this.name,
    this.mimeType,
  });
}

/// Connects to the Arogya medical-records-service (port 8087).
class TestResultsApiService {
  static const String _baseUrl = 'http://10.0.2.2:8087';
  static const int maxFiles = 5;

  /// Helper to resolve standard MIME type for accepted formats.
  static String? mimeTypeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  /// Submits a lab test result. The backend consumes multipart/form-data.
  ///
  /// Pass [files] (or legacy [fileBytes] + [fileName]) to attach files.
  /// Backend expects multi-part parameter name "files".
  static Future<Map<String, dynamic>> create({
    required int labTestId,
    required int patientId,
    required int technicianId,
    required String testResultDescription,
    String? technicianNotes,
    List<TestResultUploadFile>? files,
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
    if (technicianNotes != null && technicianNotes.trim().isNotEmpty) {
      request.fields['technicianNotes'] = technicianNotes.trim();
    }

    final allFiles = <TestResultUploadFile>[];
    if (files != null && files.isNotEmpty) {
      allFiles.addAll(files);
    }
    if (fileBytes != null && fileName != null) {
      allFiles.add(
        TestResultUploadFile(
          bytes: fileBytes,
          name: fileName,
          mimeType: mimeType ?? mimeTypeFor(fileName),
        ),
      );
    }

    for (final f in allFiles) {
      final mt = f.mimeType ?? mimeTypeFor(f.name);
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          f.bytes,
          filename: f.name,
          contentType: mt != null ? MediaType.parse(mt) : null,
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to submit test result'));
  }

  /// Updates an existing test result. Uses POST /test-results/{id}/update
  /// (or PUT /test-results/{id}) with multipart/form-data.
  static Future<Map<String, dynamic>> update(
    int id, {
    String? testResultDescription,
    String? technicianNotes,
    List<TestResultUploadFile>? files,
    List<int>? removeFileIds,
  }) async {
    final uri = Uri.parse('$_baseUrl/test-results/$id/update');
    final request = http.MultipartRequest('POST', uri);

    final headers = ApiAuth.headers();
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    if (testResultDescription != null) {
      request.fields['testResultDescription'] = testResultDescription;
    }
    if (technicianNotes != null) {
      request.fields['technicianNotes'] = technicianNotes;
    }
    if (removeFileIds != null && removeFileIds.isNotEmpty) {
      request.fields['removeFileIds'] = removeFileIds.join(',');
    }

    if (files != null && files.isNotEmpty) {
      for (final f in files) {
        final mt = f.mimeType ?? mimeTypeFor(f.name);
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            f.bytes,
            filename: f.name,
            contentType: mt != null ? MediaType.parse(mt) : null,
          ),
        );
      }
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Failed to update test result'));
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

  /// Deletes a test result.
  static Future<void> delete(int id) async {
    final uri = Uri.parse('$_baseUrl/test-results/$id/delete');
    final response = await http
        .post(uri, headers: ApiAuth.headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_message(response, 'Failed to delete test result'));
    }
  }

  /// Downloads a file from the test result.
  static Future<List<int>> downloadFile(int testResultId, int fileId) async {
    final uri = Uri.parse(
      '$_baseUrl/test-results/$testResultId/files/$fileId/download',
    );
    final response = await http
        .get(uri, headers: ApiAuth.headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception(_message(response, 'Failed to download file'));
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
