import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/personal_chat_provider.dart';
import './message_bubble_screen.dart';

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
  bool _isSending = false; // Add this to prevent duplicate sends

  // Voice recording variables
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PersonalChatProvider>();
      await provider.fetchConversation(widget.userId);

      // After fetching, mark as read
      await provider.updateReadStatus(
        senderId: widget.userId,
        receiverId: provider.currentUserId!,
      );

      // Scroll to bottom after messages load
      _scrollToBottom();
    });
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
        content: const Text('To send voice messages, please allow microphone access in settings.'),
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
      final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
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
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      print('🎤 Stopped recording. File: $_recordingPath');

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
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((count) {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: count + 1);
        });
      }
    });
  }

  // Show voice message preview
  void _showVoicePreview() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.blue),
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
                    _deleteRecording();
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
    );
  }

  // Send voice message
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
      final response = await provider.sendVoiceMessage(
        audioFile: audioFile,
        receiverId: receiverId,
        readBy: false,
      );

      if (response != null) {
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message sent!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: ${provider.sendMessageError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _deleteRecording();
    }
  }

  // Delete recording file
  void _deleteRecording() {
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      File(_recordingPath!).deleteSync();
      _recordingPath = null;
    }
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

  // STEP 1: Replace the entire _sendMessage() method in chat_detail_screen.dart
// Location: Inside _ChatDetailScreenState class

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
        SnackBar(
          content: Text(
              'Error: Unable to send message. receiverId: $receiverId, currentUserId: $currentUserId'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // File message
    if (_selectedFile != null) {
      setState(() => _isSending = true);

      final fileToSend = _selectedFile!;

      // Clear input BEFORE sending
      setState(() {
        _selectedFile = null;
        _messageController.clear();
      });

      try {
        final response = await provider.sendFileMessage(
          file: fileToSend,
          receiverId: receiverId,
          readBy: false,
        );

        if (response != null) {
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send file: ${provider.sendMessageError ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSending = false);
      }
    }
    // Text message
    else if (content.isNotEmpty) {
      setState(() => _isSending = true);

      final messageText = content;

      // Clear input BEFORE sending
      _messageController.clear();
      _scrollToBottom();

      try {
        final result = await provider.sendMessage(
          receiverId: receiverId,
          text: messageText,
          readBy: false,
        );

        if (result != null && (result['error'] == false || result['success'] == true)) {
          print('✅ Message sent successfully');
          _scrollToBottom();
        } else {
          print('❌ Failed to send message');
        }
      } catch (e) {
        print('💥 Error sending message: $e');
      } finally {
        setState(() => _isSending = false);
      }
    }
  }

  String _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  String _constructFullFileUrl(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return '';

    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      return fileUrl;
    }

    const String baseUrl = 'https://api.ixes.ai';
    String cleanPath = fileUrl;
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    if (cleanPath.contains('/voice/')) {
      return '$baseUrl$cleanPath';
    }

    return '$baseUrl/fileUrl$cleanPath';
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
               color: Primary
              ),
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
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/icons/call.png', // Replace with your asset path
              width: 24,
              height: 24,
              color: Colors.grey[800], // Optional: to tint the icon
            ),
            onPressed: () {
              // Handle audio call action
              print('Audio call pressed');
            },
            tooltip: 'Audio Call',
          ),SizedBox(width: 10,),
          IconButton(
            icon: Image.asset(
              'assets/icons/video.png', // Replace with your asset path
              width: 24,
              height: 24,
              color: Colors.grey[800], // Optional: to tint the icon
            ),
            onPressed: () {
              // Handle video call action
              print('Video call pressed');
            },
            tooltip: 'Video Call',
          ),
          const SizedBox(width:20),
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
                      final isMe = message['senderId'] == provider.currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MessageBubble(
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
                          // Voice message properties
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
                    child: Column(
                      children: [
                        if (_selectedFile != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file, size: 20, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFile!.path.split('/').last,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => setState(() {
                                    _selectedFile = null;
                                    _messageController.clear();
                                  }),
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
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
                                          if (!_isSending && (_messageController.text.trim().isNotEmpty || _selectedFile != null)) {
                                            _sendMessage();
                                          }
                                        },
                                      ),
                                    ),

                                    // Action buttons (merged inside the same container)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Voice message button
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            icon: Icon(
                                              _isRecording ? Icons.stop : Icons.mic,
                                              size: 20,
                                              color: _isRecording ? Colors.red : Primary,
                                            ),
                                            onPressed: _isSending
                                                ? null
                                                : (_isRecording ? _stopRecording : _startRecording),
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
                                            onPressed: (_selectedFile == null && !_isSending) ? _pickFile : null,
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
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                            )
                                                : IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              icon: const Icon(Icons.send, size: 18, color: Colors.white),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // Clean up voice recorder
    if (_recorder != null) {
      _recorder!.closeRecorder();
    }
    _deleteRecording();

    super.dispose();
  }
}