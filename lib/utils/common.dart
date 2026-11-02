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

/// Check if refresh token exists in SharedPreferences
Future<bool> _hasRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString('refreshToken');
  return refreshToken != null && refreshToken.isNotEmpty;
}

/// Refresh token on 403 error
/// Calls the refresh endpoint and saves new tokens
/// Returns true if refresh was successful
/// The refresh endpoint is called without the access token in headers
/// since the access token may be expired (which is why we're refreshing).
Future<bool> refreshTokenOn403() async {
  final hasRefreshToken = await _hasRefreshToken();
  if (!hasRefreshToken) {
    logger.log('No refresh token available for 403 handling');
    return false;
  }

  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString('refreshToken');

  try {
    final response = await http.post(
      Uri.parse('${Constant.baseUrl}fm/auth/refresh'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({
        'refreshToken': refreshToken,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final newJwt = responseData['jwtToken']?.toString().trim() ?? '';
      final newRefreshToken = responseData['refreshToken']?.toString().trim() ?? '';

      if (newJwt.isNotEmpty) {
        await prefs.setString('jwt', newJwt);
        await saveAuthToken(newJwt);
        if (newRefreshToken.isNotEmpty) {
          await prefs.setString('refreshToken', newRefreshToken);
        }
        logger.log('✅ Token refreshed successfully after 403');
        return true;
      } else {
        logger.log('❌ Refresh response missing jwtToken');
      }
    } else {
      logger.log('❌ Token refresh failed after 403: ${response.statusCode}');
    }
  } catch (e) {
    logger.log('❌ Token refresh error after 403: $e');
  }
  return false;
}

/// Check response status and refresh token on 403
/// Returns true if the response was a 403 and token refresh was attempted.
/// Caller should retry the API call if this returns true and refresh was successful.
Future<bool> checkResponseAndRefreshOn403(http.Response response) async {
  if (response.statusCode != 403) {
    return false;
  }

  logger.log('🔄 Received 403, attempting token refresh...', name: 'HTTP');
  final refreshed = await refreshTokenOn403();
  if (refreshed) {
    logger.log('✅ Token refreshed successfully after 403', name: 'HTTP');
    return true;
  }
  logger.log('❌ Token refresh failed after 403', name: 'HTTP');
  return true; // Return true so caller knows 403 was encountered
}

/// Common headers for all API calls
Future<Map<String, String>> getHeaders() async {
  final token = await getAuthToken();
  // final token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkZXZhZG1pbiIsInJvbGVzIjpbIlJPTEVfREVWQURNSU4iXSwidXNlcklkIjo3NywiaWF0IjoxNzg3NzIyMDgxLCJleHAiOjE3ODc4MDg0ODF9.43xp9DxOfhc33vEpWpK_NU_KiG1aUeeklWt1cXXG3Is";

  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': token,
  };
}
