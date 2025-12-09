import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();

  // Profile data
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _events = [];

  // Loading states
  bool _isLoadingProfile = false;
  bool _isLoadingDashboard = false;
  bool _isLoadingEvents = false;
  bool _isUpdatingProfile = false;
  bool _isCreatingEvent = false;

  // Error messages
  String? _profileError;
  String? _dashboardError;
  String? _eventsError;
  String? _updateProfileError;
  String? _createEventError;

  // Getters
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

  // Get User Profile
  Future<bool> getUserProfile() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final result = await _profileService.getUserProfile();

      if (!result['error']) {
        _userProfile = result['data'];
        _profileError = null;
        _isLoadingProfile = false;
        notifyListeners();
        return true;
      } else {
        _profileError = result['message'];
        _isLoadingProfile = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _profileError = 'Error fetching profile: ${e.toString()}';
      _isLoadingProfile = false;
      notifyListeners();
      return false;
    }
  }

  // Get Dashboard Data
  Future<bool> getDashboardData() async {
    _isLoadingDashboard = true;
    _dashboardError = null;
    notifyListeners();

    try {
      final result = await _profileService.getDashboardData();

      if (!result['error']) {
        _dashboardData = result['data'];
        _dashboardError = null;
        _isLoadingDashboard = false;
        notifyListeners();
        return true;
      } else {
        _dashboardError = result['message'];
        _isLoadingDashboard = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _dashboardError = 'Error fetching dashboard data: ${e.toString()}';
      _isLoadingDashboard = false;
      notifyListeners();
      return false;
    }
  }

  // Update User Profile
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    _isUpdatingProfile = true;
    _updateProfileError = null;
    notifyListeners();

    try {
      final result = await _profileService.updateUserProfile(profileData);

      if (!result['error']) {
        _userProfile = result['data'];
        _updateProfileError = null;
        _isUpdatingProfile = false;
        notifyListeners();
        return true;
      } else {
        _updateProfileError = result['message'];
        _isUpdatingProfile = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _updateProfileError = 'Error updating profile: ${e.toString()}';
      _isUpdatingProfile = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch Events
  Future<bool> fetchEvents() async {
    _isLoadingEvents = true;
    _eventsError = null;
    notifyListeners();

    try {
      final result = await _profileService.fetchEvents();

      if (!result['error']) {
        _events = result['events'];
        _eventsError = null;
        _isLoadingEvents = false;
        notifyListeners();
        return true;
      } else {
        _eventsError = result['message'];
        _isLoadingEvents = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _eventsError = 'Error fetching events: ${e.toString()}';
      _isLoadingEvents = false;
      notifyListeners();
      return false;
    }
  }

  // Create Event
  Future<bool> createEvent(Map<String, dynamic> eventData) async {
    _isCreatingEvent = true;
    _createEventError = null;
    notifyListeners();

    try {
      final result = await _profileService.createEvent(eventData);

      if (!result['error']) {
        // Add the new event to the list
        if (result['event'] != null) {
          _events.add(result['event']);
        }
        _createEventError = null;
        _isCreatingEvent = false;
        notifyListeners();
        return true;
      } else {
        _createEventError = result['message'];
        _isCreatingEvent = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _createEventError = 'Error creating event: ${e.toString()}';
      _isCreatingEvent = false;
      notifyListeners();
      return false;
    }
  }

  // Clear specific errors
  void clearProfileError() {
    _profileError = null;
    notifyListeners();
  }

  void clearDashboardError() {
    _dashboardError = null;
    notifyListeners();
  }

  void clearEventsError() {
    _eventsError = null;
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

  // Clear all data (useful for logout)
  void clearAllData() {
    _userProfile = null;
    _dashboardData = null;
    _events = [];
    _profileError = null;
    _dashboardError = null;
    _eventsError = null;
    _updateProfileError = null;
    _createEventError = null;
    _isLoadingProfile = false;
    _isLoadingDashboard = false;
    _isLoadingEvents = false;
    _isUpdatingProfile = false;
    _isCreatingEvent = false;
    notifyListeners();
  }

}