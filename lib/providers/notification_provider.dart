import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _notificationSubscription;

  // Client-side tracking of read notifications (persisted locally)
  Set<String> _readNotificationIds = {};

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ✅ Helper to extract chatId from notification (handles nested structure)
  String? _extractChatId(Map<String, dynamic> notification) {
    if (notification['relatedData'] != null) {
      final relatedData = notification['relatedData'] as Map<String, dynamic>;
      if (relatedData['chatId'] != null) {
        return relatedData['chatId'].toString();
      }
    }
    return notification['chatId']?.toString() ??
        notification['communityId']?.toString() ??
        notification['referenceId']?.toString();
  }

  // ✅ Helper to extract communityId from notification
  String? _extractCommunityId(Map<String, dynamic> notification) {
    if (notification['relatedData'] != null) {
      final relatedData = notification['relatedData'] as Map<String, dynamic>;
      if (relatedData['communityId'] != null) {
        return relatedData['communityId'].toString();
      }
    }
    return notification['communityId']?.toString() ??
        notification['referenceId']?.toString() ??
        notification['_id']?.toString();
  }

  // ✅ Check if notification is read (client-side tracking)
  bool _isNotificationRead(Map<String, dynamic> notification) {
    final id = notification['_id']?.toString();
    if (id == null) return false;

    // Check both backend status and client-side tracking
    final backendRead = notification['read'] == true || notification['status'] == 'read';
    final clientRead = _readNotificationIds.contains(id);

    return backendRead || clientRead;
  }

  // ✅ Get unread count by type
  int getUnreadCountByType(String type) {
    return _notifications.where((n) {
      return n['type'] == type && !_isNotificationRead(n);
    }).length;
  }

  // ✅ Get unread count for multiple types
  int getUnreadCountForTypes(List<String> types) {
    return _notifications.where((n) {
      return types.contains(n['type']) && !_isNotificationRead(n);
    }).length;
  }

  // ✅ Total unread count
  int get totalUnreadCount {
    return _notifications.where((n) => !_isNotificationRead(n)).length;
  }

  // ✅ Get notifications by type
  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return _notifications.where((n) => n['type'] == type).toList();
  }

  // ✅ Load read notification IDs from local storage
  Future<void> _loadReadNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;

      String key = 'read_notifications_$userId';
      List<String>? stored = prefs.getStringList(key);

      if (stored != null) {
        _readNotificationIds = stored.toSet();
        print('📂 Loaded ${_readNotificationIds.length} read notifications from storage');
      }
    } catch (e) {
      print('💥 Error loading read notifications: $e');
    }
  }

  // ✅ Save read notification IDs to local storage
  Future<void> _saveReadNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;

      String key = 'read_notifications_$userId';
      await prefs.setStringList(key, _readNotificationIds.toList());
      print('💾 Saved ${_readNotificationIds.length} read notifications to storage');
    } catch (e) {
      print('💥 Error saving read notifications: $e');
    }
  }

  // ✅ Initialize notifications
  Future<void> initializeNotifications() async {
    await _loadReadNotifications();
    await _notificationService.initializeSocket();
    await loadNotifications();

    // Listen for real-time notifications
    _notificationSubscription = _notificationService.onNotification.listen(
          (notification) {
        print('📬 New notification received in provider: ${notification['type']}');
        // Add to local list at the beginning
        _notifications.insert(0, notification);
        notifyListeners();
      },
      onError: (error) {
        print('💥 Notification stream error: $error');
      },
    );
  }

  // ✅ Load all notifications
  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _notificationService.fetchNotifications();
      if (result != null) {
        _notifications = result;
        print('📦 Loaded ${_notifications.length} notifications');

        // Clean up read IDs for notifications that no longer exist
        final currentIds = _notifications.map((n) => n['_id']?.toString()).whereType<String>().toSet();
        _readNotificationIds.removeWhere((id) => !currentIds.contains(id));
        await _saveReadNotifications();
      } else {
        _error = 'Failed to fetch notifications.';
      }
    } catch (e) {
      _error = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ✅ Mark all notifications of specific types as read (CLIENT-SIDE ONLY)
  Future<void> markTypesAsRead(List<String> types) async {
    try {
      print('🔔 Marking types as read (client-side): $types');

      // Get all notifications that need to be marked as read
      final notificationsToMark = _notifications
          .where((n) => types.contains(n['type']) && !_isNotificationRead(n))
          .toList();

      if (notificationsToMark.isEmpty) {
        print('✅ No unread notifications to mark for types: $types');
        return;
      }

      print('📝 Found ${notificationsToMark.length} notifications to mark as read');

      // Mark all as read in client-side tracking
      for (var notification in notificationsToMark) {
        final id = notification['_id']?.toString();
        if (id != null) {
          _readNotificationIds.add(id);
        }
      }

      // Save to local storage
      await _saveReadNotifications();

      // Update UI
      notifyListeners();
      print('✅ Marked ${notificationsToMark.length} notifications as read (client-side)');

      // Optional: Try to sync with backend using Socket.IO (non-blocking)
      _syncWithBackendAsync(notificationsToMark);

    } catch (e) {
      print('💥 Error marking types as read: $e');
    }
  }

  // ✅ Background sync with backend (doesn't block UI)
  void _syncWithBackendAsync(List<Map<String, dynamic>> notifications) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;

      print('🔄 Syncing with backend (non-blocking)...');

      for (var notif in notifications) {
        final chatId = _extractChatId(notif);
        final type = notif['type'];

        if (chatId != null && type != null) {
          // Use Socket.IO to mark as read
          _notificationService.markChatAsActive(
            userId: userId,
            type: type,
            chatId: chatId,
          );

          // Small delay between socket emissions
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('✅ Backend sync completed (background)');
    } catch (e) {
      print('⚠️ Backend sync failed (non-critical): $e');
    }
  }

  // ✅ Mark notifications as read
  Future<bool> markAsRead({
    required String type,
    required String communityId,
  }) async {
    try {
      // Find matching notifications and mark them
      bool hasChanges = false;
      for (var notification in _notifications) {
        if (notification['type'] == type &&
            _extractCommunityId(notification) == communityId) {
          final id = notification['_id']?.toString();
          if (id != null) {
            _readNotificationIds.add(id);
            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        await _saveReadNotifications();
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('💥 Error marking as read: $e');
      return false;
    }
  }

  // ✅ Mark chat notifications as read when opening a chat
  Future<bool> markChatAsRead({
    required String chatId,
    required String type,
  }) async {
    try {
      // Find matching notifications and mark them
      bool hasChanges = false;
      for (var notification in _notifications) {
        final notifChatId = _extractChatId(notification);

        if (notifChatId == chatId && notification['type'] == type) {
          final id = notification['_id']?.toString();
          if (id != null) {
            _readNotificationIds.add(id);
            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        await _saveReadNotifications();
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('💥 Error marking chat as read: $e');
      return false;
    }
  }

  // ✅ Clear specific notifications
  Future<bool> clearNotifications({
    required String type,
    required String communityId,
  }) async {
    try {
      // Remove from read tracking
      final toRemove = _notifications
          .where((n) => n['type'] == type && _extractCommunityId(n) == communityId)
          .map((n) => n['_id']?.toString())
          .whereType<String>()
          .toList();

      for (var id in toRemove) {
        _readNotificationIds.remove(id);
      }

      // Remove from local state
      _notifications.removeWhere((notification) =>
      notification['type'] == type &&
          _extractCommunityId(notification) == communityId);

      await _saveReadNotifications();
      notifyListeners();

      // Try to sync with backend (non-blocking)
      _notificationService.clearNotifications(type: type, communityId: communityId);

      return true;
    } catch (e) {
      print('💥 Error clearing notifications: $e');
      return false;
    }
  }

  // ✅ Mark chat as active (suppress real-time notifications)
  void activateChat({
    required String userId,
    required String type,
    required String chatId,
  }) {
    _notificationService.markChatAsActive(
      userId: userId,
      type: type,
      chatId: chatId,
    );

    // Also mark existing notifications as read
    markChatAsRead(chatId: chatId, type: type);
  }

  // ✅ Mark chat as inactive
  void deactivateChat({
    required String userId,
    required String type,
    required String chatId,
  }) {
    _notificationService.markChatAsInactive(
      userId: userId,
      type: type,
      chatId: chatId,
    );
  }

  // ✅ Clear all notifications
  void clearAll(String userId) async {
    // Clear client-side tracking
    _readNotificationIds.clear();
    await _saveReadNotifications();

    // Clear local state
    _notifications.clear();
    notifyListeners();

    // Sync with backend
    _notificationService.clearAllNotifications(userId);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
}