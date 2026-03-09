import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/group_chat_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GroupChatProvider — wires every GroupChatService method to the UI
// ═══════════════════════════════════════════════════════════════════════════
class GroupChatProvider with ChangeNotifier {
  final GroupChatService _svc = GroupChatService();

  // ── Loading flags ───────────────────────────────────────────────────────
  bool _isLoading          = false;
  bool _isSearching        = false;
  bool _isCreatingGroup    = false;
  bool _isRequestingGroup  = false;
  bool _isCancellingRequest = false;
  bool _isUpdatingRequest  = false;
  bool _isLoadingMessages  = false;
  bool _isSendingMessage   = false;
  bool _isSendingFile      = false;
  bool _isSendingVoice     = false;
  bool _isSendingCamera    = false;
  bool _isAddingMembers    = false;
  bool _isRemovingMember   = false;
  bool _isFetchingUsers    = false;
  bool _isLoadingMyGroups  = false;
  bool _isLoadingRequests  = false;

  // ── Error messages ──────────────────────────────────────────────────────
  String? _error;
  String? _createGroupError;
  String? _messagesError;
  String? _sendMessageError;
  String? _sendFileError;
  String? _sendVoiceError;
  String? _myGroupsError;
  String? _requestsError;

  // ── Result messages (for snackbars) ────────────────────────────────────
  String _groupRequestMessage   = '';
  String _addMemberMessage      = '';
  String _removeMessage         = '';
  String _updateRequestMessage  = '';

  // ── Data ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _groups         = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  List<Map<String, dynamic>> _myGroups       = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<dynamic>              _allUsers       = [];
  Map<String, List<Map<String, dynamic>>> _groupMessages = {};

  String  _currentSearchQuery = '';
  String? _currentGroupId;
  String? _currentCommunityId;
  double  _fileUploadProgress  = 0.0;
  int     _allUsersTotalPages  = 1;
  int     _allUsersCurrentPage = 1;

  // ── Getters ────────────────────────────────────────────────────────────
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
  bool get isFetchingUsers     => _isFetchingUsers;
  bool get isLoadingMyGroups   => _isLoadingMyGroups;
  bool get isLoadingRequests   => _isLoadingRequests;

  String? get error            => _error;
  String? get createGroupError => _createGroupError;
  String? get messagesError    => _messagesError;
  String? get sendMessageError => _sendMessageError;
  String? get sendFileError    => _sendFileError;
  String? get sendVoiceError   => _sendVoiceError;
  String? get myGroupsError    => _myGroupsError;
  String? get requestsError    => _requestsError;

  String get groupRequestMessage  => _groupRequestMessage;
  String get addMemberMessage     => _addMemberMessage;
  String get removeMessage        => _removeMessage;
  String get updateRequestMessage => _updateRequestMessage;

  List<Map<String, dynamic>> get groups =>
      _filteredGroups.isNotEmpty || _currentSearchQuery.isNotEmpty
          ? _filteredGroups
          : _groups;
  List<Map<String, dynamic>> get myGroups         => _myGroups;
  List<Map<String, dynamic>> get pendingRequests  => _pendingRequests;
  List<dynamic>              get allUsers         => _allUsers;

  String  get currentSearchQuery  => _currentSearchQuery;
  String? get currentGroupId      => _currentGroupId;
  double  get fileUploadProgress  => _fileUploadProgress;
  int     get allUsersTotalPages  => _allUsersTotalPages;
  int     get allUsersCurrentPage => _allUsersCurrentPage;
  bool    get hasMyGroups         => _myGroups.isNotEmpty;
  int     get myGroupsCount       => _myGroups.length;

  List<Map<String, dynamic>> get currentGroupMessages =>
      _currentGroupId != null ? _groupMessages[_currentGroupId] ?? [] : [];

  List<Map<String, dynamic>> getMessagesForGroup(String id) =>
      _groupMessages[id] ?? [];

  // ══════════════════════════════════════════════════════════════════════
  // INIT / RESET
  // ══════════════════════════════════════════════════════════════════════
  void initialize() {
    _clearAllErrors();
    _groups.clear();
    _filteredGroups.clear();
    _currentSearchQuery = '';
    _groupMessages.clear();
    _currentGroupId = null;
    _fileUploadProgress = 0.0;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // ALL GROUPS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> fetchGroups({int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroups page=$pageNo');
    _isLoading = true; _error = null; notifyListeners();

    final r = await _svc.getAllGroups(pageNo: pageNo);
    if (!r['error']) {
      _groups = List<Map<String, dynamic>>.from(r['data'] ?? []);
      if (_currentSearchQuery.isNotEmpty) _filterLocally(_currentSearchQuery);
      else _filteredGroups.clear();
    } else {
      _error = r['message'];
    }
    _isLoading = false; notifyListeners();
  }

  Future<void> searchGroups(String query) async {
    _currentSearchQuery = query;
    if (query.isEmpty) { _filteredGroups.clear(); notifyListeners(); return; }

    print('🔍 [Provider] searchGroups: "$query"');
    _isSearching = true; _error = null; notifyListeners();

    final r = await _svc.getAllGroups(searchQuery: query);
    _filteredGroups = r['error'] ? [] : List<Map<String, dynamic>>.from(r['data'] ?? []);
    if (r['error']) _error = r['message'];
    _isSearching = false; notifyListeners();
  }

  void _filterLocally(String q) {
    if (q.isEmpty) { _filteredGroups.clear(); return; }
    final lq = q.toLowerCase();
    _filteredGroups = _groups.where((g) {
      return (g['name']?.toString().toLowerCase().contains(lq) ?? false) ||
          (g['description']?.toString().toLowerCase().contains(lq) ?? false);
    }).toList();
  }

  void clearSearch() {
    _currentSearchQuery = '';
    _filteredGroups.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // MY GROUPS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> fetchMyGroups({String? communityId}) async {
    print('🔄 [Provider] fetchMyGroups communityId=$communityId');
    _isLoadingMyGroups = true; _myGroupsError = null;
    _currentCommunityId = communityId; notifyListeners();

    final r = await _svc.getMyGroups(communityId: communityId);
    _myGroups = r['error'] ? [] : List<Map<String, dynamic>>.from(r['data'] ?? []);
    if (r['error']) _myGroupsError = r['message'];
    _isLoadingMyGroups = false; notifyListeners();
  }

  Future<void> refreshMyGroups() async =>
      fetchMyGroups(communityId: _currentCommunityId);

  void clearMyGroups() {
    _myGroups.clear(); _myGroupsError = null; _currentCommunityId = null;
    notifyListeners();
  }

  bool isMyGroup(String groupId) => _myGroups.any((g) => g['_id'] == groupId);

  List<Map<String, dynamic>> filterMyGroups(String q) {
    if (q.isEmpty) return _myGroups;
    final lq = q.toLowerCase();
    return _myGroups.where((g) =>
    (g['name']?.toString().toLowerCase().contains(lq) ?? false) ||
        (g['description']?.toString().toLowerCase().contains(lq) ?? false)).toList();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CREATE GROUP
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> createGroup({
    required String name,
    required String description,
    String? profileImage,
    List<String> members = const [],
  }) async {
    print('🔄 [Provider] createGroup "$name"');
    _isCreatingGroup = true; _createGroupError = null; notifyListeners();

    final r = await _svc.createGroup(
        name: name, description: description,
        profileImage: profileImage, members: members);

    if (!r['error']) {
      if (r['data'] != null) _groups.insert(0, r['data'] as Map<String, dynamic>);
      await fetchGroups();
      _isCreatingGroup = false; notifyListeners();
      return true;
    }
    _createGroupError = r['message'];
    _isCreatingGroup = false; notifyListeners();
    return false;
  }




  // ══════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════
  Future<void> fetchGroupMessages(String groupId, {int pageNo = 1}) async {
    print('🔄 [Provider] fetchGroupMessages $groupId page=$pageNo');
    _isLoadingMessages = true; _messagesError = null;
    _currentGroupId = groupId; notifyListeners();

    final r = await _svc.getGroupMessages(groupId, pageNo: pageNo);
    _groupMessages[groupId] = r['error']
        ? []
        : List<Map<String, dynamic>>.from(r['data'] ?? []);
    if (r['error']) _messagesError = r['message'];
    _isLoadingMessages = false; notifyListeners();
  }

  Future<void> refreshCurrentGroupMessages() async {
    if (_currentGroupId != null) await fetchGroupMessages(_currentGroupId!);
  }

  void setCurrentGroup(String groupId) {
    _currentGroupId = groupId; _messagesError = null; notifyListeners();
  }

  void clearCurrentGroup() {
    _currentGroupId = null; _messagesError = null; notifyListeners();
  }

  void addMessageToCurrentGroup(Map<String, dynamic> message) {
    if (_currentGroupId == null) return;
    _groupMessages[_currentGroupId!] ??= [];
    _groupMessages[_currentGroupId!]!.add(message);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // SEND TEXT MESSAGE
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
    String? image,
  }) async {
    print('🔄 [Provider] sendGroupMessage to $groupId');
    _isSendingMessage = true; _sendMessageError = null; notifyListeners();

    final r = await _svc.sendGroupMessage(
        groupId: groupId, text: text, communityInfo: communityInfo, image: image);

    if (!r['error']) {
      if (_currentGroupId == groupId && r['data'] != null) {
        _groupMessages[groupId] ??= [];
        _groupMessages[groupId]!.add(r['data'] as Map<String, dynamic>);
      }
      _isSendingMessage = false; notifyListeners();
      return true;
    }
    _sendMessageError = r['message'];
    _isSendingMessage = false; notifyListeners();
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // SEND FILE
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
  }) async {
    print('🔄 [Provider] sendGroupFileMessage to $groupId');
    _isSendingFile = true; _sendFileError = null; _fileUploadProgress = 0.0;
    notifyListeners();

    final r = await _svc.sendGroupFileMessage(
        groupId: groupId, file: file, communityInfo: communityInfo);

    if (!r['error']) {
      if (_currentGroupId == groupId && r['data'] != null) {
        _groupMessages[groupId] ??= [];
        _groupMessages[groupId]!.add(r['data'] as Map<String, dynamic>);
      }
      _isSendingFile = false; _fileUploadProgress = 1.0; notifyListeners();
      return true;
    }
    _sendFileError = r['message'];
    _isSendingFile = false; _fileUploadProgress = 0.0; notifyListeners();
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // SEND VOICE MESSAGE  ← NEW
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupVoiceMessage({
    required String groupId,
    required File audioFile,
    Map<String, dynamic>? communityInfo,
  }) async {
    print('🔄 [Provider] sendGroupVoiceMessage to $groupId');
    _isSendingVoice = true; _sendVoiceError = null; notifyListeners();

    final r = await _svc.sendGroupVoiceMessage(
        groupId: groupId, audioFile: audioFile, communityInfo: communityInfo);

    if (!r['error']) {
      if (_currentGroupId == groupId && r['data'] != null) {
        _groupMessages[groupId] ??= [];
        _groupMessages[groupId]!.add(r['data'] as Map<String, dynamic>);
        print('🎤 [Provider] Voice message added to local messages');
      }
      _isSendingVoice = false; notifyListeners();
      return true;
    }
    _sendVoiceError = r['message'];
    _isSendingVoice = false; notifyListeners();
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // SEND CAMERA PHOTO  ← NEW
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> sendGroupCameraPhoto({
    required String groupId,
    Map<String, dynamic>? communityInfo,
  }) async {
    print('🔄 [Provider] sendGroupCameraPhoto to $groupId');
    _isSendingCamera = true; _sendFileError = null; notifyListeners();

    final r = await _svc.sendGroupCameraPhoto(
        groupId: groupId, communityInfo: communityInfo);

    // User cancelled — not an error, just stop loading
    if (r['cancelled'] == true) {
      _isSendingCamera = false; notifyListeners();
      return false;
    }

    if (!r['error']) {
      if (_currentGroupId == groupId && r['data'] != null) {
        _groupMessages[groupId] ??= [];
        _groupMessages[groupId]!.add(r['data'] as Map<String, dynamic>);
        print('📸 [Provider] Camera photo added to local messages');
      }
      _isSendingCamera = false; notifyListeners();
      return true;
    }
    _sendFileError = r['message'];
    _isSendingCamera = false; notifyListeners();
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // JOIN GROUP REQUEST
  // ══════════════════════════════════════════════════════════════════════
  Future<void> requestToJoinGroup(String groupId) async {
    print('🔄 [Provider] requestToJoinGroup $groupId');
    _isRequestingGroup = true; _groupRequestMessage = ''; notifyListeners();

    final r = await _svc.requestToJoinGroup(groupId: groupId);
    _groupRequestMessage = r['message'] ?? 'Unknown';
    _isRequestingGroup = false; notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CANCEL JOIN REQUEST  ← NEW
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> cancelGroupRequest(String groupId) async {
    print('🔄 [Provider] cancelGroupRequest $groupId');
    _isCancellingRequest = true; notifyListeners();

    final r = await _svc.cancelGroupRequest(groupId: groupId);
    _isCancellingRequest = false; notifyListeners();

    if (!r['error']) {
      // Update local state so button reflects cancellation
      for (final g in [..._groups, ..._myGroups]) {
        if (g['_id'] == groupId) g['isRequested'] = false;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // PENDING REQUESTS (admin)
  // ══════════════════════════════════════════════════════════════════════
  Future<void> fetchPendingRequests() async {
    print('🔄 [Provider] fetchPendingRequests');
    _isLoadingRequests = true; _requestsError = null; _pendingRequests = [];
    notifyListeners();

    try {
      final adminGroups = _groups.where((g) => g['isAdmin'] == true).toList();
      print('📋 [Provider] Admin groups: ${adminGroups.length}');

      if (adminGroups.isEmpty) {
        _isLoadingRequests = false; notifyListeners(); return;
      }

      final results = await Future.wait(
        adminGroups.map((g) async {
          final r = await _svc.getGroupRequests(g['_id']);
          if (!r['error']) {
            final reqs = List<Map<String, dynamic>>.from(r['data'] ?? []);
            for (final req in reqs) {
              req['groupName'] = g['name'];
              req['groupId']   = g['_id'];
            }
            return reqs;
          }
          return <Map<String, dynamic>>[];
        }),
      );

      for (final list in results) { _pendingRequests.addAll(list); }
      print('📊 [Provider] Total pending: ${_pendingRequests.length}');
    } catch (e) {
      _requestsError = e.toString();
      print('💥 [Provider] fetchPendingRequests error: $e');
    }
    _isLoadingRequests = false; notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // APPROVE / REJECT REQUEST  ← NEW
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> updateGroupRequest({
    required String requestId,
    required String status, // "approved" or "rejected"
  }) async {
    print('🔄 [Provider] updateGroupRequest $requestId → $status');
    _isUpdatingRequest = true; _updateRequestMessage = ''; notifyListeners();

    final r = await _svc.updateGroupRequest(requestId: requestId, status: status);
    _updateRequestMessage = r['message'] ?? 'Unknown';
    _isUpdatingRequest = false;

    if (!r['error']) {
      // Remove from local pending list
      _pendingRequests.removeWhere((req) => req['_id'] == requestId);
    }
    notifyListeners();
    return !r['error'];
  }

  // ══════════════════════════════════════════════════════════════════════
  // ADD MEMBERS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
  }) async {
    print('🔄 [Provider] addMembersToGroup $groupId — ${memberIds.length} members');
    _isAddingMembers = true; _addMemberMessage = ''; notifyListeners();

    final r = await _svc.addMembersToGroup(groupId: groupId, memberIds: memberIds);
    _addMemberMessage = r['message'] ?? 'Unknown';
    _isAddingMembers = false; notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // REMOVE MEMBER  ← NEW
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    print('🔄 [Provider] removeMemberFromGroup $userId from $groupId');
    _isRemovingMember = true; _removeMessage = ''; notifyListeners();

    final r = await _svc.removeMemberFromGroup(groupId: groupId, userId: userId);
    _removeMessage = r['message'] ?? 'Unknown';
    _isRemovingMember = false; notifyListeners();
    return !r['error'];
  }

  // ══════════════════════════════════════════════════════════════════════
  // FETCH ALL USERS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> fetchAllUsers({int page = 1, String? search}) async {
    print('🔄 [Provider] fetchAllUsers page=$page search=$search');
    _isFetchingUsers = true; notifyListeners();

    final r = await _svc.fetchAllUsers(page: page, search: search);
    _isFetchingUsers = false;
    if (!r['error']) {
      _allUsers = r['data']?['allUsers'] ?? [];
      _allUsersTotalPages  = r['totalPage']  ?? 1;
      _allUsersCurrentPage = r['currentPage'] ?? 1;
    }
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS — group lookups
  // ══════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? getGroupById(String id) {
    try { return _groups.firstWhere((g) => g['_id'] == id); }
    catch (_) { return null; }
  }

  Map<String, dynamic>? getMyGroupById(String id) {
    try { return _myGroups.firstWhere((g) => g['_id'] == id); }
    catch (_) { return null; }
  }

  bool isGroupMember(String id)  => getGroupById(id)?['isMember']    ?? false;
  bool isGroupAdmin(String id)   => getGroupById(id)?['isAdmin']      ?? false;
  bool hasRequestedToJoin(String id) => getGroupById(id)?['isRequested'] ?? false;

  void markMessageAsRead(String messageId, String userId) {
    if (_currentGroupId == null) return;
    final msgs = _groupMessages[_currentGroupId!];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m['_id'] == messageId);
    if (idx != -1) {
      final readers = List<String>.from(msgs[idx]['readers'] ?? []);
      if (!readers.contains(userId)) {
        readers.add(userId);
        msgs[idx]['readers'] = readers;
        notifyListeners();
      }
    }
  }

  void updateFileUploadProgress(double p) {
    _fileUploadProgress = p; notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CLEAR ERRORS
  // ══════════════════════════════════════════════════════════════════════
  void _clearAllErrors() {
    _error = null; _createGroupError = null; _messagesError = null;
    _sendMessageError = null; _sendFileError = null; _sendVoiceError = null;
    _myGroupsError = null; _requestsError = null;
  }

  void clearErrors()           { _clearAllErrors(); notifyListeners(); }
  void clearCreateGroupError() { _createGroupError = null; notifyListeners(); }
  void clearMessagesError()    { _messagesError    = null; notifyListeners(); }
  void clearSendMessageError() { _sendMessageError = null; notifyListeners(); }
  void clearSendFileError()    { _sendFileError    = null; notifyListeners(); }
  void clearSendVoiceError()   { _sendVoiceError   = null; notifyListeners(); }
  void clearMyGroupsError()    { _myGroupsError    = null; notifyListeners(); }
}