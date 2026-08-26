import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
