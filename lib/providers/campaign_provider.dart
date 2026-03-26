import 'package:flutter/material.dart';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/campaigns_service.dart';

class CampaignProvider with ChangeNotifier {
  final CampaignService _campaignService = CampaignService();

  // All campaigns from server
  List<dynamic> _allCampaigns = [];

  // Displayed campaigns (paginated)
  List<dynamic> campaigns = [];

  bool isLoading = false;
  bool hasMoreCampaigns = true;
  String? errorMessage;
  int _currentPage = 0;
  int _itemsPerPage = 10;
  bool _allDataLoaded = false;

  // ✅ Expose currentPage for screen to use
  int get currentPage => _currentPage;

  // ✅ Silent reset — no notifyListeners, used internally before fetch
  void _resetState() {
    _allCampaigns = [];
    campaigns = [];
    hasMoreCampaigns = true;
    _currentPage = 0;
    _allDataLoaded = false;
    errorMessage = null;
    isLoading = false;
  }

  // ✅ Public clear for logout — notifies listeners to update UI
  void clearCampaigns() {
    _resetState();
    notifyListeners();
  }

  Future<void> fetchAllCampaigns({required int page, int limit = 10}) async {
    _itemsPerPage = limit;

    if (page == 1) {
      await _fetchFromServer();
      _loadPage(1);
      return;
    }

    // ✅ If somehow data isn't loaded yet, fetch first
    if (!_allDataLoaded) {
      await _fetchFromServer();
    }

    _loadPage(page); // ✅ Always runs now
  }

  Future<void> _fetchFromServer() async {
    if (isLoading) {
      print('Already loading, skipping');
      return;
    }

    // ✅ Silently reset state before fetch — no extra notifyListeners
    _resetState();

    isLoading = true;
    errorMessage = null;
    notifyListeners(); // ✅ Only ONE notify for loading state

    print('🔄 Fetching all campaigns from server...');

    final response = await _campaignService.getAllCampaigns(page: 1, limit: 1000);

    if (!response['error']) {
      final fetchedCampaigns = response['campaigns'] as List<dynamic>;

      print('✅ Fetched ${fetchedCampaigns.length} total campaigns from server');

      _allCampaigns = fetchedCampaigns
          .map((campaign) => Map<String, dynamic>.from(campaign as Map))
          .toList();

      _allDataLoaded = true;
      _currentPage = 0;
      campaigns.clear();
    } else {
      errorMessage = response['message'];
      print('❌ Error fetching campaigns: ${response['message']}');
      _allCampaigns.clear();
      campaigns.clear();
      hasMoreCampaigns = false;
    }

    isLoading = false;
    notifyListeners();
  }

  void _loadPage(int page) {
    print('📄 Loading page $page (client-side)');

    final startIndex = (page - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _allCampaigns.length) {
      print('⚠️ No more campaigns to load');
      hasMoreCampaigns = false;
      notifyListeners();
      return;
    }

    final actualEndIndex = endIndex > _allCampaigns.length
        ? _allCampaigns.length
        : endIndex;

    if (page == 1) {
      campaigns = _allCampaigns.sublist(startIndex, actualEndIndex);
      print('🔄 Loaded first page: ${campaigns.length} campaigns');
    } else {
      final newCampaigns = _allCampaigns.sublist(startIndex, actualEndIndex);
      campaigns.addAll(newCampaigns);
      print('➕ Added ${newCampaigns.length} campaigns (total: ${campaigns.length})');
    }

    _currentPage = page;
    hasMoreCampaigns = actualEndIndex < _allCampaigns.length;

    final totalPages = (_allCampaigns.length / _itemsPerPage).ceil();
    print('📊 Page $_currentPage/$totalPages');
    print('📈 Showing ${campaigns.length}/${_allCampaigns.length} campaigns');
    print('🔜 Has more: $hasMoreCampaigns');

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

        _allCampaigns.insert(0, typedCampaign);
        campaigns.insert(0, typedCampaign);

        print('Campaign created and added. Total: ${_allCampaigns.length}');
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

  String? getCampaignImageUrl(Map<String, dynamic> campaign) {
    final imageFields = ['coverImage', 'coverImageUrl', 'image'];

    for (final field in imageFields) {
      if (campaign[field] != null && campaign[field].toString().isNotEmpty) {
        String imageUrl = campaign[field].toString().trim();
        String originalUrl = imageUrl;

        if (imageUrl.startsWith('http://') ||
            imageUrl.startsWith('https://') ||
            imageUrl.contains('amazonaws.com') ||
            imageUrl.contains('cloudfront.net')) {
          print('🌐 Using full URL: $imageUrl');
          return imageUrl;
        }

        if (imageUrl.isNotEmpty) {
          imageUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
          final finalUrl = '${apiBaseUrl}$imageUrl';
          print('🔗 Converted "$originalUrl" → "$finalUrl"');
          return finalUrl;
        }
      }
    }

    print('⚠️ No image URL found for campaign: ${campaign['_id']}');
    return null;
  }

  Widget buildCampaignImage(
      Map<String, dynamic> campaign, {
        double? width,
        double? height,
        BoxFit fit = BoxFit.cover,
      }) {
    final imageUrl = getCampaignImageUrl(campaign);

    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildImagePlaceholder(
          width,
          height,
          false,
          isLoading: true,
        ),
        errorWidget: (context, url, error) {
          print('❌ Error loading image: $url, Error: $error');
          return _buildImagePlaceholder(width, height, true);
        },
      );
    }

    return _buildImagePlaceholder(width, height, false);
  }

  Widget _buildImagePlaceholder(
      double? width,
      double? height,
      bool isError, {
        bool isLoading = false,
      }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isError
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                color: Colors.grey[400], size: 32),
            const SizedBox(height: 4),
            Text(
              'Image unavailable',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            : isLoading
            ? CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
        )
            : Icon(
          Icons.campaign_outlined,
          color: Colors.grey[400],
          size: 32,
        ),
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
      final updatedCampaign =
      Map<String, dynamic>.from(response['campaign'] as Map);

      final allIndex = _allCampaigns.indexWhere((c) => c['_id'] == campaignId);
      if (allIndex != -1) {
        _allCampaigns[allIndex] = updatedCampaign;
      }

      final displayIndex = campaigns.indexWhere((c) => c['_id'] == campaignId);
      if (displayIndex != -1) {
        campaigns[displayIndex] = updatedCampaign;
      }

      print('Campaign updated in lists');
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
      _allCampaigns.removeWhere((c) => c['_id'] == campaignId);
      campaigns.removeWhere((c) => c['_id'] == campaignId);
      print('Campaign $campaignId removed from lists');

      hasMoreCampaigns = campaigns.length < _allCampaigns.length;
    } else {
      errorMessage = response['message'];
    }

    isLoading = false;
    notifyListeners();
    return response;
  }

  Future<void> refreshCampaigns() async {
    print('🔄 Refreshing campaigns...');
    await fetchAllCampaigns(page: 1);
  }

  String getPaginationInfo() {
    final totalPages = (_allCampaigns.length / _itemsPerPage).ceil();
    return 'Page $_currentPage of $totalPages (${campaigns.length}/${_allCampaigns.length} campaigns)';
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