import 'package:flutter/material.dart';
import 'package:ixes.app/providers/announcement_provider.dart';

import 'package:ixes.app/providers/campaign_provider.dart';
import 'package:ixes.app/providers/chat_provider.dart';
import 'package:ixes.app/providers/comment_provider.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:ixes.app/providers/coupon_provider.dart';
import 'package:ixes.app/providers/group_provider.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:ixes.app/providers/personal_chat_provider.dart';
import 'package:ixes.app/providers/service_provider.dart';
import 'package:ixes.app/providers/service_request_provider.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/BottomNaviagation.dart';
import 'utils/app_theme.dart';
import 'services/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getString('user_id');

  debugPrint('🔐 Loaded token: $token');
  debugPrint('👤 Loaded userId: $userId');

  if (token != null && userId != null) {
    debugPrint('📡 Connecting socket...');

  } else {
    debugPrint('⚠️ No token or userId found. Skipping socket.');
  }

  runApp(IxesApp(initialToken: token));
}


class IxesApp extends StatelessWidget {

  final String? initialToken;

  const IxesApp({super.key, this.initialToken});


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
          ],
          child: MaterialApp(
            title: 'Ixes',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: initialToken != null
                ? const MainScreen(initialIndex: 0)
                : const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/main': (context) => const MainScreen(initialIndex: 0),
            },
          ),
        );
      },
    );
  }
}
