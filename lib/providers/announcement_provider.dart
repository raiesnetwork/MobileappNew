import 'package:flutter/material.dart';
import 'package:ixes.app/services/announcement_service.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementService _announcementService = AnnouncementService();
  List<dynamic> _announcements = [];
  String? _errorMessage;
  bool _isLoading = false;

  List<dynamic> get announcements => _announcements;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  // Fetch all announcements for a community
  Future<Map<String, dynamic>> fetchAnnouncements({
    required String communityId,
    int page = 1,
    int limit = 10,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _announcementService.getAllAnnouncements(
      communityId: communityId,
      page: page,
      limit: limit,
    );

    _isLoading = false;
    if (result['error'] == false) {
      _announcements = result['announcements'] ?? [];
      _errorMessage = null;
    } else {
      _errorMessage = result['message'];
      _announcements = [];
    }
    notifyListeners();
    return result;
  }

  // Create a new announcement
  Future<Map<String, dynamic>> createAnnouncement({
    required String communityId,
    required String description,
    String? templateType,
    String? title,
    String? contactInfo,
    String? endDate,
    String? image,
    String? startDate,
    String? time,
    String? location,
    String? endTime,
    String? company,
    String? experience,
    String? employmentType,
    String? salaryRange,
    String? url,
    String? currency,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _announcementService.createAnnouncement(
      communityId: communityId,
      description: description,
      templateType: templateType,
      title: title,
      contactInfo: contactInfo,
      endDate: endDate,
      image: image,
      startDate: startDate,
      time: time,
      location: location,
      endTime: endTime,
      company: company,
      experience: experience,
      employmentType: employmentType,
      salaryRange: salaryRange,
      url: url,
      currency: currency,
    );

    _isLoading = false;
    if (result['error'] == false) {
      _errorMessage = null;
      // Optionally refresh announcements
      await fetchAnnouncements(communityId: communityId);
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
    return result;
  }

  // Update an existing announcement
  Future<Map<String, dynamic>> updateAnnouncement({
    required String id,
    required String communityId,
    String? templateType,
    String? title,
    String? contactInfo,
    String? endDate,
    String? image,
    String? startDate,
    String? time,
    String? description,
    String? location,
    String? endTime,
    String? company,
    String? experience,
    String? employmentType,
    String? salaryRange,
    String? url,
    String? currency,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _announcementService.updateAnnouncement(
      id: id,
      communityId: communityId,
      description: description,
      templateType: templateType,
      title: title,
      contactInfo: contactInfo,
      endDate: endDate,
      image: image,
      startDate: startDate,
      time: time,
      location: location,
      endTime: endTime,
      company: company,
      experience: experience,
      employmentType: employmentType,
      salaryRange: salaryRange,
      url: url,
      currency: currency,
    );

    _isLoading = false;
    if (result['error'] == false) {
      _errorMessage = null;
      // Optionally refresh announcements
      await fetchAnnouncements(communityId: communityId);
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
    return result;
  }

  // Delete an announcement
  Future<Map<String, dynamic>> deleteAnnouncement({
    required String id,
    required String communityId,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _announcementService.deleteAnnouncement(id: id);

    _isLoading = false;
    if (result['error'] == false) {
      _errorMessage = null;
      // Refresh announcements after deletion
      await fetchAnnouncements(communityId: communityId);
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
    return result;
  }

  // Reset error message
  void resetError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset announcements
  void resetAnnouncements() {
    _announcements = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
  int _totalCommunities = 0;
  int _totalCampaigns = 0;
  int _totalServices = 0;

  int get totalCommunities => _totalCommunities;
  int get totalCampaigns => _totalCampaigns;
  int get totalServices => _totalServices;
  Future<void> fetchDashboardCounts() async {
    final result = await _announcementService.getDashboardCounts();
    if (result['error'] == false) {
      _totalCommunities = result['totalCommunities'] ?? 0;
      _totalCampaigns = result['totalCampaigns'] ?? 0;
      _totalServices = result['totalServices'] ?? 0;
    } else {
      // You can handle the error message here if needed
      print('Dashboard count fetch error: ${result['message']}');
      _totalCommunities = 0;
      _totalCampaigns = 0;
      _totalServices = 0;
    }
    notifyListeners();
  }

}