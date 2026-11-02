import 'package:http/http.dart' as http;

/// Safe HTTP client wrapper.
///
/// Wraps an [http.Client] with a request timeout and converts transport-level
/// failures (network error / timeout) into `null` so callers can treat an error
/// as "no response" and handle it gracefully.
class SafeHttpClient {
  SafeHttpClient._internal();
  static final SafeHttpClient _instance = SafeHttpClient._internal();
  factory SafeHttpClient() => _instance;

  static final http.Client _client = http.Client();

  /// POST request with a timeout.
  /// Returns the [http.Response], or `null` when the request fails
  /// (network error / timeout).
  static Future<http.Response?> safePost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await _client
          .post(url, headers: headers, body: body)
          .timeout(timeout);
      return response;
    } catch (_) {
      return null;
    }
  }

  /// GET request with a timeout.
  /// Returns the [http.Response], or `null` when the request fails
  /// (network error / timeout).
  static Future<http.Response?> safeGet(
    Uri url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await _client.get(url, headers: headers).timeout(timeout);
      return response;
    } catch (_) {
      return null;
    }
  }

  static void dispose() {
    _client.close();
  }
}
