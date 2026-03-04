import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
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
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:ixes.app/screens/voice_call/voice_call_room_screen.dart';
import 'package:ixes.app/screens/widgets/video_call.dart';
import 'package:ixes.app/screens/widgets/voice_call.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:ixes.app/services/meeting_overlay_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/BottomNaviagation.dart';
import 'utils/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const _uuid = Uuid();

Map<String, dynamic>? _pendingCallData;
String?   _dispatchedRoomName;
DateTime? _pendingCallDispatchedAt;
const Duration _callTTL = Duration(seconds: 30);

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
  if (at == null) return true;
  final elapsed = DateTime.now().difference(at);
  debugPrint('⏱️ [EXPIRY] elapsed=${elapsed.inSeconds}s');
  return elapsed > _callTTL;
}

final StreamController<Map<String, dynamic>> _callStream =
StreamController<Map<String, dynamic>>.broadcast();

// ════════════════════════════════════════════════════════════════════════
// SHOW CALLKIT UI
// ════════════════════════════════════════════════════════════════════════
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
      supportsDTMF:                          true,
      supportsHolding:                       true,
      supportsGrouping:                      false,
      supportsUngrouping:                    false,
      ringtonePath:                          'system_ringtone_default',
    ),
  ));
  debugPrint('✅ [CALLKIT UI] Shown | room=$roomName | uuid=$callUUID');
}

// ════════════════════════════════════════════════════════════════════════
// BACKGROUND FCM HANDLER (killed app — separate isolate)
// ════════════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final type = data['type'] ?? '';
  if (type == 'voice_call' || type == 'video_call') {
    await _showCallkitIncoming(
      roomName:   data['roomName']   ?? '',
      callerId:   data['callerId']   ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callType:   type,
    );
  }
}

Future<void> _saveFcmToken() async {
  try {
    final prefs     = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null || authToken.isEmpty) return;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;
    await ApiService.post(
      '/api/mobile/user/save-fcm',
      {'fcmToken': fcmToken, 'platform': Platform.isAndroid ? 'android' : 'ios'},
      requireAuth: true,
    );
    debugPrint('✅ [FCM TOKEN] Saved');
  } catch (e) {
    debugPrint('❌ [FCM TOKEN] $e');
  }
}

Future<void> _initFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false, badge: false, sound: false,
    );
    await messaging.getToken();
    messaging.onTokenRefresh.listen((_) => _saveFcmToken());

    // Foreground FCM (app open)
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final d = msg.data;
      if (d['type'] == 'voice_call' || d['type'] == 'video_call') {
        _showCallkitIncoming(
          roomName:   d['roomName']   ?? '',
          callerId:   d['callerId']   ?? '',
          callerName: d['callerName'] ?? 'Unknown',
          callType:   d['type']       ?? 'voice_call',
        );
        _callStream.add({
          'callType':   d['type']       ?? '',
          'roomName':   d['roomName']   ?? '',
          'callerId':   d['callerId']   ?? '',
          'callerName': d['callerName'] ?? '',
          'autoAccept': false,
        });
      }
    });
  } catch (e) {
    debugPrint('❌ [FCM INIT] $e');
  }
}

// ════════════════════════════════════════════════════════════════════════
// ✅ CHECK ACTIVE CALLS ON STARTUP
//
// This is THE critical fix for killed-app flow.
//
// When app is killed and user taps "Answer" on CallKit notification:
//   1. Android launches the app process
//   2. FlutterCallkitIncoming fires Event.actionCallAccept
//   3. Flutter engine initializes (runApp, widget tree builds)
//   4. initState() runs and registers onEvent listener
//
// Steps 2 and 4 are NOT synchronized — step 2 fires BEFORE step 4.
// The event is LOST before the listener exists.
//
// Solution: In main() (before runApp), call activeCalls() to see if
// there's already an accepted call waiting. Store it as pending.
// The retry loop in initState will then pick it up once ready.
// ════════════════════════════════════════════════════════════════════════
Future<void> _checkActiveCallsOnStartup() async {
  try {
    debugPrint('🔍 [STARTUP] Checking for active CallKit calls...');
    final calls = await FlutterCallkitIncoming.activeCalls();
    debugPrint('🔍 [STARTUP] Active calls: ${calls?.length ?? 0}');

    if (calls == null || calls.isEmpty) {
      debugPrint('ℹ️ [STARTUP] No active calls');
      return;
    }

    // Take the most recent call
    final call = calls.last;
    debugPrint('🔍 [STARTUP] Raw call data: $call');

    // Extract fields — the structure varies by platform
    String roomName   = '';
    String callerId   = '';
    String callerName = '';
    String callType   = 'voice_call';

    // Try to get extra data (where we store roomName, callType etc.)
    final extra = call['extra'] as Map<dynamic, dynamic>?
        ?? call['Extra'] as Map<dynamic, dynamic>?
        ?? {};

    roomName   = extra['roomName']?.toString()   ?? call['roomName']?.toString()   ?? '';
    callerId   = extra['callerId']?.toString()   ?? call['callerId']?.toString()   ?? call['handle']?.toString() ?? '';
    callerName = extra['callerName']?.toString() ?? call['callerName']?.toString() ?? call['nameCaller']?.toString() ?? 'Unknown';
    callType   = extra['callType']?.toString()   ?? call['callType']?.toString()   ?? 'voice_call';

    debugPrint('🔍 [STARTUP] Parsed: roomName=$roomName | callerId=$callerId | callType=$callType');

    if (roomName.isEmpty) {
      debugPrint('⚠️ [STARTUP] roomName is empty — cannot proceed');
      return;
    }

    // Store as pending with autoAccept=true (user already tapped Answer)
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

// ════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [MAIN] Starting...');

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await _initFCM();

  // ✅ Check for missed CallKit accept event BEFORE runApp
  await _checkActiveCallsOnStartup();

  final prefs  = await SharedPreferences.getInstance();
  final token  = prefs.getString('auth_token');
  final userId = prefs.getString('user_id');
  debugPrint('🔑 [MAIN] token=${token != null} | pending=${_pendingCallData != null}');

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
  const AppWithLifecycleObserver({super.key, this.initialToken, this.initialUserId});

  @override
  State<AppWithLifecycleObserver> createState() => _AppWithLifecycleObserverState();
}

class _AppWithLifecycleObserverState extends State<AppWithLifecycleObserver>
    with WidgetsBindingObserver {

  StreamSubscription<Map<String, dynamic>>? _callSub;
  bool _providersReady = false;

  // Polls every 300ms until providers + navigator both ready, then navigates
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // If _checkActiveCallsOnStartup already stored a pending call,
    // start the retry loop immediately
    if (_pendingCallData != null) {
      debugPrint('🔁 [INIT] Found pending call from startup — starting retry loop');
      _startRetryLoop();
    }

    // Foreground stream (app open, user receives call while using app)
    _callSub = _callStream.stream.listen((data) {
      debugPrint('📡 [STREAM] Foreground call | ready=$_providersReady');
      if (_providersReady && mounted) {
        if (_isCallExpired()) { _clearCallState(); return; }
        _navigate(data);
      } else {
        _storePendingCall(data);
        _startRetryLoop();
      }
    });

    // CallKit live events (app in background/recents)
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('📲 [CALLKIT EVENT] ${event.event}');
      _handleCallKitEvent(event);
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // CALLKIT EVENT HANDLER
  // ════════════════════════════════════════════════════════════════════
  void _handleCallKitEvent(CallEvent event) {
    final body  = event.body as Map<dynamic, dynamic>? ?? {};
    final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};

    final roomName   = extra['roomName']?.toString()   ?? '';
    final callerId   = extra['callerId']?.toString()   ?? '';
    final callerName = extra['callerName']?.toString() ?? '';
    final callType   = extra['callType']?.toString()   ?? 'voice_call';

    debugPrint('🎯 [CALLKIT] ${event.event} | room=$roomName | type=$callType | ready=$_providersReady');

    switch (event.event) {

      case Event.actionCallAccept:
        if (roomName.isEmpty) {
          debugPrint('❌ [ACCEPT] Empty roomName — ignoring');
          return;
        }

        final callData = {
          'callType':   callType,
          'roomName':   roomName,
          'callerId':   callerId,
          'callerName': callerName,
          'autoAccept': true,
        };

        if (_providersReady && mounted &&
            navigatorKey.currentContext != null &&
            navigatorKey.currentState != null) {
          // App was in background — everything ready, navigate now
          debugPrint('✅ [ACCEPT] Everything ready → navigating immediately');
          _navigate(callData);
        } else {
          // App was killed OR providers not ready yet
          debugPrint('⏳ [ACCEPT] Not ready → storing + retry loop');
          _storePendingCall(callData);
          _startRetryLoop();
        }
        break;

      case Event.actionCallDecline:
        _clearCallState();
        _retryTimer?.cancel();
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        if (callType == 'video_call') {
          ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
            roomName: roomName, callerId: callerId, callerName: callerName,
          );
          ctx.read<VideoCallProvider>().rejectCall();
        } else {
          ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
            roomName: roomName, callerId: callerId, callerName: callerName,
          );
          ctx.read<VoiceCallProvider>().rejectVoiceCall();
        }
        break;

      case Event.actionCallTimeout:
      case Event.actionCallEnded:
        debugPrint('📴 [CALLKIT] ${event.event} — clearing');
        _clearCallState();
        _retryTimer?.cancel();
        _endAllCallKitCalls(); // 👈 ADD THIS
        break;
        debugPrint('📴 [CALLKIT] ${event.event} — clearing');
        _clearCallState();
        _retryTimer?.cancel();
        break;

      default:
        break;

    }
  }

  // ════════════════════════════════════════════════════════════════════
  // ✅ RETRY LOOP — polls every 300ms until all 3 conditions met:
  //   1. _providersReady == true
  //   2. navigatorKey.currentContext != null
  //   3. navigatorKey.currentState != null
  //
  // This handles BOTH:
  //   A) activeCalls() found a call on startup (killed app)
  //   B) actionCallAccept fires while app is still initializing
  // ════════════════════════════════════════════════════════════════════
  void _startRetryLoop() {
    _retryTimer?.cancel();
    int attempts = 0;

    debugPrint('🔁 [RETRY] Starting retry loop | pending=${_pendingCallData?['roomName']}');

    _retryTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final data = _pendingCallData;

      if (data == null) {
        debugPrint('✅ [RETRY #$attempts] No pending call — stopping');
        timer.cancel();
        return;
      }

      if (_isCallExpired()) {
        debugPrint('⏰ [RETRY #$attempts] Expired — stopping');
        _clearCallState();
        timer.cancel();
        return;
      }

      if (attempts > 100) { // 100 × 300ms = 30s
        debugPrint('⏰ [RETRY] Max attempts — giving up');
        _clearCallState();
        timer.cancel();
        return;
      }

      if (!_providersReady) {
        debugPrint('⏳ [RETRY #$attempts] Providers not ready...');
        return;
      }

      if (navigatorKey.currentContext == null) {
        debugPrint('⏳ [RETRY #$attempts] Navigator context null...');
        return;
      }

      if (navigatorKey.currentState == null) {
        debugPrint('⏳ [RETRY #$attempts] Navigator state null...');
        return;
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      // ✅ ALL CONDITIONS MET
      debugPrint('🚀 [RETRY #$attempts] ALL READY → navigating!');
      final callData = data;
      _pendingCallData = null;
      timer.cancel();
      _navigate(callData);
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try { MeetingOverlayService().dispose(); } catch (_) {}
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // NAVIGATE — always uses navigatorKey.currentContext
  // ════════════════════════════════════════════════════════════════════
  Future<void> _navigate(Map<String, dynamic> data) async {
    final roomName   = data['roomName']   ?? '';
    final callType   = data['callType']   ?? '';
    final callerId   = data['callerId']   ?? '';
    final callerName = data['callerName'] ?? '';
    final autoAccept = data['autoAccept'] == true;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎯 [NAVIGATE] type=$callType | room=$roomName | auto=$autoAccept');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (roomName.isEmpty || callType.isEmpty) {
      debugPrint('❌ [NAVIGATE] Empty fields — abort');
      return;
    }

    final ctx = navigatorKey.currentContext;
    final nav = navigatorKey.currentState;

    if (ctx == null || nav == null) {
      // Shouldn't happen — retry loop guarantees both are non-null
      // but restart the loop as a safety net
      debugPrint('⚠️ [NAVIGATE] ctx/nav null — restarting retry');
      _storePendingCall(data);
      _startRetryLoop();
      return;
    }

    if (callType == 'video_call') {
      debugPrint('📹 [NAVIGATE] VIDEO');

      ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
        roomName:           roomName,
        callerId:           callerId,
        callerName:         callerName,
        acceptedViaCallKit: autoAccept,
      );

      if (autoAccept) {
        nav.push(MaterialPageRoute(builder: (_) => VideoCallScreen()));
        ctx.read<VideoCallProvider>().acceptCall();

        await _endAllCallKitCalls(); // ✅ ADD THIS
      }

    } else {
      debugPrint('🎙️ [NAVIGATE] VOICE');

      ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
        roomName:           roomName,
        callerId:           callerId,
        callerName:         callerName,
        acceptedViaCallKit: autoAccept,
      );


      if (autoAccept) {
        nav.push(MaterialPageRoute(builder: (_) => const VoiceRoomScreen()));
        ctx.read<VoiceCallProvider>().acceptVoiceCall();

        await _endAllCallKitCalls(); // ✅ ADD THIS
      }
    }
  }

  void _consumePending() {
    final data = _pendingCallData;
    if (data == null) return;
    if (_isCallExpired()) { _clearCallState(); return; }
    debugPrint('▶️ [CONSUME] type=${data['callType']} | room=${data['roomName']}');
    _retryTimer?.cancel();
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
          if (_providersReady && _pendingCallData != null) _consumePending();
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

          debugPrint('⚙️ [PROVIDER INIT] userId=${user.id}');
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
            debugPrint('✅ [PROVIDER INIT] Done | pending=${_pendingCallData != null} | room=${_pendingCallData?['roomName']}');

            // Fast path: if retry loop already started and navigator is ready,
            // _consumePending will finish it immediately.
            // If navigator isn't ready yet, the retry loop continues ticking.
            if (mounted) _consumePending();

          } catch (e) {
            debugPrint('❌ [PROVIDER INIT] $e');
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
  Future<void> _endAllCallKitCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;

      for (final call in calls) {
        final id = call['id']?.toString();
        if (id != null) {
          await FlutterCallkitIncoming.endCall(id);
        }
      }

      debugPrint('🧹 [CALLKIT] Force cleared all native calls');
    } catch (e) {
      debugPrint('❌ [CALLKIT CLEAR] $e');
    }
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