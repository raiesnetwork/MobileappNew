import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../services/group_chat_service.dart';
import '../services/socket_service.dart';

class GroupChatProvider with ChangeNotifier {
  final GroupChatService _svc = GroupChatService();

  sio.Socket? _socket;
  bool _isDisposed = false;
  StreamSubscription<sio.Socket>? _socketReadySubscription;
  VoidCallback? onNewMessageReceived;

  // ── Loading flags ────────────────────────────────────────────────────────
  bool _isLoading           = false;
  bool _isSearching         = false;
  bool _isCreatingGroup     = false;
  bool _isRequestingGroup   = false;
  bool _isCancellingRequest = false;
  bool _isUpdatingRequest   = false;
  bool _isLoadingMessages   = false;
  bool _isSendingMessage    = false;
  bool _isSendingFile       = false;
  bool _isSendingVoice      = false;
  bool _isSendingCamera     = false;
  bool _isAddingMembers     = false;
  bool _isRemovingMember    = false;
  bool _isEditingMessage    = false;
  bool _isDeletingMessage   = false;
  bool _isFetchingUsers     = false;
  bool _isLoadingMyGroups   = false;
  bool _isLoadingRequests   = false;

  // ── Errors ───────────────────────────────────────────────────────────────
  String? _error;
  String? _createGroupError;
  String? _messagesError;
  String? _sendMessageError;
  String? _sendFileError;
  String? _sendVoiceError;
  String? _myGroupsError;
  String? _requestsError;
  String? _editMessageError;
  String? _deleteMessageError;

  // ── Messages ─────────────────────────────────────────────────────────────
  String _groupRequestMessage  = '';
  String _addMemberMessage     = '';
  String _removeMessage        = '';
  String _updateRequestMessage = '';

  // ── Data ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _groups          = [];
  List<Map<String, dynamic>> _filteredGroups  = [];
  List<Map<String, dynamic>> _myGroups        = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<dynamic>              _allUsers        = [];

  final Map<String, List<Map<String, dynamic>>> _groupMessages = {};

  String  _currentSearchQuery = '';
  String? _currentGroupId;
  String? _currentCommunityId;
  double  _fileUploadProgress  = 0.0;
  int     _allUsersTotalPages  = 1;
  int     _allUsersCurrentPage = 1;

  int  _myGroupsCurrentPage = 1;
  int  _myGroupsTotalPages  = 1;
  bool _myGroupsHasMore     = false;

  // ════════════════════════════════════════════════════════════════════════
  //  GETTERS
  // ════════════════════════════════════════════════════════════════════════
  bool get isLoading           => _isLoading;
  bool get isSearching         => _isSearching;
  bool get isCreatingGroup     => _isCreatingGroup;
  bool get isRequestingGroup   => _isRequestingGroup;
  bool get isCancellingRequest => _isCancellingRequest;
  bool get isUpdatingRequest   => _isUpdatingRequest;
  bool get isLoadingMessages   => _isLoadingMessages;
  bool get isSendingMessage    => _isSendingMessage;
  bool get isSendingFile       => _isSendingFile;
  bool get isSendingVoice      => _isSendingVoice;
  bool get isSendingCamera     => _isSendingCamera;
  bool get isAddingMembers     => _isAddingMembers;
  bool get isRemovingMember    => _isRemovingMember;
  bool get isEditingMessage    => _isEditingMessage;
  bool get isDeletingMessage   => _isDeletingMessage;
  bool get isFetchingUsers     => _isFetchingUsers;
  bool get isLoadingMyGroups   => _isLoadingMyGroups;
  bool get isLoadingRequests   => _isLoadingRequests;

  String? get error              => _error;
  String? get createGroupError   => _createGroupError;
  String? get messagesError      => _messagesError;
  String? get sendMessageError   => _sendMessageError;
  String? get sendFileError      => _sendFileError;
  String? get sendVoiceError     => _sendVoiceError;
  String? get myGroupsError      => _myGroupsError;
  String? get requestsError      => _requestsError;
  String? get editMessageError   => _editMessageError;
  String? get deleteMessageError => _deleteMessageError;

  String get groupRequestMessage  => _groupRequestMessage;
  String get addMemberMessage     => _addMemberMessage;
  String get removeMessage        => _removeMessage;
  String get updateRequestMessage => _updateRequestMessage;

  List<Map<String, dynamic>> get groups =>
      _filteredGroups.isNotEmpty || _currentSearchQuery.isNotEmpty
          ? _filteredGroups
          : _groups;

  List<Map<String, dynamic>> get myGroups        => _myGroups;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  List<dynamic>              get allUsers        => _allUsers;

  String  get currentSearchQuery  => _currentSearchQuery;
  String? get currentGroupId      => _currentGroupId;
  double  get fileUploadProgress  => _fileUploadProgress;
  int     get allUsersTotalPages  => _allUsersTotalPages;
  int     get allUsersCurrentPage => _allUsersCurrentPage;
  bool    get hasMyGroups         => _myGroups.isNotEmpty;
  int     get myGroupsCount       => _myGroups.length;
  bool    get isSocketConnected   => _socket?.connected ?? false;

  int  get myGroupsCurrentPage => _myGroupsCurrentPage;
  int  get myGroupsTotalPages  => _myGroupsTotalPages;
  bool get myGroupsHasMore     => _myGroupsHasMore;

  List<Map<String, dynamic>> get currentGroupMessages =>
      _groupMessages[_currentGroupId ?? ''] ?? [];

  List<Map<String, dynamic>> getMessagesForGroup(String id) =>
      _groupMessages[id] ?? [];

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════
  @override
  void dispose() {
    _isDisposed = true;
    _socketReadySubscription?.cancel();
    _socketReadySubscription = null;
    _removeSocketListeners();
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET SETUP
  // ════════════════════════════════════════════════════════════════════════
  void initialize() {
    _clearAllErrors();
    _groups.clear();
    _filteredGroups.clear();
    _currentSearchQuery = '';
    _groupMessages.clear();
    _currentGroupId     = null;
    _fileUploadProgress = 0.0;

    _socketReadySubscription?.cancel();
    _socketReadySubscription = SocketService().onSocketReady.listen((socket) {
      if (!_isDisposed) {
        print('📡 [GroupChatProvider] Auto-wiring socket from onSocketReady');
        setSocket(socket);
      }
    });

    // Wire immediately if already connected
    final existing = SocketService().socket;
    if (existing != null && existing.connected) {
      print('📡 [GroupChatProvider] Wiring existing connected socket');
      setSocket(existing);
    } else {
      print('⚠️ [GroupChatProvider] No connected socket yet — waiting for onSocketReady');
    }

    _notify();
  }

  void setSocket(sio.Socket socket) {
    if (_socket == socket) return;
    _removeSocketListeners();
    _socket = socket;
    _addSocketListeners();
    print('🔌 [GroupChatProvider] Socket set — connected: ${socket.connected}');
    _notify();
  }

  void clearSocket() {
    _removeSocketListeners();
    _socket = null;
    print('🔌 [GroupChatProvider] Socket cleared');
    _notify();
  }

  void _addSocketListeners() {
    final s = _socket;
    if (s == null) return;

    // ✅ Match EXACTLY what server emits
    s.on('groupMessage',      (d) => _handleIncomingMessage(d, 'groupMessage'));
    s.on('groupVoiceMessage', (d) => _handleIncomingMessage(d, 'groupVoiceMessage'));
    s.on('groupFileMessage',  (d) => _handleIncomingMessage(d, 'groupFileMessage'));

    s.on('groupMessageEdited', (data) {
      if (_isDisposed) return;
      try {
        final map       = _toMap(data);
        final groupId   = map['groupId']?.toString();
        final messageId = map['messageId']?.toString();
        final newText   = map['newText']?.toString();
        if (groupId == null || messageId == null || newText == null) {
          print('⚠️ [GroupChat] groupMessageEdited missing fields: $map');
          return;
        }
        _updateMessageTextLocally(groupId, messageId, newText);
        _notify();
      } catch (e) {
        print('💥 [Socket] groupMessageEdited: $e');
      }
    });

    s.on('groupMessageDeleted', (data) {
      if (_isDisposed) return;
      try {
        final map       = _toMap(data);
        final groupId   = map['groupId']?.toString();
        final messageId = map['messageId']?.toString();
        if (groupId == null || messageId == null) {
          print('⚠️ [GroupChat] groupMessageDeleted missing fields: $map');
          return;
        }
        _markMessageDeletedLocally(groupId, messageId);
        _notify();
      } catch (e) {
        print('💥 [Socket] groupMessageDeleted: $e');
      }
    });

    print('🎯 [GroupChatProvider] Socket listeners registered');
  }

  void _removeSocketListeners() {
    final s = _socket;
    if (s == null) return;
    s.off('groupMessage');
    s.off('groupVoiceMessage');
    s.off('groupFileMessage');
    s.off('groupMessageEdited');
    s.off('groupMessageDeleted');
    print('🔕 [GroupChatProvider] Socket listeners removed');
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPER: safely convert any socket data to Map<String, dynamic>
  // ════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> _toMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HANDLE INCOMING MESSAGE — mirrors PersonalChatProvider._handleNewMessage
  // ════════════════════════════════════════════════════════════════════════
  void _handleIncomingMessage(dynamic data, String eventName) {
    if (_isDisposed) return;

    try {
      print('📨 [GroupChat] event=$eventName raw=$data');

      // STEP 1: Normalize
      final raw = _toMap(data);
      if (raw.isEmpty) {
        print('⚠️ [GroupChat] Empty data for event=$eventName');
        return;
      }

      // STEP 2: Extract message object
      Map<String, dynamic>? message;
      if (raw['message'] is Map) {
        message = Map<String, dynamic>.from(raw['message']);
      } else if (raw['data'] is Map) {
        message = Map<String, dynamic>.from(raw['data']);
      } else if (raw['_id'] != null) {
        message = raw;
      } else {
        print('⚠️ [GroupChat] Cannot find message in keys: ${raw.keys.toList()}');
        return;
      }

      // STEP 3: Extract groupId — check raw first then inside message
      String? groupId;
      final rawGroupId = raw['groupId'];
      if (rawGroupId is String && rawGroupId.isNotEmpty) {
        groupId = rawGroupId;
      } else if (rawGroupId is Map) {
        groupId = rawGroupId['_id']?.toString();
      } else {
        final msgGroupId = message['groupId'];
        if (msgGroupId is String && msgGroupId.isNotEmpty) {
          groupId = msgGroupId;
        } else if (msgGroupId is Map) {
          groupId = msgGroupId['_id']?.toString();
        }
      }

      if (groupId == null || groupId.isEmpty) {
        print('⚠️ [GroupChat] Could not extract groupId. raw keys: ${raw.keys.toList()}');
        return;
      }

      // STEP 4: Extract messageId
      final msgId = message['_id']?.toString();
      print('✅ [GroupChat] groupId=$groupId msgId=$msgId');

      // STEP 5: Initialize list if needed
      _groupMessages[groupId] ??= [];
      final msgs = _groupMessages[groupId]!;

      // STEP 6: Find optimistic message to replace
      final optimisticIdx = msgs.indexWhere(
            (m) =>
        m['isOptimistic'] == true &&
            m['_id']?.toString().startsWith('temp_') == true,
      );

      // STEP 7: Merge — update existing → replace optimistic → append new
      if (msgId != null && msgId.isNotEmpty) {
        final existingIdx = msgs.indexWhere(
              (m) => m['_id']?.toString() == msgId,
        );

        if (existingIdx != -1) {
          // Update existing in place, preserve replyToMessage
          final existing = msgs[existingIdx];
          final incoming = Map<String, dynamic>.from(message);
          if (incoming['replyToMessage'] == null &&
              existing['replyToMessage'] != null) {
            incoming['replyToMessage'] = existing['replyToMessage'];
          }
          msgs[existingIdx] = incoming;
          print('♻️ [GroupChat] Updated existing at idx=$existingIdx');
        } else if (optimisticIdx != -1) {
          // Replace optimistic with real message
          final optimistic = msgs[optimisticIdx];
          final incoming   = Map<String, dynamic>.from(message);
          if (incoming['replyToMessage'] == null &&
              optimistic['replyToMessage'] != null) {
            incoming['replyToMessage'] = optimistic['replyToMessage'];
          }
          msgs[optimisticIdx] = incoming;
          print('✅ [GroupChat] Replaced optimistic at idx=$optimisticIdx');
        } else {
          // New message from another user — append
          msgs.add(Map<String, dynamic>.from(message));
          print('➕ [GroupChat] Appended new. Total=${msgs.length}');
        }
      } else {
        // No _id — replace optimistic or append
        if (optimisticIdx != -1) {
          final optimistic = msgs[optimisticIdx];
          final incoming   = Map<String, dynamic>.from(message);
          if (incoming['replyToMessage'] == null &&
              optimistic['replyToMessage'] != null) {
            incoming['replyToMessage'] = optimistic['replyToMessage'];
          }
          msgs[optimisticIdx] = incoming;
          print('✅ [GroupChat] Replaced optimistic (no msgId) at idx=$optimisticIdx');
        } else {
          msgs.add(Map<String, dynamic>.from(message));
          print('➕ [GroupChat] Appended (no msgId). Total=${msgs.length}');
        }
      }

      // STEP 8: Increment unread only if group is NOT currently open
      if (groupId != _currentGroupId) {
        final myIdx = _myGroups.indexWhere(
              (g) => g['_id']?.toString() == groupId,
        );
        if (myIdx != -1) {
          final current = (_myGroups[myIdx]['unreadCount'] as int?) ?? 0;
          _myGroups[myIdx] = Map<String, dynamic>.from(_myGroups[myIdx])
            ..['unreadCount'] = current + 1;
          print('🔔 [GroupChat] unread=$groupId → ${current + 1}');
        }
      }

      // STEP 9: Move group to top
      _moveGroupToTop(groupId, Map<String, dynamic>.from(message));
      // STEP 10: Notify UI
      if (onNewMessageReceived != null) {
        onNewMessageReceived!();
      }
      _notify();

      // STEP 10: Notify UI
      _notify();
      print('🎉 [GroupChat] Done for group=$groupId');
    } catch (e, stack) {
      print('💥 [GroupChat] _handleIncomingMessage crashed: $e');
      print('💥 Stack: $stack');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ALL GROUPS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchGroups({int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroups page=$pageNo');
    _isLoading = true; _error = null; _notify();

    try {
      final r = await _svc.getAllGroups(pageNo: pageNo);
      if (!r['error']) {
        _groups = List<Map<String, dynamic>>.from(r['data'] ?? []);
        if (_currentSearchQuery.isNotEmpty) _filterLocally(_currentSearchQuery);
        else _filteredGroups.clear();
      } else {
        _error = r['message'];
      }
    } catch (e) {
      _error = 'Exception: $e';
      print('💥 fetchGroups: $e');
    }

    _isLoading = false; _notify();
  }

  Future<void> searchGroups(String query) async {
    _currentSearchQuery = query;
    if (query.isEmpty) { _filteredGroups.clear(); _notify(); return; }
    _isSearching = true; _error = null; _notify();

    try {
      final r = await _svc.getAllGroups(searchQuery: query);
      _filteredGroups = r['error']
          ? []
          : List<Map<String, dynamic>>.from(r['data'] ?? []);
      if (r['error']) _error = r['message'];
    } catch (e) {
      _error = 'Exception: $e';
      print('💥 searchGroups: $e');
    }

    _isSearching = false; _notify();
  }

  void _filterLocally(String q) {
    if (q.isEmpty) { _filteredGroups.clear(); return; }
    final lq = q.toLowerCase();
    _filteredGroups = _groups.where((g) =>
    (g['name']?.toString().toLowerCase().contains(lq) ?? false) ||
        (g['description']?.toString().toLowerCase().contains(lq) ?? false))
        .toList();
  }

  void clearSearch() {
    _currentSearchQuery = ''; _filteredGroups.clear(); _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MY GROUPS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchMyGroups({String? communityId, String? search}) async {
    print('🔄 [Provider] fetchMyGroups communityId=$communityId search=$search');
    _isLoadingMyGroups   = true;
    _myGroupsError       = null;
    _currentCommunityId  = communityId;
    _myGroupsCurrentPage = 1;
    _notify();

    try {
      final r = await _svc.getMyGroups(
        communityId: communityId, pageNo: 1, search: search,
      );
      if (!r['error']) {
        _myGroups = List<Map<String, dynamic>>.from(r['data'] ?? []);
        final p = r['pagination'] as Map<String, dynamic>?;
        _myGroupsCurrentPage = (p?['currentPage'] as int?) ?? 1;
        _myGroupsTotalPages  = (p?['totalPages']  as int?) ?? 1;
        _myGroupsHasMore     = (p?['hasMore']     as bool?) ?? false;
      } else {
        _myGroupsError = r['message'];
      }
    } catch (e) {
      _myGroupsError = 'Exception: $e';
      print('💥 fetchMyGroups: $e');
    }

    _isLoadingMyGroups = false; _notify();
  }

  Future<void> loadMoreMyGroups({String? search}) async {
    if (_isLoadingMyGroups || !_myGroupsHasMore) return;
    final nextPage = _myGroupsCurrentPage + 1;
    _isLoadingMyGroups = true; _notify();

    try {
      final r = await _svc.getMyGroups(
        communityId: _currentCommunityId, pageNo: nextPage, search: search,
      );
      if (!r['error']) {
        final newGroups   = List<Map<String, dynamic>>.from(r['data'] ?? []);
        final existingIds = _myGroups.map((g) => g['_id']).toSet();
        for (final g in newGroups) {
          if (!existingIds.contains(g['_id'])) _myGroups.add(g);
        }
        final p = r['pagination'] as Map<String, dynamic>?;
        _myGroupsCurrentPage = (p?['currentPage'] as int?) ?? nextPage;
        _myGroupsTotalPages  = (p?['totalPages']  as int?) ?? _myGroupsTotalPages;
        _myGroupsHasMore     = (p?['hasMore']     as bool?) ?? false;
      } else {
        _myGroupsError = r['message'];
      }
    } catch (e) {
      _myGroupsError = 'Exception: $e';
      print('💥 loadMoreMyGroups: $e');
    }

    _isLoadingMyGroups = false; _notify();
  }

  Future<void> refreshMyGroups({String? search}) async =>
      fetchMyGroups(communityId: _currentCommunityId, search: search);

  void clearMyGroups() {
    _myGroups.clear();
    _myGroupsError       = null;
    _currentCommunityId  = null;
    _myGroupsCurrentPage = 1;
    _myGroupsTotalPages  = 1;
    _myGroupsHasMore     = false;
    _notify();
  }

  bool isMyGroup(String groupId) =>
      _myGroups.any((g) => g['_id'] == groupId);

  List<Map<String, dynamic>> filterMyGroups(String q) {
    if (q.isEmpty) return _myGroups;
    final lq = q.toLowerCase();
    return _myGroups.where((g) =>
    (g['name']?.toString().toLowerCase().contains(lq) ?? false) ||
        (g['description']?.toString().toLowerCase().contains(lq) ?? false))
        .toList();
  }
  Future<bool> createGroup({
    required String name,
    required String description,
    String? profileImage,
    List<String> members = const [],
  }) async {
    print('🔄 [Provider] createGroup "$name"');
    _isCreatingGroup = true; _createGroupError = null; _notify();

    try {
      final r = await _svc.createGroup(
        name: name, description: description,
        profileImage: profileImage, members: members,
      );
      if (!r['error']) {
        if (r['data'] != null) {
          _groups.insert(0, r['data'] as Map<String, dynamic>);
        }
        await fetchGroups();
        _isCreatingGroup = false; _notify();
        return true;
      }
      _createGroupError = r['message'];
    } catch (e) {
      _createGroupError = 'Exception: $e';
      print('💥 createGroup: $e');
    }

    _isCreatingGroup = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchGroupMessages(String groupId, {int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroupMessages $groupId page=$pageNo');
    _isLoadingMessages = true;
    _messagesError     = null;
    _currentGroupId    = groupId;
    _notify();

    try {
      final r = await _svc.getGroupMessages(groupId, pageNo: pageNo);
      if (!r['error']) {
        _groupMessages[groupId] =
        List<Map<String, dynamic>>.from(r['data'] ?? []);
      } else {
        _messagesError          = r['message'];
        _groupMessages[groupId] = [];
      }
    } catch (e) {
      _messagesError          = 'Exception: $e';
      _groupMessages[groupId] = [];
      print('💥 fetchGroupMessages: $e');
    }

    _isLoadingMessages = false; _notify();
  }

  Future<void> refreshCurrentGroupMessages() async {
    if (_currentGroupId != null) await fetchGroupMessages(_currentGroupId!);
  }

  void setCurrentGroup(String groupId) {
    _currentGroupId = groupId; _messagesError = null; _notify();
  }

  void clearCurrentGroup() {
    _currentGroupId = null; _messagesError = null; _notify();
  }

  void addMessageToCurrentGroup(Map<String, dynamic> message) {
    if (_currentGroupId == null) return;
    _groupMessages[_currentGroupId!] ??= [];
    _groupMessages[_currentGroupId!]!.add(message);
    _notify();
  }

  void removeOptimisticMessage(String groupId, String tempId) {
    try {
      final msgs = _groupMessages[groupId];
      if (msgs == null) return;
      msgs.removeWhere((m) => m['_id']?.toString() == tempId);
      _notify();
    } catch (e) {
      print('💥 removeOptimisticMessage: $e');
    }
  }

  void updateOptimisticStatus(String groupId, String tempId, String status) {
    try {
      final msgs = _groupMessages[groupId];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m['_id']?.toString() == tempId);
      if (idx != -1) {
        msgs[idx] = Map<String, dynamic>.from(msgs[idx])..['status'] = status;
        _notify();
      }
    } catch (e) {
      print('💥 updateOptimisticStatus: $e');
    }
  }

  Future<bool> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
    String? image,
    String? replyTo,
    String? tempId, // ← ADD THIS
  }) async {
    _isSendingMessage = true; _sendMessageError = null; _notify();

    try {
      final r = await _svc.sendGroupMessage(
        groupId: groupId, text: text,
        communityInfo: communityInfo, image: image, replyTo: replyTo,
      );

      if (!r['error']) {
        // ✅ Replace optimistic message with real one
        final realMessage = r['message'] ?? r['data']?['message'] ?? r['data'];
        if (realMessage is Map && tempId != null) {
          final msgs = _groupMessages[groupId];
          if (msgs != null) {
            final idx = msgs.indexWhere((m) => m['_id']?.toString() == tempId);
            if (idx != -1) {
              msgs[idx] = Map<String, dynamic>.from(realMessage as Map);
              print('✅ [GroupChat] Replaced optimistic tempId=$tempId with real message');
            }
          }
        }
        _moveGroupToTop(groupId, {'text': text});
        _isSendingMessage = false; _notify();
        return true;
      }
      _sendMessageError = r['message'];
    } catch (e) {
      _sendMessageError = 'Exception: $e';
      print('💥 sendGroupMessage: $e');
    }

    _isSendingMessage = false; _notify();
    return false;
  }


  Future<bool> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
    String? replyTo,
    String? tempId, // ← ADD THIS
  }) async {
    _isSendingFile = true; _sendFileError = null; _fileUploadProgress = 0.0; _notify();

    try {
      final r = await _svc.sendGroupFileMessage(
        groupId: groupId, file: file,
        communityInfo: communityInfo, replyTo: replyTo,
      );
      if (!r['error']) {
        final realMessage = r['message'] ?? r['data']?['message'] ?? r['data'];
        if (realMessage is Map && tempId != null) {
          final msgs = _groupMessages[groupId];
          if (msgs != null) {
            final idx = msgs.indexWhere((m) => m['_id']?.toString() == tempId);
            if (idx != -1) {
              msgs[idx] = Map<String, dynamic>.from(realMessage as Map);
            }
          }
        }
        _moveGroupToTop(groupId, {'isFile': true});
        _isSendingFile = false; _fileUploadProgress = 1.0; _notify();
        return true;
      }
      _sendFileError = r['message'];
    } catch (e) {
      _sendFileError = 'Exception: $e';
      print('💥 sendGroupFileMessage: $e');
    }

    _isSendingFile = false; _fileUploadProgress = 0.0; _notify();
    return false;
  }
  Future<bool> sendGroupVoiceMessage({
    required String groupId,
    required File audioFile,
    Map<String, dynamic>? communityInfo,
    int? audioDurationMs,
    String? replyTo,
    String? tempId, // ← ADD THIS
  }) async {
    _isSendingVoice = true; _sendVoiceError = null; _notify();

    try {
      final r = await _svc.sendGroupVoiceMessage(
        groupId: groupId, audioFile: audioFile,
        communityInfo: communityInfo,
        audioDurationMs: audioDurationMs, replyTo: replyTo,
      );
      if (!r['error']) {
        final realMessage = r['message'] ?? r['data']?['message'] ?? r['data'];
        if (realMessage is Map && tempId != null) {
          final msgs = _groupMessages[groupId];
          if (msgs != null) {
            final idx = msgs.indexWhere((m) => m['_id']?.toString() == tempId);
            if (idx != -1) {
              final real = Map<String, dynamic>.from(realMessage as Map);
              // Preserve local audio path for playback
              real['localFilePath']   = audioFile.path;
              if (real['audioDurationMs'] == null && audioDurationMs != null) {
                real['audioDurationMs'] = audioDurationMs;
              }
              msgs[idx] = real;
            }
          }
        }
        _moveGroupToTop(groupId, {'isAudio': true});
        _isSendingVoice = false; _notify();
        return true;
      }
      _sendVoiceError = r['message'];
    } catch (e) {
      _sendVoiceError = 'Exception: $e';
      print('💥 sendGroupVoiceMessage: $e');
    }

    _isSendingVoice = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND CAMERA PHOTO
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupCameraPhoto({
    required String groupId,
    Map<String, dynamic>? communityInfo,
  }) async {
    _isSendingCamera = true; _sendFileError = null; _notify();

    try {
      final r = await _svc.sendGroupCameraPhoto(
        groupId: groupId, communityInfo: communityInfo,
      );
      if (r['cancelled'] == true) {
        _isSendingCamera = false; _notify(); return false;
      }
      if (!r['error']) {
        if (_currentGroupId == groupId && r['data'] != null) {
          _groupMessages[groupId] ??= [];
          _groupMessages[groupId]!
              .add(Map<String, dynamic>.from(r['data'] as Map));
        }
        _moveGroupToTop(groupId, {'isFile': true});
        _isSendingCamera = false; _notify();
        return true;
      }
      _sendFileError = r['message'];
    } catch (e) {
      _sendFileError = 'Exception: $e';
      print('💥 sendGroupCameraPhoto: $e');
    }

    _isSendingCamera = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EDIT / DELETE
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> editGroupMessage({
    required String messageId,
    required String newText,
    required String groupId,
  }) async {
    if (!(_socket?.connected ?? false)) {
      _editMessageError = 'Not connected to server'; _notify(); return false;
    }
    _isEditingMessage = true; _editMessageError = null; _notify();

    try {
      _svc.editGroupMessage(
        messageId: messageId, newText: newText, groupId: groupId,
      );
      _updateMessageTextLocally(groupId, messageId, newText);
    } catch (e) {
      _editMessageError = 'Exception: $e';
      print('💥 editGroupMessage: $e');
      _isEditingMessage = false; _notify();
      return false;
    }

    _isEditingMessage = false; _notify();
    return true;
  }

  Future<bool> deleteGroupMessage({
    required String messageId,
    required String groupId,
  }) async {
    if (!(_socket?.connected ?? false)) {
      _deleteMessageError = 'Not connected to server'; _notify(); return false;
    }
    _isDeletingMessage = true; _deleteMessageError = null; _notify();

    try {
      _svc.deleteGroupMessage(messageId: messageId, groupId: groupId);
      _markMessageDeletedLocally(groupId, messageId);
    } catch (e) {
      _deleteMessageError = 'Exception: $e';
      print('💥 deleteGroupMessage: $e');
      _isDeletingMessage = false; _notify();
      return false;
    }

    _isDeletingMessage = false; _notify();
    return true;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  JOIN / LEAVE / REQUESTS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> requestToJoinGroup(String groupId) async {
    _isRequestingGroup = true; _groupRequestMessage = ''; _notify();
    try {
      final r = await _svc.requestToJoinGroup(groupId: groupId);
      _groupRequestMessage = r['message'] ?? 'Unknown';
    } catch (e) {
      _groupRequestMessage = 'Exception: $e';
      print('💥 requestToJoinGroup: $e');
    }
    _isRequestingGroup = false; _notify();
  }

  Future<bool> cancelGroupRequest(String groupId) async {
    _isCancellingRequest = true; _notify();
    try {
      final r = await _svc.cancelGroupRequest(groupId: groupId);
      _isCancellingRequest = false;
      if (!r['error']) {
        for (final g in [..._groups, ..._myGroups]) {
          if (g['_id'] == groupId) g['isRequested'] = false;
        }
      }
      _notify();
      return !r['error'];
    } catch (e) {
      print('💥 cancelGroupRequest: $e');
      _isCancellingRequest = false; _notify();
      return false;
    }
  }

  Future<void> fetchGroupMembers(String groupId) async {
    try {
      final r = await _svc.getAllGroups(searchQuery: groupId);
      if (!r['error']) {
        final fresh = List<Map<String, dynamic>>.from(r['data'] ?? []);
        for (final fg in fresh) {
          final idx   = _groups.indexWhere((g) => g['_id'] == fg['_id']);
          if (idx   != -1) _groups[idx]   = fg;
          final myIdx = _myGroups.indexWhere((g) => g['_id'] == fg['_id']);
          if (myIdx != -1) _myGroups[myIdx] = fg;
        }
        _notify();
      }
    } catch (e) {
      print('💥 fetchGroupMembers: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PENDING REQUESTS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchPendingRequests() async {
    _isLoadingRequests = true; _requestsError = null;
    _pendingRequests   = []; _notify();
    try {
      final adminGroups =
      _groups.where((g) => g['isAdmin'] == true).toList();
      if (adminGroups.isEmpty) {
        _isLoadingRequests = false; _notify(); return;
      }
      final results = await Future.wait(adminGroups.map((g) async {
        try {
          final r = await _svc.getGroupRequests(g['_id']);
          if (!r['error']) {
            final reqs =
            List<Map<String, dynamic>>.from(r['data'] ?? []);
            for (final req in reqs) {
              req['groupName'] = g['name'];
              req['groupId']   = g['_id'];
            }
            return reqs;
          }
        } catch (e) {
          print('💥 fetchPendingRequests inner: $e');
        }
        return <Map<String, dynamic>>[];
      }));
      for (final list in results) _pendingRequests.addAll(list);
    } catch (e) {
      _requestsError = e.toString();
      print('💥 fetchPendingRequests: $e');
    }
    _isLoadingRequests = false; _notify();
  }

  Future<bool> updateGroupRequest({
    required String requestId,
    required String status,
  }) async {
    _isUpdatingRequest = true; _updateRequestMessage = ''; _notify();
    try {
      final r = await _svc.updateGroupRequest(
        requestId: requestId, status: status,
      );
      _updateRequestMessage = r['message'] ?? 'Unknown';
      _isUpdatingRequest    = false;
      if (!r['error']) {
        _pendingRequests.removeWhere((req) => req['_id'] == requestId);
      }
      _notify();
      return !r['error'];
    } catch (e) {
      _updateRequestMessage = 'Exception: $e';
      print('💥 updateGroupRequest: $e');
      _isUpdatingRequest = false; _notify();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MEMBERS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
  }) async {
    _isAddingMembers = true; _addMemberMessage = ''; _notify();
    try {
      final r = await _svc.addMembersToGroup(
        groupId: groupId, memberIds: memberIds,
      );
      _addMemberMessage = r['message'] ?? 'Unknown';
    } catch (e) {
      _addMemberMessage = 'Exception: $e';
      print('💥 addMembersToGroup: $e');
    }
    _isAddingMembers = false; _notify();
  }

  Future<bool> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    _isRemovingMember = true; _removeMessage = ''; _notify();
    try {
      final r = await _svc.removeMemberFromGroup(
        groupId: groupId, userId: userId,
      );
      _removeMessage    = r['message'] ?? 'Unknown';
      _isRemovingMember = false; _notify();
      return !r['error'];
    } catch (e) {
      _removeMessage    = 'Exception: $e';
      print('💥 removeMemberFromGroup: $e');
      _isRemovingMember = false; _notify();
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FETCH ALL USERS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchAllUsers({int page = 1, String? search}) async {
    _isFetchingUsers = true; _notify();
    try {
      final r = await _svc.fetchAllUsers(page: page, search: search);
      if (!r['error']) {
        _allUsers            = r['data']?['allUsers'] ?? [];
        _allUsersTotalPages  = r['totalPage']   ?? 1;
        _allUsersCurrentPage = r['currentPage'] ?? 1;
      }
    } catch (e) {
      print('💥 fetchAllUsers: $e');
    }
    _isFetchingUsers = false; _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LOCAL STATE HELPERS
  // ════════════════════════════════════════════════════════════════════════
  void _moveGroupToTop(String groupId, Map<String, dynamic> message) {
    try {
      final idx = _myGroups.indexWhere(
            (g) => g['_id']?.toString() == groupId,
      );
      if (idx == -1) return;

      final preview =
      message['text']?.toString().isNotEmpty == true
          ? message['text'].toString()
          : message['isAudio'] == true
          ? '🎤 Voice message'
          : message['isFile'] == true
          ? '📎 File'
          : '';

      final updated = Map<String, dynamic>.from(_myGroups[idx]);
      updated['updatedAt']   = DateTime.now().toIso8601String();
      updated['lastMessage'] = {
        'text':   preview,
        'sender': {'profile': {'name': 'You'}},
      };

      _myGroups.removeAt(idx);
      _myGroups.insert(0, updated);
    } catch (e) {
      print('💥 _moveGroupToTop: $e');
    }
  }

  void clearUnreadCount(String groupId) {
    bool changed = false;
    try {
      final myIdx =
      _myGroups.indexWhere((g) => g['_id']?.toString() == groupId);
      if (myIdx != -1 && (_myGroups[myIdx]['unreadCount'] ?? 0) != 0) {
        _myGroups[myIdx] = Map<String, dynamic>.from(_myGroups[myIdx])
          ..['unreadCount'] = 0;
        changed = true;
      }

      final allIdx =
      _groups.indexWhere((g) => g['_id']?.toString() == groupId);
      if (allIdx != -1 && (_groups[allIdx]['unreadCount'] ?? 0) != 0) {
        _groups[allIdx] = Map<String, dynamic>.from(_groups[allIdx])
          ..['unreadCount'] = 0;
        changed = true;
      }
    } catch (e) {
      print('💥 clearUnreadCount: $e');
    }
    if (changed) _notify();
  }

  void _updateMessageTextLocally(
      String groupId, String messageId, String newText) {
    try {
      final msgs = _groupMessages[groupId];
      if (msgs == null) return;
      final idx =
      msgs.indexWhere((m) => m['_id']?.toString() == messageId);
      if (idx != -1) {
        msgs[idx] = Map<String, dynamic>.from(msgs[idx])
          ..['text']     = newText
          ..['isEdited'] = true;
      }
    } catch (e) {
      print('💥 _updateMessageTextLocally: $e');
    }
  }

  void _markMessageDeletedLocally(String groupId, String messageId) {
    try {
      final msgs = _groupMessages[groupId];
      if (msgs == null) return;
      final idx =
      msgs.indexWhere((m) => m['_id']?.toString() == messageId);
      if (idx != -1) {
        msgs[idx] = Map<String, dynamic>.from(msgs[idx])
          ..['isDelete'] = true;
      }
    } catch (e) {
      print('💥 _markMessageDeletedLocally: $e');
    }
  }

  void markMessageAsRead(String messageId, String userId) {
    try {
      if (_currentGroupId == null) return;
      final msgs = _groupMessages[_currentGroupId!];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m['_id']?.toString() == messageId);
      if (idx != -1) {
        final readers = List<String>.from(msgs[idx]['readers'] ?? []);
        if (!readers.contains(userId)) {
          readers.add(userId);
          msgs[idx] = Map<String, dynamic>.from(msgs[idx])
            ..['readers'] = readers;
          _notify();
        }
      }
    } catch (e) {
      print('💥 markMessageAsRead: $e');
    }
  }

  void updateFileUploadProgress(double progress) {
    _fileUploadProgress = progress; _notify();
  }

  void onGroupMessageEdited(
      String groupId, String messageId, String newText) {
    _updateMessageTextLocally(groupId, messageId, newText); _notify();
  }

  void onGroupMessageDeleted(String groupId, String messageId) {
    _markMessageDeletedLocally(groupId, messageId); _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GROUP LOOKUP
  // ════════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? getGroupById(String id) {
    try {
      return _groups.firstWhere((g) => g['_id']?.toString() == id);
    } catch (_) { return null; }
  }

  Map<String, dynamic>? getMyGroupById(String id) {
    try {
      return _myGroups.firstWhere((g) => g['_id']?.toString() == id);
    } catch (_) { return null; }
  }

  bool isGroupMember(String id)      =>
      getGroupById(id)?['isMember']   ?? false;
  bool isGroupAdmin(String id)       =>
      getGroupById(id)?['isAdmin']     ?? false;
  bool hasRequestedToJoin(String id) =>
      getGroupById(id)?['isRequested'] ?? false;

  // ════════════════════════════════════════════════════════════════════════
  //  CLEAR ERRORS
  // ════════════════════════════════════════════════════════════════════════
  void _clearAllErrors() {
    _error             = null; _createGroupError  = null;
    _messagesError     = null; _sendMessageError  = null;
    _sendFileError     = null; _sendVoiceError    = null;
    _myGroupsError     = null; _requestsError     = null;
    _editMessageError  = null; _deleteMessageError = null;
  }

  void clearErrors()             { _clearAllErrors();            _notify(); }
  void clearCreateGroupError()   { _createGroupError   = null;   _notify(); }
  void clearMessagesError()      { _messagesError       = null;   _notify(); }
  void clearSendMessageError()   { _sendMessageError    = null;   _notify(); }
  void clearSendFileError()      { _sendFileError       = null;   _notify(); }
  void clearSendVoiceError()     { _sendVoiceError      = null;   _notify(); }
  void clearMyGroupsError()      { _myGroupsError       = null;   _notify(); }
  void clearEditMessageError()   { _editMessageError    = null;   _notify(); }
  void clearDeleteMessageError() { _deleteMessageError  = null;   _notify(); }
}