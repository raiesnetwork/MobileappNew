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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupListener();
  }

  void _setupListener() {
    final meetingProvider = context.read<MeetingProvider>();
    meetingProvider.addListener(_handleJoinStatusChange);
  }

  void _handleJoinStatusChange() {
    if (!mounted) return;

    final meetingProvider = context.read<MeetingProvider>();

    if (meetingProvider.joinStatus == JoinStatus.approved) {
      // Navigate to meeting room
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingRoomScreen(meetingId: widget.meetingId),
        ),
      );
    } else if (meetingProvider.joinStatus == JoinStatus.rejected) {
      // Show rejection and go back
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your request was rejected by the host'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    try {
      context.read<MeetingProvider>().removeListener(_handleJoinStatusChange);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }
    super.dispose();
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated icon
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_animationController.value * 0.1),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.hourglass_empty,
                          size: 80,
                          color: Colors.orange[700],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Title
                const Text(
                  'Waiting for Host Approval',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'The meeting host will approve your request shortly',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Meeting ID
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Meeting ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.meetingId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Loading indicator
                const SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),

                const Spacer(),

                // Cancel button
                TextButton(
                  onPressed: _showCancelDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Cancel Request',
                    style: TextStyle(fontSize: 16),
                  ),
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
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cancel Join Request?'),
          content: const Text(
            'Are you sure you want to cancel your request to join this meeting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, Wait'),
            ),
            TextButton(
              onPressed: () {
                // Cancel the request
                context.read<MeetingProvider>().cancelJoinRequest();

                // Close dialog
                Navigator.pop(context);

                // Go back to previous screen
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Join request cancelled'),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }
}