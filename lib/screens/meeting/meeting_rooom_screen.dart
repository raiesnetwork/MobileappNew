import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/meeting_provider.dart';
import 'dart:async';

class MeetingRoomScreen extends StatefulWidget {
  final String meetingId;

  const MeetingRoomScreen({
    Key? key,
    required this.meetingId,
  }) : super(key: key);

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  Room? _room;
  List<ParticipantTrack> _participantTracks = [];
  LocalParticipant? _localParticipant;

  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isChatOpen = false;
  bool _isParticipantsOpen = false;
  bool _isConnecting = true;
  String? _errorMessage;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final Set<String> _displayedMessageIds = {}; // Track displayed messages

  @override
  void initState() {
    super.initState();
    _initializeMeeting();
  }

  Future<void> _initializeMeeting() async {
    final meetingProvider = context.read<MeetingProvider>();

    debugPrint('🎬 ===== INITIALIZING MEETING ROOM =====');
    debugPrint('🎬 Is Host: ${meetingProvider.isHost}');
    debugPrint('🎬 Meeting ID: ${meetingProvider.currentMeetingId}');

    await _connectToRoom();

    if (_room == null) {
      debugPrint('❌ Failed to connect to room');
      return;
    }

    debugPrint('✅ Connected to LiveKit room');

    if (meetingProvider.isHost) {
      debugPrint('👑 User is host, rejoining as host via socket...');
      await meetingProvider.rejoinAsHost();
      debugPrint('📋 Pending requests after rejoin: ${meetingProvider.pendingRequests.length}');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    debugPrint('💬 Joining chat room...');
    meetingProvider.joinChatRoom();

    debugPrint('✅ ===== MEETING INITIALIZATION COMPLETE =====');
  }

  Future<void> _connectToRoom() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final meetingProvider = context.read<MeetingProvider>();
      final accessToken = meetingProvider.accessToken;

      if (accessToken == null) {
        throw Exception('No access token available');
      }
      _room = Room();

      _setupRoomListeners();

      await _room!.connect(
        'wss://meet.ixes.ai',
        accessToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );

      await _room!.localParticipant?.setCameraEnabled(_isVideoEnabled);
      await _room!.localParticipant?.setMicrophoneEnabled(_isAudioEnabled);

      setState(() {
        _localParticipant = _room!.localParticipant;
        _isConnecting = false;
      });

      if (meetingProvider.isHost && meetingProvider.currentMeetingId != null) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to meeting: $e';
        _isConnecting = false;
      });
    }
  }

  void _setupRoomListeners() {
    _room?.addListener(_onRoomUpdate);

    _room?.createListener()
      ?..on<RoomDisconnectedEvent>((event) async {
        debugPrint('Disconnected from room');

        if (!mounted) return;

        // Schedule navigation safely
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Use maybePop in case the route was already removed
            Navigator.of(context).maybePop();
          }
        });
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint('👤 Participant connected: ${event.participant.identity}');
        _updateParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('👋 Participant disconnected: ${event.participant.identity}');
        _updateParticipants();
      })
      ..on<TrackPublishedEvent>((event) {
        debugPrint('📹 Track published');
        _updateParticipants();
      })
      ..on<TrackUnpublishedEvent>((event) {
        debugPrint('📹 Track unpublished');
        _updateParticipants();
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint('📹 Track subscribed');
        _updateParticipants();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint('📹 Track unsubscribed');
        _updateParticipants();
      });
  }

  void _onRoomUpdate() {
    _updateParticipants();
  }

  void _updateParticipants() {
    if (_room == null) return;

    final tracks = <ParticipantTrack>[];

    // Add local participant VIDEO tracks only
    for (var trackPub in _room!.localParticipant!.trackPublications.values) {
      if (trackPub.track != null && trackPub.kind == TrackType.VIDEO) {
        tracks.add(ParticipantTrack(
          participant: _room!.localParticipant!,
          videoTrack: trackPub.track as VideoTrack?,
          publication: trackPub,
        ));
      }
    }

    // Add remote participants VIDEO tracks only
    for (var participant in _room!.remoteParticipants.values) {
      for (var trackPub in participant.trackPublications.values) {
        if (trackPub.track != null && trackPub.kind == TrackType.VIDEO) {
          tracks.add(ParticipantTrack(
            participant: participant,
            videoTrack: trackPub.track as VideoTrack?,
            publication: trackPub,
          ));
        }
      }
    }

    setState(() {
      _participantTracks = tracks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: _isConnecting
              ? _buildLoadingState()
              : _buildMeetingUI(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Connecting to meeting...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingUI() {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildParticipantsGrid(),
            ),
            _buildControls(),
          ],
        ),

        // Chat panel
        // Replace both Positioned side panels with this single smart overlay
        if (_isChatOpen || _isParticipantsOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Material(
              elevation: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Max 90% of screen width, but never more than 400px
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  minWidth: 300, // Minimum readable width
                ).normalize(), // Ensures min ≤ max
                child: Container(
                  width: 380, // Ideal width
                  color: Colors.white,
                  child: _isChatOpen ? _buildChatPanel() : _buildParticipantsPanel(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final meetingProvider = context.watch<MeetingProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting ID',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.meetingId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.meetingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Meeting ID copied'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (meetingProvider.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_participantTracks.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participantTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for participants...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final count = _participantTracks.length;
    final columns = count == 1 ? 1 : count == 2 ? 2 : count <= 4 ? 2 : 3;

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _participantTracks.length,
        itemBuilder: (context, index) {
          return _buildParticipantTile(_participantTracks[index]);
        },
      ),
    );
  }

  Widget _buildParticipantTile(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final videoTrack = track.videoTrack;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal ? const Color(0xFF2196F3) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null && !videoTrack.muted)
              VideoTrackRenderer(
                videoTrack,
                fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _buildVideoPlaceholder(participant),

            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      participant.isMicrophoneEnabled()
                          ? Icons.mic
                          : Icons.mic_off,
                      color: participant.isMicrophoneEnabled()
                          ? Colors.white
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLocal ? 'You' : participant.identity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(Participant participant) {
    final isLocal = participant is LocalParticipant;
    final initial = (isLocal ? 'You' : participant.identity)
        .substring(0, 1)
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2A2A),
            const Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFF2196F3),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: _isVideoEnabled,
            onPressed: _toggleVideo,
          ),
          _buildControlButton(
            icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: _isAudioEnabled,
            onPressed: _toggleAudio,
          ),
          _buildControlButton(
            icon: Icons.chat_bubble,
            label: 'Chat',
            isActive: _isChatOpen,
            onPressed: () {
              setState(() {
                _isChatOpen = !_isChatOpen;
                _isParticipantsOpen = false;
              });
            },
            badge: context.watch<MeetingProvider>().chatMessages.length,
          ),
          _buildControlButton(
            icon: Icons.people,
            label: 'People',
            isActive: _isParticipantsOpen,
            onPressed: () {
              setState(() {
                _isParticipantsOpen = !_isParticipantsOpen;
                _isChatOpen = false;
              });
            },
            badge: context.watch<MeetingProvider>().isHost
                ? context.watch<MeetingProvider>().pendingRequests.length
                : null,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: false,
            onPressed: _showLeaveDialog,
            backgroundColor: const Color(0xFFE53935),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? backgroundColor,
    int? badge,
  }) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: backgroundColor ??
                          (isActive
                              ? const Color(0xFF2196F3)
                              : Colors.white.withOpacity(0.1)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2A2A2A),
                        width: 2,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF666666)),
                  onPressed: () {
                    setState(() {
                      _isChatOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                final messages = provider.chatMessages;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter out duplicate messages based on unique ID
                final uniqueMessages = <Map<String, dynamic>>[];
                final seenIds = <String>{};

                for (var message in messages) {
                  // Create unique ID from message content, userId, and timestamp
                  final messageId = '${message['userId']}_${message['message']}_${message['timestamp']}';
                  if (!seenIds.contains(messageId)) {
                    seenIds.add(messageId);
                    uniqueMessages.add(message);
                  }
                }

                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: uniqueMessages.length,
                  itemBuilder: (context, index) {
                    final message = uniqueMessages[index];
                    final isMe = message['userId'] == provider.currentUserId;

                    return _buildChatMessage(
                      username: message['username'] ?? 'Unknown',
                      message: message['message'] ?? '',
                      timestamp: message['timestamp'],
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage({
    required String username,
    required String message,
    required dynamic timestamp,
    required bool isMe,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'You' : username,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              )
                  : null,
              color: isMe ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF666666)),
                  onPressed: () {
                    setState(() {
                      _isParticipantsOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                final shouldShowPending =
                    provider.isHost && provider.pendingRequests.isNotEmpty;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (shouldShowPending)
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.orange[50],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Pending Requests (${provider.pendingRequests.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...provider.pendingRequests.map((request) {
                                return _buildPendingRequest(request);
                              }),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      if (_participantTracks.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.grey[50],
                          child: Text(
                            'In Meeting (${_participantTracks.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _participantTracks.length,
                          itemBuilder: (context, index) {
                            final track = _participantTracks[index];
                            return _buildParticipantListItem(track);
                          },
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No participants yet',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequest(Map<String, dynamic> request) {
    final name = request['name'] ?? 'Unknown';
    final requestId = '${request['meetingId']}-${request['userId']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange,
            radius: 20,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.white, size: 20),
              onPressed: () {
                context.read<MeetingProvider>().approveJoinRequest(requestId);
              },
              tooltip: 'Approve',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                context.read<MeetingProvider>().rejectJoinRequest(requestId);
              },
              tooltip: 'Reject',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantListItem(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final name = isLocal ? 'You' : participant.identity;
    final provider = context.watch<MeetingProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2196F3),
            radius: 20,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.isHost && isLocal)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: participant.isMicrophoneEnabled()
                      ? Colors.grey[100]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  participant.isMicrophoneEnabled()
                      ? Icons.mic
                      : Icons.mic_off,
                  size: 16,
                  color: participant.isMicrophoneEnabled()
                      ? Colors.grey[700]
                      : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: participant.isCameraEnabled()
                      ? Colors.grey[100]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  participant.isCameraEnabled()
                      ? Icons.videocam
                      : Icons.videocam_off,
                  size: 16,
                  color: participant.isCameraEnabled()
                      ? Colors.grey[700]
                      : Colors.red,
                ),
              ),
              // Add kick button for host (only for remote participants)
              if (provider.isHost && !isLocal) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_remove, size: 16),
                    color: Colors.red,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () => _kickParticipant(participant.identity),
                    tooltip: 'Remove participant',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    context.read<MeetingProvider>().sendChatMessage(message);
    _chatController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVideo() async {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });

    await _room?.localParticipant?.setCameraEnabled(_isVideoEnabled);
  }

  Future<void> _toggleAudio() async {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });

    await _room?.localParticipant?.setMicrophoneEnabled(_isAudioEnabled);
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Leave Meeting?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to leave this meeting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _leaveMeeting();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveMeeting() async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Leaving meeting...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Disconnect room in background
      final room = _room;
      if (room != null) {
        // Remove listener first to prevent callbacks
        room.removeListener(_onRoomUpdate);

        // Disconnect asynchronously
        unawaited(room.disconnect());
        unawaited(room.dispose());
      }

      // Clear meeting data on main thread
      if (mounted) {
        final provider = context.read<MeetingProvider>();

        // Leave meeting via provider (socket disconnect, etc.)
        provider.leaveMeeting();

        // Small delay to ensure cleanup
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate back
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Error leaving meeting: $e');
      // Force navigation even if error
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
  Future<void> _kickParticipant(String participantIdentity) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Participant?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove $participantIdentity from the meeting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await context.read<MeetingProvider>().kickParticipant(participantIdentity);

      // Show success/error message
      final provider = context.read<MeetingProvider>();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? provider.successMessage ?? 'Participant removed',
            ),
            backgroundColor: provider.errorMessage != null ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _chatController.dispose();
    _chatScrollController.dispose();

    // Clean up room - do this asynchronously to avoid blocking
    if (_room != null) {
      _room!.removeListener(_onRoomUpdate);
      unawaited(_room!.disconnect());
      unawaited(_room!.dispose());
    }

    super.dispose();
  }
}

class ParticipantTrack {
  final Participant participant;
  final VideoTrack? videoTrack;
  final TrackPublication publication;

  ParticipantTrack({
    required this.participant,
    required this.videoTrack,
    required this.publication,
  });
}