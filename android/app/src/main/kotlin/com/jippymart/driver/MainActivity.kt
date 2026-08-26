package com.jippymart.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the main notification channel
            val channelId = "order_channel"
            val channelName = "Order Notifications"

            // For Android 8.0+, you need to use resource URI format
            val soundUri = Uri.parse("android.resource://${packageName}/raw/order_ringtone")

            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            channel.setSound(soundUri, attributes)
            channel.enableVibration(true)
            channel.vibrationPattern = longArrayOf(1000, 1000, 1000, 1000)
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)

            // Also create a high priority channel for background notifications
            val backgroundChannel = NotificationChannel(
                "background_order_channel",
                "Background Order Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            backgroundChannel.setSound(soundUri, attributes)
            backgroundChannel.enableVibration(true)
            backgroundChannel.vibrationPattern = longArrayOf(1000, 1000, 1000, 1000)
            backgroundChannel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            manager.createNotificationChannel(backgroundChannel)
        }
    }
}

////package com.jippymart.driver
////
////import io.flutter.embedding.android.FlutterActivity
////
////class MainActivity : FlutterActivity()
//package com.jippymart.driver
//
//import android.content.ContentValues
//import android.graphics.Bitmap
//import android.graphics.BitmapFactory
//import android.os.Bundle
//import android.provider.MediaStore
//import io.flutter.embedding.android.FlutterFragmentActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//import java.io.File
//import java.io.OutputStream
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.media.AudioAttributes
//import android.net.Uri
//import android.os.Build
//
//class MainActivity : FlutterFragmentActivity() {
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        createNotificationChannel()
//    }
//
//    private fun createNotificationChannel() {
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//            val channelId = "order_channel"
//            val channelName = "Order Notifications"
//            val soundUri = Uri.parse("android.resource://${packageName}/raw/order_ringtone")
//
//            val attributes = AudioAttributes.Builder()
//                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
//                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
//                .build()
//
//            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
//            channel.setSound(soundUri, attributes)
//
//            val manager = getSystemService(NotificationManager::class.java)
//            manager.createNotificationChannel(channel)
//        }
//    }
//}