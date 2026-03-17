import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../services/group_chat_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GroupChatProvider
// ═══════════════════════════════════════════════════════════════════════════
class GroupChatProvider with ChangeNotifier {
  final GroupChatService _svc = GroupChatService();

  // ── Socket ───────────────────────────────────────────────────────────────
  sio.Socket? _socket;
  bool _isDisposed = false;

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

  // ── Result strings (for SnackBars) ───────────────────────────────────────
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

  // groupId → message list
  final Map<String, List<Map<String, dynamic>>> _groupMessages = {};

  String  _currentSearchQuery  = '';
  String? _currentGroupId;
  String? _currentCommunityId;
  double  _fileUploadProgress  = 0.0;
  int     _allUsersTotalPages   = 1;
  int     _allUsersCurrentPage  = 1;

  // ── MyGroups pagination ───────────────────────────────────────────────────
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

  // MyGroups pagination getters
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
    _removeSocketListeners();
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET
  // ════════════════════════════════════════════════════════════════════════
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

    s.on('groupMessage',      (d) => _handleIncomingMessage(d));
    s.on('groupVoiceMessage', (d) => _handleIncomingMessage(d));
    s.on('groupFileMessage',  (d) => _handleIncomingMessage(d));

    s.on('groupMessageEdited', (data) {
      if (_isDisposed) return;
      try {
        final groupId   = data?['groupId']?.toString();
        final messageId = data?['messageId']?.toString();
        final newText   = data?['newText']?.toString();
        if (groupId == null || messageId == null || newText == null) return;
        _updateMessageTextLocally(groupId, messageId, newText);
        _notify();
      } catch (e) { print('💥 [Socket] groupMessageEdited: $e'); }
    });

    s.on('groupMessageDeleted', (data) {
      if (_isDisposed) return;
      try {
        final groupId   = data?['groupId']?.toString();
        final messageId = data?['messageId']?.toString();
        if (groupId == null || messageId == null) return;
        _markMessageDeletedLocally(groupId, messageId);
        _notify();
      } catch (e) { print('💥 [Socket] groupMessageDeleted: $e'); }
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

  void _handleIncomingMessage(dynamic data) {
    if (_isDisposed) return;
    try {
      final raw     = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final message = (raw['message'] ?? raw['data']) as Map<String, dynamic>?;
      final groupId = (raw['groupId'] ?? message?['groupId'])?.toString();

      if (message == null || groupId == null) return;

      final msgId   = message['_id']?.toString();
      final msgs    = _groupMessages[groupId] ??= [];

      // Try to find and replace an optimistic (temp_*) message first
      final optimisticIdx = msgs.indexWhere(
            (m) => m['isOptimistic'] == true && m['_id'].toString().startsWith('temp_'),
      );

      if (msgId != null) {
        final existingIdx = msgs.indexWhere((m) => m['_id'] == msgId);
        if (existingIdx != -1) {
          // Already exists — update in place (no blink)
          msgs[existingIdx] = Map<String, dynamic>.from(message);
        } else if (optimisticIdx != -1) {
          // Replace the optimistic bubble with the real message (no blink)
          msgs[optimisticIdx] = Map<String, dynamic>.from(message);
        } else {
          msgs.add(Map<String, dynamic>.from(message));
        }
      } else {
        if (optimisticIdx != -1) {
          msgs[optimisticIdx] = Map<String, dynamic>.from(message);
        } else {
          msgs.add(Map<String, dynamic>.from(message));
        }
      }
      _notify();
    } catch (e) {
      print('💥 [GroupChatProvider] _handleIncomingMessage: $e');
    }
  }

  Future<Map<String, dynamic>?> _emitWithAck(
      String event, Map<String, dynamic> data) async {
    final s = _socket;
    if (s == null || !s.connected) return null;
    final completer = Completer<Map<String, dynamic>?>();
    try {
      s.emitWithAck(event, data, ack: (response) {
        if (response is Map) {
          completer.complete(Map<String, dynamic>.from(response));
        } else {
          completer.complete(null);
        }
      });
    } catch (e) {
      return null;
    }
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  INIT / RESET
  // ════════════════════════════════════════════════════════════════════════
  void initialize() {
    _clearAllErrors();
    _groups.clear();
    _filteredGroups.clear();
    _currentSearchQuery = '';
    _groupMessages.clear();
    _currentGroupId = null;
    _fileUploadProgress = 0.0;
    _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ALL GROUPS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchGroups({int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroups page=$pageNo');
    _isLoading = true; _error = null; _notify();

    final r = await _svc.getAllGroups(pageNo: pageNo);
    if (!r['error']) {
      _groups = List<Map<String, dynamic>>.from(r['data'] ?? []);
      if (_currentSearchQuery.isNotEmpty) _filterLocally(_currentSearchQuery);
      else _filteredGroups.clear();
    } else {
      _error = r['message'];
    }
    _isLoading = false; _notify();
  }

  Future<void> searchGroups(String query) async {
    _currentSearchQuery = query;
    if (query.isEmpty) { _filteredGroups.clear(); _notify(); return; }
    _isSearching = true; _error = null; _notify();

    final r = await _svc.getAllGroups(searchQuery: query);
    _filteredGroups = r['error'] ? [] : List<Map<String, dynamic>>.from(r['data'] ?? []);
    if (r['error']) _error = r['message'];
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
  //  MY GROUPS  (unified: personal + community via same endpoint)
  // ════════════════════════════════════════════════════════════════════════

  /// Fetch page 1 and reset list. Supports optional [search].
  /// Pass [communityId] to get community-specific groups.
  Future<void> fetchMyGroups({
    String? communityId,
    String? search,
  }) async {
    print('🔄 [Provider] fetchMyGroups communityId=$communityId search=$search');
    _isLoadingMyGroups   = true;
    _myGroupsError       = null;
    _currentCommunityId  = communityId;
    _myGroupsCurrentPage = 1;
    _notify();

    final r = await _svc.getMyGroups(
      communityId: communityId,
      pageNo: 1,
      search: search,
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
    _isLoadingMyGroups = false;
    _notify();
  }

  /// Appends next page to _myGroups. Call from scroll listener.
  Future<void> loadMoreMyGroups({String? search}) async {
    if (_isLoadingMyGroups || !_myGroupsHasMore) return;
    final nextPage = _myGroupsCurrentPage + 1;
    print('🔄 [Provider] loadMoreMyGroups page=$nextPage');
    _isLoadingMyGroups = true;
    _notify();

    final r = await _svc.getMyGroups(
      communityId: _currentCommunityId,
      pageNo: nextPage,
      search: search,
    );

    if (!r['error']) {
      final newGroups  = List<Map<String, dynamic>>.from(r['data'] ?? []);
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
    _isLoadingMyGroups = false;
    _notify();
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

  bool isMyGroup(String groupId) => _myGroups.any((g) => g['_id'] == groupId);

  List<Map<String, dynamic>> filterMyGroups(String q) {
    if (q.isEmpty) return _myGroups;
    final lq = q.toLowerCase();
    return _myGroups.where((g) =>
    (g['name']?.toString().toLowerCase().contains(lq) ?? false) ||
        (g['description']?.toString().toLowerCase().contains(lq) ?? false))
        .toList();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CREATE GROUP
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> createGroup({
    required String name,
    required String description,
    String? profileImage,
    List<String> members = const [],
  }) async {
    print('🔄 [Provider] createGroup "$name"');
    _isCreatingGroup = true; _createGroupError = null; _notify();

    final r = await _svc.createGroup(
        name: name, description: description,
        profileImage: profileImage, members: members);

    if (!r['error']) {
      if (r['data'] != null) _groups.insert(0, r['data'] as Map<String, dynamic>);
      await fetchGroups();
      _isCreatingGroup = false; _notify();
      return true;
    }
    _createGroupError = r['message'];
    _isCreatingGroup = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchGroupMessages(String groupId, {int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroupMessages $groupId page=$pageNo');
    _isLoadingMessages = true; _messagesError = null;
    _currentGroupId = groupId; _notify();

    final r = await _svc.getGroupMessages(groupId, pageNo: pageNo);
    _groupMessages[groupId] = r['error']
        ? [] : List<Map<String, dynamic>>.from(r['data'] ?? []);
    if (r['error']) _messagesError = r['message'];
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

  // ── Optimistic helpers ────────────────────────────────────────────────
  void addMessageToCurrentGroup(Map<String, dynamic> message) {
    if (_currentGroupId == null) return;
    _groupMessages[_currentGroupId!] ??= [];
    _groupMessages[_currentGroupId!]!.add(message);
    _notify();
  }

  void removeOptimisticMessage(String groupId, String tempId) {
    final msgs = _groupMessages[groupId];
    if (msgs == null) return;
    msgs.removeWhere((m) => m['_id'] == tempId);
    _notify();
  }

  void updateOptimisticStatus(String groupId, String tempId, String status) {
    final msgs = _groupMessages[groupId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m['_id'] == tempId);
    if (idx != -1) {
      msgs[idx] = Map<String, dynamic>.from(msgs[idx])..['status'] = status;
      _notify();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND TEXT MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
    String? image,
  }) async {
    _isSendingMessage = true; _sendMessageError = null; _notify();

    final r = await _svc.sendGroupMessage(
        groupId: groupId, text: text,
        communityInfo: communityInfo, image: image);

    if (!r['error']) {
      _isSendingMessage = false; _notify();
      return true;
    }
    _sendMessageError = r['message'];
    _isSendingMessage = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND FILE
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
  }) async {
    _isSendingFile = true; _sendFileError = null; _fileUploadProgress = 0.0; _notify();

    final r = await _svc.sendGroupFileMessage(
        groupId: groupId, file: file, communityInfo: communityInfo);

    if (!r['error']) {
      _isSendingFile = false; _fileUploadProgress = 1.0; _notify();
      return true;
    }
    _sendFileError = r['message'];
    _isSendingFile = false; _fileUploadProgress = 0.0; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND VOICE MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupVoiceMessage({
    required String groupId,
    required File audioFile,
    Map<String, dynamic>? communityInfo,
    int? audioDurationMs,
  }) async {
    _isSendingVoice = true; _sendVoiceError = null; _notify();

    final r = await _svc.sendGroupVoiceMessage(
        groupId: groupId, audioFile: audioFile,
        communityInfo: communityInfo, audioDurationMs: audioDurationMs);

    if (!r['error']) {
      _isSendingVoice = false; _notify();
      return true;
    }
    _sendVoiceError = r['message'];
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

    final r = await _svc.sendGroupCameraPhoto(
        groupId: groupId, communityInfo: communityInfo);

    if (r['cancelled'] == true) {
      _isSendingCamera = false; _notify(); return false;
    }
    if (!r['error']) {
      if (_currentGroupId == groupId && r['data'] != null) {
        _groupMessages[groupId] ??= [];
        _groupMessages[groupId]!.add(Map<String, dynamic>.from(r['data'] as Map));
      }
      _isSendingCamera = false; _notify();
      return true;
    }
    _sendFileError = r['message'];
    _isSendingCamera = false; _notify();
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EDIT / DELETE MESSAGES (socket-only)
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> editGroupMessage({
    required String messageId,
    required String newText,
    required String groupId,
  }) async {
    if (!_svc.isSocketConnected) {
      _editMessageError = 'Not connected to server';
      _notify();
      return false;
    }
    _isEditingMessage = true; _editMessageError = null; _notify();
    _svc.editGroupMessage(messageId: messageId, newText: newText, groupId: groupId);
    _updateMessageTextLocally(groupId, messageId, newText);
    _isEditingMessage = false; _notify();
    return true;
  }

  Future<bool> deleteGroupMessage({
    required String messageId,
    required String groupId,
  }) async {
    if (!_svc.isSocketConnected) {
      _deleteMessageError = 'Not connected to server';
      _notify();
      return false;
    }
    _isDeletingMessage = true; _deleteMessageError = null; _notify();
    _svc.deleteGroupMessage(messageId: messageId, groupId: groupId);
    _markMessageDeletedLocally(groupId, messageId);
    _isDeletingMessage = false; _notify();
    return true;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  JOIN / LEAVE
  // ════════════════════════════════════════════════════════════════════════
  Future<void> requestToJoinGroup(String groupId) async {
    _isRequestingGroup = true; _groupRequestMessage = ''; _notify();
    final r = await _svc.requestToJoinGroup(groupId: groupId);
    _groupRequestMessage = r['message'] ?? 'Unknown';
    _isRequestingGroup = false; _notify();
  }

  Future<bool> cancelGroupRequest(String groupId) async {
    _isCancellingRequest = true; _notify();
    final r = await _svc.cancelGroupRequest(groupId: groupId);
    _isCancellingRequest = false;
    if (!r['error']) {
      for (final g in [..._groups, ..._myGroups]) {
        if (g['_id'] == groupId) g['isRequested'] = false;
      }
    }
    _notify();
    return !r['error'];
  }

  Future<void> fetchGroupMembers(String groupId) async {
    final groupResult = await _svc.getAllGroups(searchQuery: groupId);
    if (!groupResult['error']) {
      final freshGroups =
      List<Map<String, dynamic>>.from(groupResult['data'] ?? []);
      for (final fg in freshGroups) {
        final idx = _groups.indexWhere((g) => g['_id'] == fg['_id']);
        if (idx != -1) _groups[idx] = fg;
        final myIdx = _myGroups.indexWhere((g) => g['_id'] == fg['_id']);
        if (myIdx != -1) _myGroups[myIdx] = fg;
      }
      _notify();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PENDING REQUESTS (admin)
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchPendingRequests() async {
    _isLoadingRequests = true; _requestsError = null; _pendingRequests = []; _notify();
    try {
      final adminGroups = _groups.where((g) => g['isAdmin'] == true).toList();
      if (adminGroups.isEmpty) { _isLoadingRequests = false; _notify(); return; }

      final results = await Future.wait(adminGroups.map((g) async {
        final r = await _svc.getGroupRequests(g['_id']);
        if (!r['error']) {
          final reqs = List<Map<String, dynamic>>.from(r['data'] ?? []);
          for (final req in reqs) {
            req['groupName'] = g['name']; req['groupId'] = g['_id'];
          }
          return reqs;
        }
        return <Map<String, dynamic>>[];
      }));

      for (final list in results) _pendingRequests.addAll(list);
    } catch (e) {
      _requestsError = e.toString();
    }
    _isLoadingRequests = false; _notify();
  }

  Future<bool> updateGroupRequest({
    required String requestId, required String status,
  }) async {
    _isUpdatingRequest = true; _updateRequestMessage = ''; _notify();
    final r = await _svc.updateGroupRequest(requestId: requestId, status: status);
    _updateRequestMessage = r['message'] ?? 'Unknown';
    _isUpdatingRequest = false;
    if (!r['error']) _pendingRequests.removeWhere((req) => req['_id'] == requestId);
    _notify();
    return !r['error'];
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MEMBERS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> addMembersToGroup({
    required String groupId, required List<String> memberIds,
  }) async {
    _isAddingMembers = true; _addMemberMessage = ''; _notify();
    final r = await _svc.addMembersToGroup(groupId: groupId, memberIds: memberIds);
    _addMemberMessage = r['message'] ?? 'Unknown';
    _isAddingMembers = false; _notify();
  }

  Future<bool> removeMemberFromGroup({
    required String groupId, required String userId,
  }) async {
    _isRemovingMember = true; _removeMessage = ''; _notify();
    final r = await _svc.removeMemberFromGroup(groupId: groupId, userId: userId);
    _removeMessage = r['message'] ?? 'Unknown';
    _isRemovingMember = false; _notify();
    return !r['error'];
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FETCH ALL USERS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchAllUsers({int page = 1, String? search}) async {
    _isFetchingUsers = true; _notify();
    final r = await _svc.fetchAllUsers(page: page, search: search);
    _isFetchingUsers = false;
    if (!r['error']) {
      _allUsers            = r['data']?['allUsers'] ?? [];
      _allUsersTotalPages  = r['totalPage']   ?? 1;
      _allUsersCurrentPage = r['currentPage'] ?? 1;
    }
    _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LOCAL STATE HELPERS
  // ════════════════════════════════════════════════════════════════════════
  void _updateMessageTextLocally(String groupId, String messageId, String newText) {
    final msgs = _groupMessages[groupId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m['_id'] == messageId);
    if (idx != -1) {
      msgs[idx] = Map<String, dynamic>.from(msgs[idx])
        ..['text'] = newText ..['isEdited'] = true;
    }
  }

  void _markMessageDeletedLocally(String groupId, String messageId) {
    final msgs = _groupMessages[groupId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m['_id'] == messageId);
    if (idx != -1) {
      msgs[idx] = Map<String, dynamic>.from(msgs[idx])..['isDelete'] = true;
    }
  }

  void markMessageAsRead(String messageId, String userId) {
    if (_currentGroupId == null) return;
    final msgs = _groupMessages[_currentGroupId!];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m['_id'] == messageId);
    if (idx != -1) {
      final readers = List<String>.from(msgs[idx]['readers'] ?? []);
      if (!readers.contains(userId)) {
        readers.add(userId);
        msgs[idx] = Map<String, dynamic>.from(msgs[idx])..['readers'] = readers;
        _notify();
      }
    }
  }

  void updateFileUploadProgress(double progress) {
    _fileUploadProgress = progress; _notify();
  }

  void onGroupMessageEdited(String groupId, String messageId, String newText) {
    _updateMessageTextLocally(groupId, messageId, newText); _notify();
  }
  void onGroupMessageDeleted(String groupId, String messageId) {
    _markMessageDeletedLocally(groupId, messageId); _notify();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GROUP LOOKUP HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? getGroupById(String id) {
    try { return _groups.firstWhere((g) => g['_id'] == id); }
    catch (_) { return null; }
  }

  Map<String, dynamic>? getMyGroupById(String id) {
    try { return _myGroups.firstWhere((g) => g['_id'] == id); }
    catch (_) { return null; }
  }

  bool isGroupMember(String id)      => getGroupById(id)?['isMember']   ?? false;
  bool isGroupAdmin(String id)       => getGroupById(id)?['isAdmin']     ?? false;
  bool hasRequestedToJoin(String id) => getGroupById(id)?['isRequested'] ?? false;

  // ════════════════════════════════════════════════════════════════════════
  //  CLEAR ERRORS
  // ════════════════════════════════════════════════════════════════════════
  void _clearAllErrors() {
    _error = null; _createGroupError = null; _messagesError = null;
    _sendMessageError = null; _sendFileError = null; _sendVoiceError = null;
    _myGroupsError = null; _requestsError = null;
    _editMessageError = null; _deleteMessageError = null;
  }

  void clearErrors()             { _clearAllErrors();           _notify(); }
  void clearCreateGroupError()   { _createGroupError   = null;  _notify(); }
  void clearMessagesError()      { _messagesError       = null;  _notify(); }
  void clearSendMessageError()   { _sendMessageError    = null;  _notify(); }
  void clearSendFileError()      { _sendFileError       = null;  _notify(); }
  void clearSendVoiceError()     { _sendVoiceError      = null;  _notify(); }
  void clearMyGroupsError()      { _myGroupsError       = null;  _notify(); }
  void clearEditMessageError()   { _editMessageError    = null;  _notify(); }
  void clearDeleteMessageError() { _deleteMessageError  = null;  _notify(); }
}