import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import '../main.dart';
import '../screens/meeting/waiting_approval_screeen.dart';


class DeepLinkService {
  static void init() async {
    // App opened from killed state
    final initialLink = await getInitialLink();

    if (initialLink != null) {
      _handleLink(initialLink);
    }

    // App already running
    linkStream.listen((link) {
      if (link != null) {
        _handleLink(link);
      }
    });
  }

  static void _handleLink(String link) {
    debugPrint('🔗 Deep Link: $link');

    final uri = Uri.parse(link);

    // Check: ixes.ai/meeting/{id}
    if (uri.pathSegments.contains('meeting')) {
      final meetingId = uri.pathSegments.last;

      debugPrint('📌 Meeting ID: $meetingId');

      // Wait until app is ready
      Future.delayed(const Duration(seconds: 1), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => WaitingApprovalScreen(
              meetingId: meetingId,
            ),
          ),
        );
      });
    }
  }
}