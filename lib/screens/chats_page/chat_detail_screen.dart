import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
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

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedFile;
  bool _isSending = false;
  // ✅ ADD THESE
  String? _userId;
  late NotificationProvider _notificationProvider;// Add this to prevent duplicate sends

  // Voice recording variables
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordingTimer;

  late PersonalChatProvider _chatProvider;
  Map<String, dynamic>? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Store the provider reference
      _chatProvider = context.read<PersonalChatProvider>();

      // ✅ ADD THESE LINES
      _notificationProvider = context.read<NotificationProvider>();
      await _initializeChatNotifications();

      await _chatProvider.fetchConversation(widget.userId);

      // After fetching, mark as read
      await _chatProvider.updateReadStatus(
        senderId: widget.userId,
        receiverId: _chatProvider.currentUserId!,
      );

      // Scroll to bottom after messages load
      _scrollToBottom();
    });
  }
  /// ✅ Initialize chat and clear notifications
  // In chat_detail_screen.dart

  /// ✅ Initialize chat and clear notifications
  Future<void> _initializeChatNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');

      if (_userId != null && mounted) {
        // ✅ FIX 1: Use correct notification type
        // Personal chat notifications typically use 'Conversation' or 'Message' type
        // Try both to be safe
        await _notificationProvider.markChatAsRead(
          chatId: widget.userId, // This is the sender's ID
          type: 'Conversation', // Try this first
        );

        // Also try 'Message' type if your backend uses that
        await _notificationProvider.markChatAsRead(
          chatId: widget.userId,
          type: 'Message',
        );

        // ✅ FIX 2: Activate chat to prevent new notifications
        _notificationProvider.activateChat(
          userId: _userId!,
          type: 'Conversation', // Match the type above
          chatId: widget.userId,
        );

        print('✅ Chat notifications cleared for userId: ${widget.userId}');
      }
    } catch (e) {
      print('💥 Error initializing chat notifications: $e');
    }
  }
  void _setReplyMessage(Map<String, dynamic> message) {
    setState(() {
      _replyingToMessage = message;
    });

  }
  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress image to reduce file size
      );

      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _messageController.text = _selectedFile!.path.split('/').last;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  Map<String, dynamic>? _getMessageById(String messageId) {
    final provider = context.read<PersonalChatProvider>();
    try {
      return provider.messages.firstWhere(
            (msg) => msg['_id'] == messageId,
      );
    } catch (e) {
      return null;
    }
  }

  // Initialize voice recorder
  Future<void> _initializeRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        await _recorder!.openRecorder();
        setState(() {
          _isRecorderInitialized = true;
        });
        print('✅ Voice recorder initialized successfully');
      } else {
        print('❌ Microphone permission denied');
        _showPermissionDialog();
      }
    } catch (e) {
      print('💥 Error initializing recorder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize voice recorder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
            'To send voice messages, please allow microphone access in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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

  // Start voice recording
  Future<void> _startRecording() async {
    if (!_isRecorderInitialized || _recorder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recorder not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero; // ✅ Reset to zero
      });

      _startDurationTimer();
      print('🎤 Started recording to: $_recordingPath');
    } catch (e) {
      print('💥 Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Stop voice recording
  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;

    try {
      // ✅ Cancel timer first
      _recordingTimer?.cancel();
      _recordingTimer = null;

      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      print('🎤 Stopped recording. File: $_recordingPath');
      print('🎤 Duration: ${_formatDuration(_recordingDuration)}');

      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        _showVoicePreview();
      }
    } catch (e) {
      print('💥 Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Timer for recording duration
  void _startDurationTimer() {
    // Cancel any existing timer
    _recordingTimer?.cancel();

    // Start new timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Show voice message preview
  void _showVoicePreview() {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // ✅ Prevent accidental dismissal
      enableDrag: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 25, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Voice message recorded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: ${_formatDuration(_recordingDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRecording(); // ✅ Properly cleanup
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.red,
                    ),
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
                      foregroundColor: Colors.white,
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

  // Send voice message
  // In chat_detail_screen.dart
// Replace the ENTIRE _sendVoiceMessage method with this:

  Future<void> _sendVoiceMessage() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No voice recording found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to send voice message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final audioFile = File(_recordingPath!);

      // ✅ CRITICAL: Capture duration BEFORE any async operations
      final durationMs = _recordingDuration.inMilliseconds;
      final durationStr = _formatDuration(_recordingDuration);

      print('📤 Preparing to send voice message');
      print('📤 Duration: $durationStr ($durationMs ms)');
      print('📤 File: $_recordingPath');

      // Send voice message with duration
      final response = await provider.sendVoiceMessage(
        audioFile: audioFile,
        receiverId: receiverId,
        readBy: false,
        replyTo: _replyingToMessage?['_id'],
        audioDurationMs: durationMs, // ✅ PASS DURATION HERE
      );

      _clearReply();

      if (response != null) {
        // ✅ VERIFY: Check if duration was properly saved
        final savedMessage = response['message'];
        if (savedMessage != null) {
          final savedDuration = savedMessage['audioDurationMs'];
          if (savedDuration != null) {
            print('✅ Voice sent with duration: $savedDuration ms');
          } else {
            print('⚠️ Warning: Duration not in response, but was sent: $durationMs ms');
          }
        }

        _scrollToBottom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice message sent! ($durationStr)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to send voice message: ${provider.sendMessageError ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _deleteRecording(); // ✅ This properly resets timer and path
    }
  }

  // Delete recording file
  void _deleteRecording() {
    // ✅ Cancel timer when deleting
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        File(_recordingPath!).deleteSync();
        _recordingPath = null;
      } catch (e) {
        print('⚠️ Error deleting recording file: $e');
      }
    }

    // ✅ Only call setState if widget is still mounted
    if (mounted) {
      setState(() {
        _recordingDuration = Duration.zero;
      });
    } else {
      // ✅ If not mounted, just reset the variable directly
      _recordingDuration = Duration.zero;
    }

    print('🗑️ Recording deleted and timer reset');
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Quick scroll to bottom for new messages
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendMessage() async {
    // Prevent duplicate sends
    if (_isSending) {
      print('⚠️ Already sending a message, ignoring duplicate call');
      return;
    }

    final content = _messageController.text.trim();
    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to send message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // File message
    if (_selectedFile != null) {
      setState(() => _isSending = true);
      final fileToSend = _selectedFile!;

      // Clear input IMMEDIATELY before sending
      setState(() {
        _selectedFile = null;
        _messageController.clear();
      });

      try {
        final response = await provider.sendFileMessage(
          file: fileToSend,
          receiverId: receiverId,
          readBy: false,
          replyTo: _replyingToMessage?['_id'],
        );
        _clearReply(); // ADD THIS LINE


        if (response != null) {
          _scrollToBottom();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to send file: ${provider.sendMessageError ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
    }
    // Text message
    else if (content.isNotEmpty) {
      setState(() => _isSending = true);
      final messageText = content;

      // Clear input IMMEDIATELY before sending
      _messageController.clear();

      // Scroll immediately to show optimistic message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });

      try {
        final result = await provider.sendMessage(
          receiverId: receiverId,
          text: messageText,
          readBy: false,
          replyTo: _replyingToMessage?['_id'],
        );
        _clearReply();

        if (result != null &&
            (result['error'] == false || result['success'] == true)) {
          print('✅ Message sent successfully');
          // Scroll again after real message arrives
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _scrollToBottom();
          });
        } else {
          print('❌ Failed to send message');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to send message: ${result?['message'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('💥 Error sending message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
    }
  }

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
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        // In the AppBar actions section, replace the existing IconButtons:

        actions: [
          // Audio Call Button
          Consumer<VoiceCallProvider>(
            builder: (context, voiceCallProvider, child) {
              return IconButton(
                icon: Image.asset(
                  'assets/icons/call.png',
                  width: 24,
                  height: 24,
                  color: Colors.grey[800],
                ),
                tooltip: 'Audio Call',
                onPressed: voiceCallProvider.isConnected
                    ? () => _initiateVoiceCall()
                    : null,
              );
            },
          ),

          const SizedBox(width: 10),

          // Video Call Button
          Consumer<VideoCallProvider>(
            builder: (context, videoCallProvider, child) {
              return IconButton(
                icon: Image.asset(
                  'assets/icons/video.png',
                  width: 24,
                  height: 24,
                  color: Colors.grey[800],
                ),
                onPressed: videoCallProvider.isConnected
                    ? () => _handleVideoCall()
                    : null,
                tooltip: 'Video Call',
              );
            },
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
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading conversation...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error ?? 'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        provider.fetchConversation(widget.userId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final messages = provider.messages ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation by sending a message below',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchConversation(widget.userId);
                  },
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final message = messages[index];

                      // ✅ SKIP DELETED MESSAGES - DON'T RENDER THEM AT ALL
                      if (message['isDelete'] == true) {
                        return const SizedBox.shrink(); // Returns empty widget
                      }

                      final isMe = message['senderId'] == provider.currentUserId;
                      Map<String, dynamic>? repliedMessage;
                      if (message['replyTo'] != null) {
                        repliedMessage = _getMessageById(message['replyTo']);
                      }

                      return Padding(
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
                        ),
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
                    border: Border(
                      top: BorderSide(color: Colors.red[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recording... ${_formatDuration(_recordingDuration)}',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _stopRecording,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    // REPLACE the entire section from line ~890 onwards with this:

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply preview (OUTSIDE the TextField container)
                        if (_replyingToMessage != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(color: Primary, width: 3),
                              ),
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
                                          fontSize: 12,
                                        ),
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
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                                  onPressed: _clearReply,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Message input row with mic button outside
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Message input container
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    // TextField
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
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                        maxLines: null,
                                        textCapitalization: TextCapitalization.sentences,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                        ),
                                        cursorColor: Primary,
                                        enabled: !_isSending,
                                        onSubmitted: (_) {
                                          if (!_isSending &&
                                              (_messageController.text.trim().isNotEmpty ||
                                                  _selectedFile != null)) {
                                            _sendMessage();
                                          }
                                        },
                                      ),
                                    ),

                                    // Action buttons inside text field
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Camera button (replaces mic)
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            icon: Icon(
                                              Icons.camera_alt,
                                              size: 20,
                                              color: (_selectedFile == null && !_isSending)
                                                  ? Primary
                                                  : Colors.grey[500],
                                            ),
                                            onPressed: (_selectedFile == null && !_isSending)
                                                ? _capturePhoto
                                                : null,
                                          ),

                                          // File attachment button
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            icon: Icon(
                                              Icons.attach_file,
                                              size: 20,
                                              color: (_selectedFile == null && !_isSending)
                                                  ? Primary
                                                  : Colors.grey[500],
                                            ),
                                            onPressed: (_selectedFile == null && !_isSending)
                                                ? _pickFile
                                                : null,
                                          ),

                                          const SizedBox(width: 4),

                                          // Send button
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
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                                ),
                                              ),
                                            )
                                                : IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              icon: const Icon(Icons.send,
                                                  size: 18, color: Colors.white),
                                              onPressed: _isSending ? null : _sendMessage,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Mic button (OUTSIDE text field on RIGHT side)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.red : Primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  size: 22,
                                  color: Colors.white,
                                ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleVideoCall() async {
    final videoCallProvider = context.read<VideoCallProvider>();
    final receiverId = widget.userProfile['_id'];
    final receiverName = widget.chatTitle;

    if (receiverId == null || receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot initiate call: Invalid user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Check if user is busy
      final isBusy = await videoCallProvider.checkUserBusy(receiverId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (isBusy) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$receiverName is currently in another call'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Initiate the call
      await videoCallProvider.initiateCall(
        receiverId: receiverId,
        receiverName: receiverName,
      );

      // Check for errors
      if (videoCallProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(videoCallProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        videoCallProvider.clearMessages();
        return;
      }

      // Navigate to calling screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallingScreen(),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// STEP 3: Replace the dispose method in ChatDetailScreen

  @override
  void deactivate() {
    // ✅ ADD THIS SECTION
    if (_userId != null) {
      try {
        _notificationProvider.deactivateChat(
          userId: _userId!,
          type: 'chat',
          chatId: widget.userId,
        );
        print('👋 Chat notifications deactivated in deactivate');
      } catch (e) {
        print('⚠️ Error in deactivate: $e');
      }
    }

    // Your existing code
    if (_chatProvider.currentUserId != null &&
        _chatProvider.currentReceiverId != null) {
      _chatProvider.leaveConversation();
      print('👋 Left conversation in deactivate');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    print('🧹 ChatDetailScreen disposing...');

    // Cancel timer first
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Notification cleanup
    if (_userId != null) {
      try {
        _notificationProvider.deactivateChat(
          userId: _userId!,
          type: 'chat',
          chatId: widget.userId,
        );
        print('👋 Chat notifications deactivated');
      } catch (e) {
        print('⚠️ Error deactivating chat notifications: $e');
      }
    }

    // Leave conversation
    if (_chatProvider.currentUserId != null &&
        _chatProvider.currentReceiverId != null) {
      _chatProvider.leaveConversation();
      print('👋 Left conversation in dispose');
    }

    // Dispose controllers
    _messageController.dispose();
    _scrollController.dispose();

    // Close recorder
    if (_recorder != null) {
      _recorder!.closeRecorder().then((_) {
        print('✅ Voice recorder closed');
      }).catchError((error) {
        print('⚠️ Error closing recorder: $error');
      });
    }

    // Delete recording WITHOUT setState
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        File(_recordingPath!).deleteSync();
      } catch (e) {
        print('⚠️ Error deleting recording in dispose: $e');
      }
    }

    super.dispose();
    print('✅ ChatDetailScreen disposed');
  }


  Future<void> _initiateVoiceCall() async {
    final voiceCallProvider = context.read<VoiceCallProvider>();

    final receiverId = widget.userProfile['_id'];
    final receiverName = widget.chatTitle;

    if (receiverId == null || receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot initiate voice call: Invalid user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clear previous call messages
    voiceCallProvider.clearMessages();

    // Initiate call
    await voiceCallProvider.initiateVoiceCall(
      receiverId: receiverId,
      receiverName: receiverName,
      isConference: false,
    );

    // Handle states
    if (voiceCallProvider.callState == VoiceCallState.calling) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const VoiceCallingScreen(),
          ),
        );
      }
    } else if (voiceCallProvider.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voiceCallProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
