import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/meeting/join_meeting_screen.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription? _sub;

  static void init() {
    // cold start — app was closed, user tapped link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    });

    // foreground/background — app already open
    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _handle(uri);
    });
  }

  static void _handle(Uri uri) {
    String? meetingId;

    // ✅ Custom scheme: ixesapp://meeting/MEETING_ID
    if (uri.scheme == 'ixesapp' && uri.host == 'meeting') {
      meetingId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments[0]
          : null;
    }

    // ✅ HTTPS scheme: https://ixes.ai/meeting/MEETING_ID
    else if (uri.scheme == 'https' && uri.host == 'ixes.ai') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments[0] == 'meeting') {
        meetingId = segments.length > 1 ? segments[1] : null;
      }
    }

    if (meetingId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;

      if (nav == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handle(uri);
        });
        return;
      }

      nav.push(
        MaterialPageRoute(
          builder: (_) => JoinMeetingScreen(
            prefilledMeetingId: meetingId,
          ),
        ),
      );
    });
  }

  static void dispose() {
    _sub?.cancel();
  }
}