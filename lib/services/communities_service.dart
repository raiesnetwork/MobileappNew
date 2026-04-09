import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ixes.app/services/api_service.dart';

class CommunityService {
  Future<Map<String, dynamic>> getAllCommunities({required int page}) async {
    try {
      final response = await ApiService.get(
          '/api/communities/defaultList?pageNo=$page');
      ApiService.checkResponse(response);

      print('getAllCommunities - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Communities fetched successfully',
          'communities': decoded['communities'] ?? [],
          'totalPages': decoded['totalPages'] ?? page,
          'currentPage': decoded['currentPage'] ?? page,
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch communities',
          'communities': []
        };
      }
    } catch (e) {
      print('Error in getAllCommunities: $e');
      return {
        'error': true,
        'message': 'Error fetching communities: ${e.toString()}',
        'communities': []
      };
    }
  }

  Future<Map<String, dynamic>> getMyCommunities() async {
    try {
      final response = await ApiService.get('/api/communities/my-communities');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          return {'error': false, 'message': 'No communities', 'data': []};
        }
        return {
          'error': false,
          'message': 'Communities fetched successfully',
          'data': decoded.map((c) => _transformCommunity(c as Map<String, dynamic>)).toList(),
        };
      }

      if (response.statusCode == 401 ||
          response.statusCode == 404 ||
          response.statusCode == 403) {
        return {'error': false, 'message': 'No communities yet', 'data': []};
      }

      return {
        'error': true,
        'message': 'Failed to fetch communities (${response.statusCode})',
        'data': [],
      };
    } catch (e) {
      return {'error': true, 'message': 'Network error: ${e.toString()}', 'data': []};
    }
  }

  Map<String, dynamic> _transformCommunity(Map<String, dynamic> c) {
    final id = (c['id'] ?? c['_id'])?.toString() ?? '';
    final profileImage = c['profileImage'] ?? c['profile_image'] ?? c['image'] ?? c['avatar'];
    return {
      'id': id,
      '_id': id,
      'name': c['name']?.toString() ?? 'Unnamed Community',
      'isMember': true,
      'isAdmin': c['isAdmin'] ?? false,
      'isPrivate': c['isPrivate'] ?? false,
      'profileImage': profileImage,
      'description': c['description'],
      'memberCount': c['memberCount'] ?? 0,
      'subCommunities': (c['subCommunities'] as List?)
          ?.map((s) => _transformCommunity(s as Map<String, dynamic>))
          .toList() ??
          [],
    };
  }

  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
    try {
      final response = await ApiService.post(
        '/api/communities/join',
        {'communityId': communityId},
      );
      ApiService.checkResponse(response);

      print('joinCommunity - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'] ?? true,
          'isPrivate': decoded['isPrivate'] ?? false,
          'requestStatus': decoded['requestStatus'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to join community',
          'data': null
        };
      }
    } catch (e) {
      print('Error in joinCommunity: $e');
      return {
        'error': true,
        'message': 'Error joining community: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> exitCommunity(String communityId) async {
    try {
      final response = await ApiService.delete(
          '/api/communities/$communityId/exit');
      ApiService.checkResponse(response);

      print('exitCommunity - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Successfully exited the community',
          'data': decoded['communityId'] ?? communityId
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['error'] ?? 'Failed to exit community',
          'data': null
        };
      }
    } catch (e) {
      print('Error in exitCommunity: $e');
      return {
        'error': true,
        'message': 'Error exiting community: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> updateJoinRequest(
      String communityId, String userId, bool status) async {
    try {
      final response = await ApiService.put(
        '/api/communities/updateJoinRequest/$communityId/$userId/${status.toString()}',
        {},
      );
      ApiService.checkResponse(response);

      print('updateJoinRequest - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'error': false,
          'message': status
              ? 'Join request approved successfully'
              : 'Join request rejected successfully',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update join request',
          'data': null
        };
      }
    } catch (e) {
      print('Error in updateJoinRequest: $e');
      return {
        'error': true,
        'message': 'Error updating join request: ${e.toString()}',
        'data': null
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
      final body = {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        if (parentId != null) 'parentId': parentId,
        if (coverImage != null) 'coverImage': coverImage,
        if (profileImage != null) 'profileImage': profileImage,
      };

      final response = await ApiService.post('/api/communities/', body);
      ApiService.checkResponse(response);

      print('createCommunity - Status Code: ${response.statusCode}');
      print('Create response body: ${response.body}');

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['messages'] ?? 'Community created successfully',
          'data': decoded['communityId']
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? '',
          'data': null
        };
      }
    } catch (e) {
      print('Error in createCommunity: $e');
      return {
        'error': true,
        'message': 'Error creating community: ${e.toString()}',
        'data': null
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }
      final uri = Uri.parse('${apiBaseUrl}api/communities/$communityId');
      final request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['isPrivate'] = isPrivate.toString();

      if (profileImage != null && profileImage.startsWith('/')) {
        request.files.add(await http.MultipartFile.fromPath(
            'profileImage', profileImage));
      }
      if (coverImage != null && coverImage.startsWith('/')) {
        request.files.add(await http.MultipartFile.fromPath(
            'coverImage', coverImage));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      ApiService.checkResponse(response); // ✅ 401 check
      final body = jsonDecode(response.body);
      return {'error': response.statusCode != 200, ...body};
    } catch (e) {
      return {'error': true, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteCommunity(
      String communityId) async {
    final response = await ApiService.delete(
        '/api/communities/$communityId');
    ApiService.checkResponse(response);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'error': true,
        'message': 'Failed to delete community',
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityInfo(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/info/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityInfo - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Community info fetched successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch community info',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getCommunityInfo: $e');
      return {
        'error': true,
        'message': 'Error fetching community info: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityUsers(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/users/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityUsers - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Community users fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch community users',
          'data': []
        };
      }
    } catch (e) {
      print('Error in getCommunityUsers: $e');
      return {
        'error': true,
        'message': 'Error fetching community users: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> updateAdminStatus(
      String communityId, String userId, bool isAdmin) async {
    try {
      final response = await ApiService.put(
        '/api/communities/updateAdmin/$communityId/$userId/$isAdmin',
        {},
      );
      ApiService.checkResponse(response);

      print('updateAdminStatus - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Admin status updated successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update admin status',
          'data': null
        };
      }
    } catch (e) {
      print('Error in updateAdminStatus: $e');
      return {
        'error': true,
        'message': 'Error updating admin status: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> removeUserFromCommunity(
      String communityId, String userId) async {
    try {
      final response = await ApiService.delete(
          '/api/communities/removeUser/$communityId/$userId');
      ApiService.checkResponse(response);

      print('removeUserFromCommunity - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'User removed from community successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to remove user from community',
          'data': null
        };
      }
    } catch (e) {
      print('Error in removeUserFromCommunity: $e');
      return {
        'error': true,
        'message': 'Error removing user from community: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> addUserToCommunity({
    required String communityId,
    String? name,
    String? email,
    String? mobile,
    String? password,
    required String memberType,
    String? userId,
  }) async {
    try {
      Map<String, dynamic> body = {
        'communityId': communityId,
        'memberType': memberType,
        'userType': 'member',
        'userRole': 'basic',
        'inheritSubCommunity': true,
      };

      if (memberType == 'New') {
        body.addAll({
          'name': name,
          'email': email,
          'mobile': mobile,
          'password': password,
        });
      } else {
        body['userId'] = userId;
      }

      final response = await ApiService.post('/api/communities/addUser', body);
      ApiService.checkResponse(response);

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'User added successfully',
          'data': data
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'error': true,
          'message': data['message'] ?? 'Failed to add user',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityCampaigns(String communityId,
      {String? timestamp}) async {
    try {
      final queryString = timestamp != null ? '?timestamp=$timestamp' : '';
      final response = await ApiService.get(
          '/api/communities/campaigns/$communityId$queryString');
      ApiService.checkResponse(response);

      print('getCommunityCampaigns - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Campaigns fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch campaigns',
          'data': []
        };
      }
    } catch (e) {
      print('Error in getCommunityCampaigns: $e');
      return {
        'error': true,
        'message': 'Error fetching campaigns: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityCoupons(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/coupons/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityCoupons - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Coupons fetched successfully',
          'coupons': decoded['coupons'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch coupons',
          'coupons': []
        };
      }
    } catch (e) {
      print('Error in getCommunityCoupons: $e');
      return {
        'error': true,
        'message': 'Error fetching coupons: ${e.toString()}',
        'coupons': []
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityServices(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/services/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityServices - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Services fetched successfully',
          'services': decoded['services'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch services',
          'services': []
        };
      }
    } catch (e) {
      print('Error in getCommunityServices: $e');
      return {
        'error': true,
        'message': 'Error fetching services: ${e.toString()}',
        'services': []
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityHierarchyStats(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/stats/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityHierarchyStats - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Community hierarchy stats fetched successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch community hierarchy stats',
          'data': {}
        };
      }
    } catch (e) {
      print('Error in getCommunityHierarchyStats: $e');
      return {
        'error': true,
        'message': 'Error fetching community hierarchy stats: ${e.toString()}',
        'data': {}
      };
    }
  }

  Future<Map<String, dynamic>> checkCommunityInviteStatus(String communityName) async {
    try {
      final response = await ApiService.get(
          '/api/communities/invite?name=${Uri.encodeComponent(communityName.trim())}');
      ApiService.checkResponse(response);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Community status fetched successfully',
          'data': decoded['data'],
          'status': decoded['status']
        };
      } else if (response.statusCode == 404) {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Community not found or you don\'t have access',
            'data': null,
            'status': null
          };
        } catch (e) {
          return {
            'error': true,
            'message': 'Community not found (404 error)',
            'data': null,
            'status': null
          };
        }
      } else {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to check community status (${response.statusCode})',
            'data': null,
            'status': null
          };
        } catch (e) {
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
            'data': null,
            'status': null
          };
        }
      }
    } catch (e) {
      print('Exception in checkCommunityInviteStatus: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': null,
        'status': null
      };
    }
  }

  Future<Map<String, dynamic>> sendInvitationLink({
    required String link,
    required String type,
    required dynamic contact,
  }) async {
    try {
      List<String> contactList;
      if (contact is String) {
        contactList = [contact];
      } else if (contact is List<String>) {
        contactList = contact;
      } else {
        return {
          'error': true,
          'message': 'Invalid contact format',
          'data': false
        };
      }

      final requestBody = {
        'link': link,
        'type': type,
        'contact': contactList,
      };

      print('=== INVITATION REQUEST DEBUG ===');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Contact count: ${contactList.length}');
      print('===============================');

      final response = await ApiService.post(
          '/api/communities/invitelink', requestBody);
      ApiService.checkResponse(response);

      print('sendInvitationLink - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Invitation(s) sent successfully',
          'data': decoded['data'] ?? true
        };
      } else if (response.statusCode == 500) {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Server error occurred',
            'data': false
          };
        } catch (e) {
          return {'error': true, 'message': 'Internal server error (500)', 'data': false};
        }
      } else if (response.statusCode == 400) {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Invalid request data',
            'data': false
          };
        } catch (e) {
          return {'error': true, 'message': 'Bad request (400) - Invalid data format', 'data': false};
        }
      } else if (response.statusCode == 403) {
        return {
          'error': true,
          'message': 'You don\'t have permission to send invitations',
          'data': false
        };
      } else if (response.statusCode == 404) {
        return {
          'error': true,
          'message': 'Invitation service not found. Please contact support.',
          'data': false
        };
      } else {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to send invitation (${response.statusCode})',
            'data': false
          };
        } catch (e) {
          return {'error': true, 'message': 'Server error: ${response.statusCode}', 'data': false};
        }
      }
    } catch (e) {
      print('Exception in sendInvitationLink: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': false
      };
    }
  }

  Future<Map<String, dynamic>> getCommunityEvents(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/event/fetch/$communityId');
      ApiService.checkResponse(response);

      print('getCommunityEvents - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Events fetched successfully',
          'data': decoded['data'] ?? [],
          'email': decoded['email'],
          'password': decoded['password']
        };
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Unauthorized access',
          'data': [],
          'email': null,
          'password': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch events',
          'data': [],
          'email': null,
          'password': null
        };
      }
    } catch (e) {
      print('Error in getCommunityEvents: $e');
      return {
        'error': true,
        'message': 'Error fetching events: ${e.toString()}',
        'data': [],
        'email': null,
        'password': null
      };
    }
  }
}