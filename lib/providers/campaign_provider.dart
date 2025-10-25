import 'package:flutter/material.dart';
import 'package:ixes.app/constants/apiConstants.dart';

import '../services/campaigns_service.dart';

class CampaignProvider with ChangeNotifier {
  final CampaignService _campaignService = CampaignService();
  List<dynamic> campaigns = [];
  bool isLoading = false;
  bool hasMoreCampaigns = true;
  String? errorMessage;

  Future<void> fetchAllCampaigns({required int page, int limit = 10}) async {
    if (isLoading || !hasMoreCampaigns) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    print('Fetching campaigns page: $page, current total: ${campaigns.length}');

    final response = await _campaignService.getAllCampaigns(page: page, limit: limit);

    if (!response['error']) {
      final newCampaigns = response['campaigns'] as List<dynamic>;
      print('Fetched ${newCampaigns.length} campaigns');

      // Convert to proper Map objects if needed
      final List<Map<String, dynamic>> typedCampaigns = newCampaigns
          .map((campaign) => Map<String, dynamic>.from(campaign as Map))
          .toList();

      if (page == 1) {
        campaigns = typedCampaigns;
      } else {
        campaigns.addAll(typedCampaigns);
      }

      hasMoreCampaigns = newCampaigns.length == limit;
      print('Has more campaigns? $hasMoreCampaigns');
      print('Total campaigns now: ${campaigns.length}');
    } else {
      errorMessage = response['message'];
      print('Error fetching campaigns: ${response['message']}');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createCampaign(
      Map<String, dynamic> campaignData) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    print('Creating campaign with data keys: ${campaignData.keys}');

    final response = await _campaignService.createCampaign(campaignData);
    print('Create campaign response: $response');

    if (!response['error']) {
      final newCampaign = response['campaign'];
      if (newCampaign != null) {
        // Ensure it's a proper Map<String, dynamic>
        final Map<String, dynamic> typedCampaign =
        Map<String, dynamic>.from(newCampaign as Map);

        // Add to the beginning of the list
        campaigns.insert(0, typedCampaign);
        print('Campaign created and added to list. New total: ${campaigns.length}');
        print('Added campaign: ${typedCampaign['id']} - ${typedCampaign['title']}');
      } else {
        print('Warning: Campaign was created but campaign object is null');
        errorMessage = 'Campaign created but not returned from server';
      }
    } else {
      errorMessage = response['message'];
      print('Error creating campaign: ${response['message']}');
    }

    isLoading = false;
    notifyListeners();
    return response;
  }

// HELPER METHOD FOR IMAGE DISPLAY
  String? getCampaignImageUrl(Map<String, dynamic> campaign) {
    // Check different possible image fields
    if (campaign['coverImageUrl'] != null && campaign['coverImageUrl'].toString().isNotEmpty) {
      String imageUrl = campaign['coverImageUrl'].toString();
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else if (imageUrl.isNotEmpty) {
        return '${apiBaseUrl}$imageUrl';
      }
    }

    if (campaign['coverImage'] != null && campaign['coverImage'].toString().isNotEmpty) {
      String imageUrl = campaign['coverImage'].toString();
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else if (imageUrl.isNotEmpty) {
        return '${apiBaseUrl}$imageUrl';
      }
    }

    if (campaign['image'] != null && campaign['image'].toString().isNotEmpty) {
      String imageUrl = campaign['image'].toString();
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else if (imageUrl.isNotEmpty) {
        return '${apiBaseUrl}$imageUrl';
      }
    }

    return null;
  }

// WIDGET FOR DISPLAYING CAMPAIGN IMAGE
  Widget buildCampaignImage(Map<String, dynamic> campaign, {double? width, double? height}) {
    final imageUrl = getCampaignImageUrl(campaign);

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image: $imageUrl, Error: $error');
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Future<Map<String, dynamic>> getCampaignDetails(String campaignId) async {
    final response = await _campaignService.getCampaignDetails(campaignId);
    return response;
  }

  Future<Map<String, dynamic>> editCampaign(
      String campaignId, Map<String, dynamic> campaignData) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final response =
        await _campaignService.editCampaign(campaignId, campaignData);

    if (!response['error'] && response['campaign'] != null) {
      final index = campaigns.indexWhere((c) => c['_id'] == campaignId);
      if (index != -1) {
        campaigns[index] = {
          '_id': campaignId,
          'title': campaignData['title'],
          'description': campaignData['description'],
          'totalAmountNeeded': campaignData['totalAmountNeeded'],
          'currency': campaignData['currency'],
          'endDate': campaignData['endDate'],
          'coverImage': campaignData['coverImage'],
          'progress': campaigns[index]['progress'], // Preserve progress
          'community': campaigns[index]['community'], // Preserve community
          'isUserAdmin': campaigns[index]
              ['isUserAdmin'], // Preserve isUserAdmin
        };
        print('Campaign updated in list at index $index');
      }
    } else {
      errorMessage = response['message'];
    }

    isLoading = false;
    notifyListeners();
    return response;
  }

  Future<Map<String, dynamic>> deleteCampaign(String campaignId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final response = await _campaignService.deleteCampaign(campaignId);

    if (!response['error']) {
      campaigns.removeWhere((c) => c['_id'] == campaignId);
      print('Campaign $campaignId removed from list');
    } else {
      errorMessage = response['message'];
    }

    isLoading = false;
    notifyListeners();
    return response;
  }

  Future<void> refreshCampaigns() async {
    campaigns.clear();
    hasMoreCampaigns = true;
    await fetchAllCampaigns(page: 1);
  }

  Future<Map<String, dynamic>> getCampaignMembers(String campaignId) async {
    final response = await _campaignService.getCampaignMembers(campaignId);
    return response;
  }

  Map<String, dynamic> _unpaidMembers = {'data': []};
  String? _unpaidMembersError;

  Map<String, dynamic> get unpaidMembers => _unpaidMembers;
  String? get unpaidMembersError => _unpaidMembersError;

  Future<void> fetchUnpaidCommunityMembers(
      String communityId, String campaignId) async {
    try {
      final response = await _campaignService.getUnpaidCommunityMembers(
          communityId, campaignId);

      if (response['error'] == false) {
        _unpaidMembers = {
          'data': response['data'] ?? [],
        };
        _unpaidMembersError = null;
      } else {
        _unpaidMembers = {'data': []};
        _unpaidMembersError = response['message'] ?? 'Unknown error occurred';
      }
    } catch (e) {
      _unpaidMembers = {'data': []};
      _unpaidMembersError = 'Error fetching unpaid members: $e';
    }

    notifyListeners();
  }

  void clearUnpaidMembers() {
    _unpaidMembers = {'data': []};
    _unpaidMembersError = null;
    notifyListeners();
  }
}
