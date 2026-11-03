

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jippydriver_driver/firebase_options.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_player_service.dart' show AudioPlayerService;

// This MUST be a top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("📱 Background FCM received: ${message.messageId}");
  log("📱 Message data: ${message.data}");
  log("📱 Message notification: ${message.notification?.title} - ${message.notification?.body}");
  // Initialize Firebase and services in background isolate
  // Background handler runs in separate isolate, so we need to initialize Firebase here
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Preferences.initPref();
  // Do NOT call AudioPlayerService here: it runs in this isolate, while the UI
  // isolate's stop() on Accept/Reject cannot stop that playback (rings "forever").
  // Alert sound comes from the local notification channel (order_ringtone raw).
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInitializationSettings = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: iosInitializationSettings);
  
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(initializationSettings);

  // CRITICAL: Create notification channel before showing notification
  const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
    'background_order_channel',
    'Background Order Notifications',
    description: 'Order notifications when app is in background',
    importance: Importance.max, // MAX importance for better visibility
    playSound: true,
    sound: RawResourceAndroidNotificationSound('order_ringtone'),
  );
  final androidImplementation = localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(backgroundChannel);
    log("✅ Background notification channel created");
  }

  // Show local notification with sound (handles both notification and data-only messages)
  await NotificationService().displayBackgroundNotification(message, localNotifications);
}

class NotificationService {
  // Best-effort local de-dupe window to avoid double-display from
  // overlapping FCM handlers (system + app local notification paths).
  static final Map<String, DateTime> _recentNotificationKeys = {};
  static const Duration _dedupeWindow = Duration(seconds: 6);

  static String _buildMessageKey(RemoteMessage message) {
    final id = message.messageId?.trim() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    final title = message.notification?.title ?? message.data['title'] ?? '';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    return 'payload:${title.toString().trim()}|${body.toString().trim()}|${jsonEncode(message.data)}';
  }

  static bool _shouldDisplayLocalNotification(RemoteMessage message) {
    final now = DateTime.now();
    _recentNotificationKeys.removeWhere(
      (_, time) => now.difference(time) > _dedupeWindow,
    );
    final key = _buildMessageKey(message);
    final last = _recentNotificationKeys[key];
    if (last != null && now.difference(last) <= _dedupeWindow) {
      log("⏭️ Duplicate notification suppressed: $key");
      return false;
    }
    _recentNotificationKeys[key] = now;
    return true;
  }

  // Special method for background notifications
  Future<void> displayBackgroundNotification(RemoteMessage message, FlutterLocalNotificationsPlugin? localNotifications) async {
    try {
      // For notification payloads in background/terminated states, Android/iOS
      // can already display the push. Only force local display for data-only.
      if (message.notification != null) {
        log("ℹ️ Skipping manual background display (notification payload already present).");
        return;
      }
      if (!_shouldDisplayLocalNotification(message)) return;

      final plugin = localNotifications ?? flutterLocalNotificationsPlugin;
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'background_order_channel',
        'Background Order Notifications',
        description: 'Order notifications when app is in background',
        importance: Importance.max, // MAX importance for better visibility
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_ringtone'),
      );

      AndroidNotificationDetails notificationDetails =
      AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max, // MAX for critical notifications
        priority: Priority.max, // Changed to MAX priority
        playSound: true,
        sound: channel.sound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([1000, 1000, 1000, 1000]),
        timeoutAfter: 30000, // 30 seconds
        fullScreenIntent: false, // Set to true if you want heads-up notification
        ongoing: false,
        autoCancel: true,
        showWhen: true,
      );

      const DarwinNotificationDetails darwinNotificationDetails =
      DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true);

      NotificationDetails notificationDetailsBoth = NotificationDetails(
          android: notificationDetails,
          iOS: darwinNotificationDetails);
      // Use data from message if available, otherwise use defaults
      final title = message.notification?.title ?? 
                    message.data['title'] ?? 
                    'New Order';
      final body = message.notification?.body ?? 
                   message.data['body'] ?? 
                   'You have a new order';

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );

      log("✅ Background notification displayed: $title - $body");
    } catch (e) {
      log("❌ Background notification error: $e");
    }
  }
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  initInfo() async {
    try {
      // Request Firebase messaging permissions (iOS/macOS)
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      var request = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      log("📱 Firebase permission status: ${request.authorizationStatus}");

      // Request Android 13+ POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final granted = await androidImplementation.requestNotificationsPermission();
          log("📱 Android notification permission granted: $granted");
        }
      }

      // Keep the FCM token in sync — persist refreshed tokens to Firestore so
      // push notifications keep reaching this device.
      _listenForTokenRefresh();

      if (request.authorizationStatus == AuthorizationStatus.authorized ||
          request.authorizationStatus == AuthorizationStatus.provisional) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        var iosInitializationSettings = const DarwinInitializationSettings();
        final InitializationSettings initializationSettings =
            InitializationSettings(
                android: initializationSettingsAndroid,
                iOS: iosInitializationSettings);
        await flutterLocalNotificationsPlugin.initialize(initializationSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {
          log("📱 Notification tapped: ${response.payload}");
          unawaited(AudioPlayerService.playSound(false));
        });
        
        // CRITICAL: Create notification channels before using them
        await _createNotificationChannels();
        
        setupInteractedMessage();
      } else {
        log("❌ Notification permission not granted: ${request.authorizationStatus}");
      }
    } catch (e) {
      log("❌ Error initializing notifications: $e");
    }
  }

  // Listen for FCM token rotations and persist the new token so notifications
  // keep being delivered to this device.
  StreamSubscription<String>? _tokenRefreshSub;

  void _listenForTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      final newToken = token.trim();
      if (newToken.isEmpty) return;
      log("🔄 FCM token refreshed: $newToken");
      try {
        final prefs = await SharedPreferences.getInstance();
        final firebaseId =
            (prefs.getString('firebase_id') ?? prefs.getString('userId') ?? '')
                .trim();
        if (firebaseId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseId)
              .set(<String, dynamic>{'fcmToken': newToken},
                  SetOptions(merge: true));
        }
      } catch (e) {
        log("❌ Failed to persist refreshed FCM token: $e");
      }
    });
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    // Create foreground channel (this matches the default channel in AndroidManifest.xml)
    const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
      'order_channel',
      'goRide-customer',
      description: 'Show QuickLAI Notification',
      importance: Importance.max, // MAX importance for critical notifications
      playSound: true,
      sound: RawResourceAndroidNotificationSound('order_ringtone'),
    );

    // Create background channel (used by background handler for data-only messages)
    const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
      'background_order_channel',
      'Background Order Notifications',
      description: 'Order notifications when app is in background',
      importance: Importance.max, // Changed to MAX for better visibility
      playSound: true,
      sound: RawResourceAndroidNotificationSound('order_ringtone'),
    );

    // Create channels on Android
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(foregroundChannel);
      await androidImplementation.createNotificationChannel(backgroundChannel);
      log("✅ Notification channels created successfully");
      log("   - Foreground channel: order_channel (importance: max)");
      log("   - Background channel: background_order_channel (importance: max)");
    }
  }

  Future<void> setupInteractedMessage() async {
    // Handle initial message (when app is opened from terminated state via notification)
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      log("::::::::::::Initial message received:::::::::::::::::");
      log(initialMessage.notification.toString());
      unawaited(AudioPlayerService.playSound(false));
    }

    // Handle foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log("::::::::::::onMessage (Foreground):::::::::::::::::");
      log("Message data: ${message.data}");
      log("Message notification: ${message.notification?.title} - ${message.notification?.body}");
      
      // Display notification even if it's a data-only message
      if (message.notification != null || message.data.isNotEmpty) {
        display(message);
      }
    });
    
    // Handle messages when app is opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      log("::::::::::::onMessageOpenedApp:::::::::::::::::");
      await AudioPlayerService.playSound(false);
      if (message.notification != null) {
        log(message.notification.toString());
      }
    });
    
    log("::::::::::::Permission authorized:::::::::::::::::");
    await FirebaseMessaging.instance.subscribeToTopic("driver");
  }

  static getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        log("getToken timeout - returning empty string");
        return null;
      });
      return token ?? '';
    } catch (e) {
      log("getToken error: $e - returning empty string");
      return '';
    }
  }

  void display(RemoteMessage message) async {
    log('Got a message whilst in the foreground!');
    log('Message data: ${message.data}');
    log('Message notification: ${message.notification?.title} - ${message.notification?.body}');
    try {
      if (!_shouldDisplayLocalNotification(message)) return;

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'order_channel',
        'goRide-customer',
        description: 'Show QuickLAI Notification',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('order_ringtone'),
      );
      AndroidNotificationDetails notificationDetails =
          AndroidNotificationDetails(
            channel.id, 
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'ticker',
            playSound: true,
            sound: channel.sound,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([1000, 1000, 1000, 1000]),
          );
      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: true);
      NotificationDetails notificationDetailsBoth = NotificationDetails(
          android: notificationDetails, iOS: darwinNotificationDetails);
      
      // Extract title and body from notification or data payload
      final title = message.notification?.title ?? 
                    message.data['title'] ?? 
                    'New Order';
      final body = message.notification?.body ?? 
                   message.data['body'] ?? 
                   message.data['message'] ??
                   'You have a new order';
      
      // CRITICAL: Use the existing plugin instance, not a new one
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
      log("✅ Foreground notification displayed: $title - $body");
    } catch (e) {
      log("❌ Foreground notification error: $e");
    }
  }
}




// import 'dart:convert';
// import 'dart:developer';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
//   log("BackGround Message :: ${message.messageId}");
// }
//
// class NotificationService {
//   FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   initInfo() async {
//     await FirebaseMessaging.instance
//         .setForegroundNotificationPresentationOptions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//     var request = await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       announcement: false,
//       badge: true,
//       carPlay: false,
//       criticalAlert: false,
//       provisional: false,
//       sound: true,
//     );
//
//     if (request.authorizationStatus == AuthorizationStatus.authorized ||
//         request.authorizationStatus == AuthorizationStatus.provisional) {
//       const AndroidInitializationSettings initializationSettingsAndroid =
//           AndroidInitializationSettings('@mipmap/ic_launcher');
//       var iosInitializationSettings = const DarwinInitializationSettings();
//       final InitializationSettings initializationSettings =
//           InitializationSettings(
//               android: initializationSettingsAndroid,
//               iOS: iosInitializationSettings);
//       await flutterLocalNotificationsPlugin.initialize(initializationSettings,
//           onDidReceiveNotificationResponse: (payload) {});
//       setupInteractedMessage();
//     }
//   }
//
//   Future<void> setupInteractedMessage() async {
//     RemoteMessage? initialMessage =
//         await FirebaseMessaging.instance.getInitialMessage();
//     if (initialMessage != null) {
//       FirebaseMessaging.onBackgroundMessage(
//           (message) => firebaseMessageBackgroundHandle(message));
//     }
//
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//       log("::::::::::::onMessage:::::::::::::::::");
//       if (message.notification != null) {
//         log(message.notification.toString());
//         display(message);
//       }
//     });
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
//       log("::::::::::::onMessageOpenedApp:::::::::::::::::");
//       if (message.notification != null) {
//         log(message.notification.toString());
//       }
//     });
//     log("::::::::::::Permission authorized:::::::::::::::::");
//     await FirebaseMessaging.instance.subscribeToTopic("driver");
//   }
//
//   static getToken() async {
//     try {
//       String? token = await FirebaseMessaging.instance.getToken()
//           .timeout(const Duration(seconds: 10), onTimeout: () {
//         log("getToken timeout - returning empty string");
//         return null;
//       });
//       return token ?? '';
//     } catch (e) {
//       log("getToken error: $e - returning empty string");
//       return '';
//     }
//   }
//
//   void display(RemoteMessage message) async {
//     log('Got a message whilst in the foreground!');
//     log('Message data: ${message.notification?.body.toString() ?? ''}');
//     try {
//       AndroidNotificationChannel channel = const AndroidNotificationChannel(
//         'order_channel',
//         'goRide-customer',
//         description: 'Show QuickLAI Notification',
//         importance: Importance.max,
//         sound: RawResourceAndroidNotificationSound('order_ringtone'), // Add this
//       );
//       AndroidNotificationDetails notificationDetails =
//           AndroidNotificationDetails(channel.id, channel.name,
//               channelDescription: 'your channel Description',
//               importance: Importance.high,
//               priority: Priority.high,
//               ticker: 'ticker',
//             sound: channel.sound, // Use channel sound);
//           );
//       const DarwinNotificationDetails darwinNotificationDetails =
//           DarwinNotificationDetails(
//               presentAlert: true, presentBadge: true, presentSound: true);
//       NotificationDetails notificationDetailsBoth = NotificationDetails(
//           android: notificationDetails, iOS: darwinNotificationDetails);
//       await FlutterLocalNotificationsPlugin().show(
//         0,
//         message.notification?.title ?? 'Notification',
//         message.notification?.body ?? '',
//         notificationDetailsBoth,
//         payload: jsonEncode(message.data),
//       );
//     } on Exception catch (e) {
//       log(e.toString());
//     }
//   }
// }
