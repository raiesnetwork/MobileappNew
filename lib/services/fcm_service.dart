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

  // ============================================================================
  // ✅ FIX — WRONG USER RECEIVING CALLS
  //
  // ROOT CAUSE:
  // One physical device has ONE FCM token. When UserA logs out and UserB logs in,
  // the server still has UserA → <FCMtoken> mapping. When someone calls UserA,
  // the FCM push goes to the device's token → UserB (who is logged in) sees it.
  //
  // The backend /api/mobile/user/save-fcm probably just ADDS a record without
  // removing the old user's mapping for the same token.
  //
  // FIX STRATEGY (client-side):
  // On logout → BEFORE clearing auth → call this method to tell the server
  // "remove this FCM token from current user". We pass an empty/null token
  // which the backend should interpret as "unregister this device".
  //
  // On new login → saveFcmToken() re-registers the token for the new user.
  //
  // IMPORTANT: For this to fully work, your backend must also handle the case
  // where a token already belongs to another user when saving — it should
  // REMOVE the token from the old user first. Add that logic server-side too.
  // ============================================================================
  static Future<void> clearFcmToken() async {
    try {
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      debugPrint('🗑️ [FCM] Clearing token for logged-out user...');

      // Strategy 1: Call dedicated remove endpoint if it exists
      bool cleared = false;
      try {
        await ApiService.post(
          '/api/mobile/user/remove-fcm',
          {
            'fcmToken': fcmToken,
            'platform': Platform.isAndroid ? 'android' : 'ios',
          },
          requireAuth: true,
        );
        cleared = true;
        debugPrint('✅ [FCM] Token removed via remove-fcm endpoint');
      } catch (e) {
        debugPrint('⚠️ [FCM] remove-fcm endpoint not available: $e');
      }

      // Strategy 2: Save empty token to overwrite the mapping
      if (!cleared) {
        try {
          await ApiService.post(
            '/api/mobile/user/save-fcm',
            {
              'fcmToken': '',   // empty = unregister this device from current user
              'platform': Platform.isAndroid ? 'android' : 'ios',
            },
            requireAuth: true,
          );
          debugPrint('✅ [FCM] Token cleared via empty-token save');
        } catch (e) {
          debugPrint('⚠️ [FCM] Could not clear token: $e');
        }
      }

      // Strategy 3: Also end any active callkit calls for this user
      try {
        await FlutterCallkitIncoming.endAllCalls();
        debugPrint('✅ [FCM] All CallKit calls ended on logout');
      } catch (e) {
        debugPrint('⚠️ [FCM] Could not end CallKit calls: $e');
      }
    } catch (e) {
      debugPrint('❌ [FCM] clearFcmToken error: $e');
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