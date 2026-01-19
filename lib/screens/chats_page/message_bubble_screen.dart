import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/chats_page/view_file_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../providers/personal_chat_provider.dart';

class MessageBubble extends StatefulWidget {
  final String? content;
  final bool isMe;
  final DateTime timestamp;
  final String? status;
  final bool isFile;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String? localFilePath;
  final bool isOptimistic;
  final bool readBy;
  final String messageId;
  final String? receiverId;

  // Voice message properties
  final bool isAudio;
  final String? audioUrl;
  final int? audioDurationMs;
  final String? replyTo;
  final Map<String, dynamic>? replyToMessage;
  final Function(Map<String, dynamic>)? onReply;// Changed name for clarity

  const MessageBubble({
    Key? key,
    this.content,
    required this.isMe,
    required this.timestamp,
    this.status,
    this.isFile = false,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.localFilePath,
    this.isOptimistic = false,
    this.readBy = false,
    required this.messageId,
    this.receiverId,
    this.isAudio = false,
    this.audioUrl,
    this.audioDurationMs,
    this.replyTo,
    this.replyToMessage,
    this.onReply,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {


  // Voice message variables
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isPlayerInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localAudioPath;
  bool _isLoadingAudio = false;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isAudio) {
      _initializePlayer();

      // ✅ CRITICAL: Set initial duration from widget
      if (widget.audioDurationMs != null && widget.audioDurationMs! > 0) {
        _duration = Duration(milliseconds: widget.audioDurationMs!);
        print('✅ Initial duration set: ${_formatDuration(_duration)}');
      } else {
        print('⚠️ No duration provided in widget');
      }
    }
  }

  ScaffoldMessengerState get _scaffoldMessenger => ScaffoldMessenger.of(context);

  Future<void> _initializePlayer() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

// In message_bubble_screen.dart
// Replace the _playPauseAudio method with this fixed version:

  Future<void> _playPauseAudio() async {
    if (!_isPlayerInitialized || _player == null) {
      print('❌ Player not initialized');
      return;
    }

    try {
      if (_isPlaying) {
        // Pause playback
        await _player!.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
        print('⏸️ Paused at ${_formatDuration(_position)}');
      } else {
        // Start/Resume playback
        String? audioPath = await _getAudioPath();
        if (audioPath == null) {
          print('❌ No audio path available');
          return;
        }

        print('🎵 Starting playback: $audioPath');
        print('🎵 Known duration: ${_formatDuration(_duration)}');

        // ✅ Only load duration if we don't have it
        if (_duration == Duration.zero || _duration.inMilliseconds < 100) {
          print('⏳ Loading duration...');
          await _loadAudioDuration(audioPath);
        }

        // Cancel any existing subscription
        await _playerSubscription?.cancel();
        _playerSubscription = null;

        // Start playing
        await _player!.startPlayer(
          fromURI: audioPath,
          whenFinished: () {
            print('🎵 Playback finished');
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
        );

        // Update state immediately
        setState(() {
          _isPlaying = true;
        });

        // Subscribe to progress updates
        _playerSubscription = _player!.onProgress!.listen(
              (event) {
            if (!mounted || !_isPlaying) return;

            setState(() {
              _position = event.position;

              // Update duration if we get a better value
              if (event.duration > Duration.zero &&
                  (_duration == Duration.zero || event.duration != _duration)) {
                _duration = event.duration;
                print('🔄 Duration updated from stream: ${_formatDuration(_duration)}');
              }
            });
          },
          onError: (error) {
            print('⚠️ Progress stream error: $error');
          },
          onDone: () {
            print('🎵 Progress stream completed');
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
          cancelOnError: false,
        );

        print('✅ Playback started successfully');
      }
    } catch (e) {
      print('💥 Playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadAudioDuration(String audioPath) async {
    print('⏳ Loading audio duration from: $audioPath');

    try {
      // Method 1: Use widget duration if available (most reliable)
      if (widget.audioDurationMs != null && widget.audioDurationMs! > 0) {
        final widgetDuration = Duration(milliseconds: widget.audioDurationMs!);
        if (mounted) {
          setState(() {
            _duration = widgetDuration;
          });
        }
        print('✅ Using widget duration: ${_formatDuration(widgetDuration)}');
        return;
      }

      print('⚠️ No widget duration, attempting detection...');

      // Method 2: Try to detect duration by playing briefly
      final tempPlayer = FlutterSoundPlayer();
      await tempPlayer.openPlayer();

      Duration? detectedDuration;
      bool durationFound = false;

      // Start playing to get duration
      await tempPlayer.startPlayer(
        fromURI: audioPath,
        whenFinished: () {},
      );

      // Wait a bit for player to initialize
      await Future.delayed(const Duration(milliseconds: 200));

      // Subscribe to get duration
      final tempSubscription = tempPlayer.onProgress!.listen(
            (event) {
          if (event.duration > Duration.zero && !durationFound) {
            detectedDuration = event.duration;
            durationFound = true;
          }
        },
      );

      // Wait up to 1 second for duration detection
      int attempts = 0;
      while (!durationFound && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Cleanup
      await tempSubscription.cancel();
      await tempPlayer.stopPlayer();
      await tempPlayer.closePlayer();

      // Update duration if found
      if (detectedDuration != null && mounted) {
        setState(() {
          _duration = detectedDuration!;
        });
        print('✅ Detected duration: ${_formatDuration(detectedDuration!)}');
      } else {
        print('! Could not detect audio duration, using widget value');
        // Fallback to widget's audioDurationMs if available
        if (widget.audioDurationMs != null && mounted) {
          setState(() {
            _duration = Duration(milliseconds: widget.audioDurationMs!);
          });
        }
      }
    } catch (e) {
      print('💥 Error loading duration: $e');
      // Last resort: use widget duration
      if (widget.audioDurationMs != null && mounted) {
        setState(() {
          _duration = Duration(milliseconds: widget.audioDurationMs!);
        });
      }
    }
  }

  Future<String?> _getAudioPath() async {
    // If we have local file path and it exists, use it
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final localFile = File(widget.localFilePath!);
      if (await localFile.exists()) {
        return widget.localFilePath;
      }
    }

    // If we have cached audio, use it
    if (_localAudioPath != null && File(_localAudioPath!).existsSync()) {
      return _localAudioPath;
    }

    // Download from server
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      setState(() {
        _isLoadingAudio = true;
      });

      try {
        final response = await http.get(Uri.parse(widget.audioUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'voice_${widget.messageId}.aac';
          final audioFile = File('${tempDir.path}/$fileName');
          await audioFile.writeAsBytes(response.bodyBytes);

          _localAudioPath = audioFile.path;
          return _localAudioPath;
        }
      } catch (e) {
        print('Error downloading audio: $e');
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to load voice message'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }

    return null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildVoiceMessage() {
    // Calculate progress for waveform
    double progress = 0.0;
    if (_duration.inMilliseconds > 0) {
      progress = _position.inMilliseconds / _duration.inMilliseconds;
      progress = progress.clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _isLoadingAudio ? null : _playPauseAudio,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: _isLoadingAudio
                  ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isMe ? Colors.blue : Colors.white,
                  ),
                ),
              )
                  : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.blue : Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform visualization with progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform bars
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(20, (index) {
                      final barProgress = index / 20;
                      final isActive = progress >= barProgress;

                      // Varying heights for waveform effect
                      final heights = [
                        20.0, 15.0, 10.0, 18.0, 12.0, 16.0, 14.0, 20.0, 11.0, 15.0,
                        17.0, 13.0, 19.0, 10.0, 16.0, 14.0, 18.0, 12.0, 15.0, 20.0
                      ];

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: heights[index],
                          decoration: BoxDecoration(
                            color: isActive
                                ? (widget.isMe ? Colors.white : Colors.blue)
                                : (widget.isMe ? Colors.white54 : Colors.grey[400]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),

                // ✅ FIXED: Duration display
                Text(
                  _buildDurationText(),
                  style: TextStyle(
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Status indicators
          if (widget.status == 'sending') ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isMe ? Colors.white70 : Colors.grey[600]!,
                ),
              ),
            ),
          ] else if (widget.status == 'failed') ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.error_outline,
              size: 16,
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
  String _buildDurationText() {
    // If playing or paused with position, show current/total
    if (_isPlaying || _position.inSeconds > 0) {
      return '${_formatDuration(_position)} / ${_formatDuration(_duration)}';
    }

    // If we have duration, show it
    if (_duration.inSeconds > 0) {
      return _formatDuration(_duration);
    }

    // Fallback
    return '0:00';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Primary
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: widget.isMe ? const Radius.circular(4) : null,
                bottomLeft: !widget.isMe ? const Radius.circular(4) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inside the main Container, before content, add:
                if (widget.replyToMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: widget.isMe ? Colors.white : Colors.grey[800]!,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replied to',
                          style: TextStyle(
                            color: widget.isMe ? Colors.white70 : Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyToMessage!['text'] != null && widget.replyToMessage!['text'].toString().isNotEmpty
                              ? widget.replyToMessage!['text']
                              : (widget.replyToMessage!['isFile'] == true
                              ? '📎 ${widget.replyToMessage!['fileName'] ?? 'File'}'
                              : (widget.replyToMessage!['isAudio'] == true
                              ? '🎤 Voice message'
                              : 'Message')),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isMe ? Colors.white70 : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Voice message content
                if (widget.isAudio)
                  _buildVoiceMessage()

                // File content
                else if (widget.isFile && widget.fileUrl != null && widget.fileName != null)

                  GestureDetector(

                    onTap: () => _handleFileOpen(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(widget.fileType),
                            color: widget.isMe ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.fileName!,
                                  style: TextStyle(
                                    color: widget.isMe ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.status == 'sending')
                                  Text(
                                    'Uploading...',
                                    style: TextStyle(
                                      color: widget.isMe ? Colors.white70 : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  )
                                else if (widget.status == 'failed')
                                  Text(
                                    'Failed to upload',
                                    style: TextStyle(
                                      color: widget.isMe ? Colors.white70 : Colors.red[600],
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  Text(
                                    'Tap to open',
                                    style: TextStyle(
                                      color: widget.isMe ? Colors.white70 : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.status != 'sending' && widget.status != 'failed')
                            Icon(
                              Icons.open_in_new,
                              color: widget.isMe ? Colors.white70 : Colors.grey[600],
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  )
                // Text content
                // Text content with clickable URLs
                else if (widget.content != null)
                    ClickableMessageText(
                      text: widget.content!,
                      isMe: widget.isMe,
                    ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.timestamp),
                      style: TextStyle(
                        color: widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (widget.isMe && widget.status != null) ...[
                      const SizedBox(width: 4),
                      if (widget.status == 'sent' && widget.readBy)
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color: Colors.blue[300],
                        )
                      else
                        Icon(
                          _getStatusIcon(),
                          size: 12,
                          color: widget.isMe ? Colors.white70 : Colors.grey[600],
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _showMessageOptions(BuildContext context) {
    // Build options list based on message type
    List<Widget> options = [];

    // REPLY option - available for ALL messages (sent and received)
    options.add(
      ListTile(
        leading: Icon(Icons.reply, color: Theme.of(context).colorScheme.primary),
        title: const Text('Reply'),
        onTap: () {
          Navigator.pop(context);
          if (widget.onReply != null) {
            widget.onReply!({
              '_id': widget.messageId,
              'text': widget.content,
              'isFile': widget.isFile,
              'fileName': widget.fileName,
              'isAudio': widget.isAudio,
              'senderId': widget.isMe ? 'current_user' : 'other_user',
            });
          }
        },
      ),
    );

    // EDIT option - only for MY TEXT messages
    if (widget.isMe &&
        !widget.isFile &&
        !widget.isAudio &&
        widget.content != null &&
        widget.content!.isNotEmpty &&
        !widget.isOptimistic &&
        widget.status != 'sending') {
      options.add(
        ListTile(
          leading: Icon(
            Icons.edit,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Edit Message'),
          onTap: () {
            Navigator.pop(context);
            _showEditDialog(context);
          },
        ),
      );
    }

    // DELETE option - for ALL MY messages (text, file, AND voice)
    if (widget.isMe &&
        !widget.isOptimistic &&
        widget.status != 'sending' &&
        widget.status != 'failed') {
      options.add(
        ListTile(
          leading: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
          title: const Text(
            'Delete Message',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(context);
          },
        ),
      );
    }

    // Show the bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ...options,
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    if (widget.content == null) return;

    final TextEditingController editController = TextEditingController(text: widget.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleEditMessage(context, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleDeleteMessage(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditMessage(BuildContext context, String newText) async {
    if (newText.isEmpty || newText == widget.content) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    if (!mounted) return;

    _scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Editing message...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final provider = context.read<PersonalChatProvider>();
      final result = await provider.editMessage(
        messageId: widget.messageId,
        newText: newText,
        receiverId: widget.receiverId ?? '',
      );

      if (!mounted) return;

      if (result != null && result['error'] != true) {
        _scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Message edited successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to edit message: ${result?['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error editing message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDeleteMessage(BuildContext context) async {
    Navigator.pop(context);

    if (!mounted) return;

    _scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Deleting message...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final provider = context.read<PersonalChatProvider>();
      final result = await provider.deleteMessage(
        messageId: widget.messageId,
        receiverId: widget.receiverId ?? '',
      );

      if (!mounted) return;

      if (result != null && result['error'] != true) {
        _scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Message deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = result?['message'] ?? 'Unknown error';
        if (errorMessage.contains('Cannot DELETE') || errorMessage.contains('404')) {
          errorMessage = 'Message not found. Please refresh the chat.';
        }
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleFileOpen(BuildContext context) async {
    if (widget.fileUrl == null || widget.fileName == null) {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('File information is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.status == 'sending') {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('File is still uploading, please wait'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.status == 'failed') {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('File upload failed, cannot open'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await FileViewerHelper.openFile(
      context: context,
      fileUrl: widget.fileUrl!,
      fileName: widget.fileName!,
      localFilePath: widget.localFilePath,
    );
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;
    final type = fileType.toLowerCase();
    if (type.contains('image')) return Icons.image;
    if (type.contains('audio')) return Icons.audiotrack;
    if (type.contains('video')) return Icons.videocam;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('word') || type.contains('document')) return Icons.description;
    if (type.contains('excel') || type.contains('spreadsheet')) return Icons.table_chart;
    if (type.contains('powerpoint') || type.contains('presentation')) return Icons.slideshow;
    if (type.contains('text')) return Icons.text_snippet;
    if (type.contains('zip') || type.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.done;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.done;
    }
  }

  @override
  void dispose() {
    print('🧹 MessageBubble disposing...');

    // Cancel the progress subscription FIRST
    _playerSubscription?.cancel();
    _playerSubscription = null;

    // Stop player
    if (_isPlaying && _player != null) {
      _player!.stopPlayer().catchError((error) {
        print('⚠️ Error stopping player: $error');
      });
    }

    // Then close player
    if (_player != null) {
      _player!.closePlayer().then((_) {
        print('✅ Audio player closed');
      }).catchError((error) {
        print('⚠️ Error closing player: $error');
      });
      _player = null;
    }

    super.dispose();
    print('✅ MessageBubble disposed');
  }

  @override
  void deactivate() {
    // Cancel subscription when deactivated
    _playerSubscription?.cancel();

    if (_isPlaying && _player != null) {
      _player!.pausePlayer().catchError((error) {
        print('⚠️ Error pausing player: $error');
      });
      setState(() {
        _isPlaying = false;
      });
    }
    super.deactivate();
  }

}

class ClickableMessageText extends StatelessWidget {
  final String text;
  final bool isMe;

  const ClickableMessageText({
    Key? key,
    required this.text,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: _buildTextSpans(),
    );
  }

  TextSpan _buildTextSpans() {
    final List<TextSpan> spans = [];

    // Enhanced regex to detect URLs (http, https, www)
    final urlPattern = RegExp(
      r'(?:(?:https?):\/\/|www\.)'
      r'(?:\S+(?::\S*)?@)?'
      r'(?:'
      r'(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])'
      r'(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}'
      r'(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))'
      r'|'
      r'(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+'
      r'(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*'
      r'(?:\.(?:[a-z\u00a1-\uffff]{2,}))'
      r')'
      r'(?::\d{2,5})?'
      r'(?:[/?#]\S*)?',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    int currentPosition = 0;

    for (final match in matches) {
      // Add text before URL
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ));
      }

      // Add clickable URL with VERY visible styling
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          // ✅ BRIGHT COLORS - Very visible!
          color: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          fontSize: 16,
          // ✅ UNDERLINE - Makes it obvious it's a link
          decoration: TextDecoration.underline,
          decorationColor: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          decorationThickness: 2.0, // ✅ Thicker underline
          fontWeight: FontWeight.w600, // ✅ Bold text
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchURL(url),
      ));

      currentPosition = match.end;
    }

    // Add remaining text after last URL
    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _launchURL(String urlString) async {
    // Add https:// if URL starts with www.
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }

    final Uri url = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}