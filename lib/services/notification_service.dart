import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/apiConstants.dart';
import 'api_service.dart';

class NotificationService {
  IO.Socket? _socket;

  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

  // ✅ 1. Fetch all notifications
  Future<List<Map<String, dynamic>>?> fetchNotifications() async {
    try {
      final response = await ApiService.get('/api/notifications');
      ApiService.checkResponse(response);

      print("📡 Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List notifications = json['notifications'] ?? [];

        final unreadCount = notifications.where((n) => n['read'] == false).length;
        print("📊 Total: ${notifications.length}, Unread: $unreadCount");

        return notifications.cast<Map<String, dynamic>>();
      } else {
        print("❌ Error: ${response.statusCode} - ${response.reasonPhrase}");
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
      final requestBody = {
        'type': type,
        'communityId': communityId,
      };

      print("✅ Marking notifications as read: ${jsonEncode(requestBody)}");

      final response = await ApiService.post(
          '/api/notifications/mark-read', requestBody);
      ApiService.checkResponse(response);

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

  // ✅ 3. Mark chat notifications as read
  Future<bool> markChatNotificationsAsRead({
    required String chatId,
    required String type,
  }) async {
    try {
      final requestBody = {
        'type': type,
        'communityId': chatId,
      };

      print("✅ Marking chat notifications as read: ${jsonEncode(requestBody)}");

      final response = await ApiService.post(
          '/api/notifications/mark-read', requestBody);
      ApiService.checkResponse(response);

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

  // ✅ 4. Clear specific notifications
  Future<bool> clearNotifications({
    required String type,
    required String communityId,
  }) async {
    try {
      print("🗑️ Clearing notifications: type=$type, communityId=$communityId");

      final response = await ApiService.post('/api/notifications/clear', {
        'type': type,
        'communityId': communityId,
      });
      ApiService.checkResponse(response);

      print("📡 Status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print('💥 Exception in clearNotifications: $e');
      return false;
    }
  }

  // ✅ 5. Initialize socket connection
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

      _socket?.on('notification', (data) {
        print('📬 New notification received: $data');
        _notificationController.add(Map<String, dynamic>.from(data));
      });

      print('🔌 Notification socket initialized');
    } catch (e) {
      print('💥 Error initializing notification socket: $e');
    }
  }

  // ✅ 6. Mark chat as active
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

  // ✅ 7. Mark chat as inactive
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

  // ✅ 8. Clear all notifications
  void clearAllNotifications(String userId) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected');
      return;
    }

    _socket?.emit('notificationRead', {'userId': userId});
    print('🗑️ Cleared all notifications for userId: $userId');
  }

  void dispose() {
    _notificationController.close();
    _socket?.disconnect();
    _socket?.dispose();
  }
}