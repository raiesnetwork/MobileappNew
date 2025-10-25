import 'package:flutter/material.dart';
import 'package:ixes.app/screens/newa_page/setting_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  void _showDeleteConfirmation(BuildContext context, String historyId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 50, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                "Do you want to delete the history?",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "You won't be able to revert this!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Provider.of<ChatProvider>(context, listen: false)
                          .deleteHistoryItem(historyId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Delete"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    if (chatProvider.chatHistory.isEmpty && !chatProvider.isHistoryLoading) {
      chatProvider.loadChatHistory();
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
      height: MediaQuery.of(context).size.height,
      color: Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Chat History"),
          backgroundColor: Colors.transparent,
          elevation: 1,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (chatProvider.isHistoryLoading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (chatProvider.historyError != null)
                Expanded(
                  child: Center(
                    child: Text(
                      "❌ ${chatProvider.historyError}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else if (chatProvider.chatHistory.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: chatProvider.chatHistory.length,
                    itemBuilder: (context, index) {
                      final item = chatProvider.chatHistory[index];
                      final chats = item['chats'] as List<dynamic>? ?? [];
                      final historyId = item['_id'] ?? '';
                      final firstMessage =
                          chats.isNotEmpty ? chats.first['message'] ?? '' : '';
                      final dateKey = item['dateKey'] ?? '';
                      final category = item['category'] ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🗓️ Date Header
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, top: 16, bottom: 4),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // 🏷️ Category Label
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Text(
                              category[0].toUpperCase() + category.substring(1),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                          // 💬 Chat history section
                          ExpansionTile(
                            title: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                firstMessage,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () =>
                                  _showDeleteConfirmation(context, historyId),
                            ),
                            children: chats.map((chat) {
                              final question = chat['message'] ?? '';
                              final reply = chat['reply'] ?? '';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (question.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            16, 6, 16, 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                question,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.red,
                                              child: Text('U',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (reply.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            16, 6, 16, 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border:
                                              Border.all(color: Colors.black12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.language,
                                                size: 16),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                reply,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                const Expanded(
                  child: Center(child: Text("No history found.")),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom:5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    label: const Text(
                      'Settings',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}
