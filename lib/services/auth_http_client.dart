import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';

/// HTTP client wrapper that transparently handles expired access tokens.
///
/// Every request made through this client:
///  1. Sends the currently stored access token (`Authorization: Bearer ...`).
///  2. If the backend answers `401` / `403`, calls the refresh-token API
///     **once** (shared between concurrent requests) and retries the original
///     request with the new token.
///  3. Persists the refresh response (access token + refresh token) so the new
///     credentials are stored in the app.
///
/// Use this instead of `http.get` / `http.post` for any authenticated API so no
/// call site has to deal with token expiry itself.
class AuthHttpClient {
  AuthHttpClient._internal();
  static final AuthHttpClient _instance = AuthHttpClient._internal();
  factory AuthHttpClient() => _instance;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  /// Status codes that mean "the access token is missing / expired / invalid".
  static bool isUnauthorized(int statusCode) =>
      statusCode == 401 || statusCode == 403;

  /// Merges caller-provided [headers] over the default app headers and fills in
  /// `Authorization` from secure storage when the caller did not supply one.
  static Future<Map<String, String>> _headersWithAuth(
    Map<String, String>? headers,
  ) async {
    final base = await getHeaders();
    final merged = <String, String>{...base, ...?headers};
    if ((merged['Authorization'] ?? '').trim().isEmpty) {
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) {
        merged['Authorization'] = formatAuthToken(token);
      }
    }
    return merged;
  }

  /// Low-level send used by all helpers. Retries once after a successful
  /// token refresh when the response is `401` / `403`.
  Future<http.Response> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
    bool retryOnUnauthorized = true,
  }) async {
    final requestHeaders = await _headersWithAuth(headers);
    final response = await _dispatch(
      method,
      url,
      headers: requestHeaders,
      body: body,
      timeout: timeout,
    );

    if (retryOnUnauthorized && isUnauthorized(response.statusCode)) {
      AppLogger.log(
        '🔒 HTTP ${response.statusCode} from $url - attempting token refresh',
        tag: 'Auth',
      );
      final refreshed = await refreshAuthToken();
      if (refreshed) {
        final retryHeaders = Map<String, String>.from(requestHeaders);
        final newToken = await getAuthToken();
        if (newToken != null && newToken.isNotEmpty) {
          retryHeaders['Authorization'] = formatAuthToken(newToken);
        }
        final retried = await _dispatch(
          method,
          url,
          headers: retryHeaders,
          body: body,
          timeout: timeout,
        );
        AppLogger.log(
          '🔁 Retried $method $url after refresh -> ${retried.statusCode}',
          tag: 'Auth',
        );
        return retried;
      }
    }
    return response;
  }

  Future<http.Response> _dispatch(
    String method,
    Uri url, {
    required Map<String, String> headers,
    Object? body,
    required Duration timeout,
  }) {
    final Future<http.Response> request;
    switch (method) {
      case 'GET':
        request = http.get(url, headers: headers);
        break;
      case 'POST':
        request = http.post(url, headers: headers, body: body);
        break;
      case 'PUT':
        request = http.put(url, headers: headers, body: body);
        break;
      case 'PATCH':
        request = http.patch(url, headers: headers, body: body);
        break;
      case 'DELETE':
        request = http.delete(url, headers: headers, body: body);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
    return request.timeout(timeout);
  }

  /// GET the [url] with auth handling. Retries once after a token refresh
  /// when the response is `401` / `403`, and throws on network / timeout
  /// failure (callers usually wrap the request in their own try/catch).
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) =>
      send('GET', url, headers: headers, timeout: timeout);

  /// POST the [url] with auth handling. See [get].
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) =>
      send('POST', url, headers: headers, body: body, timeout: timeout);

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) =>
      send('PUT', url, headers: headers, body: body, timeout: timeout);

  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) =>
      send('PATCH', url, headers: headers, body: body, timeout: timeout);

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) =>
      send('DELETE', url, headers: headers, body: body, timeout: timeout);

  /// Multipart upload with the same 401/403 → refresh → retry contract as
  /// the JSON helpers.
  ///
  /// [buildRequest] is called once up-front and a second time after a
  /// successful token refresh, so file streams are rebuilt instead of being
  /// reused. The helper sets the `Authorization` header itself from secure
  /// storage.
  static Future<http.Response> sendMultipartWithRefresh({
    required Future<http.MultipartRequest> Function() buildRequest,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    Future<http.Response> doSend() async {
      final request = await buildRequest();
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = formatAuthToken(token);
      } else {
        request.headers.remove('Authorization');
      }
      final streamed = await request.send().timeout(timeout);
      return http.Response.fromStream(streamed);
    }

    final response = await doSend();
    if (!isUnauthorized(response.statusCode)) return response;

    AppLogger.log(
      '🔒 HTTP ${response.statusCode} on multipart upload - attempting token refresh',
      tag: 'Auth',
    );
    if (!await refreshAuthToken()) return response;
    return doSend();
  }

  /// Used when a raw response came back `401` / `403` and the caller wants the
  /// same refresh-and-retry contract without switching clients.
  ///
  /// Returns `true` when the token was refreshed and the request should be
  /// retried with fresh headers.
  static Future<bool> handleUnauthorized(http.Response response) async {
    if (!isUnauthorized(response.statusCode)) return false;
    return refreshAuthToken();
  }

  /// Parses a refresh endpoint body. Tolerates both `jwtToken` and `jwt`
  /// style payloads. Returns `null` when the body carries no access token.
  static ({String accessToken, String refreshToken})? parseRefreshResponse(
    String body,
  ) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final access = (map['jwtToken'] ??
              map['jwt'] ??
              map['accessToken'] ??
              map['token'] ??
              '')
          .toString()
          .trim();
      final refresh =
          (map['refreshToken'] ?? map['refresh_token'] ?? '').toString().trim();
      if (access.isEmpty) return null;
      return (accessToken: access, refreshToken: refresh);
    } catch (_) {
      return null;
    }
  }
}
