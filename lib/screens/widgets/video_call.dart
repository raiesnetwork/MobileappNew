import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

import '../video_call/incoming_call_screen.dart';


class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({Key? key, required this.child}) : super(key: key);

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final videoCallProvider = context.read<VideoCallProvider>();
    videoCallProvider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    final videoCallProvider = context.read<VideoCallProvider>();

    if (videoCallProvider.callState == CallState.ringing) {
      // Show incoming call screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    try {
      context.read<VideoCallProvider>().removeListener(_handleCallStateChange);
    } catch (e) {
      // Provider already disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}