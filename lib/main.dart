import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background/flutter_background.dart';
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
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/BottomNaviagation.dart';
import 'utils/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const _uuid = Uuid();

Map<String, dynamic>? _pendingCallData;
String? _dispatchedRoomName;
DateTime? _pendingCallDispatchedAt;
const Duration _callTTL = Duration(seconds: 30);

void _storePendingCall(Map<String, dynamic> data) {
  _pendingCallData = data;
  _pendingCallDispatchedAt = DateTime.now();
  _dispatchedRoomName = data['roomName'] ?? '';
  debugPrint('💾 [PENDING] Stored | type=${data['callType']} | room=${data['roomName']}');
}

void _clearCallState() {
  _pendingCallData = null;
  _dispatchedRoomName = null;
  _pendingCallDispatchedAt = null;
  debugPrint('🧹 [CALL STATE] Cleared');
}

bool _isCallExpired() {
  final at = _pendingCallDispatchedAt;
  if (at == null) return true;
  return DateTime.now().difference(at) > _callTTL;
}

final StreamController<Map<String, dynamic>> _callStream =
StreamController<Map<String, dynamic>>.broadcast();

Future<void> _showCallkitIncoming({
  required String roomName,
  required String callerId,
  required String callerName,
  required String callType,
}) async {
  final callUUID = _uuid.v4();
  await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
    id: callUUID,
    nameCaller: callerName,
    appName: 'Ixes',
    avatar: null,
    handle: callerId,
    type: callType == 'video_call' ? 1 : 0,
    textAccept: 'Accept',
    textDecline: 'Decline',
    missedCallNotification: const NotificationParams(
      showNotification: true, isShowCallback: false, subtitle: 'Missed call',
    ),
    duration: 30000,
    extra: <String, dynamic>{
      'roomName': roomName, 'callerId': callerId,
      'callerName': callerName, 'callType': callType,
    },
    android: const AndroidParams(
      isCustomNotification: true, isShowLogo: false,
      ringtonePath: 'system_ringtone_default', backgroundColor: '#0D0D14',
      backgroundUrl: null, actionColor: '#4CAF50', textColor: '#ffffff',
      incomingCallNotificationChannelName: 'Incoming Calls',
      missedCallNotificationChannelName: 'Missed Calls', isShowCallID: false,
    ),
    ios: const IOSParams(
      iconName: 'AppIcon', handleType: 'generic', supportsVideo: true,
      maximumCallGroups: 1, maximumCallsPerCallGroup: 1,
      audioSessionMode: 'default', audioSessionActive: true,
      audioSessionPreferredSampleRate: 44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF: true, supportsHolding: true,
      supportsGrouping: false, supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  ));
  debugPrint('✅ [CALLKIT UI] Shown | room=$roomName | uuid=$callUUID');
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final type = data['type'] ?? '';
  if (type == 'voice_call' || type == 'video_call') {
    await _showCallkitIncoming(
      roomName: data['roomName'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callType: type,
    );
  }
}

Future<void> _saveFcmToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null || authToken.isEmpty) return;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;
    final userId = prefs.getString('user_id');
    debugPrint('📱 [FCM] Saving token for userId=$userId');
    await ApiService.post(
      '/api/mobile/user/save-fcm',
      {'fcmToken': fcmToken, 'platform': Platform.isAndroid ? 'android' : 'ios'},
      requireAuth: true,
    );
    debugPrint('✅ [FCM TOKEN] Saved for userId=$userId');
  } catch (e) { debugPrint('❌ [FCM TOKEN] $e'); }
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
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final d = msg.data;
      final type = d['type'] ?? '';
      if (type == 'voice_call' || type == 'video_call') {
        // ✅ App is FOREGROUND — socket handles in-app calls automatically.
        // Do NOT show CallKit here. Do NOT stream it.
        // Socket events (onIncomingVoiceCall / onIncomingVideoCall) already
        // fire and VoiceCallListener/IncomingCallListener show your custom screen.
        debugPrint('📲 [FG FCM] $type received — app is foreground, socket handles it, ignoring FCM');
        return;
      }
    });
  } catch (e) { debugPrint('❌ [FCM INIT] $e'); }
}

Future<void> _checkActiveCallsOnStartup() async {
  try {
    final calls = await FlutterCallkitIncoming.activeCalls();
    if (calls == null || calls.isEmpty) return;
    final call = calls.last;
    final extra = call['extra'] as Map<dynamic, dynamic>? ??
        call['Extra'] as Map<dynamic, dynamic>? ?? {};
    final roomName = extra['roomName']?.toString() ?? call['roomName']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? call['callerId']?.toString() ?? call['handle']?.toString() ?? '';
    final callerName = extra['callerName']?.toString() ?? call['callerName']?.toString() ?? call['nameCaller']?.toString() ?? 'Unknown';
    final callType = extra['callType']?.toString() ?? call['callType']?.toString() ?? 'voice_call';
    if (roomName.isEmpty) return;
    _storePendingCall({
      'callType': callType, 'roomName': roomName,
      'callerId': callerId, 'callerName': callerName, 'autoAccept': true,
    });
    debugPrint('✅ [STARTUP] Stored pending call from activeCalls()');
  } catch (e) { debugPrint('❌ [STARTUP] activeCalls() error: $e'); }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await _initFCM();
  await _checkActiveCallsOnStartup();
  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: 'Screen Sharing',
    notificationText: 'Ixes meeting is running in background',
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getString('user_id');
  final language = prefs.getString('app_language');
  runApp(IxesApp(initialToken: token, initialUserId: userId, showLanguage: language == null));
}

class IxesApp extends StatelessWidget {
  final String? initialToken;
  final String? initialUserId;
  final bool showLanguage;
  const IxesApp({super.key, this.initialToken, this.initialUserId, this.showLanguage = false});

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
          initialToken: initialToken, initialUserId: initialUserId, showLanguage: showLanguage,
        ),
      ),
    );
  }
}

// ============================================================================
// CALL CONNECTING SPLASH — same gradient/logo/spinner as SplashScreen
// ============================================================================
class _CallConnectingSplash extends StatelessWidget {
  final String callerName;
  final String callType;
  const _CallConnectingSplash({required this.callerName, required this.callType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: Center(
                  child: Text(
                    callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                callType == 'video_call' ? 'Connecting video call...' : 'Connecting voice call...',
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

class AppWithLifecycleObserver extends StatefulWidget {
  final String? initialToken;
  final String? initialUserId;
  final bool showLanguage;
  const AppWithLifecycleObserver({super.key, this.initialToken, this.initialUserId, this.showLanguage = false});

  @override
  State<AppWithLifecycleObserver> createState() => _AppWithLifecycleObserverState();
}

class _AppWithLifecycleObserverState extends State<AppWithLifecycleObserver>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _callSub;
  bool _providersReady = false;
  bool _initStarted = false;
  Timer? _retryTimer;
  String? _lastInitUserId;

  @override
  void initState() {
    super.initState();
    DeepLinkService.init();
    WidgetsBinding.instance.addObserver(this);
    if (_pendingCallData != null) _startRetryLoop();
    _callSub = _callStream.stream.listen((data) {
      if (_providersReady && mounted) {
        if (_isCallExpired()) { _clearCallState(); return; }
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

  void _handleCallKitEvent(CallEvent event) {
    final body = event.body as Map<dynamic, dynamic>? ?? {};
    final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};
    final roomName = extra['roomName']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';
    final callerName = extra['callerName']?.toString() ?? '';
    final callType = extra['callType']?.toString() ?? 'voice_call';
    debugPrint('🎯 [CALLKIT] ${event.event} | room=$roomName | type=$callType | ready=$_providersReady');

    switch (event.event) {

    // Tap notification body → show in-app incoming screen
      case Event.actionCallIncoming:
        if (roomName.isEmpty) return;
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          _storePendingCall({
            'callType': callType, 'roomName': roomName,
            'callerId': callerId, 'callerName': callerName, 'autoAccept': false,
          });
          _startRetryLoop();
          return;
        }
        if (callType == 'video_call') {
          ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
            roomName: roomName, callerId: callerId, callerName: callerName,
            acceptedViaCallKit: false,
          );
        } else {
          ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
            roomName: roomName, callerId: callerId, callerName: callerName,
            acceptedViaCallKit: false,
          );
        }
        break;

    // Tap Answer button → store and wait for providers ready
      case Event.actionCallAccept:
        if (roomName.isEmpty) { debugPrint('❌ [ACCEPT] Empty roomName'); return; }
        final callData = {
          'callType': callType, 'roomName': roomName,
          'callerId': callerId, 'callerName': callerName, 'autoAccept': true,
        };
        if (_providersReady && mounted &&
            navigatorKey.currentContext != null &&
            navigatorKey.currentState != null) {
          _navigate(callData);
        } else {
          _storePendingCall(callData);
          _startRetryLoop();
        }
        break;

    // Decline
      case Event.actionCallDecline:
        _clearCallState();
        _retryTimer?.cancel();
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        if (callType == 'video_call') {
          ctx.read<VideoCallProvider>().setCallerForReject(
            callerId: callerId, callerName: callerName, roomName: roomName,
          );
          ctx.read<VideoCallProvider>().rejectCall();
        } else {
          ctx.read<VoiceCallProvider>().setCallerForReject(
            callerId: callerId, callerName: callerName, roomName: roomName,
          );
          ctx.read<VoiceCallProvider>().rejectVoiceCall();
        }
        break;

    // Caller cancelled / timeout
      case Event.actionCallTimeout:
      case Event.actionCallEnded:
        _clearCallState();
        _retryTimer?.cancel();
        _endAllCallKitCalls();
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

  void _startRetryLoop() {
    _retryTimer?.cancel();
    int attempts = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final data = _pendingCallData;
      if (data == null) { timer.cancel(); return; }
      if (_isCallExpired()) { _clearCallState(); timer.cancel(); return; }
      if (attempts > 100) { _clearCallState(); timer.cancel(); return; }
      if (!_providersReady || navigatorKey.currentContext == null ||
          navigatorKey.currentState == null || !mounted) {
        if (!mounted) timer.cancel();
        return;
      }
      debugPrint('🚀 [RETRY #$attempts] Providers ready → navigating!');
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

  // ============================================================================
  // ✅ FIX — _navigate for autoAccept calls
  //
  // PROBLEM 1 (call not connecting):
  // Previous fix pushed MainScreen first via pushAndRemoveUntil which
  // triggered MainScreen's provider init AGAIN, causing race conditions
  // and losing the call data → VoiceRoomScreen had null userId → token failed.
  //
  // PROBLEM 2 (splash shows after call ends):
  // Splash was the root route. Call screen pushed on top. Call ends → pop →
  // splash appears again because it's still the root.
  //
  // CORRECT FIX:
  // Step 1: Push call screen with nav.push() (simple, doesn't touch root)
  //         Call connects correctly ✅
  // Step 2: The splash (root) stays hidden BEHIND the call screen — invisible.
  // Step 3: VoiceRoomScreen/_closeScreen() uses pushAndRemoveUntil(MainScreen)
  //         instead of pop() — this replaces the entire stack with MainScreen.
  //         User sees MainScreen after call, not the splash. ✅
  //
  // So the fix is split: _navigate stays simple (just push),
  // and VoiceRoomScreen/VideoCallScreen handle the post-call navigation.
  // We pass a flag `fromFcmAutoAccept` so those screens know to use
  // pushAndRemoveUntil instead of pop.
  // ============================================================================
  Future<void> _navigate(Map<String, dynamic> data) async {
    final roomName = data['roomName'] ?? '';
    final callType = data['callType'] ?? '';
    final callerId = data['callerId'] ?? '';
    final callerName = data['callerName'] ?? '';
    final autoAccept = data['autoAccept'] == true;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎯 [NAVIGATE] type=$callType | room=$roomName | auto=$autoAccept');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (roomName.isEmpty || callType.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    final nav = navigatorKey.currentState;
    if (ctx == null || nav == null) { _storePendingCall(data); _startRetryLoop(); return; }

    if (callType == 'video_call') {
      ctx.read<VideoCallProvider>().setIncomingCallFromFCM(
        roomName: roomName, callerId: callerId, callerName: callerName,
        acceptedViaCallKit: autoAccept,
      );
      if (autoAccept) {
        // Simple push — call connects correctly.
        // VideoCallScreen will use pushAndRemoveUntil(MainScreen) on close
        // when fromFcmAutoAccept=true so splash doesn't show after call ends.
        nav.push(MaterialPageRoute(
          builder: (_) => VideoCallScreen(fromFcmAutoAccept: true),
        ));
        await _endAllCallKitCalls();
      }
    } else {
      ctx.read<VoiceCallProvider>().setIncomingCallFromFCM(
        roomName: roomName, callerId: callerId, callerName: callerName,
        acceptedViaCallKit: autoAccept,
      );
      if (autoAccept) {
        // Simple push — call connects correctly.
        // VoiceRoomScreen will use pushAndRemoveUntil(MainScreen) on close
        // when fromFcmAutoAccept=true so splash doesn't show after call ends.
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
    if (_isCallExpired()) { _clearCallState(); return; }
    _retryTimer?.cancel();
    _pendingCallData = null;
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
          if (chat.currentReceiverId != null) chat.fetchConversation(chat.currentReceiverId!);
          if (_providersReady && _pendingCallData != null) _consumePending();
          break;
        case AppLifecycleState.detached:
          chat.cleanup();
          try { MeetingOverlayService().hideOverlay(); } catch (_) {}
          break;
        default: break;
      }
    } catch (e) { debugPrint('❌ [LIFECYCLE] $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      final auth = ctx.watch<AuthProvider>();

      // Show connecting splash while providers init for autoAccept calls
      if (_pendingCallData != null &&
          _pendingCallData!['autoAccept'] == true &&
          auth.isAuthenticated) {
        if (auth.user != null) {
          final user = auth.user!;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (_initStarted && _lastInitUserId == user.id) return;
            _initStarted = true;
            _providersReady = false;
            _lastInitUserId = user.id;
            final name = user.username.isNotEmpty
                ? user.username
                : 'User_${user.mobile.substring(user.mobile.length - 4)}';
            try {
              await ctx.read<PersonalChatProvider>().initialize();
              final sock = SocketService().socket;
              if (sock != null) ctx.read<GroupChatProvider>().setSocket(sock);
              SocketService().onSocketReady.listen((s) {
                if (mounted) ctx.read<GroupChatProvider>().setSocket(s);
              });
              ctx.read<VideoCallProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
              ctx.read<VoiceCallProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
              ctx.read<MeetingProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
              await _saveFcmToken();
              ctx.read<CommentProvider>().setCurrentUserId(user.id ?? '');
              _providersReady = true;
              debugPrint('✅ [PROVIDER INIT] Done | pending=${_pendingCallData != null}');
              if (mounted) _consumePending();
            } catch (e) { debugPrint('❌ [PROVIDER INIT] $e'); }
          });
        }
        return _buildApp(
          home: _CallConnectingSplash(
            callerName: _pendingCallData!['callerName'] ?? '',
            callType: _pendingCallData!['callType'] ?? 'voice_call',
          ),
        );
      }

      if (!auth.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ctx.read<AuthProvider>().loadUserFromStorage();
        });
        return _buildApp(home: const SplashScreen());
      }

      if (auth.isAuthenticated && auth.user != null) {
        final user = auth.user!;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          // ✅ FIX: If different user logged in, reset and re-initialize
          if (_initStarted && _lastInitUserId == user.id) return;
          _initStarted = true;
          _providersReady = false;
          _lastInitUserId = user.id;
          final name = user.username.isNotEmpty
              ? user.username
              : 'User_${user.mobile.substring(user.mobile.length - 4)}';
          try {
            await ctx.read<PersonalChatProvider>().initialize();
            final sock = SocketService().socket;
            if (sock != null) ctx.read<GroupChatProvider>().setSocket(sock);
            SocketService().onSocketReady.listen((s) {
              if (mounted) ctx.read<GroupChatProvider>().setSocket(s);
            });
            ctx.read<VideoCallProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
            ctx.read<VoiceCallProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
            ctx.read<MeetingProvider>().initialize(userId: user.id, userName: name, authToken: widget.initialToken);
            await _saveFcmToken();
            ctx.read<CommentProvider>().setCurrentUserId(user.id ?? '');
            _providersReady = true;
            debugPrint('✅ [PROVIDER INIT] Done | pending=${_pendingCallData != null}');
            if (mounted) _consumePending();
          } catch (e) { debugPrint('❌ [PROVIDER INIT] $e'); }
        });
      }

      return _buildApp(
        home: auth.isAuthenticated
            ? VoiceCallListener(child: IncomingCallListener(child: const MainScreen(initialIndex: 0)))
            : widget.showLanguage ? const LanguageSelectionScreen() : const SplashScreen(),
      );
    });
  }

  Future<void> _endAllCallKitCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;
      for (final call in calls) {
        final id = call['id']?.toString();
        if (id != null) await FlutterCallkitIncoming.endCall(id);
      }
    } catch (e) { debugPrint('❌ [CALLKIT CLEAR] $e'); }
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
        '/main': (_) => VoiceCallListener(child: IncomingCallListener(child: const MainScreen(initialIndex: 0))),
      },
    );
  }
}