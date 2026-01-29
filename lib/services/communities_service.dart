import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';


class CommunityService {
  Future<Map<String, dynamic>> getAllCommunities({required int page}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'communities': []
        };
      }

      final response = await http.get(
        Uri.parse(
            '${apiBaseUrl}api/communities/defaultList?pageNo=$page'), // Add page parameter
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('Retrieved token: $token');

      if (token == null || token.isEmpty) {
        print('Token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final url = '${apiBaseUrl}api/communities/my-communities';
      print('Requesting URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('Decoded response: $decoded');

        // Ensure decoded is a List
        if (decoded is! List) {
          print('Expected List but got ${decoded.runtimeType}');
          return {
            'error': true,
            'message': 'Invalid response format',
            'data': []
          };
        }

        // Transform the response to match expected structure
        final transformedData = decoded.map((community) {
          final communityMap = community as Map<String, dynamic>;

          // Debug: Print the raw community data to see what fields exist
          print('Raw community data: $communityMap');

          // Extract the ID - try both 'id' and '_id'
          final id = communityMap['id']?.toString() ??
              communityMap['_id']?.toString() ?? '';

          // Extract profile image - try multiple possible field names
          final profileImage = communityMap['profileImage'] ??
              communityMap['profile_image'] ??
              communityMap['image'] ??
              communityMap['avatar'];

          print('Community ID: $id, ProfileImage: $profileImage');

          return {
            // Use BOTH 'id' and '_id' to ensure compatibility
            'id': id,
            '_id': id,
            'name': communityMap['name']?.toString() ?? 'Unnamed Community',
            'isMember': true,
            'isAdmin': communityMap['isAdmin'] ?? false,
            'isPrivate': communityMap['isPrivate'] ?? false,
            'profileImage': profileImage, // Use the extracted profile image
            'description': communityMap['description'],
            'memberCount': communityMap['memberCount'] ?? 0,
            // Handle subcommunities recursively
            'subCommunities': (communityMap['subCommunities'] as List?)?.map((sub) {
              final subMap = sub as Map<String, dynamic>;
              final subId = subMap['id']?.toString() ?? subMap['_id']?.toString() ?? '';
              final subProfileImage = subMap['profileImage'] ??
                  subMap['profile_image'] ??
                  subMap['image'] ??
                  subMap['avatar'];

              return {
                'id': subId,
                '_id': subId,
                'name': subMap['name']?.toString() ?? 'Unnamed Community',
                'isMember': true,
                'isAdmin': subMap['isAdmin'] ?? false,
                'isPrivate': subMap['isPrivate'] ?? false,
                'profileImage': subProfileImage,
                'description': subMap['description'],
                'memberCount': subMap['memberCount'] ?? 0,
                'subCommunities': subMap['subCommunities'] ?? [],
              };
            }).toList() ?? [],
          };
        }).toList();

        print('Transformed data: $transformedData');

        return {
          'error': false,
          'message': 'Communities fetched successfully',
          'data': transformedData
        };
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Unauthorized - Please log in again',
          'data': []
        };
      } else if (response.statusCode == 500) {
        return {
          'error': true,
          'message': 'Server error - Please try again later',
          'data': []
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to fetch communities (${response.statusCode})',
          'data': []
        };
      }
    } catch (e) {
      print('Exception caught: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
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

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/communities/join'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'communityId': communityId}),
      );

      print('joinCommunity - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'] ?? true,
          'isPrivate': decoded['isPrivate'] ?? false, // Include privacy info
          'requestStatus': decoded[
              'requestStatus'], // Include request status for private communities
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final response = await http.delete(
        Uri.parse('${apiBaseUrl}api/communities/$communityId/exit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/communities/updateJoinRequest/$communityId/$userId/${status.toString()}'),
        headers: {
          'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},);

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final body = {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        if (parentId != null) 'parentId': parentId,
        if (coverImage != null) 'coverImage': coverImage,
        if (profileImage != null) 'profileImage': profileImage,
      };

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/communities/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('createCommunity - Status Code: ${response.statusCode}');
      print('Create response body: ${response.body}'); // Debug line

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
      print('Error in createCommunity: $e'); // Debug line
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
        };
      }

      final body = {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'coverImage': coverImage, // Explicitly include, even if null
        'profileImage': profileImage, // Explicitly include, even if null
      };

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/communities/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('Update Community Status: ${response.statusCode}');
      print('Update Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Community updated successfully',
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update community',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating community: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCommunity(
      String communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.delete(
      Uri.parse(
          '${apiBaseUrl}api/communities/$communityId'), // Use your full delete endpoint URL here
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }
      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/info/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/users/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
  // Add these methods to your service class

  /// Update admin status of a community member
  /// PUT /updateAdmin/:communityId/:userId/:isAdmin
  Future<Map<String, dynamic>> updateAdminStatus(
      String communityId,
      String userId,
      bool isAdmin
      ) async {
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

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/communities/updateAdmin/$communityId/$userId/$isAdmin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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

  /// Remove user from community
  /// DELETE /removeUser/:communityId/:userId
  Future<Map<String, dynamic>> removeUserFromCommunity(
      String communityId,
      String userId
      ) async {
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

      final response = await http.delete(
        Uri.parse('${apiBaseUrl}api/communities/removeUser/$communityId/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      // Get token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'error': true, 'message': 'No token found'};
      }

      // Prepare data
      Map<String, dynamic> body = {
        'communityId': communityId,
        'memberType': memberType,
        'userType': 'member',
        'userRole': 'basic',
        'inheritSubCommunity': true,
      };

      // Add data based on type
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

      // Make API call
      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/communities/addUser'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("$token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final uri =
          Uri.parse('${apiBaseUrl}api/communities/campaigns/$communityId').replace(queryParameters:
          timestamp != null ? {'timestamp': timestamp} : null);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'coupons': []
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/coupons/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'services': []
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/services/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': {}
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/stats/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
          'status': null
        };
      }

      // Enhanced URL construction with better debugging
      final baseUrl = apiBaseUrl.endsWith('/') ? apiBaseUrl : '${apiBaseUrl}/';
      final uri = Uri.parse('${baseUrl}api/communities/invite').replace(
          queryParameters: {'name': communityName.trim()}
      );


      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
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
        // Handle 404 specifically
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
        // Handle other error status codes
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
    required String type, // 'mail' or 'mobile'
    required dynamic contact, // Can be String or List<String>
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': false
        };
      }

      // Ensure contact is always an array
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

      final baseUrl = apiBaseUrl.endsWith('/') ? apiBaseUrl : '${apiBaseUrl}/';
      final uri = Uri.parse('${baseUrl}api/communities/invitelink');

      final requestBody = {
        'link': link,
        'type': type,
        'contact': contactList, // Always send as array
      };

      print('=== INVITATION REQUEST DEBUG ===');
      print('URL: $uri');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Token present: ${token.isNotEmpty}');
      print('Contact count: ${contactList.length}');
      print('===============================');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('sendInvitationLink - Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
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
          return {
            'error': true,
            'message': 'Internal server error (500)',
            'data': false
          };
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
          return {
            'error': true,
            'message': 'Bad request (400) - Invalid data format',
            'data': false
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Authentication failed. Please login again.',
          'data': false
        };
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
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
            'data': false
          };
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
  // Add this method to your CommunityService class

  Future<Map<String, dynamic>> getCommunityEvents(String communityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': [],
          'email': null,
          'password': null
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/event/fetch/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
