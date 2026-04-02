import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/personal_chat_provider.dart';
import '../../providers/video_call_provider.dart';
import '../../providers/voice_call_provider.dart';
import '../video_call/video_call_initiate_.dart';
import '../voice_call/outgoing_voice_call.dart';
import './message_bubble_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/notification_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String chatTitle;
  final Map<String, dynamic> userProfile;

  const ChatDetailScreen({
    Key? key,
    required this.userId,
    required this.chatTitle,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}
bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedFile;
  bool _isSending = false;
  String? _userId;
  late NotificationProvider _notificationProvider;

  // Voice recording
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordingTimer;

  late PersonalChatProvider _chatProvider;
  Map<String, dynamic>? _replyingToMessage;

  // ── Max sizes before compression triggers ────────────────────────────────
  static const int _maxImageBytes = 800 * 1024; // 800 KB
  static const int _maxAudioBytes = 4 * 1024 * 1024; // 4 MB

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _chatProvider = context.read<PersonalChatProvider>();
      _notificationProvider = context.read<NotificationProvider>();

      // ✅ Auto scroll when new message arrives via socket
      _chatProvider.onNewMessageReceived = () {
        if (mounted) _scrollToBottom();
      };

      await _initializeChatNotifications();
      _chatProvider.clearUnreadCount(widget.userId);
      await _chatProvider.fetchConversation(widget.userId);
      await _chatProvider.updateReadStatus(
        senderId: widget.userId,
        receiverId: _chatProvider.currentUserId!,
      );
      _scrollToBottom();
    });
  }
  Widget _buildDateDivider(DateTime dt) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ]),
    );
  }

  Future<void> _initializeChatNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      if (_userId != null && mounted) {
        await _notificationProvider.markChatAsRead(
            chatId: widget.userId, type: 'Conversation');
        await _notificationProvider.markChatAsRead(
            chatId: widget.userId, type: 'Message');
        _notificationProvider.activateChat(
            userId: _userId!, type: 'Conversation', chatId: widget.userId);
      }
    } catch (e) {
      print('💥 Error initializing chat notifications: $e');
    }
  }

  void _setReplyMessage(Map<String, dynamic> message) =>
      setState(() => _replyingToMessage = message);

  void _clearReply() => setState(() => _replyingToMessage = null);

  Map<String, dynamic>? _getMessageById(String messageId) {
    try {
      return context
          .read<PersonalChatProvider>()
          .messages
          .firstWhere((m) => m['_id'] == messageId);
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  COMPRESSION HELPERS
  // ════════════════════════════════════════════════════════════════════════

  /// Returns a readable file size string
  String _readableSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  /// Compresses an image file, returns compressed File
  /// Tries quality 80 → 60 → 40 until under _maxImageBytes
  Future<File> _compressImage(File imageFile) async {
    final ext = p.extension(imageFile.path).toLowerCase();
    final format = ext == '.png' ? CompressFormat.png : CompressFormat.jpeg;
    final tmpDir = await getTemporaryDirectory();
    final outExt = ext == '.png' ? 'png' : 'jpg';

    for (final quality in [80, 60, 40, 25]) {
      final Uint8List? result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
        format: format,
        keepExif: false,
      );
      if (result == null) break;

      final outPath = p.join(
          tmpDir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.$outExt');
      final outFile = File(outPath)..writeAsBytesSync(result);

      print(
          '🗜️ [Compress] quality=$quality → ${_readableSize(result.length)}');

      if (result.length <= _maxImageBytes || quality == 25) return outFile;
    }
    return imageFile; // fallback: original
  }

  /// Re-encodes audio to lower bitrate AAC using flutter_sound
  /// If file is already small enough, returns original unchanged
  Future<File> _compressAudio(File audioFile) async {
    final size = await audioFile.length();
    if (size <= _maxAudioBytes) {
      print(
          '🎵 [Compress] Audio already ${_readableSize(size)} — no compression needed');
      return audioFile;
    }

    // flutter_sound can't transcode directly; we trim silence / downgrade
    // by re-recording isn't possible here. Best approach: warn + still send
    // (server 413 handled below). For actual transcoding add ffmpeg_kit_flutter.
    print(
        '⚠️ [Compress] Audio ${_readableSize(size)} exceeds limit — sending as-is');
    return audioFile;
  }

  /// Returns true if extension is an image type
  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic']
        .contains(ext);
  }

  /// Master compress: auto-detects type and compresses
  Future<File> _compressFile(File file) async {
    final origSize = await file.length();
    print(
        '📦 [Compress] Original: ${file.path.split('/').last} ${_readableSize(origSize)}');

    File result;
    if (_isImageFile(file.path)) {
      result = await _compressImage(file);
    } else {
      result = await _compressAudio(file);
    }

    final newSize = await result.length();
    if (newSize < origSize) {
      final saved = ((origSize - newSize) / origSize * 100).toStringAsFixed(0);
      print(
          '✅ [Compress] ${_readableSize(origSize)} → ${_readableSize(newSize)} ($saved% smaller)');
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECORDER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _initializeRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        await _recorder!.openRecorder();
        setState(() => _isRecorderInitialized = true);
        print('✅ Recorder initialized');
      } else {
        _showPermissionDialog();
      }
    } catch (e) {
      print('💥 Error initializing recorder: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
            'To send voice messages, allow microphone access in settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized || _recorder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Voice recorder not available'),
          backgroundColor: Colors.red));
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${dir.path}/$fileName';
      await _recorder!
          .startRecorder(toFile: _recordingPath, codec: Codec.aacMP4);
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _startDurationTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        _showVoicePreview();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _startDurationTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isRecording && mounted) {
        setState(() => _recordingDuration = Duration(seconds: t.tick));
      } else {
        t.cancel();
      }
    });
  }

  void _showVoicePreview() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 25, color: Colors.blue),
              const SizedBox(height: 16),
              Text('Voice message recorded',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(_recordingDuration)}'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRecording();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.red),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendVoiceMessage();
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendVoiceMessage() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No voice recording found'),
          backgroundColor: Colors.red));
      return;
    }

    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) return;

    try {
      final durationMs = _recordingDuration.inMilliseconds;
      final durationStr = _formatDuration(_recordingDuration);
      print('📤 Voice: $durationStr ($durationMs ms) — $_recordingPath');

      final audioFile = File(_recordingPath!);

      // ── Compress audio if needed ──────────────────────────────────
      final uploadFile = await _compressFile(audioFile);
      // ─────────────────────────────────────────────────────────────

      final response = await provider.sendVoiceMessage(
        audioFile: uploadFile,
        receiverId: receiverId,
        readBy: false,
        replyTo: _replyingToMessage?['_id'],
        audioDurationMs: durationMs,
      );

      _clearReply();

      if (response != null) {
        _scrollToBottom();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Voice message sent! ($durationStr)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Failed to send voice message: ${provider.sendMessageError ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      print('💥 Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      _deleteRecording();
    }
  }

  void _deleteRecording() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        File(_recordingPath!).deleteSync();
      } catch (_) {}
      _recordingPath = null;
    }
    if (mounted)
      setState(() => _recordingDuration = Duration.zero);
    else
      _recordingDuration = Duration.zero;
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CAMERA & FILE PICKER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _messageController.text = _selectedFile!.path.split('/').last;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _messageController.text = _selectedFile!.path.split('/').last;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  void _sendMessage() async {
    if (_isSending) return;

    final content = _messageController.text.trim();
    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Unable to send message'),
          backgroundColor: Colors.red));
      return;
    }

    // ── File message ────────────────────────────────────────────────────
    if (_selectedFile != null) {
      setState(() => _isSending = true);
      final rawFile = _selectedFile!;

      setState(() {
        _selectedFile = null;
        _messageController.clear();
      });

      try {
        // ── COMPRESS before upload ────────────────────────────────────
        final fileToSend = await _compressAndWarnUser(rawFile);
        // ─────────────────────────────────────────────────────────────

        final response = await provider.sendFileMessage(
          file: fileToSend,
          receiverId: receiverId,
          readBy: false,
          replyTo: _replyingToMessage?['_id'],
        );
        _clearReply();

        if (response != null) {
          _scrollToBottom();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Failed to send: ${provider.sendMessageError ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }

      // ── Text message ────────────────────────────────────────────────────
    } else if (content.isNotEmpty) {
      setState(() => _isSending = true);
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });

      try {
        final result = await provider.sendMessage(
          receiverId: receiverId,
          text: content,
          readBy: false,
          replyTo: _replyingToMessage?['_id'],
        );
        _clearReply();

        if (result != null &&
            (result['error'] == false || result['success'] == true)) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _scrollToBottom();
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${result?['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  /// Compresses a file and shows a brief snackbar if it was reduced
  Future<File> _compressAndWarnUser(File rawFile) async {
    final origSize = await rawFile.length();
    final compressed = await _compressFile(rawFile);
    final newSize = await compressed.length();

    if (newSize < origSize && mounted) {
      final saved = ((origSize - newSize) / origSize * 100).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '📦 Compressed: ${_readableSize(origSize)} → ${_readableSize(newSize)} ($saved% smaller)',
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ));
    }
    return compressed;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final profileImage = widget.userProfile['profile']['profileImage'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Primary),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? (profileImage.startsWith('data:image/')
                        ? MemoryImage(base64Decode(profileImage.split(',')[1]))
                        : NetworkImage(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        widget.chatTitle.isNotEmpty
                            ? widget.chatTitle[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatTitle,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<VoiceCallProvider>(
            builder: (context, voiceCallProvider, _) => IconButton(
              icon: Image.asset('assets/icons/call.png',
                  width: 18, height: 18, color: Colors.grey[800]),
              tooltip: 'Audio Call',
              onPressed:
                  voiceCallProvider.isConnected ? _initiateVoiceCall : null,
            ),
          ),
          const SizedBox(width: 10),
          Consumer<VideoCallProvider>(
            builder: (context, videoCallProvider, _) => IconButton(
              icon: Image.asset('assets/icons/video.png',
                  width: 24, height: 24, color: Colors.grey[800]),
              tooltip: 'Video Call',
              onPressed:
                  videoCallProvider.isConnected ? _handleVideoCall : null,
            ),
          ),
          const SizedBox(width: 20),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        shadowColor: Colors.grey[200],
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<PersonalChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('Loading conversation...',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.red[50], shape: BoxShape.circle),
                    child: Icon(Icons.error_outline,
                        size: 48, color: Colors.red[400]),
                  ),
                  const SizedBox(height: 20),
                  Text('Oops! Something went wrong',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  Text(provider.error ?? 'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14, height: 1.4)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => provider.fetchConversation(widget.userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Try Again',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            );
          }

          final messages = provider.messages ?? [];

          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle),
                            child: Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 24),
                          Text('No messages yet',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Text(
                              'Start the conversation by sending a message below',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  height: 1.4)),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            provider.fetchConversation(widget.userId),
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Colors.white,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final message = messages[index];

// ✅ Debug shared post
                      if (message['isSharedPost'] == true || message['sharedPost'] != null ||
                          (message['text']?.toString() ?? '').contains('Forwarded')) {
                        print('🔍 SHARED POST MESSAGE: ${jsonEncode(message)}');
                      }

                      if (message['isDelete'] == true)
                        return const SizedBox.shrink();

                      final isMe = message['senderId'] == provider.currentUserId;
                      final msgTime = DateTime.parse(message['createdAt']).toLocal();

                      DateTime? prevTime;
                      for (int j = index - 1; j >= 0; j--) {
                        if (messages[j]['isDelete'] != true) {
                          prevTime = DateTime.parse(messages[j]['createdAt']).toLocal();
                          break;
                        }
                      }
                      final showDateDiv = prevTime == null || !_sameDay(msgTime, prevTime);

                      Map<String, dynamic>? repliedMessage;
                      if (message['replyTo'] != null) {
                        repliedMessage = _getMessageById(message['replyTo']);
                      }

                      return Column(
                        children: [
                          if (showDateDiv) _buildDateDivider(msgTime),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MessageBubble(
                              replyTo: message['replyTo'],
                              replyToMessage: repliedMessage,
                              onReply: (msg) => _setReplyMessage(msg),
                              content: message['text'],
                              isMe: isMe,
                              timestamp: DateTime.parse(message['createdAt']),
                              status: message['status'],
                              isFile: message['isFile'] ?? false,
                              fileUrl: message['fileUrl'],
                              fileName: message['fileName'],
                              fileType: message['fileType'],
                              localFilePath: message['localFilePath'],
                              isOptimistic: message['isOptimistic'] ?? false,
                              readBy: message['readBy'] ?? false,
                              messageId: message['_id'] ?? '',
                              receiverId: isMe ? message['receiverId'] : message['senderId'],
                              isAudio: message['isAudio'] ?? false,
                              audioUrl: message['audioUrl'],
                              // ✅ Pass shared post data
                              isSharedPost: message['forwerd'] == true ||
                                  message['forwerdMessage'] != null ||
                                  message['isSharedPost'] == true ||
                                  message['sharedPost'] != null,
                              sharedPostData: _resolveSharedPostData(message),
                            ),
                          ),
                        ],
                      );
                    },

                  ),

                      ),
              ),

              // Recording indicator
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border(top: BorderSide(color: Colors.red[200]!)),

                  ),
                  child: Row(
                    children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Text(
                          'Recording... ${_formatDuration(_recordingDuration)}',
                          style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      TextButton(
                          onPressed: _stopRecording, child: const Text('Stop')),
                    ],
                  ),
                ),

              _buildInputBar(provider),
            ],
          );
        },
      ),
    );
  }
  Map<String, dynamic>? _resolveSharedPostData(Map<String, dynamic> message) {
    final direct = message['sharedPost'];
    if (direct is Map<String, dynamic>) return direct;

    final isForwarded = message['forwerd'] == true ||
        message['forwerdMessage'] != null;

    if (isForwarded) {
      final image = message['image']?.toString() ?? '';
      final text = message['text']?.toString() ?? '';
      final forwardLabel = message['forwerdMessage']?.toString() ?? '';

      // ✅ Extract actual postId from forwerdUrl
      // forwerdUrl format: "https://ixes.ai/feeds/6954b0fcfb282e4eb94cee1a"
      String actualPostId = '';
      final forwerdUrl = message['forwerdUrl']?.toString() ?? '';
      if (forwerdUrl.isNotEmpty) {
        actualPostId = forwerdUrl.split('/').last;
      }
      // Fallback to sharedPostId if forwerdUrl not available
      if (actualPostId.isEmpty) {
        actualPostId = message['sharedPostId']?.toString() ?? '';
      }

      print('✅ Resolved postId: $actualPostId from forwerdUrl: $forwerdUrl');

      return {
        '_id': actualPostId,
        'text': text,
        'images': image.isNotEmpty ? [image] : [],
        'authorName': forwardLabel,
        'authorProfile': '',
        'likesCount': 0,
        'commentsCount': 0,
      };
    }

    return null;
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(PersonalChatProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply preview
              if (_replyingToMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: Primary, width: 3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Replying to ${_replyingToMessage!['senderId'] == provider.currentUserId ? 'yourself' : widget.chatTitle}',
                              style: TextStyle(
                                  color: Primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _replyingToMessage!['text'] ??
                                  (_replyingToMessage!['isFile'] == true
                                      ? '📎 ${_replyingToMessage!['fileName']}'
                                      : (_replyingToMessage!['isAudio'] == true
                                          ? '🎤 Voice message'
                                          : '')),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 20, color: Colors.grey[600]),
                        onPressed: _clearReply,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),

              // File preview chip
              if (_selectedFile != null) _buildFilePreviewChip(),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('message_input_field'),
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: _selectedFile != null
                                    ? 'Add a caption...'
                                    : 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[800]),
                              cursorColor: Primary,
                              enabled: !_isSending,
                              onSubmitted: (_) {
                                if (!_isSending &&
                                    (_messageController.text
                                            .trim()
                                            .isNotEmpty ||
                                        _selectedFile != null)) {
                                  _sendMessage();
                                }
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                  icon: Icon(Icons.camera_alt,
                                      size: 20,
                                      color:
                                          (_selectedFile == null && !_isSending)
                                              ? Primary
                                              : Colors.grey[500]),
                                  onPressed:
                                      (_selectedFile == null && !_isSending)
                                          ? _capturePhoto
                                          : null,
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                  icon: Icon(Icons.attach_file,
                                      size: 20,
                                      color:
                                          (_selectedFile == null && !_isSending)
                                              ? Primary
                                              : Colors.grey[500]),
                                  onPressed:
                                      (_selectedFile == null && !_isSending)
                                          ? _pickFile
                                          : null,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isSending
                                        ? Colors.grey[400]
                                        : const Color(0xFF6C5CE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isSending
                                      ? const Center(
                                          child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          Colors.white))))
                                      : IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                          icon: const Icon(Icons.send,
                                              size: 18, color: Colors.white),
                                          onPressed:
                                              _isSending ? null : _sendMessage,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Primary,
                        shape: BoxShape.circle),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                          size: 22, color: Colors.white),
                      onPressed: _isSending
                          ? null
                          : (_isRecording ? _stopRecording : _startRecording),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows selected file name with size info and a clear button
  Widget _buildFilePreviewChip() {
    return FutureBuilder<int>(
      future: _selectedFile!.length(),
      builder: (context, snap) {
        final sizeStr = snap.hasData ? _readableSize(snap.data!) : '...';
        final name = _selectedFile!.path.split('/').last;
        final isImg = _isImageFile(_selectedFile!.path);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(isImg ? Icons.image : Icons.attach_file,
                  size: 18, color: Primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500)),
                    Text(sizeStr,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (isImg && snap.hasData && snap.data! > _maxImageBytes)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Will compress',
                      style:
                          TextStyle(fontSize: 10, color: Colors.orange[800])),
                ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => setState(() {
                  _selectedFile = null;
                  _messageController.clear();
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALLS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _handleVideoCall() async {
    final videoCallProvider = context.read<VideoCallProvider>();
    final receiverId = widget.userProfile['_id'];
    final receiverName = widget.chatTitle;
    if (receiverId == null || receiverId.isEmpty) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final isBusy = await videoCallProvider.checkUserBusy(receiverId);
      if (mounted) Navigator.of(context).pop();
      if (isBusy) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$receiverName is currently in another call'),
            backgroundColor: Colors.orange));
        return;
      }
      await videoCallProvider.initiateCall(
          receiverId: receiverId, receiverName: receiverName);
      if (videoCallProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(videoCallProvider.errorMessage!),
            backgroundColor: Colors.red));
        videoCallProvider.clearMessages();
        return;
      }
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => CallingScreen()));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _initiateVoiceCall() async {
    final voiceCallProvider = context.read<VoiceCallProvider>();
    final receiverId = widget.userProfile['_id'];
    if (receiverId == null || receiverId.isEmpty) return;
    voiceCallProvider.clearMessages();
    await voiceCallProvider.initiateVoiceCall(
        receiverId: receiverId,
        receiverName: widget.chatTitle,
        isConference: false);
    if (voiceCallProvider.callState == VoiceCallState.calling && mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VoiceCallingScreen()));
    } else if (voiceCallProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(voiceCallProvider.errorMessage!),
          backgroundColor: Colors.red));
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════
  @override
  void deactivate() {
    if (_userId != null) {
      try {
        _notificationProvider.deactivateChat(
            userId: _userId!, type: 'chat', chatId: widget.userId);
      } catch (_) {}
    }
    if (_chatProvider.currentUserId != null &&
        _chatProvider.currentReceiverId != null) {
      _chatProvider.leaveConversation();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _chatProvider.onNewMessageReceived = null; // ✅ clear callbac
    _recordingTimer?.cancel();
    if (_userId != null) {
      try {
        _notificationProvider.deactivateChat(
            userId: _userId!, type: 'chat', chatId: widget.userId);
      } catch (_) {}
    }
    if (_chatProvider.currentUserId != null &&
        _chatProvider.currentReceiverId != null) {
      _chatProvider.leaveConversation();
    }
    _messageController.dispose();
    _scrollController.dispose();
    _recorder?.closeRecorder();
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        File(_recordingPath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }
}
