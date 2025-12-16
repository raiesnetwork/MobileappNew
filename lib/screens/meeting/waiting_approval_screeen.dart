import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/meeting_provider.dart';
import 'meeting_rooom_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String meetingId;

  const WaitingApprovalScreen({
    Key? key,
    required this.meetingId,
  }) : super(key: key);

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasNavigated = false;
  MeetingProvider? _meetingProvider; // Save provider reference

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Save provider reference safely
    if (_meetingProvider == null) {
      _meetingProvider = context.read<MeetingProvider>();
      _meetingProvider!.addListener(_handleStatus);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Use saved provider reference instead of context.read
    _meetingProvider?.removeListener(_handleStatus);
    super.dispose();
  }

  void _handleStatus() {
    if (_hasNavigated || !mounted || _meetingProvider == null) return;

    final provider = _meetingProvider!;

    // Handle approval - navigate to meeting room
    if (provider.joinStatus == JoinStatus.approved &&
        provider.accessToken != null) {
      _hasNavigated = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingRoomScreen(meetingId: widget.meetingId),
            ),
          );
        }
      });
    }

    // Handle rejection - show dialog and navigate back
    if (provider.joinStatus == JoinStatus.rejected) {
      _hasNavigated = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Show rejection dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  "Request Rejected",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: const Text(
              "Your request to join this meeting was rejected by the host.",
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showCancelDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                // ✨ Animated Icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _controller.value,
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.shade100,
                              blurRadius: 25,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          size: 72,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // 📝 Title
                const Text(
                  "Waiting for Host Approval",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 12),

                // 📄 Subtitle
                Text(
                  "The meeting host will approve your request shortly.\nPlease wait...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // 🆔 Meeting ID Card
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Meeting ID",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.meetingId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: "monospace",
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 🔄 Loading Status Message
                Consumer<MeetingProvider>(
                  builder: (_, provider, __) {
                    String msg = "Waiting for approval...";
                    if (provider.joinStatus == JoinStatus.approved) {
                      msg = "Approved! Joining meeting...";
                    }

                    return Column(
                      children: [
                        Text(
                          msg,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(6),
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.orange.shade700,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),

                // ❌ Cancel button
                TextButton(
                  onPressed: _showCancelDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text("Cancel Request"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          "Cancel Join Request?",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "Are you sure you want to cancel your request to join this meeting?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No, Wait"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              _meetingProvider?.cancelJoinRequest();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Join request cancelled"),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }
}