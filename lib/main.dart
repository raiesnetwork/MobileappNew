// main.dart - FIXED VERSION

import 'package:flutter/material.dart';

import 'package:ixes.app/providers/announcement_provider.dart';
import 'package:ixes.app/providers/campaign_provider.dart';
import 'package:ixes.app/providers/chat_provider.dart';
import 'package:ixes.app/providers/comment_provider.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:ixes.app/providers/coupon_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getString('user_id');

  debugPrint('Loaded token: $token');
  debugPrint('Loaded userId: $userId');

  runApp(IxesApp(
    initialToken: token,
    initialUserId: userId,
  ));
}

class IxesApp extends StatelessWidget {
  final String? initialToken;
  final String? initialUserId;

  const IxesApp({
    super.key,
    this.initialToken,
    this.initialUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MultiProvider(
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
            ChangeNotifierProvider(create: (_) => MeetingOverlayService()),
          ],
          child: AppWithLifecycleObserver(
            initialToken: initialToken,
            initialUserId: initialUserId,
          ),
        );
      },
    );
  }
}

class AppWithLifecycleObserver extends StatefulWidget {
  final String? initialToken;
  final String? initialUserId;

  const AppWithLifecycleObserver({
    super.key,
    this.initialToken,
    this.initialUserId,
  });

  @override
  State<AppWithLifecycleObserver> createState() =>
      _AppWithLifecycleObserverState();
}

class _AppWithLifecycleObserverState extends State<AppWithLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up meeting overlay when app is disposed
    try {
      MeetingOverlayService().dispose();
    } catch (e) {
      debugPrint('Error disposing meeting overlay: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isAuthenticated) return;

      final personalChatProvider = context.read<PersonalChatProvider>();

      switch (state) {
        case AppLifecycleState.resumed:
          debugPrint('📱 App resumed - reconnecting socket...');
          personalChatProvider.reconnectSocket();
          if (personalChatProvider.currentReceiverId != null) {
            personalChatProvider
                .fetchConversation(personalChatProvider.currentReceiverId!);
          }
          break;
        case AppLifecycleState.paused:
          debugPrint('📱 App paused - keeping socket connected');
          break;
        case AppLifecycleState.inactive:
          debugPrint('📱 App inactive');
          break;
        case AppLifecycleState.detached:
          debugPrint('📱 App detached - cleaning up socket connections');
          personalChatProvider.cleanup();
          // Also clean up meeting overlay
          try {
            MeetingOverlayService().hideOverlay();
          } catch (e) {
            debugPrint('Error hiding meeting overlay: $e');
          }
          break;
        case AppLifecycleState.hidden:
          debugPrint('📱 App hidden');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error in lifecycle handler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final authProvider = context.watch<AuthProvider>();

        if (!authProvider.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<AuthProvider>().loadUserFromStorage();
            }
          });
          return _buildMaterialApp(home: const SplashScreen());
        }

        if (authProvider.isAuthenticated && authProvider.user != null) {
          final user = authProvider.user!;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;

            final String displayName = user.username.isNotEmpty
                ? user.username
                : "User_${user.mobile.substring(user.mobile.length - 4)}";

            debugPrint(
                '🚀 Initializing all services for: $displayName (${user.id})');

            try {
              // Initialize Personal Chat Provider
              final personalChatProvider = context.read<PersonalChatProvider>();
              await personalChatProvider.initialize();
              debugPrint('✅ Personal Chat Provider initialized');

              // Initialize Video Call
              context.read<VideoCallProvider>().initialize(
                    userId: user.id,
                    userName: displayName,
                    authToken: widget.initialToken,
                  );
              debugPrint('✅ Video Call Provider initialized');

              // Initialize Voice Call
              context.read<VoiceCallProvider>().initialize(
                    userId: user.id,
                    userName: displayName,
                    authToken: widget.initialToken,
                  );
              debugPrint('✅ Voice Call Provider initialized');

              // Initialize Meeting
              context.read<MeetingProvider>().initialize(
                    userId: user.id,
                    userName: displayName,
                    authToken: widget.initialToken,
                  );
              debugPrint('✅ Meeting Provider initialized');

              debugPrint(
                  '✅ Meeting Overlay Service ready (will be initialized on meeting join)');
            } catch (e) {
              debugPrint('❌ Error initializing services: $e');
            }
          });
        }

        final bool isLoggedIn = authProvider.isAuthenticated;

        return _buildMaterialApp(
          home: isLoggedIn
              ? VoiceCallListener(
                  child: IncomingCallListener(
                    child: const MainScreen(initialIndex: 0),
                  ),
                )
              : const SplashScreen(),
        );
      },
    );
  }

  Widget _buildMaterialApp({required Widget home}) {
    return MaterialApp(
      title: 'Ixes',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // REMOVED: The problematic builder that was blocking incoming calls
      // The default MaterialApp already has an Overlay that works for all overlays
      home: home,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => VoiceCallListener(
              child: IncomingCallListener(
                child: const MainScreen(initialIndex: 0),
              ),
            ),
      },
    );
  }
}
