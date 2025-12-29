import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../screens/meeting/meeting_rooom_screen.dart';

class MeetingOverlayService extends ChangeNotifier {
  static final MeetingOverlayService _instance = MeetingOverlayService._internal();
  factory MeetingOverlayService() => _instance;
  MeetingOverlayService._internal();

  OverlayEntry? _overlayEntry;
  bool _isMinimized = false;
  Room? _room;
  LocalParticipant? _localParticipant;
  String? _meetingId;

  // Overlay position
  Offset _position = const Offset(20, 100);

  // Track if we're currently navigating to prevent duplicate navigation
  bool _isNavigating = false;

  bool get isMinimized => _isMinimized;
  String? get meetingId => _meetingId;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;

  void initialize({
    required Room room,
    required LocalParticipant localParticipant,
    required String meetingId,
  }) {
    _room = room;
    _localParticipant = localParticipant;
    _meetingId = meetingId;
    notifyListeners();
  }

  void showOverlay(BuildContext context) {
    if (_overlayEntry != null || _room == null) return;

    _isMinimized = true;
    _isNavigating = false; // Reset navigation flag
    notifyListeners();

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildFloatingWindow(context),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMinimized = false;
    _isNavigating = false;
    notifyListeners();
  }

  void updatePosition(Offset newPosition) {
    _position = newPosition;
    _overlayEntry?.markNeedsBuild();
  }

  // FIXED: Navigate back to meeting room
  void _expandMeeting(BuildContext context) {
    if (_isNavigating || _meetingId == null) return;

    _isNavigating = true;

    debugPrint('🔄 ===== EXPANDING MEETING =====');
    debugPrint('🔄 Meeting ID: $_meetingId');
    debugPrint('🔄 Current room state: ${_room?.connectionState}');
    debugPrint('🔄 Camera: ${_localParticipant?.isCameraEnabled()}');
    debugPrint('🔄 Mic: ${_localParticipant?.isMicrophoneEnabled()}');

    // Navigate to meeting room first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeetingRoomScreen(meetingId: _meetingId!),
      ),
    ).then((_) {
      _isNavigating = false;
      debugPrint('🔙 Navigation completed (back from meeting)');
    });

    // Hide overlay AFTER a small delay to allow meeting room to read the state
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        _isMinimized = false;
        notifyListeners();
        debugPrint('✅ Overlay hidden after navigation');
      }
    });

    debugPrint('✅ Navigation triggered, will hide overlay in 300ms');
  }

  Widget _buildFloatingWindow(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          updatePosition(_position + details.delta);
        },
        // ADDED: Tap to expand
        onTap: () => _expandMeeting(context),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 160,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2196F3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Meeting',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // FIXED: Use _expandMeeting instead of manual navigation
                      InkWell(
                        onTap: () => _expandMeeting(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          // Show confirmation dialog
                          _showEndMeetingDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Video preview
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A2A2A),
                    ),
                    child: _buildVideoPreview(),
                  ),
                ),
                // Controls
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMiniControl(
                        icon: _localParticipant?.isMicrophoneEnabled() ?? false
                            ? Icons.mic
                            : Icons.mic_off,
                        isActive: _localParticipant?.isMicrophoneEnabled() ?? false,
                        onTap: () async {
                          final current = _localParticipant?.isMicrophoneEnabled() ?? false;
                          await _localParticipant?.setMicrophoneEnabled(!current);
                          _overlayEntry?.markNeedsBuild();
                          notifyListeners(); // Notify to update meeting room
                        },
                      ),
                      _buildMiniControl(
                        icon: _localParticipant?.isCameraEnabled() ?? false
                            ? Icons.videocam
                            : Icons.videocam_off,
                        isActive: _localParticipant?.isCameraEnabled() ?? false,
                        onTap: () async {
                          final current = _localParticipant?.isCameraEnabled() ?? false;
                          await _localParticipant?.setCameraEnabled(!current);
                          _overlayEntry?.markNeedsBuild();
                          notifyListeners(); // Notify to update meeting room
                        },
                      ),
                      _buildMiniControl(
                        icon: Icons.call_end,
                        isActive: false,
                        color: Colors.red,
                        onTap: () {
                          _showEndMeetingDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEndMeetingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'End Meeting?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to end this meeting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Disconnect room
                await _room?.disconnect();

                // Hide overlay
                hideOverlay();

                // Clear meeting data
                _room = null;
                _localParticipant = null;
                _meetingId = null;

                // Navigate to home if we're in the app
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('End'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    if (_localParticipant == null) {
      return const Center(
        child: Icon(
          Icons.person,
          color: Colors.white54,
          size: 40,
        ),
      );
    }

    final videoTrack = _localParticipant!.trackPublications.values
        .where((pub) => pub.kind == TrackType.VIDEO)
        .map((pub) => pub.track as VideoTrack?)
        .firstWhere((track) => track != null, orElse: () => null);

    if (videoTrack != null && !videoTrack.muted) {
      return VideoTrackRenderer(
        videoTrack,
        fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    return Center(
      child: CircleAvatar(
        radius: 30,
        backgroundColor: const Color(0xFF2196F3),
        child: Text(
          _localParticipant!.identity.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniControl({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color ?? (isActive
              ? const Color(0xFF2196F3)
              : Colors.white.withOpacity(0.1)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  void clearMeetingData() {
    _room = null;
    _localParticipant = null;
    _meetingId = null;
    _isNavigating = false;
    notifyListeners();
  }

  @override
  void dispose() {
    hideOverlay();
    clearMeetingData();
    super.dispose();
  }
}