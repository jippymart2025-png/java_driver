import 'dart:convert';
import 'dart:developer' as logger;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:http/http.dart' as http;

const FlutterSecureStorage storage = FlutterSecureStorage();

Map<String, String> get headers => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

String formatAuthToken(String token, {String tokenType = 'Bearer'}) {
  final trimmed = token.trim();

  if (trimmed.isEmpty) return trimmed;

  if (trimmed.startsWith('Bearer ')) {
    return trimmed;
  }

  return '$tokenType $trimmed';
}

/// Save token after login
Future<void> saveAuthToken(
    String accessToken, {
      String tokenType = 'Bearer',
    }) async {
  if (accessToken.trim().isEmpty) return;

  await storage.write(
    key: 'api_token',
    value: formatAuthToken(accessToken, tokenType: tokenType),
  );
}

/// Get saved token
Future<String?> getAuthToken() async {
  return await storage.read(key: 'api_token');
}

/// Remove token on logout
Future<void> clearAuthToken() async {
  await storage.delete(key: 'api_token');
}

/// Keys used to persist the refresh-token API response inside the app.
abstract class AuthTokenKeys {
  static const String accessToken = 'jwt';
  static const String legacyAccessToken = 'accessToken';
  static const String refreshToken = 'refreshToken';
  static const String refreshTokenType = 'refreshTokenType';
  static const String accessTokenIssuedAt = 'accessTokenIssuedAt';
  static const String rawRefreshResponse = 'refreshTokenResponse';
}

/// Stores every token returned by the refresh-token API.
///
/// Persists to secure storage (used by [getHeaders]) and to
/// SharedPreferences (used across app launches) so a refreshed session
/// survives restarts. The full raw refresh response is also stored under
/// [AuthTokenKeys.rawRefreshResponse].
Future<void> saveRefreshTokenResponse({
  required String accessToken,
  String? refreshToken,
  String? tokenType,
  String? rawResponse,
}) async {
  final access = accessToken.trim();
  if (access.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();

  await Future.wait([
    saveAuthToken(access, tokenType: (tokenType ?? 'Bearer').trim()),
    prefs.setString(AuthTokenKeys.accessToken, access),
    prefs.setString(AuthTokenKeys.legacyAccessToken, access),
    prefs.setString(
      AuthTokenKeys.accessTokenIssuedAt,
      DateTime.now().toIso8601String(),
    ),
    if (refreshToken != null && refreshToken.trim().isNotEmpty)
      prefs.setString(AuthTokenKeys.refreshToken, refreshToken.trim()),
    if (tokenType != null && tokenType.trim().isNotEmpty)
      prefs.setString(AuthTokenKeys.refreshTokenType, tokenType.trim()),
    if (rawResponse != null && rawResponse.trim().isNotEmpty)
      prefs.setString(AuthTokenKeys.rawRefreshResponse, rawResponse.trim()),
  ]);

  logger.log('💾 Refresh token response saved (access + refresh token)');
}

/// Check if refresh token exists in SharedPreferences
Future<bool> _hasRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString(AuthTokenKeys.refreshToken);
  return refreshToken != null && refreshToken.isNotEmpty;
}

Future<bool> _isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}

/// In-flight refresh request, shared so that a burst of parallel 401/403
/// responses triggers only ONE call to the refresh endpoint.
Future<bool>? _refreshInFlight;

/// Refreshes the access token whenever any API answers `401` or `403`.
///
/// The refresh endpoint is called without the (expired) access token. The
/// response is persisted through [saveRefreshTokenResponse] so the new access
/// token and refresh token are stored in the app.
///
/// Returns `true` when a new access token was obtained and saved.
Future<bool> refreshAuthToken() {
  // Reuse an in-flight refresh instead of hitting the endpoint again.
  return _refreshInFlight ??= _performRefresh().whenComplete(() {
    _refreshInFlight = null;
  });
}

Future<bool> _performRefresh() async {
  if (!await _hasRefreshToken()) {
    logger.log('No refresh token available for token refresh');
    return false;
  }

  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString(AuthTokenKeys.refreshToken);

  try {
    final response = await http.post(
      Uri.parse('${Constant.baseUrl}fm/auth/refresh'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'refreshToken': refreshToken,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;

      // Backend may return the tokens at the top level or wrapped in `data`.
      Map<String, dynamic> tokens = responseData;
      if (responseData['data'] is Map) {
        tokens = {
          ...responseData,
          ...Map<String, dynamic>.from(responseData['data'] as Map),
        };
      }

      final newJwt = (tokens['jwtToken'] ??
              tokens['jwt'] ??
              tokens['accessToken'] ??
              tokens['token'] ??
              '')
          .toString()
          .trim();
      final newRefreshToken =
          (tokens['refreshToken'] ?? tokens['refresh_token'] ?? '')
              .toString()
              .trim();
      final tokenType = tokens['tokenType']?.toString().trim();

      if (newJwt.isNotEmpty) {
        await saveRefreshTokenResponse(
          accessToken: newJwt,
          refreshToken: newRefreshToken,
          tokenType: tokenType,
          rawResponse: response.body,
        );
        logger.log('✅ Token refreshed successfully');
        return true;
      } else {
        logger.log('❌ Refresh response missing access token: ${response.body}');
      }
    } else {
      logger.log('❌ Token refresh failed: ${response.statusCode}');
      // The refresh token itself is invalid/expired - drop the session so the
      // user is sent back to login instead of looping on 401s.
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!await _isLoggedIn()) {
          await _clearStoredTokens(prefs);
        }
      }
    }
  } catch (e) {
    logger.log('❌ Token refresh error: $e');
  }
  return false;
}

Future<void> _clearStoredTokens(SharedPreferences prefs) async {
  await Future.wait([
    clearAuthToken(),
    prefs.remove(AuthTokenKeys.accessToken),
    prefs.remove(AuthTokenKeys.legacyAccessToken),
    prefs.remove(AuthTokenKeys.refreshToken),
    prefs.remove(AuthTokenKeys.refreshTokenType),
    prefs.remove(AuthTokenKeys.accessTokenIssuedAt),
    prefs.remove(AuthTokenKeys.rawRefreshResponse),
  ]);
}

/// Backwards-compatible alias for [refreshAuthToken].
Future<bool> refreshTokenOn403() => refreshAuthToken();

/// Backwards-compatible alias: refreshes the token when the response is
/// `401` / `403`. Returns `true` only when a refresh actually succeeded, in
/// which case the caller should retry the API call.
Future<bool> checkResponseAndRefreshOn403(http.Response response) async {
  if (response.statusCode != 401 && response.statusCode != 403) {
    return false;
  }

  logger.log(
    '🔄 Received ${response.statusCode}, attempting token refresh...',
    name: 'HTTP',
  );
  final refreshed = await refreshAuthToken();
  logger.log(
    refreshed
        ? '✅ Token refreshed successfully'
        : '❌ Token refresh failed',
    name: 'HTTP',
  );
  return refreshed;
}

/// Common headers for all API calls
Future<Map<String, String>> getHeaders() async {
  final token = await getAuthToken();

  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': token,
  };
}
