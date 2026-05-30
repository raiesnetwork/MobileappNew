import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/providers/attendance_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/providers/announcement_provider.dart';
import 'package:ixes.app/providers/campaign_provider.dart';
import 'package:ixes.app/providers/chat_provider.dart';
import 'package:ixes.app/providers/comment_provider.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:ixes.app/providers/coupon_provider.dart';
import 'package:ixes.app/providers/dash_board_provider.dart';
import 'package:ixes.app/providers/generate_link_provider.dart';
import 'package:ixes.app/providers/group_provider.dart';
import 'package:ixes.app/providers/meeting_provider.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:ixes.app/providers/personal_chat_provider.dart';
import 'package:ixes.app/providers/profile_provider.dart';
import 'package:ixes.app/providers/service_provider.dart';
import 'package:ixes.app/providers/service_request_provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';
import 'package:ixes.app/screens/auth/launguage_selection_page.dart';
import 'package:ixes.app/screens/chats_page/chat_detail_screen.dart';
import 'package:ixes.app/screens/chats_page/group_chat/group_chat_detail.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:ixes.app/screens/voice_call/voice_call_room_screen.dart';
import 'package:ixes.app/screens/widgets/video_call.dart';
import 'package:ixes.app/screens/widgets/voice_call.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:ixes.app/services/deep_linking_service.dart';
import 'package:ixes.app/services/meeting_overlay_service.dart';
import 'package:ixes.app/services/socket_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';
import 'app_localisations.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/BottomNaviagation.dart';
import 'utils/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// File-scope call state
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic>? _pendingCallData;
String?   _dispatchedRoomName;
DateTime? _pendingCallDispatchedAt;
const Duration _callTTL = Duration(seconds: 90);

void _storePendingCall(Map<String, dynamic> data) {
  _pendingCallData         = data;
  _pendingCallDispatchedAt = DateTime.now();
  _dispatchedRoomName      = data['roomName'] ?? '';
  debugPrint('💾 [PENDING] Stored | type=${data['callType']} | room=${data['roomName']}');
}

void _clearCallState() {
  _pendingCallData         = null;
  _dispatchedRoomName      = null;
  _pendingCallDispatchedAt = null;
  debugPrint('🧹 [CALL STATE] Cleared');
}

bool _isCallExpired() {
  final at = _pendingCallDispatchedAt;
  if (at == null) return false;
  return DateTime.now().difference(at) > _callTTL;
}

final StreamController<Map<String, dynamic>> _callStream =
StreamController<Map<String, dynamic>>.broadcast();

// ─────────────────────────────────────────────────────────────────────────────
// File-scope pending PERSONAL chat state
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic>? _pendingChatData;

void _storePendingChat(Map<String, dynamic> data) {
  _pendingChatData = data;
  debugPrint('💾 [PENDING CHAT] Stored | senderId=${data['senderId']} | senderName=${data['senderName']}');
}

void _clearChatState() {
  _pendingChatData = null;
  debugPrint('🧹 [CHAT STATE] Cleared');
}

// ─────────────────────────────────────────────────────────────────────────────
// File-scope pending GROUP chat state
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic>? _pendingGroupData;

void _storePendingGroup(Map<String, dynamic> data) {
  _pendingGroupData = data;
  debugPrint('💾 [PENDING GROUP] Stored | groupId=${data['groupId']} | groupName=${data['groupName']}');
}

void _clearGroupState() {
  _pendingGroupData = null;
  debugPrint('🧹 [GROUP STATE] Cleared');
}

// ─────────────────────────────────────────────────────────────────────────────
// CallKit UI helper
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showCallkitIncoming({
  required String roomName,
  required String callerId,
  required String callerName,
  required String callType,
}) async {
  final callUUID = _uuid.v4();
  await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
    id:          callUUID,
    nameCaller:  callerName,
    appName:     'Ixes',
    avatar:      null,
    handle:      callerId,
    type:        callType == 'video_call' ? 1 : 0,
    textAccept:  'Accept',
    textDecline: 'Decline',
    missedCallNotification: const NotificationParams(
      showNotification: true,
      isShowCallback:   false,
      subtitle:         'Missed call',
    ),
    duration: 30000,
    extra: <String, dynamic>{
      'roomName':   roomName,
      'callerId':   callerId,
      'callerName': callerName,
      'callType':   callType,
    },
    android: const AndroidParams(
      isCustomNotification:                true,
      isShowLogo:                          false,
      ringtonePath:                        'system_ringtone_default',
      backgroundColor:                     '#0D0D14',
      backgroundUrl:                       null,
      actionColor:                         '#4CAF50',
      textColor:                           '#ffffff',
      incomingCallNotificationChannelName: 'Incoming Calls',
      missedCallNotificationChannelName:   'Missed Calls',
      isShowCallID:                        false,
    ),
    ios: const IOSParams(
      iconName:                              'AppIcon',
      handleType:                            'generic',
      supportsVideo:                         true,
      maximumCallGroups:                     1,
      maximumCallsPerCallGroup:              1,
      audioSessionMode:                      'default',
      audioSessionActive:                    true,
      audioSessionPreferredSampleRate:       44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF:       true,
      supportsHolding:    true,
      supportsGrouping:   false,
      supportsUngrouping: false,
      ringtonePath:       'system_ringtone_default',
    ),
  ));
  debugPrint('✅ [CALLKIT UI] Shown | room=$roomName | uuid=$callUUID');
}

// ─────────────────────────────────────────────────────────────────────────────
// FCM background handler
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final type = data['type'] ?? '';

  debugPrint('🔔 [BG FCM] type=$type | roomName=${data['roomName']}');

  if (type == 'voice_call' || type == 'video_call') {
    final roomName   = data['roomName']   ?? '';
    final callerId   = data['callerId']   ?? '';
    final callerName = data['callerName'] ?? 'Incoming Call';

    if (roomName.isEmpty || callerId.isEmpty) {
      debugPrint('⚠️ [BG FCM] Missing roomName or callerId — skipping');
      return;
    }

    debugPrint('📲 [BG FCM] Showing CallKit | caller=$callerName | room=$roomName');
    await _showCallkitIncoming(
      roomName:   roomName,
      callerId:   callerId,
      callerName: callerName,
      callType:   type,
    );
  }
  // Chat and GroupChat notifications: system notification shown automatically
  // by FCM — no manual handling needed in background handler.
}

// ─────────────────────────────────────────────────────────────────────────────
// FCM token helper
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _saveFcmToken() async {
  try {
    final authToken = await ApiService.getValidToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint('⚠️ [FCM] No valid auth token — skipping FCM save');
      return;
    }
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    debugPrint('📱 [FCM] Saving token for userId=$userId');
    await ApiService.post(
      '/api/mobile/user/save-fcm',
      {'fcmToken': fcmToken, 'platform': Platform.isAndroid ? 'android' : 'ios'},
      requireAuth: true,
    );
    debugPrint('✅ [FCM TOKEN] Saved for userId=$userId');
  } catch (e) {
    debugPrint('❌ [FCM TOKEN] $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigate to ChatDetailScreen from FCM tap
// ─────────────────────────────────────────────────────────────────────────────

void _navigateToChat({
  required String senderId,
  required String senderName,
  required String conversationId,
}) {
  final nav = navigatorKey.currentState;
  final ctx = navigatorKey.currentContext;

  if (nav == null || ctx == null) {
    debugPrint('⚠️ [CHAT NAV] Navigator not ready — storing pending');
    _storePendingChat({
      'senderId':       senderId,
      'senderName':     senderName,
      'conversationId': conversationId,
    });
    return;
  }

  debugPrint('💬 [CHAT NAV] Navigating to ChatDetailScreen | sender=$senderName');

  nav.pushNamedAndRemoveUntil('/main', (route) => false);

  Future.delayed(const Duration(milliseconds: 400), () {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userId:      senderId,
          chatTitle:   senderName,
          userProfile: {
            '_id': senderId,
            'profile': {
              'name':         senderName,
              'profileImage': '',
            },
          },
        ),
      ),
    );
    _clearChatState();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigate to GroupChatDetailPage from FCM tap
// ─────────────────────────────────────────────────────────────────────────────

void _navigateToGroup({
  required String groupId,
  required String groupName,
}) {
  final nav = navigatorKey.currentState;
  final ctx = navigatorKey.currentContext;

  if (nav == null || ctx == null) {
    debugPrint('⚠️ [GROUP NAV] Navigator not ready — storing pending');
    _storePendingGroup({
      'groupId':   groupId,
      'groupName': groupName,
    });
    return;
  }

  debugPrint('💬 [GROUP NAV] Navigating to GroupChatDetailPage | group=$groupName');

  nav.pushNamedAndRemoveUntil('/main', (route) => false);

  Future.delayed(const Duration(milliseconds: 400), () {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => GroupChatDetailPage(
          groupId:   groupId,
          groupName: groupName,
          isAdmin:   false,
        ),
      ),
    );
    _clearGroupState();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FCM init — handles all 3 app states for calls, personal chat, group chat
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _initFCM() async {
  try {
    // ── Listen for call intents from native Kotlin ──────────────────────────
    const _callChannel = MethodChannel('com.ixes.app/calls');
    _callChannel.setMethodCallHandler((call) async {
      if (call.method == 'incomingCall') {
        final args       = Map<String, dynamic>.from(call.arguments as Map);
        final type       = args['type']?.toString()       ?? '';
        final roomName   = args['roomName']?.toString()   ?? '';
        final callerId   = args['callerId']?.toString()   ?? '';
        final callerName = args['callerName']?.toString() ?? 'Incoming Call';

        debugPrint('📲 [NATIVE→FLUTTER] type=$type | room=$roomName | caller=$callerName');

        if (roomName.isNotEmpty && callerId.isNotEmpty) {
          final ctx = navigatorKey.currentContext;
          bool socketHandled = false;
          if (ctx != null) {
            try {
              final vcState = ctx.read<VideoCallProvider>().callState;
              final vState  = ctx.read<VoiceCallProvider>().callState;
              socketHandled = vcState == CallState.ringing ||
                  vState == VoiceCallState.ringing;
            } catch (_) {}
          }
          if (!socketHandled) {
            await _showCallkitIncoming(
              roomName:   roomName,
              callerId:   callerId,
              callerName: callerName,
              callType:   type,
            );
          }
        }
      }
    });

    // ── App opened from KILLED state via notification tap ───────────────────
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final d    = initialMessage.data;
      final type = d['type'] ?? '';

      // Call
      if (type == 'voice_call' || type == 'video_call') {
        final roomName   = d['roomName']   ?? '';
        final callerId   = d['callerId']   ?? '';
        final callerName = d['callerName'] ?? 'Incoming Call';
        if (roomName.isNotEmpty && callerId.isNotEmpty) {
          debugPrint('📲 [FCM INITIAL] Killed state call tap | type=$type');
          await _showCallkitIncoming(
            roomName:   roomName,
            callerId:   callerId,
            callerName: callerName,
            callType:   type,
          );
        }
      }

      // Personal chat — killed state
      if (type == 'chat') {
        final senderId       = d['senderId']       ?? '';
        final senderName     = d['senderName']     ?? 'Chat';
        final conversationId = d['conversationId'] ?? '';
        if (senderId.isNotEmpty) {
          debugPrint('💬 [FCM INITIAL] Personal chat tap from killed state | sender=$senderName');
          _storePendingChat({
            'senderId':       senderId,
            'senderName':     senderName,
            'conversationId': conversationId,
          });
        }
      }

      // Group chat — killed state
      if (type == 'GroupChat') {
        final groupId   = d['groupId']   ?? '';
        final groupName = d['groupName'] ?? 'Group';
        if (groupId.isNotEmpty) {
          debugPrint('💬 [FCM INITIAL] Group chat tap from killed state | group=$groupName');
          _storePendingGroup({
            'groupId':   groupId,
            'groupName': groupName,
          });
        }
      }
    }

    // ── App foregrounded from BACKGROUND via notification tap ───────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
      // ✅ ADD THESE DEBUG LINES
      debugPrint('📦 [FCM OPENED] Full data: ${msg.data}');
      debugPrint('📦 [FCM OPENED] Notification title: ${msg.notification?.title}');
      debugPrint('📦 [FCM OPENED] Notification body: ${msg.notification?.body}');
      final d    = msg.data;
      final type = d['type'] ?? '';

      // Call
      if (type == 'voice_call' || type == 'video_call') {
        final roomName   = d['roomName']   ?? '';
        final callerId   = d['callerId']   ?? '';
        final callerName = d['callerName'] ?? 'Incoming Call';
        if (roomName.isNotEmpty && callerId.isNotEmpty) {
          debugPrint('📲 [FCM OPENED] Background call tap | type=$type');
          await Future.delayed(const Duration(milliseconds: 500));
          final ctx = navigatorKey.currentContext;
          bool socketHandled = false;
          if (ctx != null) {
            try {
              final vcState = ctx.read<VideoCallProvider>().callState;
              final vState  = ctx.read<VoiceCallProvider>().callState;
              socketHandled = vcState == CallState.ringing ||
                  vState == VoiceCallState.ringing;
            } catch (_) {}
          }
          if (!socketHandled) {
            await _showCallkitIncoming(
              roomName:   roomName,
              callerId:   callerId,
              callerName: callerName,
              callType:   type,
            );
          }
        }
      }

      // Personal chat — background state
      if (type == 'chat') {
        final senderId       = d['senderId']       ?? '';
        final senderName     = d['senderName']     ?? 'Chat';
        final conversationId = d['conversationId'] ?? '';
        if (senderId.isNotEmpty) {
          debugPrint('💬 [FCM OPENED] Personal chat tap from background | sender=$senderName');
          await Future.delayed(const Duration(milliseconds: 500));
          _navigateToChat(
            senderId:       senderId,
            senderName:     senderName,
            conversationId: conversationId,
          );
        }
      }

      // Group chat — background state
      if (type == 'GroupChat') {
        final groupId   = d['groupId']   ?? '';
        final groupName = d['groupName'] ?? 'Group';
        if (groupId.isNotEmpty) {
          debugPrint('💬 [FCM OPENED] Group chat tap from background | group=$groupName');
          await Future.delayed(const Duration(milliseconds: 500));
          _navigateToGroup(
            groupId:   groupId,
            groupName: groupName,
          );
        }
      }
    });

    // ── App FOREGROUND — onMessage ──────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    await messaging.getToken();
    messaging.onTokenRefresh.listen((_) => _saveFcmToken());

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final d    = msg.data;
      final type = d['type'] ?? '';

      // ✅ ADD THESE DEBUG LINES
      debugPrint('📦 [FCM FOREGROUND] Full data: ${msg.data}');
      debugPrint('📦 [FCM FOREGROUND] Notification title: ${msg.notification?.title}');
      debugPrint('📦 [FCM FOREGROUND] Notification body: ${msg.notification?.body}');
      debugPrint('📦 [FCM FOREGROUND] type=$type');

      if (type == 'voice_call' || type == 'video_call') {
        await Future.delayed(const Duration(milliseconds: 800));

        final ctx = navigatorKey.currentContext;
        bool socketHandled = false;
        if (ctx != null) {
          try {
            final vcState = ctx.read<VideoCallProvider>().callState;
            final vState  = ctx.read<VoiceCallProvider>().callState;
            socketHandled = vcState == CallState.ringing ||
                vState == VoiceCallState.ringing;
          } catch (_) {}
        }

        if (socketHandled) {
          debugPrint('✅ [FG FCM] Socket handled — skipping CallKit');
          return;
        }

        debugPrint('⚠️ [FG FCM] Socket missed after 800ms — showing CallKit');
        await _showCallkitIncoming(
          roomName:   d['roomName']   ?? '',
          callerId:   d['callerId']   ?? '',
          callerName: d['callerName'] ?? 'Unknown',
          callType:   type,
        );
      }

      // chat and GroupChat foreground messages handled by socket — no action needed
    });
  } catch (e) {
    debugPrint('❌ [FCM INIT] $e');
  }
}


Future<void> _checkActiveCallsOnStartup() async {
  try {
    final calls = await FlutterCallkitIncoming.activeCalls();
    if (calls == null || calls.isEmpty) return;

    final call  = calls.last;
    final extra = call['extra'] as Map<dynamic, dynamic>? ??
        call['Extra'] as Map<dynamic, dynamic>? ??
        {};

    final roomName   = extra['roomName']?.toString()   ?? call['roomName']?.toString()   ?? '';
    final callerId   = extra['callerId']?.toString()   ?? call['callerId']?.toString()   ?? call['handle']?.toString()    ?? '';
    final callerName = extra['callerName']?.toString() ?? call['callerName']?.toString() ?? call['nameCaller']?.toString() ?? 'Unknown';
    final callType   = extra['callType']?.toString()   ?? call['callType']?.toString()   ?? 'voice_call';

    if (roomName.isEmpty || callerId.isEmpty) {
      debugPrint('⚠️ [STARTUP] Active call missing roomName/callerId — skipping');
      return;
    }

    _storePendingCall({
      'callType':   callType,
      'roomName':   roomName,
      'callerId':   callerId,
      'callerName': callerName,
      'autoAccept': true,
    });
    debugPrint('✅ [STARTUP] Stored pending call from activeCalls()');
  } catch (e) {
    debugPrint('❌ [STARTUP] activeCalls() error: $e');
  }
}


void main() async {
  // Catch all uncaught async errors (including SocketException)
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // Silence specific noisy exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      final ex = details.exception.toString();
      if (ex.contains('Reading from a closed socket') ||
          ex.contains('SocketException')) {
        // swallow — known noise from socket.io polling reconnects
        return;
      }
      FlutterError.presentError(details);
    };

    print('\n');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🚀 APP STARTED');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _initFCM();
    await _checkActiveCallsOnStartup();

    final prefs    = await SharedPreferences.getInstance();
    final token    = prefs.getString('auth_token');
    final userId   = prefs.getString('user_id');
    final language = prefs.getString('app_language');

    print('🔐 authToken exists = ${token != null}');
    print('👤 userId = $userId');

    runApp(IxesApp(
      initialToken:  token,
      initialUserId: userId,
      showLanguage:  language == null,
    ));
  }, (error, stack) {
    // Catches errors that escape the Flutter error handler
    final msg = error.toString();
    if (msg.contains('Reading from a closed socket') ||
        msg.contains('SocketException')) {
      // swallow silently
      return;
    }
    print('💥 Uncaught zone error: $error');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────

class IxesApp extends StatelessWidget {
  final String? initialToken;
  final String? initialUserId;
  final bool    showLanguage;

  const IxesApp({
    super.key,
    this.initialToken,
    this.initialUserId,
    this.showLanguage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (_, __, ___) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => PostProvider()),
          ChangeNotifierProvider(create: (_) => CommentProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ServicesProvider()),
          ChangeNotifierProvider(create: (_) => CommunityProvider()),
          ChangeNotifierProvider(create: (_) => CampaignProvider()),
          ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
          ChangeNotifierProvider(create: (_) => ServiceRequestProvider()),
          ChangeNotifierProvider(create: (_) => CouponProvider()),
          ChangeNotifierProvider(create: (_) => PersonalChatProvider()),
          ChangeNotifierProvider(create: (_) => GroupChatProvider()),
          ChangeNotifierProvider(create: (_) => VideoCallProvider()),
          ChangeNotifierProvider(create: (_) => MeetProvider()),
          ChangeNotifierProvider(create: (_) => MeetingProvider()),
          ChangeNotifierProvider(create: (_) => VoiceCallProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => MeetingOverlayService()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ],
        child: AppWithLifecycleObserver(
          initialToken:  initialToken,
          initialUserId: initialUserId,
          showLanguage:  showLanguage,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connecting splash
// ─────────────────────────────────────────────────────────────────────────────

class _CallConnectingSplash extends StatelessWidget {
  final String callerName;
  final String callType;

  const _CallConnectingSplash({
    required this.callerName,
    required this.callType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [
              Color.fromARGB(165, 55, 0, 255),
              Color.fromARGB(70, 179, 154, 219),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(Images.LogoTrans, height: 100),
              const SizedBox(height: 56),
              Container(
                width:  110,
                height: 110,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  color:  Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: Center(
                  child: Text(
                    callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  callerName,
                  textAlign: TextAlign.center,
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                callType == 'video_call'
                    ? 'Connecting video call...'
                    : 'Connecting voice call...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppWithLifecycleObserver
// ─────────────────────────────────────────────────────────────────────────────

class AppWithLifecycleObserver extends StatefulWidget {
  final String? initialToken;
  final String? initialUserId;
  final bool    showLanguage;

  const AppWithLifecycleObserver({
    super.key,
    this.initialToken,
    this.initialUserId,
    this.showLanguage = false,
  });

  @override
  State<AppWithLifecycleObserver> createState() =>
      _AppWithLifecycleObserverState();
}

class _AppWithLifecycleObserverState extends State<AppWithLifecycleObserver>
    with WidgetsBindingObserver {

  StreamSubscription<Map<String, dynamic>>? _callSub;
  StreamSubscription? _socketReadySub;

  bool    _providersReady = false;
  bool    _initStarted    = false;
  Timer?  _retryTimer;
  String? _lastInitUserId;

  final Set<String> _handledRoomNames = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    DeepLinkService.init();
    WidgetsBinding.instance.addObserver(this);

    if (_pendingCallData != null) _startRetryLoop();

    _callSub = _callStream.stream.listen((data) {
      if (_providersReady && mounted) {
        if (_isCallExpired()) {
          _clearCallState();
          return;
        }
        _navigate(data);
      } else {
        _storePendingCall(data);
        _startRetryLoop();
      }
    });

    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('📲 [CALLKIT EVENT] ${event.event}');
      _handleCallKitEvent(event);
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _socketReadySub?.cancel();
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try { MeetingOverlayService().dispose(); } catch (_) {}
    super.dispose();
  }

  // ── CallKit event handler ──────────────────────────────────────────────────

  void _handleCallKitEvent(CallEvent event) {
    final body       = event.body as Map<dynamic, dynamic>? ?? {};
    final extra      = body['extra'] as Map<dynamic, dynamic>? ?? {};
    final roomName   = extra['roomName']?.toString()   ?? '';
    final callerId   = extra['callerId']?.toString()   ?? '';
    final callerName = extra['callerName']?.toString() ?? '';
    final callType   = extra['callType']?.toString()   ?? 'voice_call';

    debugPrint(
      '🎯 [CALLKIT] ${event.event} | room=$roomName | type=$callType | ready=$_providersReady',
    );

    switch (event.event) {

      case Event.actionCallIncoming:
        if (roomName.isEmpty) return;
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          _storePendingCall({
            'callType':   callType,
            'roomName':   roomName,
            'callerId':   callerId,
            'callerName': callerName,
            'autoAccept': false,
          });
          _startRetryLoop();
          return;
        }
        if (callType == 'video_call') {
          ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
            roomName:           roomName,
            callerId:           callerId,
            callerName:         callerName,
            acceptedViaCallKit: false,
          );
        } else {
          ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
            roomName:           roomName,
            callerId:           callerId,
            callerName:         callerName,
            acceptedViaCallKit: false,
          );
        }
        break;

      case Event.actionCallAccept:
        if (roomName.isEmpty) {
          debugPrint('❌ [ACCEPT] Empty roomName');
          return;
        }
        _handledRoomNames.add(roomName);

        final callData = {
          'callType':   callType,
          'roomName':   roomName,
          'callerId':   callerId,
          'callerName': callerName,
          'autoAccept': true,
        };
        if (_providersReady &&
            mounted &&
            navigatorKey.currentContext != null &&
            navigatorKey.currentState  != null) {
          _navigate(callData);
        } else {
          _storePendingCall(callData);
          _startRetryLoop();
        }
        break;

      case Event.actionCallDecline:
        _clearCallState();
        _retryTimer?.cancel();
        if (roomName.isNotEmpty) _handledRoomNames.add(roomName);
        _endAllCallKitCalls();

        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;

        _rejectCallWithReconnect(
          ctx:        ctx,
          callType:   callType,
          callerId:   callerId,
          callerName: callerName,
          roomName:   roomName,
        );
        break;

      case Event.actionCallTimeout:
      case Event.actionCallEnded:
        _clearCallState();
        _retryTimer?.cancel();
        _endAllCallKitCalls();
        _handledRoomNames.remove(roomName);

        final ctx2 = navigatorKey.currentContext;
        if (ctx2 != null) {
          if (callType == 'video_call') {
            ctx2.read<VideoCallProvider>().cancelIncomingCall();
          } else {
            ctx2.read<VoiceCallProvider>().cancelIncomingCall();
          }
        }
        break;

      default:
        break;
    }
  }

  // ── Retry loop ─────────────────────────────────────────────────────────────

  void _startRetryLoop() {
    _retryTimer?.cancel();
    int attempts = 0;

    _retryTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final data = _pendingCallData;

      if (data == null)     { timer.cancel(); return; }
      if (_isCallExpired()) { _clearCallState(); timer.cancel(); return; }
      if (attempts > 300)   { _clearCallState(); timer.cancel(); return; }
      if (!mounted)         { timer.cancel(); return; }

      if (!_providersReady ||
          navigatorKey.currentContext == null ||
          navigatorKey.currentState  == null) {
        return;
      }

      debugPrint('🚀 [RETRY #$attempts] Providers ready → navigating!');
      _pendingCallData = null;
      timer.cancel();
      _navigate(data);
    });
  }

  // ── Call navigation ────────────────────────────────────────────────────────

  Future<void> _navigate(Map<String, dynamic> data) async {
    final roomName   = data['roomName']   ?? '';
    final callType   = data['callType']   ?? '';
    final callerId   = data['callerId']   ?? '';
    final callerName = data['callerName'] ?? '';
    final autoAccept = data['autoAccept'] == true;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎯 [NAVIGATE] type=$callType | room=$roomName | auto=$autoAccept');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (roomName.isEmpty || callType.isEmpty) return;

    final ctx = navigatorKey.currentContext;
    final nav = navigatorKey.currentState;
    if (ctx == null || nav == null) {
      _storePendingCall(data);
      _startRetryLoop();
      return;
    }

    if (callType == 'video_call') {
      ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
        roomName:           roomName,
        callerId:           callerId,
        callerName:         callerName,
        acceptedViaCallKit: autoAccept,
      );
      if (autoAccept) {
        nav.push(MaterialPageRoute(
          builder: (_) => VideoCallScreen(fromFcmAutoAccept: true),
        ));
        await _endAllCallKitCalls();
      }
    } else {
      ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
        roomName:           roomName,
        callerId:           callerId,
        callerName:         callerName,
        acceptedViaCallKit: autoAccept,
      );
      if (autoAccept) {
        nav.push(MaterialPageRoute(
          builder: (_) => const VoiceRoomScreen(fromFcmAutoAccept: true),
        ));
        await _endAllCallKitCalls();
      }
    }
  }

  void _consumePending() {
    final data = _pendingCallData;
    if (data == null) return;
    if (_isCallExpired()) {
      _clearCallState();
      return;
    }
    _retryTimer?.cancel();
    _pendingCallData    = null;
    _dispatchedRoomName = null;
    _navigate(data);
  }

  // Consume pending personal chat navigation after providers are ready
  void _consumePendingChat() {
    final data = _pendingChatData;
    if (data == null) return;
    _pendingChatData = null;
    _navigateToChat(
      senderId:       data['senderId']       ?? '',
      senderName:     data['senderName']     ?? 'Chat',
      conversationId: data['conversationId'] ?? '',
    );
  }

  // Consume pending group chat navigation after providers are ready
  void _consumePendingGroup() {
    final data = _pendingGroupData;
    if (data == null) return;
    _pendingGroupData = null;
    _navigateToGroup(
      groupId:   data['groupId']   ?? '',
      groupName: data['groupName'] ?? 'Group',
    );
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) return;

      final chat = context.read<PersonalChatProvider>();

      switch (state) {
        case AppLifecycleState.resumed:
          chat.reconnectSocket();
          if (_providersReady && _pendingCallData != null) _consumePending();
          _checkActiveCallsOnResume();
          break;

        case AppLifecycleState.detached:
          chat.cleanup();
          try { MeetingOverlayService().hideOverlay(); } catch (_) {}
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('❌ [LIFECYCLE] $e');
    }
  }

  Future<void> _checkActiveCallsOnResume() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) {
        debugPrint('📵 [RESUME] No active CallKit calls');
        return;
      }

      final call  = calls.last;
      final extra = call['extra'] as Map<dynamic, dynamic>? ??
          call['Extra'] as Map<dynamic, dynamic>? ??
          {};

      final roomName   = extra['roomName']?.toString()   ?? call['roomName']?.toString()   ?? '';
      final callerId   = extra['callerId']?.toString()   ?? call['callerId']?.toString()   ?? call['handle']?.toString()    ?? '';
      final callerName = extra['callerName']?.toString() ?? call['callerName']?.toString() ?? call['nameCaller']?.toString() ?? 'Incoming Call';
      final callType   = extra['callType']?.toString()   ?? call['callType']?.toString()   ?? 'voice_call';

      if (roomName.isEmpty || callerId.isEmpty) {
        debugPrint('⚠️ [RESUME] Active call missing roomName/callerId — ending stale CallKit entry');
        await _endAllCallKitCalls();
        return;
      }

      if (_handledRoomNames.contains(roomName)) {
        debugPrint('⏭️ [RESUME] Room $roomName already handled — skipping');
        return;
      }

      if (_isCallExpired()) {
        debugPrint('⏰ [RESUME] Call expired (TTL) — ending stale CallKit | room=$roomName');
        await _endAllCallKitCalls();
        return;
      }

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      bool alreadyRinging = false;
      try {
        final vcState = ctx.read<VideoCallProvider>().callState;
        final vState  = ctx.read<VoiceCallProvider>().callState;
        alreadyRinging = vcState == CallState.ringing ||
            vState == VoiceCallState.ringing;
      } catch (_) {}

      if (alreadyRinging) {
        debugPrint('✅ [RESUME] Already ringing in-app — skipping | room=$roomName');
        _handledRoomNames.add(roomName);
        return;
      }

      _handledRoomNames.add(roomName);
      debugPrint('📲 [RESUME] Surfacing call in-app | room=$roomName | caller=$callerName | type=$callType');

      if (callType == 'video_call') {
        ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
          roomName:           roomName,
          callerId:           callerId,
          callerName:         callerName,
          acceptedViaCallKit: false,
        );
      } else {
        ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
          roomName:           roomName,
          callerId:           callerId,
          callerName:         callerName,
          acceptedViaCallKit: false,
        );
      }
    } catch (e) {
      debugPrint('❌ [RESUME] _checkActiveCallsOnResume error: $e');
    }
  }

  Future<void> _rejectCallWithReconnect({
    required BuildContext ctx,
    required String callType,
    required String callerId,
    required String callerName,
    required String roomName,
  }) async {
    try {
      if (callType == 'video_call') {
        ctx.read<VideoCallProvider>().setCallerForReject(
          callerId:   callerId,
          callerName: callerName,
          roomName:   roomName,
        );
      } else {
        ctx.read<VoiceCallProvider>().setCallerForReject(
          callerId:   callerId,
          callerName: callerName,
          roomName:   roomName,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [REJECT] setCallerForReject error: $e');
    }

    try {
      final isConnected = SocketService().socket?.connected == true;

      if (isConnected) {
        debugPrint('✅ [REJECT] Socket connected — emitting reject | room=$roomName');
        _emitReject(ctx, callType);
        return;
      }

      debugPrint('🔄 [REJECT] Socket disconnected — reconnecting | room=$roomName');
      ctx.read<PersonalChatProvider>().reconnectSocket();

      bool reconnected = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (SocketService().socket?.connected == true) {
          reconnected = true;
          break;
        }
      }

      if (reconnected) {
        debugPrint('✅ [REJECT] Socket reconnected — emitting reject | room=$roomName');
        _emitReject(ctx, callType);
      } else {
        debugPrint('⚠️ [REJECT] Reconnect timed out — REST fallback | room=$roomName');
        await _rejectViaRestApi(callerId: callerId, roomName: roomName, callType: callType);
      }
    } catch (e) {
      debugPrint('❌ [REJECT] Unexpected error ($e) — REST fallback | room=$roomName');
      await _rejectViaRestApi(callerId: callerId, roomName: roomName, callType: callType);
    }
  }

  void _emitReject(BuildContext ctx, String callType) {
    try {
      if (callType == 'video_call') {
        ctx.read<VideoCallProvider>().rejectCall();
      } else {
        ctx.read<VoiceCallProvider>().rejectVoiceCall();
      }
    } catch (e) {
      debugPrint('❌ [REJECT] emit error: $e');
    }
  }

  Future<void> _rejectViaRestApi({
    required String callerId,
    required String roomName,
    required String callType,
  }) async {
    try {
      await ApiService.post(
        '/api/call/reject',
        {'callerId': callerId, 'roomName': roomName, 'callType': callType},
        requireAuth: true,
      ).timeout(const Duration(seconds: 5));
      debugPrint('✅ [REJECT REST] Sent via API | room=$roomName');
    } on TimeoutException {
      debugPrint('⏰ [REJECT REST] Timed out after 5s | room=$roomName');
    } catch (e) {
      debugPrint('❌ [REJECT REST] API call failed: $e');
    }
  }

  Future<void> _initProviders(BuildContext ctx, dynamic user) async {
    final mobile = user.mobile as String;
    final name   = (user.username as String).isNotEmpty
        ? user.username as String
        : 'User_${mobile.substring(mobile.length - 4)}';

    await ctx.read<PersonalChatProvider>().initialize();

    final sock = SocketService().socket;
    if (sock != null) {
      ctx.read<GroupChatProvider>().setSocket(sock);
      _clearStaleCallState(sock, user.id as String);
    }

    _socketReadySub?.cancel();
    _socketReadySub = SocketService().onSocketReady.listen((s) {
      if (mounted) {
        ctx.read<GroupChatProvider>().setSocket(s);
        _clearStaleCallState(s, user.id as String);
      }
    });

    final freshPrefs = await SharedPreferences.getInstance();
    final freshToken = freshPrefs.getString('auth_token');

    ctx.read<VideoCallProvider>().initialize(
      userId:    user.id as String,
      userName:  name,
      authToken: freshToken,
    );
    ctx.read<VoiceCallProvider>().initialize(
      userId:    user.id as String,
      userName:  name,
      authToken: freshToken,
    );
    ctx.read<MeetingProvider>().initialize(
      userId:    user.id as String,
      userName:  name,
      authToken: freshToken,
    );

    await _saveFcmToken();
    ctx.read<CommentProvider>().setCurrentUserId(user.id as String? ?? '');
  }

  void _clearStaleCallState(dynamic socket, String userId) {
    try {
      socket.emit('call-rejected-voice', {
        'callerId':      userId,
        'currentUserId': userId,
        'receiverName':  '',
      });
      socket.emit('call-rejected', {
        'callerId':      userId,
        'currentUserId': userId,
        'receiverName':  '',
      });
      debugPrint('🧹 [CALL STATE] Cleared stale busy flags for userId=$userId');
    } catch (e) {
      debugPrint('❌ [CALL STATE] Failed to clear busy flags: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      final auth = ctx.watch<AuthProvider>();

      // ── Path A: cold launch via CallKit accept ──────────────────────────
      if (_pendingCallData != null &&
          _pendingCallData!['autoAccept'] == true &&
          auth.isAuthenticated &&
          auth.user != null) {

        final user = auth.user!;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (_initStarted && _lastInitUserId == user.id) return;
          _initStarted    = true;
          _providersReady = false;
          _lastInitUserId = user.id;
          try {
            await _initProviders(ctx, user);
            _providersReady = true;
            debugPrint('✅ [PROVIDER INIT / autoAccept] Done');
            if (mounted) _consumePending();
          } catch (e) {
            debugPrint('❌ [PROVIDER INIT / autoAccept] $e');
          }
        });

        return _buildApp(
          home: _CallConnectingSplash(
            callerName: _pendingCallData!['callerName'] ?? '',
            callType:   _pendingCallData!['callType']   ?? 'voice_call',
          ),
        );
      }

      // ── Path B: auth not yet loaded ─────────────────────────────────────
      if (!auth.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ctx.read<AuthProvider>().loadUserFromStorage();
        });
        return _buildApp(home: const SplashScreen());
      }

      // ── Path B.5: auth loaded, NOT authenticated — keep SplashScreen mounted
      //    so its 3-second timer can run and navigate to language/login
      if (!auth.isAuthenticated) {
        return _buildApp(home: const SplashScreen());
      }

      // ── Path C: authenticated — normal boot ─────────────────────────────
      if (auth.isAuthenticated && auth.user != null) {
        final user = auth.user!;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (_initStarted && _lastInitUserId == user.id) return;
          _initStarted    = true;
          _providersReady = false;
          _lastInitUserId = user.id;
          try {
            await _initProviders(ctx, user);
            _providersReady = true;
            debugPrint('✅ [PROVIDER INIT] Done | pendingCall=${_pendingCallData != null} | pendingChat=${_pendingChatData != null} | pendingGroup=${_pendingGroupData != null}');
            if (mounted) {
              _consumePending();       // calls
              _consumePendingChat();   // personal chat FCM tap
              _consumePendingGroup();  // group chat FCM tap
            }
          } catch (e) {
            debugPrint('❌ [PROVIDER INIT] $e');
          }
        });
      }

      // ── Path D: render home (authenticated only — unauthenticated handled at Path B.5)
      return _buildApp(
        home: VoiceCallListener(
          child: IncomingCallListener(
            child: MainScreen(key: mainScreenKey, initialIndex: 0),
          ),
        ),
      );
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _endAllCallKitCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;
      for (final call in calls) {
        final id = call['id']?.toString();
        if (id != null) await FlutterCallkitIncoming.endCall(id);
      }
    } catch (e) {
      debugPrint('❌ [CALLKIT CLEAR] $e');
    }
  }

  Widget _buildApp({required Widget home}) {
    return MaterialApp(
      title:                      'Ixes',
      theme:                      AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey:               navigatorKey,
      home:                       home,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main':  (_) => VoiceCallListener(
          child: IncomingCallListener(
            child: MainScreen(key: mainScreenKey, initialIndex: 0),
          ),
        ),
      },
    );
  }
}