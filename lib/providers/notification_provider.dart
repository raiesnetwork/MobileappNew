import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _notificationSubscription;
  Set<String> _readNotificationIds = {};

  // Debounce timer — prevents rapid successive notifyListeners calls
  Timer? _notifyDebounce;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _scheduleNotify() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
  }

  String? _extractChatId(Map<String, dynamic> notification) {
    if (notification['relatedData'] != null) {
      final relatedData = notification['relatedData'] as Map<String, dynamic>;
      if (relatedData['chatId'] != null) return relatedData['chatId'].toString();
    }
    return notification['chatId']?.toString() ??
        notification['communityId']?.toString() ??
        notification['referenceId']?.toString();
  }

  String? _extractCommunityId(Map<String, dynamic> notification) {
    if (notification['relatedData'] != null) {
      final relatedData = notification['relatedData'] as Map<String, dynamic>;
      if (relatedData['communityId'] != null) return relatedData['communityId'].toString();
    }
    return notification['communityId']?.toString() ??
        notification['referenceId']?.toString() ??
        notification['_id']?.toString();
  }

  bool _isNotificationRead(Map<String, dynamic> notification) {
    final id = notification['_id']?.toString();
    if (id == null) return false;
    final backendRead = notification['read'] == true || notification['status'] == 'read';
    final clientRead = _readNotificationIds.contains(id);
    return backendRead || clientRead;
  }

  int getUnreadCountByType(String type) {
    return _notifications.where((n) => n['type'] == type && !_isNotificationRead(n)).length;
  }

  int getUnreadCountForTypes(List<String> types) {
    return _notifications.where((n) => types.contains(n['type']) && !_isNotificationRead(n)).length;
  }

  int get totalUnreadCount {
    return _notifications.where((n) => !_isNotificationRead(n)).length;
  }

  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return _notifications.where((n) => n['type'] == type).toList();
  }

  Future<void> _loadReadNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;
      List<String>? stored = prefs.getStringList('read_notifications_$userId');
      if (stored != null) _readNotificationIds = stored.toSet();
    } catch (e) {
      debugPrint('Error loading read notifications: $e');
    }
  }

  Future<void> _saveReadNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;
      await prefs.setStringList('read_notifications_$userId', _readNotificationIds.toList());
    } catch (e) {
      debugPrint('Error saving read notifications: $e');
    }
  }

  Future<void> initializeNotifications() async {
    await _loadReadNotifications();
    await _notificationService.initializeSocket();
    await loadNotifications();

    _notificationSubscription = _notificationService.onNotification.listen(
          (notification) {
        _notifications.insert(0, notification);
        _scheduleNotify(); // debounced — won't spam rebuilds
      },
      onError: (error) => debugPrint('Notification stream error: $error'),
    );
  }

  Future<void> loadNotifications() async {
    // Don't re-enter if already loading
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners(); // intentional immediate notify — loading state changed

    try {
      final result = await _notificationService.fetchNotifications();
      if (result != null) {
        _notifications = result;
        final currentIds = _notifications
            .map((n) => n['_id']?.toString())
            .whereType<String>()
            .toSet();
        _readNotificationIds.removeWhere((id) => !currentIds.contains(id));
        await _saveReadNotifications();
      } else {
        _error = 'Failed to fetch notifications.';
      }
    } catch (e) {
      _error = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners(); // intentional immediate notify — loading done
  }

  /// Marks notifications of given types as read.
  /// Returns true if anything actually changed (so callers know whether a
  /// rebuild is needed).
  Future<bool> markTypesAsRead(List<String> types) async {
    final toMark = _notifications
        .where((n) => types.contains(n['type']) && !_isNotificationRead(n))
        .toList();

    if (toMark.isEmpty) return false; // nothing changed — no notify

    for (var n in toMark) {
      final id = n['_id']?.toString();
      if (id != null) _readNotificationIds.add(id);
    }

    await _saveReadNotifications();
    _scheduleNotify(); // debounced — collapses rapid consecutive calls

    // Background sync — fire and forget
    _syncWithBackendAsync(toMark);

    return true;
  }

  void _syncWithBackendAsync(List<Map<String, dynamic>> notifications) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;
      for (var notif in notifications) {
        final chatId = _extractChatId(notif);
        final type = notif['type'];
        if (chatId != null && type != null) {
          _notificationService.markChatAsActive(userId: userId, type: type, chatId: chatId);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint('Backend sync failed (non-critical): $e');
    }
  }

  Future<bool> markAsRead({required String type, required String communityId}) async {
    bool hasChanges = false;
    for (var notification in _notifications) {
      if (notification['type'] == type && _extractCommunityId(notification) == communityId) {
        final id = notification['_id']?.toString();
        if (id != null && !_readNotificationIds.contains(id)) {
          _readNotificationIds.add(id);
          hasChanges = true;
        }
      }
    }
    if (hasChanges) {
      await _saveReadNotifications();
      _scheduleNotify();
    }
    return true;
  }

  Future<bool> markChatAsRead({required String chatId, required String type}) async {
    bool hasChanges = false;
    for (var notification in _notifications) {
      final notifChatId = _extractChatId(notification);
      if (notifChatId == chatId && notification['type'] == type) {
        final id = notification['_id']?.toString();
        if (id != null && !_readNotificationIds.contains(id)) {
          _readNotificationIds.add(id);
          hasChanges = true;
        }
      }
    }
    if (hasChanges) {
      await _saveReadNotifications();
      _scheduleNotify();
    }
    return true;
  }

  Future<bool> clearNotifications({required String type, required String communityId}) async {
    try {
      final toRemove = _notifications
          .where((n) => n['type'] == type && _extractCommunityId(n) == communityId)
          .map((n) => n['_id']?.toString())
          .whereType<String>()
          .toList();

      for (var id in toRemove) _readNotificationIds.remove(id);
      _notifications.removeWhere(
              (n) => n['type'] == type && _extractCommunityId(n) == communityId);

      await _saveReadNotifications();
      _scheduleNotify();
      _notificationService.clearNotifications(type: type, communityId: communityId);
      return true;
    } catch (e) {
      return false;
    }
  }

  void activateChat({required String userId, required String type, required String chatId}) {
    _notificationService.markChatAsActive(userId: userId, type: type, chatId: chatId);
    markChatAsRead(chatId: chatId, type: type);
  }

  void deactivateChat({required String userId, required String type, required String chatId}) {
    _notificationService.markChatAsInactive(userId: userId, type: type, chatId: chatId);
  }

  void clearAll(String userId) async {
    _readNotificationIds.clear();
    _notifications.clear();
    await _saveReadNotifications();
    _scheduleNotify();
    _notificationService.clearAllNotifications(userId);
  }

  @override
  void dispose() {
    _notifyDebounce?.cancel();
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
}