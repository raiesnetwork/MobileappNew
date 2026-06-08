// ─────────────────────────────────────────────────────────────────────────────
// ProfileProvider
// FIX: Call clearAllData() on logout BEFORE navigating away so the next
//      account never sees the previous user's profile for even a single frame.
//
// Usage in your logout flow:
//   context.read<ProfileProvider>().clearAllData();
//   // then navigate to login
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _events = [];

  bool _isLoadingProfile = false;
  bool _isLoadingDashboard = false;
  bool _isLoadingEvents = false;
  bool _isUpdatingProfile = false;
  bool _isCreatingEvent = false;

  String? _profileError;
  String? _dashboardError;
  String? _eventsError;
  String? _updateProfileError;
  String? _createEventError;

  Map<String, dynamic>? get userProfile => _userProfile;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<dynamic> get events => _events;

  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isCreatingEvent => _isCreatingEvent;

  String? get profileError => _profileError;
  String? get dashboardError => _dashboardError;
  String? get eventsError => _eventsError;
  String? get updateProfileError => _updateProfileError;
  String? get createEventError => _createEventError;

  Future<bool> getUserProfile() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      final result = await _profileService.getUserProfile();
      if (!result['error']) {
        _userProfile = result['data'];
        _profileError = null;
      } else {
        _profileError = result['message'];
      }
    } catch (e) {
      _profileError = 'Error fetching profile: $e';
    }
    _isLoadingProfile = false;
    notifyListeners();
    return _profileError == null;
  }

  Future<bool> getDashboardData() async {
    _isLoadingDashboard = true;
    _dashboardError = null;
    notifyListeners();
    try {
      final result = await _profileService.getDashboardData();
      if (!result['error']) {
        _dashboardData = result['data'];
        _dashboardError = null;
      } else {
        _dashboardError = result['message'];
      }
    } catch (e) {
      _dashboardError = 'Error fetching dashboard: $e';
    }
    _isLoadingDashboard = false;
    notifyListeners();
    return _dashboardError == null;
  }

  // ─── UPDATE PROFILE WITH MULTIPART UPLOAD ─────────────────────────────────
  Future<bool> updateUserProfile(
      Map<String, dynamic> profileData, {
        String? profileImagePath,
      }) async {
    _isUpdatingProfile = true;
    _updateProfileError = null;
    notifyListeners();

    try {
      print('📤 [PROFILE] Starting profile update...');

      final result = await _profileService.updateUserProfile(
        profileData,
        profileImagePath: profileImagePath,
      );

      if (!result['error']) {
        print('✅ [PROFILE] Update successful, refreshing profile...');
        await getUserProfile();
        _updateProfileError = null;
        _isUpdatingProfile = false;
        notifyListeners();
        return true;
      } else {
        final errorMsg = result['message'] as String?;
        if (errorMsg?.contains('401') == true ||
            errorMsg?.contains('Unauthorized') == true) {
          _updateProfileError = 'Session expired. Please log in again.';
        } else if (errorMsg?.contains('timeout') == true ||
            errorMsg?.contains('TimeoutException') == true) {
          _updateProfileError = 'Upload timed out. Please try again.';
        } else {
          _updateProfileError = errorMsg ?? 'Failed to update profile';
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup')) {
        _updateProfileError = 'No internet connection. Please try again.';
      } else if (errorStr.contains('TimeoutException')) {
        _updateProfileError = 'Upload timed out. Please try again.';
      } else {
        _updateProfileError = 'Error updating profile: $e';
      }
    }

    _isUpdatingProfile = false;
    notifyListeners();
    return false;
  }

  Future<bool> fetchEvents() async {
    _isLoadingEvents = true;
    _eventsError = null;
    notifyListeners();
    try {
      final result = await _profileService.fetchEvents();
      if (!result['error']) {
        _events = result['events'];
        _eventsError = null;
      } else {
        _eventsError = result['message'];
      }
    } catch (e) {
      _eventsError = 'Error fetching events: $e';
    }
    _isLoadingEvents = false;
    notifyListeners();
    return _eventsError == null;
  }

  Future<bool> createEvent(Map<String, dynamic> eventData) async {
    _isCreatingEvent = true;
    _createEventError = null;
    notifyListeners();
    try {
      final result = await _profileService.createEvent(eventData);
      if (!result['event'] == null) {
        if (result['event'] != null) _events.add(result['event']);
        _createEventError = null;
        _isCreatingEvent = false;
        notifyListeners();
        return true;
      } else {
        _createEventError = result['message'];
      }
    } catch (e) {
      _createEventError = 'Error creating event: $e';
    }
    _isCreatingEvent = false;
    notifyListeners();
    return false;
  }

  void clearProfileError() {
    _profileError = null;
    notifyListeners();
  }

  void clearUpdateProfileError() {
    _updateProfileError = null;
    notifyListeners();
  }

  void clearCreateEventError() {
    _createEventError = null;
    notifyListeners();
  }

  // ── FIX: Call this BEFORE navigating to login on logout ───────────────────
  // This ensures _userProfile is null when the next account's profile screen
  // opens, so there is zero chance of the previous user's data flashing.
  void clearAllData() {
    _userProfile = null;
    _dashboardData = null;
    _events = [];
    _profileError = _dashboardError = _eventsError =
        _updateProfileError = _createEventError = null;
    _isLoadingProfile = _isLoadingDashboard = _isLoadingEvents =
        _isUpdatingProfile = _isCreatingEvent = false;
    notifyListeners(); // UI rebuilds immediately with null data before navigation
  }
}