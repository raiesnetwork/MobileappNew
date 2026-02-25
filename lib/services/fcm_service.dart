import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'api_service.dart';

class FcmService {
  static Future<void> saveFcmToken() async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      debugPrint('📲 FCM Token: $fcmToken');

      await ApiService.post(
        '/api/mobile/user/save-fcm',
        {
          'fcmToken': fcmToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
        requireAuth: true,
      );

      debugPrint('✅ FCM token saved to backend');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  static void listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      try {
        await ApiService.post(
          '/api/mobile/user/save-fcm',
          {
            'fcmToken': newToken,
            'platform': Platform.isAndroid ? 'android' : 'ios',
          },
          requireAuth: true,
        );
      } catch (e) {
        debugPrint('❌ Error updating refreshed FCM token: $e');
      }
    });
  }


}