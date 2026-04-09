import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'api_service.dart';

class CampaignService {
  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      return {'message': 'Invalid response format'};
    }
  }

  Future<Map<String, dynamic>> getAllCampaigns({
    required int page,
    int limit = 10,
  }) async {
    try {
      final response = await ApiService.get('/api/campaigns/');
      ApiService.checkResponse(response);

      print('getAllCampaigns - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> campaignsList = [];

        if (decoded is List) {
          campaignsList = decoded;
        } else if (decoded is Map) {
          campaignsList = decoded['campaigns'] ??
              decoded['data'] ??
              decoded['results'] ??
              [];
        }

        print('✅ Fetched ${campaignsList.length} total campaigns from server');

        return {
          'error': false,
          'message': 'Campaigns fetched successfully',
          'campaigns': campaignsList,
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch campaigns',
          'campaigns': [],
        };
      }
    } catch (e) {
      print('Error in getAllCampaigns: $e');
      return {
        'error': true,
        'message': 'Error fetching campaigns: ${e.toString()}',
        'campaigns': [],
      };
    }
  }

  Future<Map<String, dynamic>> createCampaign(
      Map<String, dynamic> campaignData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {'error': true, 'message': 'Authentication token is missing', 'campaign': null};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${apiBaseUrl}api/campaigns/create'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      campaignData.forEach((key, value) {
        if (key != 'coverImageBase64' && value != null) {
          if (value is List || value is Map) {
            request.fields[key] = jsonEncode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      final base64Image = campaignData['coverImageBase64']?.toString() ?? '';
      if (base64Image.isNotEmpty) {
        String cleanBase64 = base64Image;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

        final imageBytes = base64Decode(cleanBase64);
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'cover_image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      ApiService.checkResponse(response); // ✅ 401 check

      print('createCampaign - Status Code: ${response.statusCode}');
      print('createCampaign - Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Campaign created successfully',
          'campaign': decoded['campaign'] ?? {'_id': 'new'},
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? decoded['error'] ?? 'Failed to create campaign',
          'campaign': null,
        };
      }
    } catch (e) {
      print('createCampaign - Exception: $e');
      return {
        'error': true,
        'message': 'Error creating campaign: ${e.toString()}',
        'campaign': null,
      };
    }
  }

  Future<Map<String, dynamic>> getCampaignDetails(String campaignId) async {
    try {
      final response = await ApiService.get('/api/campaigns/detail/$campaignId');
      ApiService.checkResponse(response);

      print('getCampaignDetails - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Campaign fetched successfully',
          'campaign': decoded['data']
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch campaign details',
          'campaign': null
        };
      }
    } catch (e) {
      print('Error in getCampaignDetails: $e');
      return {
        'error': true,
        'message': 'Error fetching campaign details: ${e.toString()}',
        'campaign': null
      };
    }
  }

  Future<Map<String, dynamic>> editCampaign(
      String campaignId, Map<String, dynamic> campaignData) async {
    try {
      final response = await ApiService.put(
          '/api/campaigns/edit/$campaignId', campaignData);
      ApiService.checkResponse(response);

      print('editCampaign - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Campaign updated successfully',
          'campaign': decoded['data'] ?? campaignData
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update campaign',
          'campaign': null
        };
      }
    } catch (e) {
      print('Error in editCampaign: $e');
      return {
        'error': true,
        'message': 'Error updating campaign: ${e.toString()}',
        'campaign': null
      };
    }
  }

  Future<Map<String, dynamic>> deleteCampaign(String campaignId) async {
    try {
      final response = await ApiService.post(
          '/api/campaigns/delete', {'campaignId': campaignId});
      ApiService.checkResponse(response);

      print('deleteCampaign - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Campaign deleted successfully',
          'campaign': decoded['deletedCampaign']
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to delete campaign',
          'campaign': null
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error deleting campaign: ${e.toString()}',
        'campaign': null
      };
    }
  }

  Future<Map<String, dynamic>> getCampaignMembers(String campaignId) async {
    try {
      final response = await ApiService.get(
          '/api/campaigns/members/$campaignId');
      ApiService.checkResponse(response);

      print('getCampaignMembers - Status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Members fetched successfully',
          'data': decoded['data'],
        };
      } else if (response.statusCode == 403) {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'You do not have permission to view campaign members',
          'data': null,
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch campaign members',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in getCampaignMembers: $e');
      return {
        'error': true,
        'message': 'Network error. Please check your connection',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> getUnpaidCommunityMembers(
      String communityId, String campaignId) async {
    try {
      final response = await ApiService.get(
          '/api/campaigns/communitymembers/$communityId/$campaignId');
      ApiService.checkResponse(response);

      print('getUnpaidCommunityMembers - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Unpaid members fetched successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch unpaid community members',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in getUnpaidCommunityMembers: $e');
      return {
        'error': true,
        'message': 'Error fetching unpaid community members: ${e.toString()}',
        'data': null,
      };
    }
  }
}