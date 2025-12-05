import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/meeting_provider.dart';

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
  // LiveKit room and participants
  Room? _room;
  List<ParticipantTrack> _participantTracks = [];
  LocalParticipant? _localParticipant;

  // UI state
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isChatOpen = false;
  bool _isParticipantsOpen = false;
  bool _isConnecting = true;
  String? _errorMessage;

  // Chat
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeMeeting();
  }

  Future<void> _initializeMeeting() async {
    final meetingProvider = context.read<MeetingProvider>();

    // Join chat room
    meetingProvider.joinChatRoom();

    // Initialize LiveKit room
    await _connectToRoom();
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

      // Create room
      _room = Room();

      // Set up room listeners
      _setupRoomListeners();

      // Connect to LiveKit server
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

      // Enable local video and audio
      await _room!.localParticipant?.setCameraEnabled(_isVideoEnabled);
      await _room!.localParticipant?.setMicrophoneEnabled(_isAudioEnabled);

      setState(() {
        _localParticipant = _room!.localParticipant;
        _isConnecting = false;
      });

      debugPrint('✅ Connected to LiveKit room');
    } catch (e) {
      debugPrint('❌ Error connecting to room: $e');
      setState(() {
        _errorMessage = 'Failed to connect to meeting: $e';
        _isConnecting = false;
      });
    }
  }

  void _setupRoomListeners() {
    _room?.addListener(_onRoomUpdate);

    _room?.createListener()
      ?..on<RoomDisconnectedEvent>((event) {
        debugPrint('🔌 Disconnected from room');
        if (mounted) {
          Navigator.pop(context);
        }
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

    // Add local participant
    for (var trackPub in _room!.localParticipant!.trackPublications.values) {
      if (trackPub.track != null) {
        tracks.add(ParticipantTrack(
          participant: _room!.localParticipant!,
          videoTrack: trackPub.track as VideoTrack?,
          publication: trackPub,
        ));
      }
    }

    // Add remote participants
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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isConnecting
              ? _buildLoadingState()
              : _errorMessage != null
              ? _buildErrorState()
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
          const CircularProgressIndicator(color: Colors.white),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Leave Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingUI() {
    return Stack(
      children: [
        // Video grid
        Column(
          children: [
            // Header
            _buildHeader(),
            // Participants grid
            Expanded(
              child: _buildParticipantsGrid(),
            ),
            // Controls
            _buildControls(),
          ],
        ),

        // Chat panel
        if (_isChatOpen)
          Positioned(
            right: 0,
            top: 0,
            bottom: 80,
            child: _buildChatPanel(),
          ),

        // Participants panel
        if (_isParticipantsOpen)
          Positioned(
            right: 0,
            top: 0,
            bottom: 80,
            child: _buildParticipantsPanel(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final meetingProvider = context.watch<MeetingProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        children: [
          // Meeting ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meeting ID',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.meetingId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: Colors.white70,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.meetingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Meeting ID copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Host badge
          if (meetingProvider.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Participant count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${_participantTracks.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
        child: Text(
          'No participants yet',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
      );
    }

    // Calculate grid layout
    final count = _participantTracks.length;
    final columns = count == 1 ? 1 : count == 2 ? 2 : count <= 4 ? 2 : 3;
    final rows = (count / columns).ceil();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _participantTracks.length,
      itemBuilder: (context, index) {
        return _buildParticipantTile(_participantTracks[index]);
      },
    );
  }

  Widget _buildParticipantTile(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final videoTrack = track.videoTrack;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or placeholder
            if (videoTrack != null && !videoTrack.muted)
              VideoTrackRenderer(videoTrack)
            else
              _buildVideoPlaceholder(participant),

            // Participant info overlay
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
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
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLocal ? 'You' : participant.identity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
      color: Colors.grey[800],
      child: Center(
        child: CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blue,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Toggle video
          _buildControlButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: _isVideoEnabled,
            onPressed: _toggleVideo,
          ),

          // Toggle audio
          _buildControlButton(
            icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: _isAudioEnabled,
            onPressed: _toggleAudio,
          ),

          // Chat
          _buildControlButton(
            icon: Icons.chat,
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

          // Participants
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

          // Leave
          _buildControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: false,
            onPressed: _showLeaveDialog,
            backgroundColor: Colors.red,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: backgroundColor ??
                    (isActive
                        ? Colors.blue
                        : Colors.white.withOpacity(0.2)),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(icon),
                color: Colors.white,
                onPressed: onPressed,
                iconSize: 24,
              ),
            ),
            if (badge != null && badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 320,
      color: Colors.white,
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isChatOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                final messages = provider.chatMessages;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
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

          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'You' : username,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
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
      width: 320,
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isParticipantsOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Participants list
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Pending requests (host only)
                      if (provider.isHost &&
                          provider.pendingRequests.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.orange[50],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_empty,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pending Requests (${provider.pendingRequests.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...provider.pendingRequests.map(
                                    (request) => _buildPendingRequest(request),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],

                      // Current participants
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participantTracks.length,
                        itemBuilder: (context, index) {
                          final track = _participantTracks[index];
                          return _buildParticipantListItem(track);
                        },
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () {
              context.read<MeetingProvider>().approveJoinRequest(requestId);
            },
            tooltip: 'Approve',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              context.read<MeetingProvider>().rejectJoinRequest(requestId);
            },
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantListItem(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final name = isLocal ? 'You' : participant.identity;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (context.watch<MeetingProvider>().isHost && isLocal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
            size: 18,
            color: participant.isMicrophoneEnabled()
                ? Colors.grey[600]
                : Colors.red,
          ),
          const SizedBox(width: 8),
          Icon(
            participant.isCameraEnabled() ? Icons.videocam : Icons.videocam_off,
            size: 18,
            color: participant.isCameraEnabled()
                ? Colors.grey[600]
                : Colors.red,
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

    // Scroll to bottom
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
          title: const Text('Leave Meeting?'),
          content: const Text(
            'Are you sure you want to leave this meeting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _leaveMeeting();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveMeeting() async {
    // Disconnect from LiveKit
    await _room?.disconnect();

    // Clear meeting data
    if (mounted) {
      context.read<MeetingProvider>().leaveMeeting();

      // Navigate back
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }
}

// Helper class for participant tracks
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