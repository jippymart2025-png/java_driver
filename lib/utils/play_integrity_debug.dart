// import 'dart:developer';
//
// class PlayIntegrityDebug {
//   static bool _debugEnabled = true; // Set to false to disable all debug prints
//
//   /// Enable or disable debug prints
//   static void setDebugEnabled(bool enabled) {
//     _debugEnabled = enabled;
//     print('🔐 [Play Integrity Debug] Debug prints ${enabled ? "enabled" : "disabled"}');
//   }
//
//   /// Check if debug is enabled
//   static bool get isDebugEnabled => _debugEnabled;
//
//   /// Print debug message with prefix
//   static void print(String message) {
//     if (_debugEnabled) {
//       print('🔐 [Play Integrity Debug] $message');
//     }
//   }
//
//   /// Print error message
//   static void printError(String message, [dynamic error]) {
//     if (_debugEnabled) {
//       print('🔐 [Play Integrity Debug] ❌ ERROR: $message');
//       if (error != null) {
//         print('🔐 [Play Integrity Debug] Error details: $error');
//         print('🔐 [Play Integrity Debug] Error type: ${error.runtimeType}');
//       }
//     }
//   }
//
//   /// Print success message
//   static void printSuccess(String message) {
//     if (_debugEnabled) {
//       print('🔐 [Play Integrity Debug] ✅ SUCCESS: $message');
//     }
//   }
//
//   /// Print warning message
//   static void printWarning(String message) {
//     if (_debugEnabled) {
//       print('🔐 [Play Integrity Debug] ⚠️ WARNING: $message');
//     }
//   }
//
//   /// Print info message
//   static void printInfo(String message) {
//     if (_debugEnabled) {
//       print('🔐 [Play Integrity Debug] ℹ️ INFO: $message');
//     }
//   }
//
//   /// Log to developer console
//   static void log(String message) {
//     if (_debugEnabled) {
//       log('Play Integrity Debug: $message');
//     }
//   }
//
//   /// Print current debug status
//   static void printDebugStatus() {
//     print('🔐 [Play Integrity Debug] Current debug status: ${_debugEnabled ? "ENABLED" : "DISABLED"}');
//   }
//
//   /// Print all debug settings
//   static void printAllSettings() {
//     print('🔐 [Play Integrity Debug] === DEBUG SETTINGS ===');
//     print('🔐 [Play Integrity Debug] Debug enabled: $_debugEnabled');
//     print('🔐 [Play Integrity Debug] ======================');
//   }
// }