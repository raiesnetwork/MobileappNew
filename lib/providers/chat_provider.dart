import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<String> messages = [];
  final ChatService _chatService = ChatService();

  int currentTab = 0;
  bool isLoading = false;
  List<dynamic> chatHistory = [];
  bool isHistoryLoading = false;
  String? historyError;

  void changeTab(int index) {
    currentTab = index;
    messages.clear();
    notifyListeners();
  }

  // Send message and manage loading
  Future<void> sendMessage(String msg, VoidCallback scrollToBottom) async {
    messages.add(msg);
    isLoading = true;
    notifyListeners();

    scrollToBottom();

    String reply = '';
    try {
      if (currentTab == 0) {
        final response = await ChatService.sendGeneralChat(message: msg);
        reply = response["success"] == true
            ? response["reply"] ?? ""
            : "❌ ${response["message"]}";
      } else if (currentTab == 1) {
        reply = await _chatService.sendToBusiness(msg);
      } else if (currentTab == 2) {
        final response = await _chatService.sendPersonalChat(msg, '');
        reply = response["reply"] ?? "No reply from AI";
      }
    } catch (e) {
      reply = "❌ Failed to get response: ${e.toString()}";
    }

    messages.add(reply);
    isLoading = false;
    notifyListeners();

    scrollToBottom();
    await loadChatHistory(); // Refresh history
  }

  Future<void> uploadAndAskFile({
    required String question,
    required String filePath,
    required VoidCallback scrollToBottom,
  }) async {
    messages.add(question.isEmpty ? "📎 File uploaded" : question);
    isLoading = true;
    notifyListeners();
    scrollToBottom();

    try {
      final response = await _chatService.sendPersonalChat(question, filePath);
      messages.add(response["reply"] ?? "No reply from AI");
      if (!response["success"]) {
        print("file uploaded : ${response["message"]}");
      }
    } catch (e) {
      messages.add("❌ Error uploading file: ${e.toString()}");
    }

    isLoading = false;
    notifyListeners();
    scrollToBottom();
  }

  Future<void> loadChatHistory() async {
    isHistoryLoading = true;
    historyError = null;
    notifyListeners();

    try {
      chatHistory = await _chatService.fetchChatHistory();
    } catch (e) {
      historyError = e.toString();
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteHistoryItem(String historyId) async {
    final result = await ChatService.deleteChatHistory(historyId);

    if (result['success'] == true) {
      chatHistory.removeWhere((item) => item['_id'] == historyId);
      notifyListeners();
    } else {
      debugPrint("❌ Delete failed: ${result['message']}");
    }
  }

  // -------------------- SETTINGS --------------------

  Map<String, dynamic>? _userSettings;
  Map<String, dynamic>? get userSettings => _userSettings;

  bool _isSettingsLoading = false;
  bool get isSettingsLoading => _isSettingsLoading;

  String? _settingsError;
  String? get settingsError => _settingsError;

  Future<void> loadUserSettings() async {
    _isSettingsLoading = true;
    notifyListeners();

    try {
      _userSettings = await _chatService.fetchUserSettings();
      _settingsError = null;
      print("DEBUG: Loaded userSettings: $_userSettings");
    } catch (e) {
      _settingsError = e.toString();
      print("DEBUG: Error loading settings: $_settingsError");
    }

    _isSettingsLoading = false;
    notifyListeners();
  }

  Future<bool> updateUserSettings(
      Map<String, String> fields, List<String> filePaths,
      {required List<String> deletedFiles}) async {
    final result = await _chatService.saveUserSettings(fields, filePaths,
        deletedFiles: deletedFiles);

    if (result['success'] == true && result['settings'] != null) {
      _userSettings = result['settings'] as Map<String, dynamic>;
      print("DEBUG: Updated userSettings: $_userSettings");
      notifyListeners();
      return true;
    } else {
      _settingsError = result['message'] ?? 'Failed to update settings';
      print("DEBUG: Update failed, error: $_settingsError");
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> saveUserSettings(
      Map<String, String> fields, List<String> filePaths,
      {List<String> deletedFiles = const []}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final uri = Uri.parse("https://api.ixes.ai/api/ask-newa/setting");
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      if (deletedFiles.isNotEmpty) {
        request.fields['deletedFiles'] = jsonEncode(deletedFiles);
      }

      for (final path in filePaths) {
        print("📎 Attaching file: $path");
        request.files.add(await http.MultipartFile.fromPath('files', path));
      }

      print("📤 Saving settings to: $uri");
      print("🔐 Authorization: Bearer $token");
      print("📝 Fields: ${request.fields}");
      print("📁 File count: ${request.files.length}");
      print("🗑️ Deleted files: $deletedFiles");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      final decoded = jsonDecode(response.body);
      // Safely convert decoded to Map<String, dynamic>
      final Map<String, dynamic> settingsMap = decoded is Map
          ? Map<String, dynamic>.from(decoded.map((k, v) => MapEntry(k.toString(), v)))
          : {};

      return {
        "success": response.statusCode == 200,
        "settings": settingsMap, // Use converted map
        "message": settingsMap["message"]?.toString() ?? "",
      };
    } catch (e) {
      print("❌ Error saving settings: $e");
      return {
        "success": false,
        "message": "Error saving settings: ${e.toString()}",
      };
    }
  }

  // New refreshFeed method
  Future<void> refreshFeed() async {
    print("DEBUG: Refreshing feed...");
    await loadUserSettings();
    print("DEBUG: Feed refreshed");
  }
}
