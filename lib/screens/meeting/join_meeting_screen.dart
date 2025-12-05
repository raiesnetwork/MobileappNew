import 'package:flutter/material.dart';
import 'package:ixes.app/screens/meeting/waiting_approval_screeen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/meeting_provider.dart';


import 'meeting_rooom_screen.dart';

class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({Key? key}) : super(key: key);

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingIdController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _meetingIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Meeting'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Consumer<MeetingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.meeting_room,
                      size: 64,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Join a Meeting',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Enter the Meeting ID shared by the host',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Meeting ID input
                  TextFormField(
                    controller: _meetingIdController,
                    decoration: InputDecoration(
                      labelText: 'Meeting ID',
                      hintText: 'e.g., meeting-1234567890',
                      prefixIcon: const Icon(Icons.meeting_room),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a meeting ID';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _joinMeeting(context),
                  ),
                  const SizedBox(height: 32),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'The host will need to approve your request to join',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Join button
                  ElevatedButton(
                    onPressed: _isJoining ? null : () => _joinMeeting(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isJoining
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Join Meeting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _joinMeeting(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isJoining = true;
    });

    final meetingProvider = context.read<MeetingProvider>();
    final meetingId = _meetingIdController.text.trim();

    // Clear previous messages
    meetingProvider.clearMessages();

    // Request to join
    await meetingProvider.requestToJoinMeeting(meetingId);

    setState(() {
      _isJoining = false;
    });

    if (!mounted) return;

    // Check join status
    if (meetingProvider.joinStatus == JoinStatus.approved) {
      // Join immediately (user is host or auto-approved)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingRoomScreen(meetingId: meetingId),
        ),
      );
    } else if (meetingProvider.joinStatus == JoinStatus.requesting) {
      // Show waiting screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingApprovalScreen(meetingId: meetingId),
        ),
      );
    } else {
      // Error is already displayed via Consumer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            meetingProvider.errorMessage ?? 'Failed to join meeting',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}