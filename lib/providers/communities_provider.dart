import 'package:flutter/foundation.dart';
import '../services/communities_service.dart';

class CommunityProvider with ChangeNotifier {
  final CommunityService _communityService = CommunityService();

  // Separate storage for different types of communities
  Map<String, dynamic> _allCommunities = {
    'error': true,
    'message': 'Not loaded',
    'data': [],
    'totalPages': 0,
  };

  Map<String, dynamic> _myCommunities = {
    'error': true,
    'message': 'Not loaded',
    'data': []
  };
  bool _isLoadingHierarchyStats = false;
  String? _hierarchyStatsError;
  Map<String, dynamic> _communityHierarchyStats = {};

  // Getters for Community Hierarchy Stats
  bool get isLoadingHierarchyStats => _isLoadingHierarchyStats;
  String? get hierarchyStatsError => _hierarchyStatsError;
  Map<String, dynamic> get communityHierarchyStats => _communityHierarchyStats;

  Map<String, dynamic> _communityCampaigns = {
    'message': 'Not loaded',
    'data': []
  };
  Map<String, dynamic> _communityCoupons = {
    'message': 'Not loaded',
    'coupons': []
  };
  Map<String, dynamic> _communityServices = {
    'message': 'Not loaded',
    'services': []
  };

  // Separate loading states
  bool _isLoadingAll = false;
  bool _isLoadingMy = false;
  bool _isLoadingCampaigns = false;
  bool _isLoadingCoupons = false;
  bool _isLoadingServices = false;
  bool _isLoadingInfo = false;

  // Separate error states
  String? _allCommunitiesError;
  String? _myCommunitiesError;
  String? _campaignsError;
  String? _couponsError;
  String? _servicesError;
  String? _infoError;

  // Getters for all communities (used by communities screen)
  Map<String, dynamic> get allCommunities => _allCommunities;
  Map<String, dynamic> get communities => _allCommunities; // Keep for backward compatibility
  bool get isLoadingAll => _isLoadingAll;
  bool get isLoading => _isLoadingAll; // Keep for backward compatibility
  String? get allCommunitiesError => _allCommunitiesError;
  String? get error => _allCommunitiesError; // Keep for backward compatibility

  // Getters for my communities (used by drawer)
  Map<String, dynamic> get myCommunities => _myCommunities;
  bool get isLoadingMy => _isLoadingMy;
  String? get myCommunitiesError => _myCommunitiesError;

  // For backward compatibility with existing code
  bool get hasError => _myCommunitiesError != null;
  String get message => _myCommunitiesError ?? _myCommunities['message'] ?? '';

  // Other getters
  Map<String, dynamic> get communityCampaigns => _communityCampaigns;
  Map<String, dynamic> get communityCoupons => _communityCoupons;
  Map<String, dynamic> get communityServices => _communityServices;
  bool get isLoadingCampaigns => _isLoadingCampaigns;
  bool get isLoadingCoupons => _isLoadingCoupons;
  bool get isLoadingServices => _isLoadingServices;
  String? get campaignsError => _campaignsError;
  String? get couponsError => _couponsError;
  String? get servicesError => _servicesError;

  get currentPage => null;

  // Community Info
  Map<String, dynamic> _communityInfo = {'message': 'Not loaded'};
  Map<String, dynamic> get communityInfo => _communityInfo;
  bool get isLoadingInfo => _isLoadingInfo;
  String? get infoError => _infoError;

  Map<String, dynamic> communityUsers = {'message': 'Not loaded', 'data': []};

  Future<void> fetchCommunities({int page = 1}) async {
    try {
      _isLoadingAll = true;
      if (page == 1) _allCommunitiesError = null;
      notifyListeners();

      // Get all communities for current page
      final result = await _communityService.getAllCommunities(page: page);
      final allCommunities = result['communities'] as List<dynamic>? ?? [];

      // ALWAYS fetch my communities to get the latest membership data
      final myCommunitiesResult = await _communityService.getMyCommunities();
      final myCommunities = myCommunitiesResult['data'] as List<dynamic>? ?? [];

      print('=== API RESPONSE DEBUG (Page $page) ===');
      print('All communities count: ${allCommunities.length}');
      print('My communities count: ${myCommunities.length}');

      // Create a map of my community IDs for quick lookup
      Map<String, Map<String, dynamic>> myCommunitiesMap = {};
      for (final community in myCommunities) {
        final id = community['_id']?.toString();
        if (id != null) {
          myCommunitiesMap[id] = Map<String, dynamic>.from(community);
        }
      }

      // Process only the current page communities
      final processedCommunities = <Map<String, dynamic>>[];

      for (final community in allCommunities) {
        final communityMap = Map<String, dynamic>.from(community);
        final communityId = communityMap['_id']?.toString();

        if (communityId != null) {
          // Check if this community is in my communities
          final myCommunityData = myCommunitiesMap[communityId];

          if (myCommunityData != null) {
            // This is one of my communities - add proper flags
            communityMap['isMember'] = true;
            communityMap['isAdmin'] = myCommunityData['isAdmin'] ?? false;
            communityMap['isJoined'] = true;
            communityMap['membershipStatus'] = myCommunityData['membershipStatus'] ?? 'joined';
            // Clear any pending request status since user is now a member
            communityMap.remove('requestStatus');
          } else {
            // Not my community - set flags to false
            communityMap['isMember'] = false;
            communityMap['isAdmin'] = false;
            communityMap['isJoined'] = false;
            // Keep existing requestStatus if any (don't override)
          }

          processedCommunities.add(communityMap);
        }
      }

      // For page 1, replace the data completely
      // For subsequent pages, we need to merge intelligently
      if (page == 1) {
        _allCommunities = {
          'error': result['error'] as bool? ?? false,
          'message': result['message'] as String? ?? 'Success',
          'data': processedCommunities,
          'totalPages': result['totalPages'] as int? ?? 1,
        };
      } else {
        // For pagination, append new communities
        final existingData = _allCommunities['data'] as List<dynamic>? ?? [];

        // Update existing communities with fresh membership data
        final updatedExistingData = <Map<String, dynamic>>[];
        for (final existingCommunity in existingData) {
          final existingMap = Map<String, dynamic>.from(existingCommunity);
          final communityId = existingMap['_id']?.toString();

          if (communityId != null) {
            final myCommunityData = myCommunitiesMap[communityId];
            if (myCommunityData != null) {
              existingMap['isMember'] = true;
              existingMap['isAdmin'] = myCommunityData['isAdmin'] ?? false;
              existingMap['isJoined'] = true;
              existingMap['membershipStatus'] = myCommunityData['membershipStatus'] ?? 'joined';
              existingMap.remove('requestStatus');
            }
          }
          updatedExistingData.add(existingMap);
        }

        _allCommunities = {
          'error': result['error'] as bool? ?? false,
          'message': result['message'] as String? ?? 'Success',
          'data': [...updatedExistingData, ...processedCommunities],
          'totalPages': result['totalPages'] as int? ?? 1,
        };
      }

      print('=== FINAL ALL COMMUNITIES DATA (Page $page) ===');
      print('Processed communities for this page: ${processedCommunities.length}');
      print('Total communities in list: ${(_allCommunities['data'] as List).length}');

      _allCommunitiesError = null;
      _isLoadingAll = false;
      notifyListeners();
    } catch (e) {
      print('Error in fetchCommunities: $e');
      _isLoadingAll = false;
      _allCommunitiesError = 'Error fetching communities: $e';
      _allCommunities = {
        'error': true,
        'message': 'Error fetching communities: $e',
        'data': page == 1 ? [] : (_allCommunities['data'] as List<dynamic>? ?? []),
        'totalPages': 0,
      };
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result = await _communityService.joinCommunity(communityId);

      if (!(result['error'] as bool)) {
        // Update local all communities list immediately
        final communityList = _allCommunities['data'] as List<dynamic>? ?? [];
        final index = communityList.indexWhere((c) => c['_id'] == communityId);

        if (index != -1) {
          final community = communityList[index] as Map<String, dynamic>;
          final isPrivate = result['isPrivate'] as bool? ?? community['isPrivate'] ?? false;

          communityList[index] = {
            ...community,
            'isJoined': !isPrivate,
            'isMember': !isPrivate,
            'requestStatus': isPrivate ? (result['requestStatus'] ?? 'pending') : null,
          };

          _allCommunities = {..._allCommunities, 'data': communityList};
        }

        // CRITICAL: Refresh my communities FIRST, then all communities
        await fetchMyCommunities();
        await fetchCommunities(page: 1);

        _allCommunitiesError = null;
      } else {
        _allCommunitiesError = result['message'] as String? ?? 'Failed to join community';
      }

      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error joining community: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error joining community: $e',
        'data': null,
      };
    }
  }
  Future<Map<String, dynamic>> exitCommunity(String communityId) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result = await _communityService.exitCommunity(communityId);

      if (!(result['error'] as bool)) {
        // Remove the community from myCommunities
        final myCommunityList = _myCommunities['data'] as List<dynamic>? ?? [];
        myCommunityList.removeWhere((c) => c['_id'] == communityId);

        // Update allCommunities to reflect that the user is no longer a member
        final allCommunityList = _allCommunities['data'] as List<dynamic>? ?? [];
        final index = allCommunityList.indexWhere((c) => c['_id'] == communityId);
        if (index != -1) {
          final community = allCommunityList[index] as Map<String, dynamic>;
          allCommunityList[index] = {
            ...community,
            'isMember': false,
            'isAdmin': false,
            'isJoined': false,
            'membershipStatus': null,
            'requestStatus': null,
          };
          _allCommunities = {..._allCommunities, 'data': allCommunityList};
        }

        _myCommunities = {..._myCommunities, 'data': myCommunityList};
        _allCommunitiesError = null;
      } else {
        _allCommunitiesError = result['message'] as String? ?? 'Failed to exit community';
      }

      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error exiting community: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error exiting community: ${e.toString()}',
        'data': null
      };
    }
  }

// Updated fetchMyCommunities method with better error handling and data transformation
  Future<void> fetchMyCommunities() async {
    print('=== fetchMyCommunities CALLED ===');
    _isLoadingMy = true;
    _myCommunitiesError = null;
    notifyListeners();

    try {
      final response = await _communityService.getMyCommunities();
      print('fetchMyCommunities response: $response');

      if (!response['error']) {
        final rawData = response['data'] ?? [];
        print('Raw my communities data: $rawData');

        // Ensure we have a valid list
        List<dynamic> communitiesData = [];
        if (rawData is List) {
          communitiesData = rawData;

          // Debug: Log each community's profile image
          for (var community in communitiesData) {
            if (community is Map<String, dynamic>) {
              print('Community: ${community['name']}, ProfileImage: ${community['profileImage']}');
            }
          }
        } else {
          print('Warning: Expected List but got ${rawData.runtimeType}');
          communitiesData = [];
        }

        // Update ONLY my communities data
        _myCommunities = {
          'error': false,
          'message': response['message'] ?? 'Communities fetched successfully',
          'data': communitiesData
        };

        print('Updated _myCommunities with ${communitiesData.length} communities');
        _myCommunitiesError = null;
      } else {
        _myCommunities = {
          'error': true,
          'message': response['message'] ?? 'Failed to fetch communities',
          'data': []
        };
        _myCommunitiesError = response['message'] ?? 'Failed to fetch communities';
        print('Error in response: ${response['message']}');
      }
    } catch (e) {
      print('Exception in fetchMyCommunities: $e');
      print('Stack trace: ${StackTrace.current}');
      _myCommunities = {
        'error': true,
        'message': 'Error fetching communities: ${e.toString()}',
        'data': []
      };
      _myCommunitiesError = 'Error fetching communities: ${e.toString()}';
    }

    _isLoadingMy = false;
    print('fetchMyCommunities completed. Loading: $_isLoadingMy, Error: $_myCommunitiesError');
    notifyListeners();
  }

  Future<Map<String, dynamic>> updateJoinRequest(
      String communityId, String userId, bool status) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result = await _communityService.updateJoinRequest(
          communityId, userId, status);

      if (!(result['error'] as bool)) {
        // Update pending requests list
        final requests =
            _communityInfo['data']?['pendingRequests'] as List<dynamic>? ?? [];
        requests.removeWhere((r) => r['userId'] == userId);

        // If approved, also update the community member status
        if (status) {
          final communityList = _allCommunities['data'] as List<dynamic>? ?? [];
          final index = communityList.indexWhere((c) => c['_id'] == communityId);
          if (index != -1) {
            final community = communityList[index] as Map<String, dynamic>;
            communityList[index] = {
              ...community,
              'isJoined': true,
              'requestStatus': 'approved',
            };
            _allCommunities = {..._allCommunities, 'data': communityList};
          }

          // Also refresh my communities if user was approved
          await fetchMyCommunities();
        }

        _communityInfo = {
          ..._communityInfo,
          'data': {
            ...(_communityInfo['data'] as Map<String, dynamic>? ?? {}),
            'pendingRequests': requests
          }
        };
        _allCommunitiesError = null;
      } else {
        _allCommunitiesError = result['message'] as String? ?? 'Failed to update join request';
      }

      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error updating join request: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error updating join request: $e',
        'data': null,
      };
    }
  }





  Future<Map<String, dynamic>> createCommunity({
    required String name,
    required String description,
    required bool isPrivate,
    String? parentId,
    String? coverImage,
    String? profileImage,
  }) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result = await _communityService.createCommunity(
        name: name,
        description: description,
        isPrivate: isPrivate,
        parentId: parentId,
        coverImage: coverImage,
        profileImage: profileImage,
      );

      if (!result['error']) {
        await fetchCommunities(); // reload all communities after creating
        await fetchMyCommunities(); // reload my communities after creating
      }

      _isLoadingAll = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = e.toString();
      notifyListeners();
      return {
        'error': true,
        'message': 'Error creating community: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    required bool isPrivate,
    String? coverImage,
    String? profileImage,
  }) async {
    try {
      final result = await _communityService.updateCommunity(
        communityId: communityId,
        name: name,
        description: description,
        isPrivate: isPrivate,
        coverImage: coverImage,
        profileImage: profileImage,
      );

      if (!result['error']) {
        await fetchCommunities();
        await fetchMyCommunities(); // Refresh my communities if updated
      }

      return result;
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating community: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> deleteCommunity(String communityId) async {
    final result = await CommunityService.deleteCommunity(communityId);
    if (result['error'] != true) {
      // Remove from both lists
      (_allCommunities['data'] as List?)?.removeWhere((c) => c['_id'] == communityId);
      (_myCommunities['data'] as List?)?.removeWhere((c) => c['_id'] == communityId);
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> fetchCommunityInfo(String communityId) async {
    _isLoadingInfo = true;
    _infoError = null;
    _communityInfo = {'message': 'Loading'};
    notifyListeners();

    final result = await CommunityService().getCommunityInfo(communityId);
    _isLoadingInfo = false;

    if (!result['error']) {
      _communityInfo = result['data'] ?? {'message': 'No data'};
      _infoError = null;
    } else {
      _communityInfo = {'message': 'Error loading info'};
      _infoError = result['message'];
    }
    notifyListeners();
    return result;
  }

  void resetCommunityInfo() {
    _communityInfo = {'message': 'Not loaded'};
    _isLoadingInfo = false;
    _infoError = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchCommunityUsers(String communityId) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result = await _communityService.getCommunityUsers(communityId);

      communityUsers = result;
      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error fetching community users: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error fetching community users: ${e.toString()}',
        'data': []
      };
    }
  }

  bool _isLoading = false;
  String? _error;



  Future<Map<String, dynamic>> addUserToCommunity({
    required String communityId,
    String? name,
    String? email,
    String? mobile,
    String? password,
    required String memberType,
    String? userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _communityService.addUserToCommunity(
        communityId: communityId,
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        memberType: memberType,
        userId: userId,
      );

      if (result['error'] == true) {
        _error = result['message'];
      }

      return result;
    } catch (e) {
      _error = 'Error: $e';
      return {'error': true, 'message': 'Error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchCommunityCampaigns(String communityId,
      {String? timestamp}) async {
    try {
      _isLoadingCampaigns = true;
      _campaignsError = null;
      _communityCampaigns = {'message': 'Loading', 'data': []};
      notifyListeners();

      final result = await _communityService.getCommunityCampaigns(communityId,
          timestamp: timestamp);

      _isLoadingCampaigns = false;
      if (!result['error']) {
        _communityCampaigns = {
          'error': false,
          'message': result['message'] ?? 'Campaigns fetched successfully',
          'data': result['data'] ?? []
        };
        _campaignsError = null;
      } else {
        _communityCampaigns = {
          'message': 'Error loading campaigns',
          'data': []
        };
        _campaignsError = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingCampaigns = false;
      _campaignsError = 'Error fetching campaigns: $e';
      _communityCampaigns = {
        'error': true,
        'message': 'Error fetching campaigns: $e',
        'data': []
      };
      notifyListeners();
      return {
        'error': true,
        'message': 'Error fetching campaigns: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> fetchCommunityCoupons(String communityId) async {
    try {
      _isLoadingCoupons = true;
      _couponsError = null;
      _communityCoupons = {'message': 'Loading', 'coupons': []};
      notifyListeners();

      final result = await _communityService.getCommunityCoupons(communityId);

      _isLoadingCoupons = false;
      if (!result['error']) {
        _communityCoupons = {
          'error': false,
          'message': result['message'] ?? 'Coupons fetched successfully',
          'coupons': result['coupons'] ?? []
        };
        _couponsError = null;
      } else {
        _communityCoupons = {'message': 'Error loading coupons', 'coupons': []};
        _couponsError = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingCoupons = false;
      _couponsError = 'Error fetching coupons: $e';
      _communityCoupons = {
        'error': true,
        'message': 'Error fetching coupons: $e',
        'coupons': []
      };
      notifyListeners();
      return {
        'error': true,
        'message': 'Error fetching coupons: ${e.toString()}',
        'coupons': []
      };
    }
  }

  Future<Map<String, dynamic>> fetchCommunityServices(String communityId) async {
    try {
      _isLoadingServices = true;
      _servicesError = null;
      _communityServices = {'message': 'Loading', 'services': []};
      notifyListeners();

      final result = await _communityService.getCommunityServices(communityId);

      _isLoadingServices = false;
      if (!result['error']) {
        _communityServices = {
          'error': false,
          'message': result['message'] ?? 'Services fetched successfully',
          'services': result['services'] ?? []
        };
        _servicesError = null;
      } else {
        _communityServices = {
          'message': 'Error loading services',
          'services': []
        };
        _servicesError = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingServices = false;
      _servicesError = 'Error fetching services: $e';
      _communityServices = {
        'error': true,
        'message': 'Error fetching services: $e',
        'services': []
      };
      notifyListeners();
      return {
        'error': true,
        'message': 'Error fetching services: ${e.toString()}',
        'services': []
      };
    }
  }

  Future<Map<String, dynamic>> fetchCommunityHierarchyStats(String communityId) async {
    try {
      _isLoadingHierarchyStats = true;
      _hierarchyStatsError = null;
      _communityHierarchyStats = {};
      notifyListeners();

      final result = await _communityService.getCommunityHierarchyStats(communityId);

      _isLoadingHierarchyStats = false;
      if (!result['error']) {
        _communityHierarchyStats = {
          'error': false,
          'message': result['message'] ?? 'Community hierarchy stats fetched successfully',
          'data': result['data'] ?? {}
        };
        _hierarchyStatsError = null;
      } else {
        _communityHierarchyStats = {
          'error': true,
          'message': 'Error loading community hierarchy stats',
          'data': {}
        };
        _hierarchyStatsError = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingHierarchyStats = false;
      _hierarchyStatsError = 'Error fetching community hierarchy stats: $e';
      _communityHierarchyStats = {
        'error': true,
        'message': 'Error fetching community hierarchy stats: $e',
        'data': {}
      };
      notifyListeners();
      return {
        'error': true,
        'message': 'Error fetching community hierarchy stats: ${e.toString()}',
        'data': {}
      };
    }
  }

  // Method to clear hierarchy stats data
  void clearHierarchyStats() {
    _isLoadingHierarchyStats = false;
    _hierarchyStatsError = null;
    _communityHierarchyStats = {};
    notifyListeners();
  }
  bool _isCheckingStatus = false;
  Map<String, dynamic>? _communityData;
  String? _inviteStatus;
  String? _checkErrorMessage;

  // Send invitation variables
  bool _isSendingInvitation = false;
  String? _sendInvitationMessage;
  bool? _invitationSent;

  // Getters for community check
  bool get isCheckingStatus => _isCheckingStatus;
  Map<String, dynamic>? get communityData => _communityData;
  String? get inviteStatus => _inviteStatus;
  String? get checkErrorMessage => _checkErrorMessage;

  // Getters for send invitation
  bool get isSendingInvitation => _isSendingInvitation;
  String? get sendInvitationMessage => _sendInvitationMessage;
  bool? get invitationSent => _invitationSent;

  // Status check helpers
  bool get isUserAccepted => _inviteStatus == 'ACCEPTED';
  bool get canSendInvites => isUserAccepted && _communityData != null;

  // 1. Check Community Status
  Future<void> checkCommunityStatus(String communityName) async {
    _isCheckingStatus = true;
    _checkErrorMessage = null;
    _communityData = null;
    _inviteStatus = null;
    notifyListeners();

    try {
      final result = await _communityService.checkCommunityInviteStatus(communityName);

      if (result['error'] == false) {
        _communityData = result['data'];
        _inviteStatus = result['status'];
        _checkErrorMessage = null;
      } else {
        _checkErrorMessage = result['message'];
      }
    } catch (e) {
      _checkErrorMessage = 'An error occurred while checking community status';
      print('Provider error in checkCommunityStatus: $e');
    }

    _isCheckingStatus = false;
    notifyListeners();
  }

  // 2. Send Invitation Link

  Future<void> sendInvitationLink({
    required String communityId,
    required String type,
    required String contact,
  }) async {
    _isSendingInvitation = true;
    _sendInvitationMessage = null;
    _invitationSent = null;
    notifyListeners();

    try {
      // Get community name from the stored community data
      final communityName = _communityData?['name'];

      if (communityName == null) {
        _invitationSent = false;
        _sendInvitationMessage = 'Community name not available. Please check community status first.';
        _isSendingInvitation = false;
        notifyListeners();
        return;
      }

      // Validate contact based on type
      if (type == 'mail' && !_isValidEmail(contact)) {
        _invitationSent = false;
        _sendInvitationMessage = 'Please enter a valid email address';
        _isSendingInvitation = false;
        notifyListeners();
        return;
      }

      if (type == 'mobile' && !_isValidPhone(contact)) {
        _invitationSent = false;
        _sendInvitationMessage = 'Please enter a valid phone number';
        _isSendingInvitation = false;
        notifyListeners();
        return;
      }

      // Create the correct invite link using community name
      final inviteLink = 'https://app.ixes.ai/invite/$communityName';

      print('=== SENDING INVITATION ===');
      print('Invite link: $inviteLink');
      print('Contact: $contact');
      print('Type: $type');
      print('Community ID: $communityId');
      print('Community Name: $communityName');
      print('========================');

      final result = await _communityService.sendInvitationLink(
        link: inviteLink,
        type: type,
        contact: contact,
      );

      if (result['error'] == false) {
        _invitationSent = result['data'];
        _sendInvitationMessage = result['message'];
        print('✅ Invitation sent successfully');
      } else {
        _invitationSent = false;
        _sendInvitationMessage = result['message'];
        print('❌ Failed to send invitation: ${result['message']}');
      }
    } catch (e) {
      _invitationSent = false;
      _sendInvitationMessage = 'An error occurred while sending invitation: ${e.toString()}';
      print('🚨 Provider error in sendInvitationLink: $e');
    }

    _isSendingInvitation = false;
    notifyListeners();
  }

// Helper validation methods (optional)
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email.trim());
  }

  bool _isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    return phoneRegex.hasMatch(phone.trim()) && phone.trim().length >= 10;
  }
  /// Update admin status of a community member
  Future<Map<String, dynamic>> updateAdminStatusProvider(
      String communityId, String userId, bool isAdmin) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result =
      await _communityService.updateAdminStatus(communityId, userId, isAdmin);

      if (!(result['error'] as bool)) {
        // Update local community users if already loaded
        final users = communityUsers['data'] as List<dynamic>? ?? [];
        final index = users.indexWhere((u) => u['_id'] == userId);

        if (index != -1) {
          final updatedUser = Map<String, dynamic>.from(users[index]);
          updatedUser['isAdmin'] = isAdmin;
          users[index] = updatedUser;
          communityUsers = {...communityUsers, 'data': users};
        }

        // Refresh community info (optional but safer)
        await fetchCommunityInfo(communityId);
        _allCommunitiesError = null;
      } else {
        _allCommunitiesError =
            result['message'] as String? ?? 'Failed to update admin status';
      }

      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error updating admin status: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error updating admin status: $e',
        'data': null,
      };
    }
  }

  /// Remove user from a community
  Future<Map<String, dynamic>> removeUserFromCommunityProvider(
      String communityId, String userId) async {
    try {
      _isLoadingAll = true;
      notifyListeners();

      final result =
      await _communityService.removeUserFromCommunity(communityId, userId);

      if (!(result['error'] as bool)) {
        // Remove from local users list
        final users = communityUsers['data'] as List<dynamic>? ?? [];
        users.removeWhere((u) => u['_id'] == userId);
        communityUsers = {...communityUsers, 'data': users};

        // Refresh community info
        await fetchCommunityInfo(communityId);
        _allCommunitiesError = null;
      } else {
        _allCommunitiesError =
            result['message'] as String? ?? 'Failed to remove user from community';
      }

      _isLoadingAll = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoadingAll = false;
      _allCommunitiesError = 'Error removing user from community: $e';
      notifyListeners();
      return {
        'error': true,
        'message': 'Error removing user from community: $e',
        'data': null,
      };
    }
  }


}

