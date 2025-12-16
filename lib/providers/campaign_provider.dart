import 'package:flutter/material.dart';
import 'package:ixes.app/constants/apiConstants.dart';

import '../services/campaigns_service.dart';

class CampaignProvider with ChangeNotifier {
  final CampaignService _campaignService = CampaignService();
  List<dynamic> campaigns = [];
  bool isLoading = false;
  bool hasMoreCampaigns = true;
  String? errorMessage;
  int _currentPage = 0; // Track current page

  Future<void> fetchAllCampaigns({required int page, int limit = 10}) async {
    // Prevent duplicate calls
    if (page == _currentPage && page != 1) {
      print('Already loaded page $page, skipping');
      return;
    }

    if (isLoading) {
      print('Already loading, skipping');
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    print('Fetching campaigns page: $page, current total: ${campaigns.length}');

    final response = await _campaignService.getAllCampaigns(page: page, limit: limit);

    if (!response['error']) {
      final newCampaigns = response['campaigns'] as List<dynamic>;
      print('Fetched ${newCampaigns.length} campaigns');

      // Convert to proper Map objects
      final List<Map<String, dynamic>> typedCampaigns = newCampaigns
          .map((campaign) => Map<String, dynamic>.from(campaign as Map))
          .toList();

      if (page == 1) {
        campaigns = typedCampaigns;
        _currentPage = 1;
      } else {
        // Remove duplicates based on _id
        final existingIds = campaigns.map((c) => c['_id']).toSet();
        final uniqueNewCampaigns = typedCampaigns
            .where((c) => !existingIds.contains(c['_id']))
            .toList();

        campaigns.addAll(uniqueNewCampaigns);
        _currentPage = page;
        print('Added ${uniqueNewCampaigns.length} new unique campaigns');
      }

      hasMoreCampaigns = response['hasMore'] ?? (newCampaigns.length == limit);
      print('Has more campaigns? $hasMoreCampaigns');
      print('Total campaigns now: ${campaigns.length}');
    } else {
      errorMessage = response['message'];
      print('Error fetching campaigns: ${response['message']}');
      if (page == 1) {
        hasMoreCampaigns = false;
      }
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
        final Map<String, dynamic> typedCampaign =
        Map<String, dynamic>.from(newCampaign as Map);

        campaigns.insert(0, typedCampaign);
        print('Campaign created and added to list. New total: ${campaigns.length}');
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

  // UPDATED: Simplified image URL method - expects URL from backend
  String? getCampaignImageUrl(Map<String, dynamic> campaign) {
    // Priority order: coverImage > coverImageUrl > image
    final imageFields = ['coverImage', 'coverImageUrl', 'image'];

    for (final field in imageFields) {
      if (campaign[field] != null && campaign[field].toString().isNotEmpty) {
        String imageUrl = campaign[field].toString();

        // If it's already a full URL, return it
        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
          return imageUrl;
        }

        // If it's a relative path, prepend base URL
        if (imageUrl.isNotEmpty) {
          // Remove leading slash if present to avoid double slashes
          imageUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
          return '${apiBaseUrl}$imageUrl';
        }
      }
    }

    return null;
  }

  // UPDATED: Simplified image widget builder
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
          return _buildImagePlaceholder(width, height, true);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImagePlaceholder(width, height, false, loadingProgress: loadingProgress);
        },
      );
    }

    return _buildImagePlaceholder(width, height, false);
  }

  Widget _buildImagePlaceholder(double? width, double? height, bool isError, {ImageChunkEvent? loadingProgress}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: isError
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 32),
            const SizedBox(height: 4),
            Text('Failed to load', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        )
            : loadingProgress != null
            ? CircularProgressIndicator(
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null,
          strokeWidth: 2,
        )
            : Icon(Icons.image_outlined, color: Colors.grey[400], size: 32),
      ),
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
        // Get updated campaign from response
        final updatedCampaign = Map<String, dynamic>.from(response['campaign'] as Map);
        campaigns[index] = updatedCampaign;
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
    print('Refreshing campaigns...');
    _currentPage = 0;
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