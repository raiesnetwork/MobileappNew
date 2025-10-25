import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
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
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final ScaffoldMessengerState _scaffoldMessenger;

  // Voice message variables
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isPlayerInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localAudioPath;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAudio) {
      _initializePlayer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

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

  Future<void> _playPauseAudio() async {
    if (!_isPlayerInitialized || _player == null) return;

    try {
      if (_isPlaying) {
        await _player!.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Get audio file path
        String? audioPath = await _getAudioPath();
        if (audioPath == null) return;

        // Start playing
        await _player!.startPlayer(
          fromURI: audioPath,
          whenFinished: () {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          },
        );

        // Set up position stream
        _player!.onProgress!.listen((event) {
          setState(() {
            _position = event.position;
            _duration = event.duration;
          });
        });

        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error playing voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              child: Icon(
                _isLoadingAudio
                    ? Icons.hourglass_empty
                    : _isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: widget.isMe ? Colors.blue : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform visualization (simplified)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simple waveform representation
                Container(
                  height: 20,
                  child: Row(
                    children: List.generate(20, (index) {
                      final isActive = _isPlaying &&
                          (_position.inMilliseconds / _duration.inMilliseconds) * 20 > index;
                      return Container(
                        width: 2,
                        height: (index % 3 == 0) ? 20 : (index % 2 == 0) ? 15 : 10,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (widget.isMe ? Colors.white : Colors.blue)
                              : (widget.isMe ? Colors.white54 : Colors.grey[400]),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),

                // Duration
                Text(
                  _isPlaying && _duration > Duration.zero
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : _duration > Duration.zero
                      ? _formatDuration(_duration)
                      : '0:00',
                  style: TextStyle(
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator for voice messages
          if (widget.status == 'sending')
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isMe ? Colors.white70 : Colors.grey[600]!,
                ),
              ),
            )
          else if (widget.status == 'failed')
            Icon(
              Icons.error_outline,
              size: 16,
              color: Colors.red,
            ),
        ],
      ),
    );
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
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: widget.isMe ? const Radius.circular(4) : null,
                bottomLeft: !widget.isMe ? const Radius.circular(4) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                else if (widget.content != null)
                    Text(
                      widget.content!,
                      style: TextStyle(
                        color: widget.isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
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
    // Don't show options for voice messages, files, or messages being sent
    if (!widget.isMe || widget.isFile == true || widget.isAudio == true ||
        widget.isOptimistic || widget.status == 'sending') {
      return;
    }

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

  // Keep existing file handling methods
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

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening file...'),
              ],
            ),
          );
        },
      );

      File? fileToOpen;

      if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
        final localFile = File(widget.localFilePath!);
        if (await localFile.exists()) {
          fileToOpen = localFile;
        }
      }

      if (fileToOpen == null && widget.fileUrl != null) {
        if (_isUrl(widget.fileUrl!)) {
          final tempDir = await getTemporaryDirectory();
          final tempFilePath = '${tempDir.path}/${widget.fileName!}';
          final tempFile = File(tempFilePath);

          if (await tempFile.exists()) {
            final fileSize = await tempFile.length();
            if (fileSize > 0) {
              fileToOpen = tempFile;
            } else {
              await tempFile.delete();
            }
          }

          if (fileToOpen == null) {
            final response = await http.get(Uri.parse(widget.fileUrl!));
            if (response.statusCode == 200) {
              if (response.bodyBytes.isEmpty) {
                throw Exception('Downloaded file is empty');
              }
              await tempFile.writeAsBytes(response.bodyBytes);
              fileToOpen = tempFile;
            } else {
              throw Exception('Failed to download file: HTTP ${response.statusCode}');
            }
          }
        } else {
          fileToOpen = File(widget.fileUrl!);
          if (!await fileToOpen.exists()) {
            throw Exception('File not found at path: ${widget.fileUrl}');
          }
        }
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (fileToOpen == null) {
        throw Exception('Unable to locate file');
      }

      final result = await OpenFile.open(fileToOpen.path);
      if (result.type != ResultType.done) {
        String errorMessage = result.message ?? 'Cannot open file';
        if (result.type == ResultType.noAppToOpen) {
          errorMessage = 'No app available to open this file type (.${widget.fileName!.split('.').last})';
        }
        throw Exception(errorMessage);
      }

    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  bool _isUrl(String path) {
    try {
      final uri = Uri.tryParse(path);
      if (uri == null) return false;
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (e) {
      return false;
    }
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
    if (_player != null) {
      _player!.closePlayer();
    }
    super.dispose();
  }
}