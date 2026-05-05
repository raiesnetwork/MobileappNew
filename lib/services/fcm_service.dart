import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'api_service.dart';

class FcmService {
  // ════════════════════════════════════════════════════════════════════════
  //  FCM TOKEN MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════

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
  // ROOT CAUSE OF WRONG-USER RECEIVING CALLS:
  // One physical device has ONE FCM token. When UserA logs out and UserB logs in,
  // the server still has UserA → <FCMtoken> mapping. When someone calls UserA,
  // the FCM push goes to the device's token → UserB sees it.
  //
  // FIX: On logout, call clearFcmToken() BEFORE clearing auth so the token
  // is removed from the current user. On login, saveFcmToken() re-registers.
  // Backend must also remove the token from any old user when a new user saves it.
  // ============================================================================
  static Future<void> clearFcmToken() async {
    try {
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      debugPrint('🗑️ [FCM] Clearing token for logged-out user...');

      // Strategy 1: dedicated remove endpoint
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

      // Strategy 2: overwrite with empty token
      if (!cleared) {
        try {
          await ApiService.post(
            '/api/mobile/user/save-fcm',
            {
              'fcmToken': '',
              'platform': Platform.isAndroid ? 'android' : 'ios',
            },
            requireAuth: true,
          );
          debugPrint('✅ [FCM] Token cleared via empty-token save');
        } catch (e) {
          debugPrint('⚠️ [FCM] Could not clear token: $e');
        }
      }

      // Always end any active CallKit calls on logout
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

  // ════════════════════════════════════════════════════════════════════════
  //  CALL VALIDITY CHECK
  //
  //  PROBLEM: When the caller cancels/ends the call before the receiver
  //  picks up, the FCM notification is already delivered (FCM can't be
  //  recalled). The receiver's device shows the incoming call UI even
  //  though the call no longer exists on the server.
  //
  //  FIX: Before showing the CallKit UI, ask the server "is this call
  //  still active?". If not → immediately end the CallKit call silently.
  //
  //  Your backend needs one endpoint:
  //    GET /api/call/status?roomName=<roomName>
  //    Response: { "active": true/false, "callerId": "...", "callerName": "..." }
  //
  //  If you don't have this endpoint yet, add it — it's a simple lookup
  //  in your active-calls map/redis that your socket server already maintains.
  // ════════════════════════════════════════════════════════════════════════

  /// Returns true if the call with [roomName] is still active on the server.
  /// Returns false if the caller already cancelled/ended the call.
  static Future<bool> isCallStillActive(String roomName) async {
    try {
      debugPrint('🔍 [FCM] Checking call validity for room: $roomName');

      final response = await ApiService.get(
        '/api/call/status?roomName=$roomName',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final isActive = body['active'] == true;
        debugPrint('📞 [FCM] Call active: $isActive for room: $roomName');
        return isActive;
      }

      // If endpoint doesn't exist yet (404) → assume active to avoid
      // silently dropping real calls. Add the endpoint ASAP.
      if (response.statusCode == 404) {
        debugPrint('⚠️ [FCM] /api/call/status not found — assuming active. '
            'Add this endpoint to prevent ghost calls!');
        return true;
      }

      return false;
    } catch (e) {
      // Network error → assume active (better to show a ghost call
      // than to miss a real one)
      debugPrint('⚠️ [FCM] Could not check call status: $e — assuming active');
      return true;
    }
  }

  /// Call this from your FCM message handler BEFORE showing CallKit UI.
  ///
  /// Usage in your background/foreground FCM handler:
  ///
  ///   final shouldShow = await FcmService.handleIncomingCallNotification(
  ///     message: message,
  ///     onShowCall: (callerId, callerName, roomName, callType) async {
  ///       // show your CallKit / incoming call screen here
  ///     },
  ///   );
  ///
  static Future<void> handleIncomingCallNotification({
    required RemoteMessage message,
    required Future<void> Function({
    required String callerId,
    required String callerName,
    required String roomName,
    required String callType,
    }) onShowCall,
  }) async {
    try {
      final data = message.data;

      // Only process call notifications
      final notifType = data['type']?.toString() ?? '';
      final isCallNotif = notifType == 'video_call' ||
          notifType == 'voice_call' ||
          notifType == 'incoming_call' ||
          data['roomName'] != null;

      if (!isCallNotif) return;

      final roomName   = data['roomName']?.toString()   ?? '';
      final callerId   = data['callerId']?.toString()   ?? '';
      final callerName = data['callerName']?.toString() ?? 'Unknown';
      final callType   = data['callType']?.toString()   ?? data['type']?.toString() ?? 'voice';

      if (roomName.isEmpty || callerId.isEmpty) {
        debugPrint('⚠️ [FCM] Invalid call notification — missing roomName or callerId');
        return;
      }

      debugPrint('📲 [FCM] Incoming call notification — '
          'room: $roomName | caller: $callerName ($callerId) | type: $callType');

      // ── KEY FIX: check if the call is still active ──────────────────
      // Add a small delay so the cancellation socket event has time
      // to reach the server before we check
      await Future.delayed(const Duration(milliseconds: 800));

      final isActive = await isCallStillActive(roomName);

      if (!isActive) {
        debugPrint('🚫 [FCM] Call was cancelled before receiver could answer — '
            'suppressing CallKit UI for room: $roomName');

        // Make sure no ghost CallKit call is showing
        try {
          await FlutterCallkitIncoming.endAllCalls();
        } catch (_) {}

        return; // ← do NOT show the incoming call UI
      }

      // Call is still active — show the incoming call UI
      debugPrint('✅ [FCM] Call is active — showing incoming call UI');
      await onShowCall(
        callerId:   callerId,
        callerName: callerName,
        roomName:   roomName,
        callType:   callType,
      );
    } catch (e) {
      debugPrint('❌ [FCM] handleIncomingCallNotification error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  UNKNOWN CALLER FIX
  //
  //  "Unknown user" in CallKit happens because the FCM data payload
  //  has callerName missing or empty when the notification arrives
  //  while the app is in background/terminated (Firebase uses the
  //  data fields, not notification fields, for custom handling).
  //
  //  Make sure your backend sends the FCM payload like this:
  //
  //  {
  //    "to": "<fcmToken>",
  //    "priority": "high",
  //    "data": {
  //      "type": "video_call",           ← or "voice_call"
  //      "roomName": "room-12345",
  //      "callerId": "<userId>",
  //      "callerName": "John Doe",       ← MUST be set, not null/empty
  //      "callerAvatar": "https://...",  ← optional
  //      "callType": "video"             ← "video" or "voice"
  //    }
  //    // Do NOT include a "notification" key — it will show a system
  //    // notification AND trigger the background handler, causing duplicates.
  //  }
  //
  //  This utility safely extracts the caller name with fallbacks.
  // ════════════════════════════════════════════════════════════════════════

  /// Safely extracts caller info from an FCM data payload.
  /// Returns sensible fallbacks so the UI never shows "Unknown".
  static ({
  String callerId,
  String callerName,
  String callerAvatar,
  String roomName,
  String callType,
  }) extractCallData(Map<String, dynamic> data) {
    final callerId = data['callerId']?.toString().trim() ?? '';

    // callerName fallback chain: callerName → senderName → callerUsername → "Incoming Call"
    final callerName = [
      data['callerName'],
      data['senderName'],
      data['callerUsername'],
      data['name'],
    ].map((v) => v?.toString().trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null)
        ?? 'Incoming Call';

    final callerAvatar = data['callerAvatar']?.toString().trim() ??
        data['callerPhoto']?.toString().trim() ??
        data['avatar']?.toString().trim() ??
        '';

    final roomName = data['roomName']?.toString().trim() ?? '';

    final callType = data['callType']?.toString().trim() ??
        (data['type']?.toString().contains('video') == true ? 'video' : 'voice');

    debugPrint('📦 [FCM] Extracted call data — '
        'callerId: $callerId | callerName: $callerName | '
        'roomName: $roomName | callType: $callType');

    return (
    callerId:    callerId,
    callerName:  callerName,
    callerAvatar: callerAvatar,
    roomName:    roomName,
    callType:    callType,
    );
  }
}