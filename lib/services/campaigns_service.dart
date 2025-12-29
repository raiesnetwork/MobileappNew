import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';

class CampaignService {
  Future<Map<String, dynamic>> getAllCampaigns({
    required int page,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("Token missing");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'campaigns': [],
        };
      }

      // Fetch all campaigns (backend doesn't support pagination yet)
      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/campaigns/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getAllCampaigns - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> campaignsList = [];

        // Handle different response structures
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

  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      return {'message': 'Invalid response format'};
    }
  }

  Future<Map<String, dynamic>> createCampaign(
      Map<String, dynamic> campaignData) async {
    try {
      print('createCampaign - Starting with data: $campaignData');
      print('createCampaign - Community ID: ${campaignData['communityId']}');
      print('createCampaign - Has base64 image: ${campaignData['coverImageBase64']?.isNotEmpty ?? false}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print('createCampaign - Error: Authentication token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'campaign': null
        };
      }

      final processedData = Map<String, dynamic>.from(campaignData);

      // Handle base64 image properly
      if (processedData['coverImageBase64'] != null &&
          processedData['coverImageBase64'].toString().isNotEmpty) {
        String base64Image = processedData['coverImageBase64'].toString();

        if (base64Image.contains('data:image')) {
          final parts = base64Image.split(',');
          if (parts.length > 1) {
            base64Image = parts.last;
          }
        }

        base64Image = base64Image.replaceAll(RegExp(r'\s+'), '');
        processedData['coverImageBase64'] = base64Image;
        print('createCampaign - Processed base64 image length: ${base64Image.length}');
      } else {
        processedData.remove('coverImageBase64');
      }

      print('createCampaign - Sending data: ${processedData.keys}');

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/campaigns/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(processedData),
      );

      print('createCampaign - Status Code: ${response.statusCode}');
      print('createCampaign - Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);

        Map<String, dynamic>? campaign;
        if (decoded.containsKey('campaign')) {
          campaign = decoded['campaign'];
        } else if (decoded.containsKey('data')) {
          campaign = decoded['data'];
        } else if (decoded.containsKey('result')) {
          campaign = decoded['result'];
        } else {
          campaign = decoded;
        }

        print('createCampaign - Extracted campaign: $campaign');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Campaign created successfully',
          'campaign': campaign
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        print('createCampaign - Error: ${decoded['message'] ?? 'Failed to create campaign'}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create campaign',
          'campaign': null
        };
      }
    } catch (e) {
      print('createCampaign - Exception: $e');
      return {
        'error': true,
        'message': 'Error creating campaign: ${e.toString()}',
        'campaign': null
      };
    }
  }

  Future<Map<String, dynamic>> getCampaignDetails(String campaignId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'campaign': null
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/campaigns/detail/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getCampaignDetails - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print("Campaign ID: $campaignId");

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'campaign': null
        };
      }

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/campaigns/edit/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(campaignData),
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'campaign': null
        };
      }

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/campaigns/delete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'campaignId': campaignId}),
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/campaigns/members/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getCampaignMembers - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print("Campaign ID: $campaignId");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Members fetched successfully',
          'data': decoded['data'],
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
        'message': 'Error fetching campaign members: ${e.toString()}',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> getUnpaidCommunityMembers(
      String communityId, String campaignId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/campaigns/communitymembers/$communityId/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getUnpaidCommunityMembers - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print("Community ID: $communityId, Campaign ID: $campaignId");

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
          'message':
          decoded['message'] ?? 'Failed to fetch unpaid community members',
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