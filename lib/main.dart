// ════════════════════════════════════════════════════════════════════════
// main.dart  —  ZERO CallKit. Pure FCM + flutter_local_notifications.
//
// HOW IT WORKS:
//   App KILLED   → FCM background handler shows local notification
//                  User taps → getInitialMessage → IncomingCallScreen
//   App BG       → FCM background handler shows local notification
//                  User taps → onMessageOpenedApp → IncomingCallScreen
//   App FG       → onMessage fires → navigate directly (no tap needed)
//
// BACKEND must send FCM with BOTH notification + data:
//   {
//     "notification": { "title": "Abhi", "body": "Incoming Voice Call" },
//     "data": {
//       "type":       "voice_call",   ← or "video_call"
//       "roomName":   "room_123",
//       "callerId":   "user_1",
//       "callerName": "Abhi"
//     },
//     "android": { "priority": "high" }
//   }
// ════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'package:ixes.app/screens/widgets/video_call.dart';
import 'package:ixes.app/screens/widgets/voice_call.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:ixes.app/services/meeting_overlay_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/BottomNaviagation.dart';
import 'utils/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════
// GLOBAL KEYS & INSTANCES
// ════════════════════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _localNotif =
FlutterLocalNotificationsPlugin();

// High-importance channel → shows as full heads-up banner with sound
const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'incoming_calls',
  'Incoming Calls',
  description: 'Incoming voice and video calls',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// ════════════════════════════════════════════════════════════════════════
// GLOBAL CALL STATE
// ════════════════════════════════════════════════════════════════════════
Map<String, String>? _pendingCallData;
String? _dispatchedRoomName;
DateTime? _pendingCallDispatchedAt;
const Duration _callTTL = Duration(seconds: 30);

final StreamController<Map<String, String>> _callStream =
StreamController<Map<String, String>>.broadcast();

void _dispatchCall(Map<String, String> data) {
  final roomName = data['roomName'] ?? '';
  if (roomName.isNotEmpty && roomName == _dispatchedRoomName) {
    debugPrint('⚠️ _dispatchCall IGNORED — duplicate: $roomName');
    return;
  }
  debugPrint('🚀 _dispatchCall | type=${data['callType']} | room=$roomName');
  _dispatchedRoomName      = roomName;
  _pendingCallData         = data;
  _pendingCallDispatchedAt = DateTime.now();
  _callStream.add(data);
}

void _clearCallState() {
  _pendingCallData         = null;
  _dispatchedRoomName      = null;
  _pendingCallDispatchedAt = null;
}

// ════════════════════════════════════════════════════════════════════════
// BACKGROUND FCM HANDLER
// ════════════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 [BG] FCM received: ${message.data}');

  final data = message.data;
  final type = data['type'] ?? '';

  if (type == 'voice_call' || type == 'video_call') {
    await _showCallNotificationFromIsolate(data);
  }
}

// ════════════════════════════════════════════════════════════════════════
// SHOW CALL NOTIFICATION FROM ISOLATE
// ════════════════════════════════════════════════════════════════════════
Future<void> _showCallNotificationFromIsolate(
    Map<String, dynamic> data) async {
  final plugin = FlutterLocalNotificationsPlugin();

  await plugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_callChannel);

  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  final callerName = data['callerName'] ?? 'Unknown';
  final isVideo    = data['type'] == 'video_call';
  final roomName   = data['roomName'] ?? '';

  await plugin.show(
    roomName.hashCode,
    callerName,
    isVideo
        ? 'Incoming Video Call — Tap to answer'
        : 'Incoming Voice Call — Tap to answer',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _callChannel.id,
        _callChannel.name,
        channelDescription: _callChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload:
    '${data['type']}|${data['roomName']}|${data['callerId']}|${data['callerName']}',
  );
}

// ════════════════════════════════════════════════════════════════════════
// INIT LOCAL NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════
Future<void> _initLocalNotifications() async {
  await _localNotif
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_callChannel);

  await _localNotif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse res) {
      debugPrint('🔔 Notification tapped (fg/bg): ${res.payload}');
      _handleNotificationPayload(res.payload);
    },
    onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
  );

  final launchDetails =
  await _localNotif.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    debugPrint('🔔 App launched from notification tap');
    _handleNotificationPayload(
        launchDetails!.notificationResponse?.payload);
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse res) {
  debugPrint('🔔 Background notification tapped: ${res.payload}');
  _handleNotificationPayload(res.payload);
}

void _handleNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  final p = payload.split('|');
  if (p.length < 4) return;
  _dispatchCall({
    'callType':   p[0],
    'roomName':   p[1],
    'callerId':   p[2],
    'callerName': p[3],
  });
}

// ════════════════════════════════════════════════════════════════════════
// SHOW LOCAL NOTIFICATION FROM MAIN ISOLATE (foreground FCM)
// ════════════════════════════════════════════════════════════════════════
Future<void> _showCallNotification(Map<String, dynamic> data) async {
  final callerName = data['callerName'] ?? 'Unknown';
  final isVideo    = data['type'] == 'video_call';
  final roomName   = data['roomName'] ?? '';
  final callerId   = data['callerId'] ?? '';
  final callType   = data['type'] ?? 'voice_call';

  await _localNotif.show(
    roomName.hashCode,
    callerName,
    isVideo
        ? 'Incoming Video Call — Tap to answer'
        : 'Incoming Voice Call — Tap to answer',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _callChannel.id,
        _callChannel.name,
        channelDescription: _callChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: '$callType|$roomName|$callerId|$callerName',
  );
}

// ════════════════════════════════════════════════════════════════════════
// SAVE FCM TOKEN TO BACKEND
// ════════════════════════════════════════════════════════════════════════
Future<void> _saveFcmToken() async {
  try {
    final prefs     = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null || authToken.isEmpty) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;

    await ApiService.post(
      '/api/mobile/user/save-fcm',
      {
        'fcmToken': fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      },
      requireAuth: true,
    );
    debugPrint('✅ FCM token saved');
  } catch (e) {
    debugPrint('❌ _saveFcmToken: $e');
  }
}

// ════════════════════════════════════════════════════════════════════════
// INIT FCM
// ════════════════════════════════════════════════════════════════════════
Future<void> _initFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    final token = await messaging.getToken();
    debugPrint('🔥 FCM token: ${token?.substring(0, 20)}...');

    messaging.onTokenRefresh.listen((_) => _saveFcmToken());

    // ── SCENARIO 1: App KILLED → user tapped notification ──────────
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      final d = initial.data;
      debugPrint('📬 [KILLED→TAP] $d');
      if (d['type'] == 'voice_call' || d['type'] == 'video_call') {
        _dispatchCall({
          'callType':   d['type']       ?? '',
          'roomName':   d['roomName']   ?? '',
          'callerId':   d['callerId']   ?? '',
          'callerName': d['callerName'] ?? '',
        });
      }
    }

    // ── SCENARIO 2: App BACKGROUND → user tapped notification ──────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final d = msg.data;
      debugPrint('📬 [BG→TAP] $d');
      if (d['type'] == 'voice_call' || d['type'] == 'video_call') {
        _dispatchCall({
          'callType':   d['type']       ?? '',
          'roomName':   d['roomName']   ?? '',
          'callerId':   d['callerId']   ?? '',
          'callerName': d['callerName'] ?? '',
        });
      }
    });

    // ── SCENARIO 3: App FOREGROUND → FCM arrives ───────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final d = msg.data;
      debugPrint('📬 [FG] $d');
      if (d['type'] == 'voice_call' || d['type'] == 'video_call') {
        _showCallNotification(d);
        _dispatchCall({
          'callType':   d['type']       ?? '',
          'roomName':   d['roomName']   ?? '',
          'callerId':   d['callerId']   ?? '',
          'callerName': d['callerName'] ?? '',
        });
      } else if (d['type'] == 'call_cancelled' || d['type'] == 'call_ended') {
        // Handled inside the app by the providers/socket — no nav needed here
        debugPrint('📵 [FG] call_cancelled/ended received via FCM');
      }
    });
  } catch (e) {
    debugPrint('❌ _initFCM: $e');
  }
}

// ════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await _initLocalNotifications();
  await _initFCM();

  final prefs  = await SharedPreferences.getInstance();
  final token  = prefs.getString('auth_token');
  final userId = prefs.getString('user_id');
  debugPrint('🔑 Token: ${token != null} | 👤 User: $userId');

  runApp(IxesApp(initialToken: token, initialUserId: userId));
}

// ════════════════════════════════════════════════════════════════════════
// ROOT APP
// ════════════════════════════════════════════════════════════════════════
class IxesApp extends StatelessWidget {
  final String? initialToken;
  final String? initialUserId;
  const IxesApp({super.key, this.initialToken, this.initialUserId});

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
        ],
        child: AppWithLifecycleObserver(
          initialToken: initialToken,
          initialUserId: initialUserId,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// APP WITH LIFECYCLE OBSERVER
// ════════════════════════════════════════════════════════════════════════
class AppWithLifecycleObserver extends StatefulWidget {
  final String? initialToken;
  final String? initialUserId;
  const AppWithLifecycleObserver({
    super.key, this.initialToken, this.initialUserId,
  });

  @override
  State<AppWithLifecycleObserver> createState() =>
      _AppWithLifecycleObserverState();
}

class _AppWithLifecycleObserverState extends State<AppWithLifecycleObserver>
    with WidgetsBindingObserver {

  StreamSubscription<Map<String, String>>? _callSub;
  bool _providersReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _callSub = _callStream.stream.listen((data) {
      debugPrint('📡 _callStream | providersReady=$_providersReady');
      if (_providersReady && mounted) {
        if (_isCallExpired()) {
          debugPrint('⏰ Call expired — discarding');
          _clearCallState();
          return;
        }
        _pendingCallData    = null;
        _dispatchedRoomName = null;
        _navigate(data);
      }
      // else: buffered in _pendingCallData, consumed by _consumePending()
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_providersReady && mounted) _consumePending();
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try { MeetingOverlayService().dispose(); } catch (_) {}
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  // ✅ FIX: _navigate — sets provider state ONLY, listeners handle nav
  //
  // OLD CODE was calling nav.push(IncomingCallScreen()) here AND
  // setIncomingCallFromFCM which set state → ringing, which triggered
  // the listeners to push a SECOND screen → double screen → black screen.
  // ──────────────────────────────────────────────────────────────────
  void _navigate(Map<String, String> data) {
    if (!mounted) return;

    final roomName   = data['roomName']   ?? '';
    final callType   = data['callType']   ?? '';
    final callerId   = data['callerId']   ?? '';
    final callerName = data['callerName'] ?? '';

    debugPrint('🎯 _navigate | type=$callType | room=$roomName | caller=$callerName');

    if (roomName.isEmpty || callType.isEmpty) {
      debugPrint('⚠️ _navigate: missing data — abort');
      return;
    }

    if (!_providersReady) {
      debugPrint('⚠️ _navigate: providers not ready — pending');
      _pendingCallData = data;
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ _navigate: nav not ready — pending');
      _pendingCallData = data;
      return;
    }

    // ✅ Only set provider state → ringing.
    // VoiceCallListener / IncomingCallListener see the ringing state
    // and push the screen themselves. No manual nav.push() here.
    if (callType == 'video_call') {
      debugPrint('📲 _navigate: setting VideoCallProvider → ringing');
      context.read<VideoCallProvider>().setIncomingCallFromFCM(
        roomName: roomName,
        callerId: callerId,
        callerName: callerName,
        acceptedViaCallKit: false,
      );
    } else {
      debugPrint('📲 _navigate: setting VoiceCallProvider → ringing');
      context.read<VoiceCallProvider>().setIncomingCallFromFCM(
        roomName: roomName,
        callerId: callerId,
        callerName: callerName,
        acceptedViaCallKit: false,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // ✅ FIX: _handleCallCancelled — dismiss notification only.
  //
  // OLD CODE called popUntil(isFirst) which nuked the entire nav stack
  // → black screen. Now we call cancelIncomingCall() on the provider
  // which sets state → ended, and the incoming screens pop themselves.
  // ──────────────────────────────────────────────────────────────────
  Future<void> _handleCallCancelled(Map<String, dynamic> data) async {
    final roomName = data['roomName'] ?? '';
    debugPrint('📵 Call cancelled — room: $roomName');
    _clearCallState();

    // Dismiss local notification
    try {
      await _localNotif.cancel(roomName.hashCode);
    } catch (_) {}

    // ✅ Set ended state on the active provider.
    // IncomingCallScreen / IncomingVoiceCallDialog listen for ended
    // and call _safePop() themselves — no nav needed here.
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final videoProvider = ctx.read<VideoCallProvider>();
    final voiceProvider = ctx.read<VoiceCallProvider>();

    if (videoProvider.callState == CallState.ringing ||
        videoProvider.callState == CallState.calling) {
      debugPrint('📵 cancelIncomingCall → VideoCallProvider');
      videoProvider.cancelIncomingCall();
    }

    if (voiceProvider.callState == VoiceCallState.ringing ||
        voiceProvider.callState == VoiceCallState.calling) {
      debugPrint('📵 cancelIncomingCall → VoiceCallProvider');
      voiceProvider.cancelIncomingCall();
    }
  }

  bool _isCallExpired() {
    final at = _pendingCallDispatchedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > _callTTL;
  }

  void _consumePending() {
    final data = _pendingCallData;
    if (data == null) return;
    if (_isCallExpired()) {
      debugPrint('⏰ _consumePending: expired — discard');
      _clearCallState();
      return;
    }
    debugPrint('🔔 _consumePending: navigating');
    _pendingCallData    = null;
    _dispatchedRoomName = null;
    _navigate(data);
  }

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
          if (chat.currentReceiverId != null) {
            chat.fetchConversation(chat.currentReceiverId!);
          }
          if (_providersReady) _consumePending();
          break;
        case AppLifecycleState.detached:
          chat.cleanup();
          try { MeetingOverlayService().hideOverlay(); } catch (_) {}
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('❌ lifecycle: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      final auth = ctx.watch<AuthProvider>();

      if (!auth.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ctx.read<AuthProvider>().loadUserFromStorage();
        });
        return _buildApp(home: const SplashScreen());
      }

      if (auth.isAuthenticated && auth.user != null) {
        final user = auth.user!;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || _providersReady) return;

          final name = user.username.isNotEmpty
              ? user.username
              : 'User_${user.mobile.substring(user.mobile.length - 4)}';

          try {
            await ctx.read<PersonalChatProvider>().initialize();
            ctx.read<VideoCallProvider>().initialize(
              userId: user.id, userName: name, authToken: widget.initialToken,
            );
            ctx.read<VoiceCallProvider>().initialize(
              userId: user.id, userName: name, authToken: widget.initialToken,
            );
            ctx.read<MeetingProvider>().initialize(
              userId: user.id, userName: name, authToken: widget.initialToken,
            );
            await _saveFcmToken();

            _providersReady = true;
            debugPrint('✅ Providers ready');

            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) _consumePending();
          } catch (e) {
            debugPrint('❌ Provider init: $e');
          }
        });
      }

      return _buildApp(
        home: auth.isAuthenticated
            ? VoiceCallListener(
          child: IncomingCallListener(

            child: const MainScreen(initialIndex: 0),
          ),
        )
            : const SplashScreen(),
      );
    });
  }

  Widget _buildApp({required Widget home}) {
    return MaterialApp(
      title: 'Ixes',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: home,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => VoiceCallListener(
          child: IncomingCallListener(
            child: const MainScreen(initialIndex: 0),
          ),
        ),
      },
    );
  }
}