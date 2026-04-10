import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/meeting/waiting_approval_screeen.dart';


class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription? _sub;

  static void init() {
    // cold start
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    });

    // foreground/background
    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _handle(uri);
    });
  }

  static void _handle(Uri uri) {
    final segments = uri.pathSegments;

    if (segments.isNotEmpty && segments[0] == "meeting") {
      final meetingId = segments.length > 1 ? segments[1] : null;
      if (meetingId == null) return;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => WaitingApprovalScreen(
            meetingId: meetingId,
          ),
        ),
      );
    }
  }

  static void dispose() {
    _sub?.cancel();
  }
}