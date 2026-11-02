import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jippydriver_driver/services/api_cache_service.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';

/// HTTP Client Service with advanced optimizations
/// Features: Connection pooling, timeout management, retry logic, request cancellation, interceptors
class HttpClientService {
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;
  HttpClientService._internal() {
    _initializeClient();
  }
  
  final ApiCacheService _cacheService = ApiCacheService();
  
  // Optimized HTTP client with connection pooling
  late http.Client _httpClient;
  
  // Request tracking for cancellation
  final Map<String, Completer<http.Response>> _activeRequests = {};
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _fastTimeout = Duration(seconds: 10); // For critical requests
  
  // Connection pool settings
  static const int _maxConnectionsPerHost = 6; // Optimal for mobile
  static const Duration _idleTimeout = Duration(seconds: 30);
  
  /// Initialize optimized HTTP client with connection pooling
  void _initializeClient() {
    final httpClient = HttpClient()
      ..maxConnectionsPerHost = _maxConnectionsPerHost
      ..idleTimeout = _idleTimeout
      ..autoUncompress = true; // Enable gzip compression
      
    _httpClient = IOClient(httpClient);
    AppLogger.log('✅ HTTP Client initialized with connection pooling (max: $_maxConnectionsPerHost per host)', tag: 'HTTP');
  }
  
  /// Request interceptor - logs request details
  void _logRequest(String method, Uri url, {Map<String, String>? headers}) {
    AppLogger.log(
      '🌐 $method $url${headers != null ? ' | Headers: ${headers.keys.join(", ")}' : ""}',
      tag: 'HTTP'
    );
  }
  
  /// Response interceptor - logs response details and handles errors
  void _logResponse(http.Response response, Uri url, {Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    AppLogger.log(
      '${response.statusCode >= 200 && response.statusCode < 300 ? "✅" : "❌"} HTTP ${response.statusCode} $url$durationStr',
      tag: 'HTTP'
    );
  }
  
/// Retry logic with exponential backoff
  /// Also handles 403 errors by refreshing the token and retrying
  Future<http.Response> _retryRequest(
    Future<http.Response> Function() requestFn,
    int maxRetries,
    String urlString,
    Map<String, String> headers,
  ) async {
    int attempt = 0;
    Exception? lastException;
    
    while (attempt < maxRetries) {
      try {
        final response = await requestFn();
        
        // Handle 403: Refresh token and retry
        if (response.statusCode == 403) {
          AppLogger.log('🔄 Received 403, attempting token refresh...', tag: 'HTTP');
          final refreshed = await refreshTokenOn403();
          if (refreshed) {
            // Update headers with new token
            final newToken = await getAuthToken();
            if (newToken != null && newToken.isNotEmpty &&
                !newToken.startsWith('Bearer ')) {
              headers['Authorization'] = 'Bearer $newToken';
            } else if (newToken != null && newToken.isNotEmpty) {
              headers['Authorization'] = newToken;
            }
            attempt++;
            if (attempt < maxRetries) {
              continue;
            }
          }
        }
        
        return response;
      } on SocketException catch (e) {
        lastException = e;
        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: (_baseRetryDelay.inMilliseconds * (1 << attempt)).clamp(0, 5000)
          );
          AppLogger.log(
            '⚠️ Network error (attempt ${attempt + 1}/$maxRetries): $e. Retrying in ${delay.inMilliseconds}ms...',
            tag: 'HTTP'
          );
          await Future.delayed(delay);
          attempt++;
        } else {
          break;
        }
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: (_baseRetryDelay.inMilliseconds * (1 << attempt)).clamp(0, 5000)
          );
          AppLogger.log(
            '⏱️ Timeout (attempt ${attempt + 1}/$maxRetries): $e. Retrying in ${delay.inMilliseconds}ms...',
            tag: 'HTTP'
          );
          await Future.delayed(delay);
          attempt++;
        } else {
          break;
        }
      } on http.ClientException catch (e) {
        lastException = e;
        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: (_baseRetryDelay.inMilliseconds * (1 << attempt)).clamp(0, 5000)
          );
          AppLogger.log(
            '⚠️ Client error (attempt ${attempt + 1}/$maxRetries): $e. Retrying in ${delay.inMilliseconds}ms...',
            tag: 'HTTP'
          );
          await Future.delayed(delay);
          attempt++;
        } else {
          break;
        }
      } catch (e) {
        // Don't retry for other errors (4xx, 5xx status codes other than 403)
        rethrow;
      }
    }
    
    AppLogger.log('❌ Request failed after $maxRetries attempts: $lastException', tag: 'HTTP');
    throw lastException ?? Exception('Request failed after $maxRetries attempts');
  }
  
  /// Cancel a pending request
  void cancelRequest(String urlString) {
    final completer = _activeRequests.remove(urlString);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception('Request cancelled'));
      AppLogger.log('🚫 Cancelled request: $urlString', tag: 'HTTP');
    }
  }
  
  /// Cancel all pending requests
  void cancelAllRequests() {
    final count = _activeRequests.length;
    for (final completer in _activeRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('All requests cancelled'));
      }
    }
    _activeRequests.clear();
    AppLogger.log('🚫 Cancelled $count pending requests', tag: 'HTTP');
  }
  
  /// GET request with caching, retry, timeout, and connection pooling support
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    CacheStrategy? cacheStrategy,
    Duration? customTTL,
    bool useCache = true,
    bool forceRefresh = false,
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
  }) async {
    final urlString = url.toString();
    final startTime = DateTime.now();
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? (enableRetry ? _maxRetries : 0);
    
    // Check for pending duplicate request
    if (useCache && !forceRefresh) {
      final pendingRequest = _cacheService.getPendingRequest(urlString, headers);
      if (pendingRequest != null) {
        AppLogger.log('⏳ Request deduplication: Waiting for pending request to: $urlString', tag: 'HTTP');
        try {
          final cachedData = await pendingRequest;
          // Return a mock response with cached data
          return http.Response(jsonEncode(cachedData), 200);
        } catch (e) {
          AppLogger.log('Pending request failed, proceeding with new request: $e', tag: 'HTTP');
        }
      }
      
      // Check cache first
      if (!forceRefresh) {
        final cachedData = await _cacheService.getCached(
          urlString,
          headers,
          strategy: cacheStrategy,
          customTTL: customTTL,
        );
        
        if (cachedData != null) {
          AppLogger.log('✅ Cache HIT - Returning cached data for: $urlString', tag: 'HTTP');
          return http.Response(jsonEncode(cachedData), 200, headers: {
            'X-Cache': 'HIT',
            'X-Cache-Source': 'memory',
          });
        }
      }
    }
    
    // Interceptor: Log request
    _logRequest('GET', url, headers: headers);
    
    // Create request future with timeout and retry
    Future<http.Response> requestFuture = _retryRequest(
      () async {
        // Check if request was cancelled
        if (_activeRequests.containsKey(urlString)) {
          throw Exception('Request cancelled');
        }
        
        // Make HTTP request with timeout
        final response = await _makeHttpRequest(url, headers).timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException('Request timeout after ${effectiveTimeout.inSeconds}s', effectiveTimeout);
          },
        );
        
        // Interceptor: Log response
        _logResponse(response, url, duration: DateTime.now().difference(startTime));
        
        return response;
      },
      effectiveMaxRetries,
      urlString,
      headers!,
    );
    
    // Register for deduplication (convert Response to Map for deduplication tracking)
    if (useCache) {
      _cacheService.registerPendingRequest(
        urlString,
        headers,
        requestFuture.then((response) {
          if (response.statusCode == 200) {
            return jsonDecode(response.body) as Map<String, dynamic>;
          }
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }),
      );
    }
    
    try {
      final response = await requestFuture;
      
      // Cache successful responses (200 OK)
      if (useCache && response.statusCode == 200) {
        final responseBody = response.body;
        
        // Only cache JSON responses
        try {
          final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
          
          // Determine if we should save to persistent cache
          final shouldSavePersistent = cacheStrategy == CacheStrategy.vendor ||
                                      cacheStrategy == CacheStrategy.settings ||
                                      cacheStrategy == CacheStrategy.custom ||
                                      (cacheStrategy == null && 
                                       (urlString.contains('/restaurant/vendors/') ||
                                        urlString.contains('/settings')));
          
          await _cacheService.saveCache(
            urlString,
            headers,
            responseBody,
            strategy: cacheStrategy,
            customTTL: customTTL,
            saveToPersistent: shouldSavePersistent,
          );
          
          AppLogger.log('💾 Cached response for: $urlString', tag: 'HTTP');
        } catch (e) {
          AppLogger.log('Response is not JSON, skipping cache: $e', tag: 'HTTP');
        }
      }
      
      return response;
    } catch (e) {
      AppLogger.log('❌ HTTP request failed: $e', tag: 'HTTP');
      rethrow;
    } finally {
      // Clean up request tracking
      _activeRequests.remove(urlString);
    }
  }
  
  /// Internal method to make HTTP request using optimized client
  Future<http.Response> _makeHttpRequest(
    Uri url,
    Map<String, String>? headers,
  ) async {
    // Use optimized client with connection pooling
    return await _httpClient.get(url, headers: headers);
  }
  
  /// POST request with retry, timeout, and connection pooling support
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool useDeduplication = true,
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
  }) async {
    final urlString = url.toString();
    final startTime = DateTime.now();
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? (enableRetry ? _maxRetries : 0);
    
    // Check for pending duplicate request
    if (useDeduplication) {
      final pendingRequest = _cacheService.getPendingRequest(urlString, headers);
      if (pendingRequest != null) {
        AppLogger.log('⏳ Request deduplication: Waiting for pending POST request to: $urlString', tag: 'HTTP');
        try {
          final cachedData = await pendingRequest;
          return http.Response(jsonEncode(cachedData), 200);
        } catch (e) {
          AppLogger.log('Pending request failed, proceeding with new request: $e', tag: 'HTTP');
        }
      }
    }
    
    // Interceptor: Log request
    _logRequest('POST', url, headers: headers);
    
    // Make request with retry and timeout
    final response = await _retryRequest(
      () async {
        final response = await _httpClient.post(
          url,
          headers: headers,
          body: body,
          encoding: encoding,
        ).timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException('Request timeout after ${effectiveTimeout.inSeconds}s', effectiveTimeout);
          },
        );
        
        // Interceptor: Log response
        _logResponse(response, url, duration: DateTime.now().difference(startTime));
        
        return response;
      },
      effectiveMaxRetries,
      urlString,
      headers!,
    );
    
    // Register for deduplication (even though we don't cache POST responses)
    if (useDeduplication && response.statusCode == 200) {
      try {
        _cacheService.registerPendingRequest(
          urlString,
          headers,
          Future.value(jsonDecode(response.body) as Map<String, dynamic>),
        );
      } catch (e) {
        // Response is not JSON, skip deduplication registration
        AppLogger.log('POST response is not JSON, skipping deduplication: $e', tag: 'HTTP');
      }
    }
    
    return response;
  }
  
  /// Dispose resources (close HTTP client)
  void dispose() {
    cancelAllRequests();
    _httpClient.close();
    AppLogger.log('🔄 HTTP Client disposed', tag: 'HTTP');
  }
  
  /// Invalidate cache for a URL pattern
  Future<void> invalidateCache(String urlPattern) async {
    await _cacheService.invalidateCache(urlPattern);
  }
  
  /// Clear all caches
  Future<void> clearAllCache() async {
    await _cacheService.clearAllCache();
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _cacheService.getCacheStats();
  }
}
