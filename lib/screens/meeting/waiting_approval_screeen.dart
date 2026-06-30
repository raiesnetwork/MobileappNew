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
      debugPrint('👂 [WAITING] Listener registered for provider changes');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Use saved provider reference instead of context.read
    _meetingProvider?.removeListener(_handleStatus);
    debugPrint('👋 [WAITING] Listener removed on dispose');
    super.dispose();
  }

  // ✅ COMPLETE _handleStatus() METHOD WITH ALL SAFETY CHECKS
  void _handleStatus() {
    // ── Early returns for invalid states ────────────────────────────────
    if (_hasNavigated || !mounted || _meetingProvider == null) {
      debugPrint('⚠️ [WAITING] Early return | hasNavigated=$_hasNavigated | mounted=$mounted | providerNull=${_meetingProvider == null}');
      return;
    }

    final provider = _meetingProvider!;
    final currentContext = context;

    // ── Check if we're still on the WaitingApprovalScreen ────────────────
    // This prevents handling status when user has already popped/navigated
    if (!Navigator.canPop(currentContext)) {
      debugPrint('⚠️ [WAITING] Not on waiting screen (no canPop) — skipping auto-nav');
      return;
    }

    debugPrint('🔄 [WAITING] Status check | joinStatus=${provider.joinStatus} | hasToken=${provider.accessToken != null}');

    // ─────────────────────────────────────────────────────────────────────
    // ✅ HANDLE APPROVAL — Navigate to meeting room
    // ─────────────────────────────────────────────────────────────────────
    if (provider.joinStatus == JoinStatus.approved && provider.accessToken != null) {
      debugPrint('✅ [WAITING] APPROVED | accessToken=${provider.accessToken?.substring(0, 20)}...');

      // Prevent multiple navigations
      if (_hasNavigated) {
        debugPrint('⚠️ [WAITING] Already navigated once — skipping duplicate nav');
        return;
      }

      _hasNavigated = true;
      debugPrint('🚪 [WAITING] Setting _hasNavigated=true → navigating to MeetingRoomScreen');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          debugPrint('⚠️ [WAITING] Widget unmounted before callback — aborting nav');
          return;
        }

        try {
          debugPrint('📍 [WAITING] Pushing MeetingRoomScreen | meetingId=${widget.meetingId}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingRoomScreen(meetingId: widget.meetingId),
            ),
          );
        } catch (e) {
          debugPrint('❌ [WAITING] Navigation error: $e');
          _hasNavigated = false; // Reset on error
        }
      });
      return; // ✅ CRITICAL: Return to prevent handling other statuses
    }

    // ─────────────────────────────────────────────────────────────────────
    // ✅ HANDLE REJECTION — Show dialog and go back
    // ─────────────────────────────────────────────────────────────────────
    if (provider.joinStatus == JoinStatus.rejected) {
      debugPrint('❌ [WAITING] REJECTED');

      if (_hasNavigated) {
        debugPrint('⚠️ [WAITING] Already navigated once — skipping duplicate nav');
        return;
      }

      _hasNavigated = true;
      debugPrint('🚪 [WAITING] Setting _hasNavigated=true → showing rejection dialog');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          debugPrint('⚠️ [WAITING] Widget unmounted before callback — aborting dialog');
          return;
        }

        try {
          debugPrint('📋 [WAITING] Showing rejection dialog');
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
                    debugPrint('👤 [WAITING] User clicked OK on rejection dialog');

                    // ✅ Clear state before closing dialog
                    _meetingProvider?.clearMeetingState();

                    Navigator.pop(dialogContext); // Close dialog

                    if (mounted) {
                      Navigator.pop(context); // Go back to join screen
                      debugPrint('✅ [WAITING] Popped back to join screen');
                    }
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } catch (e) {
          debugPrint('❌ [WAITING] Dialog error: $e');
          _hasNavigated = false; // Reset on error
        }
      });
      return; // ✅ CRITICAL: Return to prevent handling other statuses
    }

    // ─────────────────────────────────────────────────────────────────────
    // ⏳ STILL WAITING — No action, status will be checked again on next
    // ─────────────────────────────────────────────────────────────────────
    if (provider.joinStatus == JoinStatus.requesting) {
      debugPrint('⏳ [WAITING] Still waiting for approval...');
      return;
    }

    // ─────────────────────────────────────────────────────────────────────
    // ⚠️ UNKNOWN STATE — Log and wait
    // ─────────────────────────────────────────────────────────────────────
    debugPrint('❓ [WAITING] Unknown status: ${provider.joinStatus} | errorMsg=${provider.errorMessage}');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        debugPrint('🔙 [WAITING] Back pressed');
        // ✅ Clear state when user presses back arrow
        _meetingProvider?.clearMeetingState();
        return true; // Allow pop
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
    debugPrint('❌ [WAITING] Cancel button tapped');
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
            onPressed: () {
              debugPrint('⏳ [WAITING] User clicked "No, Wait"');
              Navigator.pop(context);
            },
            child: const Text("No, Wait"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              debugPrint('✅ [WAITING] User confirmed cancel');

              _meetingProvider?.cancelJoinRequest();
              // ✅ Clear state before navigating back
              _meetingProvider?.clearMeetingState();

              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen

              debugPrint('✅ [WAITING] Back navigation complete');

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