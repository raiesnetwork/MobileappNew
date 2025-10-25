import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/group_chat_service.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class GroupChatProvider with ChangeNotifier {
  final GroupChatService _groupChatService = GroupChatService();

  // Loading states
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isCreatingGroup = false;
  bool _isJoiningGroup = false;
  bool _isLeavingGroup = false;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isSendingFile = false;

  // Error states
  String? _error;
  String? _createGroupError;
  String? _joinGroupError;
  String? _leaveGroupError;
  String? _messagesError;
  String? _sendMessageError;
  String? _sendFileError;

  // Data
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  String _currentSearchQuery = '';

  // Messages data
  Map<String, List<Map<String, dynamic>>> _groupMessages = {};
  String? _currentGroupId;

  // File upload progress
  double _fileUploadProgress = 0.0;

  // Getters
  bool get isLoading => _isLoading;

  bool get isSearching => _isSearching;

  bool get isCreatingGroup => _isCreatingGroup;

  bool get isJoiningGroup => _isJoiningGroup;

  bool get isLeavingGroup => _isLeavingGroup;

  bool get isLoadingMessages => _isLoadingMessages;

  bool get isSendingMessage => _isSendingMessage;

  bool get isSendingFile => _isSendingFile;

  String? get error => _error;

  String? get createGroupError => _createGroupError;

  String? get joinGroupError => _joinGroupError;

  String? get leaveGroupError => _leaveGroupError;

  String? get messagesError => _messagesError;

  String? get sendMessageError => _sendMessageError;

  String? get sendFileError => _sendFileError;

  List<Map<String, dynamic>> get groups =>
      _filteredGroups.isNotEmpty || _currentSearchQuery.isNotEmpty
          ? _filteredGroups
          : _groups;

  String get currentSearchQuery => _currentSearchQuery;

  String? get currentGroupId => _currentGroupId;

  double get fileUploadProgress => _fileUploadProgress;

  // Get messages for current group
  List<Map<String, dynamic>> get currentGroupMessages =>
      _currentGroupId != null ? _groupMessages[_currentGroupId] ?? [] : [];

  // Get messages for specific group
  List<Map<String, dynamic>> getMessagesForGroup(String groupId) =>
      _groupMessages[groupId] ?? [];

  // Methods

  /// Initialize the provider
  void initialize() {
    _clearErrors();
    _groups.clear();
    _filteredGroups.clear();
    _currentSearchQuery = '';
    _groupMessages.clear();
    _currentGroupId = null;
    _fileUploadProgress = 0.0;
    notifyListeners();
  }

  /// Fetch all groups
  Future<void> fetchGroups() async {
    _setLoading(true);
    _clearErrors();

    try {
      final result = await _groupChatService.getAllGroups();

      if (!result['error']) {
        _groups = List<Map<String, dynamic>>.from(result['data'] ?? []);

        // If there's an active search, filter the results
        if (_currentSearchQuery.isNotEmpty) {
          _filterGroupsLocally(_currentSearchQuery);
        } else {
          _filteredGroups.clear();
        }

        print('✅ Successfully fetched ${_groups.length} groups');
      } else {
        _error = result['message'];
        print('❌ Error fetching groups: $_error');
      }
    } catch (e) {
      _error = 'Failed to fetch groups: ${e.toString()}';
      print('💥 Exception in fetchGroups: $e');
    }

    _setLoading(false);
  }

  Future<void> searchGroups(String query) async {
    _currentSearchQuery = query;

    if (query.isEmpty) {
      // Clear search results and show all groups
      _filteredGroups.clear();
      notifyListeners();
      return;
    }

    _isSearching = true;
    _clearErrors();
    notifyListeners();

    try {
      final result = await _groupChatService.getAllGroups(searchQuery: query);

      if (!result['error']) {
        _filteredGroups = List<Map<String, dynamic>>.from(result['data'] ?? []);
        print(
            '✅ Successfully searched groups with query "$query": ${_filteredGroups.length} results');
      } else {
        _error = result['message'];
        _filteredGroups.clear();
        print('❌ Error searching groups: $_error');
      }
    } catch (e) {
      _error = 'Failed to search groups: ${e.toString()}';
      _filteredGroups.clear();
      print('💥 Exception in searchGroups: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Filter groups locally (for immediate UI feedback)
  void _filterGroupsLocally(String query) {
    if (query.isEmpty) {
      _filteredGroups.clear();
      return;
    }

    _filteredGroups = _groups.where((group) {
      final name = group['name']?.toString().toLowerCase() ?? '';
      final description = group['description']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) || description.contains(searchQuery);
    }).toList();
  }

  /// Clear search and show all groups
  void clearSearch() {
    _currentSearchQuery = '';
    _filteredGroups.clear();
    notifyListeners();
  }

  // Add this method to your GroupChatProvider class
  void clearCreateGroupError() {
    _createGroupError = null;
    notifyListeners();
  }

// Updated createGroup method
  Future<bool> createGroup({
    required String name,
    required String description,
    String? profileImage,
  }) async {
    _isCreatingGroup = true;
    _createGroupError = null;
    notifyListeners();

    try {
      print('🚀 Creating group: $name');

      final result = await _groupChatService.createGroup(
        name: name,
        description: description,
        profileImage: profileImage,
      );

      print('📋 Create group result: $result');

      if (!result['error']) {
        print('✅ Successfully created group: $name');

        // Add the new group to the local list if data is returned
        if (result['data'] != null) {
          final newGroup = result['data'] as Map<String, dynamic>;
          _groups.insert(0, newGroup); // Add to beginning of list
          print('📝 Added new group to local list');
        }

        // Refresh the groups list to get the latest data
        await fetchGroups();

        _isCreatingGroup = false;
        notifyListeners();
        return true;
      } else {
        _createGroupError = result['message'] ?? 'Failed to create group';
        print('❌ Error creating group: $_createGroupError');

        _isCreatingGroup = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _createGroupError = 'Failed to create group: ${e.toString()}';
      print('💥 Exception in createGroup: $e');

      _isCreatingGroup = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch messages for a specific group
  Future<void> fetchGroupMessages(String groupId) async {
    _isLoadingMessages = true;
    _messagesError = null;
    _currentGroupId = groupId;
    notifyListeners();

    try {
      print('🔍 Fetching messages for group: $groupId');

      final result = await _groupChatService.getGroupMessages(groupId);

      if (!result['error']) {
        final messages = List<Map<String, dynamic>>.from(result['data'] ?? []);
        _groupMessages[groupId] = messages;

        print(
            '✅ Successfully fetched ${messages.length} messages for group $groupId');
      } else {
        _messagesError = result['message'];
        _groupMessages[groupId] = [];
        print('❌ Error fetching messages: $_messagesError');
      }
    } catch (e) {
      _messagesError = 'Failed to fetch messages: ${e.toString()}';
      _groupMessages[groupId] = [];
      print('💥 Exception in fetchGroupMessages: $e');
    }

    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Refresh messages for current group
  Future<void> refreshCurrentGroupMessages() async {
    if (_currentGroupId != null) {
      await fetchGroupMessages(_currentGroupId!);
    }
  }

  /// Set current group (for navigation)
  void setCurrentGroup(String groupId) {
    _currentGroupId = groupId;
    _messagesError = null;
    notifyListeners();
  }

  /// Clear current group
  void clearCurrentGroup() {
    _currentGroupId = null;
    _messagesError = null;
    notifyListeners();
  }

  /// Add a new message to the current group (for real-time updates)
  void addMessageToCurrentGroup(Map<String, dynamic> message) {
    if (_currentGroupId != null) {
      if (_groupMessages[_currentGroupId] == null) {
        _groupMessages[_currentGroupId!] = [];
      }
      _groupMessages[_currentGroupId!]!.add(message);
      notifyListeners();
    }
  }

  /// Update message read status
  void markMessageAsRead(String messageId, String userId) {
    if (_currentGroupId != null && _groupMessages[_currentGroupId] != null) {
      final messages = _groupMessages[_currentGroupId!]!;
      final messageIndex =
          messages.indexWhere((msg) => msg['_id'] == messageId);

      if (messageIndex != -1) {
        final message = messages[messageIndex];
        final readers = List<String>.from(message['readers'] ?? []);

        if (!readers.contains(userId)) {
          readers.add(userId);
          message['readers'] = readers;
          notifyListeners();
        }
      }
    }
  }

  Map<String, dynamic>? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((group) => group['_id'] == groupId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is member of a group
  bool isGroupMember(String groupId) {
    final group = getGroupById(groupId);
    return group?['isMember'] ?? false;
  }

  /// Check if user is admin of a group
  bool isGroupAdmin(String groupId) {
    final group = getGroupById(groupId);
    return group?['isAdmin'] ?? false;
  }

  /// Check if user has requested to join a group
  bool hasRequestedToJoin(String groupId) {
    final group = getGroupById(groupId);
    return group?['isRequested'] ?? false;
  }

  /// Clear messages error
  void clearMessagesError() {
    _messagesError = null;
    notifyListeners();
  }

  /// Send a message to a group
  Future<bool> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
    String? image,
  }) async {
    _isSendingMessage = true;
    _sendMessageError = null;
    notifyListeners();

    try {
      print('📤 Sending message to group: $groupId');

      final result = await _groupChatService.sendGroupMessage(
        groupId: groupId,
        text: text,
        communityInfo: communityInfo,
        image: image,
      );

      print('📋 Send message result: $result');

      if (!result['error']) {
        print('✅ Message sent successfully');

        // Add the new message to the local messages list if we have the group loaded
        if (_currentGroupId == groupId && result['data'] != null) {
          final newMessage = result['data'] as Map<String, dynamic>;
          if (_groupMessages[groupId] == null) {
            _groupMessages[groupId] = [];
          }
          _groupMessages[groupId]!.add(newMessage);
        }

        _isSendingMessage = false;
        notifyListeners();
        return true;
      } else {
        _sendMessageError = result['message'] ?? 'Failed to send message';
        print('❌ Error sending message: $_sendMessageError');

        _isSendingMessage = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _sendMessageError = 'Failed to send message: ${e.toString()}';
      print('💥 Exception in sendGroupMessage: $e');

      _isSendingMessage = false;
      notifyListeners();
      return false;
    }
  }

  /// Send a file message to a group
  Future<bool> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
  }) async {
    _isSendingFile = true;
    _sendFileError = null;
    _fileUploadProgress = 0.0;
    notifyListeners();

    try {
      print('📤 Sending file to group: $groupId');

      final result = await _groupChatService.sendGroupFileMessage(
        groupId: groupId,
        file: file,
        communityInfo: communityInfo,
      );

      print('📋 Send file result: $result');

      if (!result['error']) {
        print('✅ File sent successfully');

        // Add the new file message to the local messages list if we have the group loaded
        if (_currentGroupId == groupId && result['data'] != null) {
          final newMessage = result['data'] as Map<String, dynamic>;
          if (_groupMessages[groupId] == null) {
            _groupMessages[groupId] = [];
          }
          _groupMessages[groupId]!.add(newMessage);
        }

        _isSendingFile = false;
        _fileUploadProgress = 1.0;
        notifyListeners();
        return true;
      } else {
        _sendFileError = result['message'] ?? 'Failed to send file';
        print('❌ Error sending file: $_sendFileError');

        _isSendingFile = false;
        _fileUploadProgress = 0.0;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _sendFileError = 'Failed to send file: ${e.toString()}';
      print('💥 Exception in sendGroupFileMessage: $e');

      _isSendingFile = false;
      _fileUploadProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  /// Update file upload progress
  void updateFileUploadProgress(double progress) {
    _fileUploadProgress = progress;
    notifyListeners();
  }

  /// Clear send message error
  void clearSendMessageError() {
    _sendMessageError = null;
    notifyListeners();
  }

  /// Clear send file error
  void clearSendFileError() {
    _sendFileError = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearErrors() {
    _error = null;
    _createGroupError = null;
    _joinGroupError = null;
    _leaveGroupError = null;
    _messagesError = null;
    _sendMessageError = null;
    _sendFileError = null;
  }

  /// Clear all errors manually
  void clearErrors() {
    _clearErrors();
    notifyListeners();
  }

  bool _isLoadingRequests = false;
  String? _requestsError;
  List<Map<String, dynamic>> _pendingRequests = [];


  bool get isLoadingRequests => _isLoadingRequests;

  String? get requestsError => _requestsError;

  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;

  Future<void> fetchPendingRequests() async {
    _isLoadingRequests = true;
    _requestsError = null;
    _pendingRequests = [];
    notifyListeners();

    try {
      final adminGroups = _groups.where((g) => g['isAdmin'] == true).toList();

      if (adminGroups.isEmpty) {
        print('📝 No admin groups found');
        _isLoadingRequests = false;
        notifyListeners();
        return;
      }

      print('🔍 Fetching requests for ${adminGroups.length} admin groups');

      // Use Future.wait to make parallel requests instead of sequential
      final results = await Future.wait(
        adminGroups.map((group) async {
          try {
            final result =
                await _groupChatService.getGroupRequests(group['_id']);

            if (!result['error']) {
              final requests =
                  List<Map<String, dynamic>>.from(result['data'] ?? []);

              // Only process if there are actual requests
              if (requests.isNotEmpty) {
                print(
                    '✅ Found ${requests.length} requests for group: ${group['name']}');

                // Add group info to each request
                for (var req in requests) {
                  req['groupName'] = group['name'];
                  req['groupId'] = group['_id'];
                  req['groupDescription'] = group['description'];
                }

                return requests;
              }
            } else {
              print(
                  '❌ Error fetching requests for group ${group['_id']}: ${result['message']}');
            }
          } catch (e) {
            print('💥 Exception for group ${group['_id']}: $e');
          }

          return <Map<String, dynamic>>[];
        }),
      );

      // Flatten all results and add to pending requests
      for (var groupRequests in results) {
        _pendingRequests.addAll(groupRequests);
      }

      print('📊 Total pending requests found: ${_pendingRequests.length}');
    } catch (e) {
      _requestsError = 'Failed to fetch requests: $e';
      print('💥 Exception in fetchPendingRequests: $e');
    }

    _isLoadingRequests = false;
    notifyListeners();
  }

  // Add these fields to your GroupChatProvider class
  bool _isLoadingMyGroups = false;
  String? _myGroupsError;
  List<Map<String, dynamic>> _myGroups = [];
  String? _currentCommunityId;

// Add these getters
  bool get isLoadingMyGroups => _isLoadingMyGroups;

  String? get myGroupsError => _myGroupsError;

  List<Map<String, dynamic>> get myGroups => _myGroups;

  String? get currentCommunityId => _currentCommunityId;

  Future<void> fetchMyGroups({String? communityId}) async {
    _isLoadingMyGroups = true;
    _myGroupsError = null;
    _currentCommunityId = communityId;
    notifyListeners();

    try {
      print(
          '🔍 Fetching my groups${communityId != null ? ' for community: $communityId' : ''}');

      final result =
          await _groupChatService.getMyGroups(communityId: communityId);

      if (!result['error']) {
        _myGroups = List<Map<String, dynamic>>.from(result['data'] ?? []);
        print('✅ Successfully fetched ${_myGroups.length} user groups');
      } else {
        _myGroupsError = result['message'];
        _myGroups = [];
        print('❌ Error fetching my groups: $_myGroupsError');
      }
    } catch (e) {
      _myGroupsError = 'Failed to fetch my groups: ${e.toString()}';
      _myGroups = [];
      print('💥 Exception in fetchMyGroups: $e');
    }

    _isLoadingMyGroups = false;
    notifyListeners();
  }

  /// Refresh user's groups
  Future<void> refreshMyGroups() async {
    await fetchMyGroups(communityId: _currentCommunityId);
  }

  /// Fetch user's groups for a specific community
  Future<void> fetchMyGroupsForCommunity(String communityId) async {
    await fetchMyGroups(communityId: communityId);
  }

  /// Clear user's groups
  void clearMyGroups() {
    _myGroups.clear();
    _myGroupsError = null;
    _currentCommunityId = null;
    notifyListeners();
  }

  /// Clear my groups error
  void clearMyGroupsError() {
    _myGroupsError = null;
    notifyListeners();
  }

  /// Check if a group exists in user's groups
  bool isMyGroup(String groupId) {
    return _myGroups.any((group) => group['_id'] == groupId);
  }

  /// Get a specific group from user's groups
  Map<String, dynamic>? getMyGroupById(String groupId) {
    try {
      return _myGroups.firstWhere((group) => group['_id'] == groupId);
    } catch (e) {
      return null;
    }
  }

  int get myGroupsCount => _myGroups.length;

  bool get hasMyGroups => _myGroups.isNotEmpty;

  List<Map<String, dynamic>> filterMyGroups(String query) {
    if (query.isEmpty) return _myGroups;

    final searchQuery = query.toLowerCase();
    return _myGroups.where((group) {
      final name = group['name']?.toString().toLowerCase() ?? '';
      final description = group['description']?.toString().toLowerCase() ?? '';
      return name.contains(searchQuery) || description.contains(searchQuery);
    }).toList();
  }

  // Fetch users
  bool _isFetchingUsers = false;
  bool get isFetchingUsers => _isFetchingUsers;

  List<dynamic> _allUsers = [];
  List<dynamic> get allUsers => _allUsers;

  Future<void> fetchAllUsers({int page = 1}) async {
    _isFetchingUsers = true;
    notifyListeners();

    final result = await _groupChatService.fetchAllUsers(page: page);

    _isFetchingUsers = false;
    if (!result['error']) {
      _allUsers = result['data']['allUsers'] ?? [];
    }
    notifyListeners();
  }

// Add members
  bool _isAddingMembers = false;
  bool get isAddingMembers => _isAddingMembers;

  String _addMemberMessage = '';
  String get addMemberMessage => _addMemberMessage;

  Future<void> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
  }) async {
    _isAddingMembers = true;
    _addMemberMessage = '';
    notifyListeners();

    final result = await _groupChatService.addMembersToGroup(
      groupId: groupId,
      memberIds: memberIds,
    );

    _isAddingMembers = false;
    _addMemberMessage = result['message'] ?? 'Unknown response';
    notifyListeners();
  }

  bool _isRequestingGroup = false;
  bool get isRequestingGroup => _isRequestingGroup;

  String _groupRequestMessage = '';
  String get groupRequestMessage => _groupRequestMessage;

  Future<void> requestToJoinGroup(String groupId) async {
    _isRequestingGroup = true;
    _groupRequestMessage = '';
    notifyListeners();

    final result = await _groupChatService.requestToJoinGroup(groupId: groupId);

    _isRequestingGroup = false;
    _groupRequestMessage = result['message'] ?? 'Unknown response';
    notifyListeners();
  }

}
