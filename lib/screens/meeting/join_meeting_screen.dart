import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/meeting/waiting_approval_screeen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/meeting_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'meeting_rooom_screen.dart';

class JoinMeetingScreen extends StatefulWidget {
  final String? prefilledMeetingId; // ✅ ADD THIS

  const JoinMeetingScreen({
    Key? key,
    this.prefilledMeetingId, // ✅ ADD THIS
  }) : super(key: key);

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingIdController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();

    if (widget.prefilledMeetingId != null) {
      String id = widget.prefilledMeetingId!.trim();

      // ✅ Clean URL to extract just the meeting ID
      if (id.startsWith('http://') || id.startsWith('https://')) {
        try {
          final uri = Uri.parse(id);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.length >= 2 && segments[0] == 'meeting') {
            id = segments[1];
          } else if (segments.isNotEmpty) {
            id = segments.last;
          }
        } catch (_) {}
      }

      _meetingIdController.text = id; // ✅ Always stores clean ID
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _joinMeeting(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true, // 👈 prevents overflow
      appBar: AppBar(
        title: const Text(
          'Join Meeting',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),

      body: Consumer<MeetingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView( // 👈 scroll when keyboard opens
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 30),

                    // Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.video_call_outlined,
                          size: 48,
                          color: Primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Join a Meeting',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Enter the Meeting ID provided by the host',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Meeting ID input
                    TextFormField(
                      controller: _meetingIdController,
                      decoration: InputDecoration(
                        labelText: 'Meeting ID',
                        labelStyle:
                        TextStyle(fontSize: 15, color: Colors.grey[700]),
                        hintText: 'ID or https://ixes.ai/meeting/...',
                        hintStyle:
                        TextStyle(fontSize: 14, color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.tag, color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a meeting ID';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _joinMeeting(context),
                    ),

                    const SizedBox(height: 35),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The host will need to approve your request to join the meeting',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Join Button
                    Center(
                      child: SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: _isJoining
                              ? null
                              : () => _joinMeeting(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isJoining
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : const Text(
                            'Join Meeting',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Error message
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _joinMeeting(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isJoining = true);

    final provider = context.read<MeetingProvider>();
    final authProvider = context.read<AuthProvider>();

    // ✅ CLEAR STALE STATE BEFORE JOINING — CRITICAL FIX
    provider.clearMeetingState();

    // ✅ Initialize provider first — CRITICAL
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    final userId = authProvider.user?.id ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userName = authProvider.user?.username ?? 'User';

    provider.initialize(
      userId: userId,
      userName: userName,
      authToken: authToken,
    );

    // wait for socket to connect
    await Future.delayed(const Duration(milliseconds: 800));

    String input = _meetingIdController.text.trim();
    String meetingId = input;

    if (input.startsWith('http://') || input.startsWith('https://')) {
      try {
        final uri = Uri.parse(input);
        // Filter out empty segments caused by trailing slashes
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 2 && segments[0] == 'meeting') {
          meetingId = segments[1];
        } else if (segments.isNotEmpty) {
          meetingId = segments.last;
        }
      } catch (e) {
        meetingId = input;
      }
    }

    provider.clearMessages();

    // ✅ KEY FIX — check isHost FIRST, then route to correct flow
    await provider.requestToJoinMeeting(meetingId);

    setState(() => _isJoining = false);

    if (!mounted) return;

    // ✅ If server says isHost → use host flow, not participant flow
    if (provider.isHost) {
      // Re-initialize as host properly
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await provider.joinAsMeetingHost(meetingId);

      if (mounted) Navigator.pop(context); // close loading

      if (provider.accessToken != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingRoomScreen(meetingId: meetingId),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Failed to start meeting'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } else if (provider.joinStatus == JoinStatus.requesting) {
      // Normal participant — go to waiting screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingApprovalScreen(meetingId: meetingId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Failed to join meeting',
            style: const TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}