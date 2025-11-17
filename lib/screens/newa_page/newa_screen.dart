import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/providers/chat_provider.dart';

import '../../animation.dart';
import 'chat_history.dart';

class NewaScreen extends StatefulWidget {
  const NewaScreen({super.key});

  @override
  State<NewaScreen> createState() => _NewaScreenState();
}

class _NewaScreenState extends State<NewaScreen> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController controller = TextEditingController();
  String? selectedFilePath;
  String? selectedFileName;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> sendMessage() async {
    final message = controller.text.trim();
    controller.clear();
    FocusScope.of(context).unfocus();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (chatProvider.currentTab == 2 && selectedFilePath != null) {
      print("📤 Sending file: $selectedFilePath with question: '$message'");

      await chatProvider.uploadAndAskFile(
        question: message,
        filePath: selectedFilePath!,
        scrollToBottom: scrollToBottom,
      );
    }
    // If only message (any tab)
    else if (message.isNotEmpty) {
      await chatProvider.sendMessage(message, scrollToBottom);
    }

    // Clear only after sending
    controller.clear();
    setState(() {
      selectedFilePath = null;
      selectedFileName = null;
    });
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const ChatHistoryDrawer(),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5, right: 20),
            child: TextButton(
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              style: TextButton.styleFrom(
                backgroundColor:Primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "History",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // text color for contrast
                ),
              ),
            ),

          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) => chatProvider
                      .messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'What do you need help with today?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              reverse: false,
                              itemCount: chatProvider.messages.length,
                              itemBuilder: (context, index) {
                                final message = chatProvider.messages[index];
                                final isUserMessage = index % 2 == 0;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 15),
                                  alignment: isUserMessage
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUserMessage
                                          ? Primary
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(13),
                                        topRight: const Radius.circular(13),
                                        bottomLeft: Radius.circular(
                                            isUserMessage ? 13 : 0),
                                        bottomRight: Radius.circular(
                                            isUserMessage ? 0 : 13),
                                      ),
                                    ),
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isUserMessage
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (chatProvider.isLoading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                              child: Column(
                                children: [
                                  const DnaLoadingAnimation(
                                    width: 250,
                                    height: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [
                                        Color(0xFF667eea),
                                        Color(0xFF4facfe),
                                      ],
                                    ).createShader(bounds),
                                    child: const Text(
                                      "Processing your question...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  if (selectedFilePath != null && selectedFileName != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFileName!,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                selectedFilePath = null;
                                selectedFileName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints:  BoxConstraints(
                              minHeight: 20, maxHeight: 160),
                          child: Scrollbar(
                            child: TextField(
                              controller: controller,
                              maxLines: null,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none, // THIS
                                hintText: 'Type your message...',
                                hintStyle:
                                    TextStyle(color: Colors.grey, fontSize: 14),

                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                              ),
                              onSubmitted: (_) => sendMessage(),
                            ),
                          ),
                        ),
                      ),
                      // IconButton(
                      //   icon: const Icon(Icons.mic, color: Colors.grey),
                      //   onPressed: () {},
                      // ),
                      Container(
                        decoration: const BoxDecoration(
                            color: Primary, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white),
                          onPressed: sendMessage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, _) {
                          return Visibility(
                              visible: chatProvider.currentTab == 2,
                              child: // Enhanced file picker with better validation
                                  IconButton(
                                icon: const Icon(Icons.attach_file,
                                    size: 20, color: Colors.grey),
                                onPressed: () async {
                                  try {
                                    FilePickerResult? result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'xls', 'xlsx'],
                                      allowMultiple: false,
                                    );

                                    if (result != null &&
                                        result.files.single.path != null) {
                                      final file = result.files.single;
                                      final extension =
                                          file.extension?.toLowerCase();

                                      // Enhanced validation
                                      print("🔍 File details:");
                                      print("   Name: ${file.name}");
                                      print("   Extension: ${file.extension}");
                                      print("   Size: ${file.size} bytes");
                                      print("   Path: ${file.path}");

                                      // Check file size (e.g., max 10MB)
                                      if (file.size > 10 * 1024 * 1024) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                '❌ File too large. Maximum size is 10MB.'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                        return;
                                      }

                                      // Validate extension
                                      if (extension != null && ['pdf', 'xls', 'xlsx'].contains(extension.toLowerCase())) {
                                        // Additional validation: check if file exists and is readable
                                        final fileExists = await File(file.path!).exists();
                                        if (!fileExists) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('❌ File not found or inaccessible.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          selectedFilePath = file.path!;
                                          selectedFileName = file.name;
                                        });

                                        print("✅ File selected successfully: ${file.name}");
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('❌ Unsupported file format. Only PDF and Excel files are allowed.'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    print("❌ File picker error: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('❌ Error selecting file: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                              ));
                        },
                      ),
                      buildInlineTab("General", 0, Icons.language),
                      const SizedBox(width: 12),
                      buildInlineTab("Business", 1, Icons.business_center),
                      const SizedBox(width: 12),
                      buildInlineTab("Personal", 2, Icons.person),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInlineTab(String label, int index, IconData icon) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final isSelected = chatProvider.currentTab == index;
        return GestureDetector(
          onTap: () => chatProvider.changeTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[300],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 14, color: isSelected ? Colors.white : Colors.black),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
