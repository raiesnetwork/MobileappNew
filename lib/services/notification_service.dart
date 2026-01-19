import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/apiConstants.dart';

class NotificationService {
  IO.Socket? _socket;

  // Stream controllers for different notification types
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

  // ✅ 1. Fetch all notifications
  Future<List<Map<String, dynamic>>?> fetchNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      final url = Uri.parse('${apiBaseUrl}api/notifications');
      print("📬 Fetching notifications from: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("📡 Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List notifications = json['notifications'] ?? [];

        // Count unread notifications
        final unreadCount = notifications.where((n) => n['read'] == false).length;
        print("📊 Total: ${notifications.length}, Unread: $unreadCount");

        return notifications.cast<Map<String, dynamic>>();
      } else {
        print("❌ Error: ${response.statusCode} - ${response.reasonPhrase}");
        print("📦 Response: ${response.body}");
        return null;
      }
    } catch (e) {
      print('💥 Exception in fetchNotifications: $e');
      return null;
    }
  }

  // ✅ 2. Mark notifications as read
  Future<bool> markNotificationsAsRead({
    required String type,
    required String communityId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token == null) {
        print('❌ No auth token found');
        return false;
      }

      final url = Uri.parse('${apiBaseUrl}api/notifications/mark-read');
      final requestBody = {
        'type': type,
        'communityId': communityId,
      };

      print("✅ Marking notifications as read:");
      print("   URL: $url");
      print("   Body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print("📡 Response Status: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Successfully marked as read");
        return true;
      } else {
        print("❌ Failed to mark as read: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print('💥 Exception in markNotificationsAsRead: $e');
      return false;
    }
  }

  // ✅ NEW: Mark chat notifications as read by chatId
  Future<bool> markChatNotificationsAsRead({
    required String chatId,
    required String type,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token == null) {
        print('❌ No auth token found');
        return false;
      }

      // FIXED: Use standard endpoint since mark-chat-read doesn't exist in docs
      final url = Uri.parse('${apiBaseUrl}api/notifications/mark-read');
      final requestBody = {
        'type': type,
        'communityId': chatId, // Send chatId as communityId parameter
      };

      print("✅ Marking chat notifications as read:");
      print("   URL: $url");
      print("   Body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print("📡 Response Status: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Successfully marked chat as read");
        return true;
      } else {
        print("❌ Failed to mark chat as read: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print('💥 Exception in markChatNotificationsAsRead: $e');
      return false;
    }
  }

  // ✅ 3. Clear specific notifications
  Future<bool> clearNotifications({
    required String type,
    required String communityId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token == null) return false;

      final url = Uri.parse('${apiBaseUrl}api/notifications/clear');
      print("🗑️ Clearing notifications: type=$type, communityId=$communityId");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'communityId': communityId,
        }),
      );

      print("📡 Status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print('💥 Exception in clearNotifications: $e');
      return false;
    }
  }

  // ✅ 4. Initialize socket connection
  Future<void> initializeSocket() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      String? userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        print('❌ Missing token or userId');
        return;
      }

      _socket = IO.io(
        apiBaseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        print('✅ Notification socket connected');
      });

      _socket?.onDisconnect((_) {
        print('❌ Notification socket disconnected');
      });

      // Listen for notifications
      _socket?.on('notification', (data) {
        print('📬 New notification received: $data');
        _notificationController.add(Map<String, dynamic>.from(data));
      });

      print('🔌 Notification socket initialized');
    } catch (e) {
      print('💥 Error initializing notification socket: $e');
    }
  }

  // ✅ 5. Mark chat as active (suppress notifications when user is viewing chat)
  void markChatAsActive({
    required String userId,
    required String type,
    required String chatId,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected');
      return;
    }

    _socket?.emit('activechat-notificatin', {
      'userId': userId,
      'type': type,
      'chatId': chatId,
    });

    print('👁️ Marked chat as active: chatId=$chatId, type=$type');
  }

  // ✅ 6. Mark chat as inactive (resume notifications when user leaves chat)
  void markChatAsInactive({
    required String userId,
    required String type,
    required String chatId,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected');
      return;
    }

    _socket?.emit('deactivechat-notificatin', {
      'userId': userId,
      'type': type,
      'chatId': chatId,
    });

    print('👋 Marked chat as inactive: chatId=$chatId, type=$type');
  }

  // ✅ 7. Clear all notifications
  void clearAllNotifications(String userId) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected');
      return;
    }

    _socket?.emit('notificationRead', {'userId': userId});
    print('🗑️ Cleared all notifications for userId: $userId');
  }

  // Cleanup
  void dispose() {
    _notificationController.close();
    _socket?.disconnect();
    _socket?.dispose();
  }
}