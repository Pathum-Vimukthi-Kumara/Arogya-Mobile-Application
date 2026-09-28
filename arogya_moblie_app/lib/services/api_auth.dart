/// Holds the current session's JWT and builds the headers every API
/// service should send. Set by [AuthProvider] after login/session-restore
/// and cleared on logout.
class ApiAuth {
  static String? token;

  static Map<String, String> headers() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }
}
