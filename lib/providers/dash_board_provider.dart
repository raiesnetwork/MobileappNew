import 'package:flutter/material.dart';

import '../services/dash_board_service.dart';


class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();

  bool _isLoading = false;
  String? _error;

  // Student Dashboard Data
  Map<String, dynamic> _studentDashboardData = {};
  Map<String, dynamic> _studentJourneyData = {};
  Map<String, dynamic> _studentProfileData = {};

  // HOD Dashboard Data
  Map<String, dynamic> _hodDashboardData = {};

  // Admin Dashboard Data
  Map<String, dynamic> _adminDashboardData = {};
  Map<String, dynamic> _leakageAnalysisData = {};

  // Placement Cell Dashboard Data
  Map<String, dynamic> _placementCellData = {};
  List<dynamic> _careerRoles = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic> get studentDashboardData => _studentDashboardData;
  Map<String, dynamic> get studentJourneyData => _studentJourneyData;
  Map<String, dynamic> get studentProfileData => _studentProfileData;

  Map<String, dynamic> get hodDashboardData => _hodDashboardData;

  Map<String, dynamic> get adminDashboardData => _adminDashboardData;
  Map<String, dynamic> get leakageAnalysisData => _leakageAnalysisData;

  Map<String, dynamic> get placementCellData => _placementCellData;
  List<dynamic> get careerRoles => _careerRoles;

  // ==================== STUDENT DASHBOARD METHODS ====================

  /// Fetch Student Dashboard Data
  Future<void> fetchStudentDashboard({String? communityId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getStudentDashboard(
        communityId: communityId,
      );

      if (result['error'] == false) {
        _studentDashboardData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _studentDashboardData = {};
      }
    } catch (e) {
      _error = 'Error fetching student dashboard: ${e.toString()}';
      _studentDashboardData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Student Journey
  Future<void> fetchStudentJourney(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getStudentJourney(communityId);

      if (result['error'] == false) {
        _studentJourneyData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _studentJourneyData = {};
      }
    } catch (e) {
      _error = 'Error fetching student journey: ${e.toString()}';
      _studentJourneyData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update Welcome Note Status
  Future<Map<String, dynamic>> updateWelcomeNote(String communityId) async {
    try {
      final result = await _dashboardService.updateWelcomeNoteStatus(communityId);

      if (result['error'] == false) {
        // Update local journey data if needed
        if (_studentJourneyData.isNotEmpty) {
          _studentJourneyData['welcomeScreenShow'] = false;
          notifyListeners();
        }
      }

      return result;
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating welcome note: ${e.toString()}',
        'success': false
      };
    }
  }

  /// Fetch Student Profile
  Future<void> fetchStudentProfile({
    required String communityId,
    required String userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getStudentProfile(
        communityId: communityId,
        userId: userId,
      );

      if (result['error'] == false) {
        _studentProfileData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _studentProfileData = {};
      }
    } catch (e) {
      _error = 'Error fetching student profile: ${e.toString()}';
      _studentProfileData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update Student Profile
  Future<Map<String, dynamic>> updateStudentProfile({
    required String communityId,
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.updateStudentProfile(
        communityId: communityId,
        userId: userId,
        profileData: profileData,
      );

      if (result['error'] == false) {
        _studentProfileData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
      }

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Error updating student profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      return {
        'error': true,
        'message': _error,
        'data': null
      };
    }
  }

  // ==================== HOD DASHBOARD METHODS ====================

  /// Fetch HOD Dashboard Data
  Future<void> fetchHODDashboard({String? communityId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getHODDashboard(
        communityId: communityId,
      );

      if (result['error'] == false) {
        _hodDashboardData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _hodDashboardData = {};
      }
    } catch (e) {
      _error = 'Error fetching HOD dashboard: ${e.toString()}';
      _hodDashboardData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== ADMIN DASHBOARD METHODS ====================

  /// Fetch Admin Dashboard Data
  Future<void> fetchAdminDashboard({required String communityId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getAdminDashboard(
        communityId: communityId,
      );

      if (result['error'] == false) {
        _adminDashboardData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _adminDashboardData = {};
      }
    } catch (e) {
      _error = 'Error fetching admin dashboard: ${e.toString()}';
      _adminDashboardData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Leakage Analysis Data
  Future<void> fetchLeakageAnalysis({required String communityId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getLeakageAnalysis(
        communityId: communityId,
      );

      if (result['error'] == false) {
        _leakageAnalysisData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _leakageAnalysisData = {};
      }
    } catch (e) {
      _error = 'Error fetching leakage analysis: ${e.toString()}';
      _leakageAnalysisData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== PLACEMENT CELL METHODS ====================

  /// Fetch Placement Cell Dashboard Data
  Future<void> fetchPlacementCellDashboard(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getPlacementCellDashboard(communityId);

      if (result['error'] == false) {
        _placementCellData = result['data'] ?? {};
        _error = null;
      } else {
        _error = result['message'];
        _placementCellData = {};
      }
    } catch (e) {
      _error = 'Error fetching placement cell dashboard: ${e.toString()}';
      _placementCellData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Career Roles
  Future<void> fetchCareerRoles(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.getCareerRoles(communityId);

      if (result['error'] == false) {
        _careerRoles = result['carrierRole'] ?? [];
        _error = null;
      } else {
        _error = result['message'];
        _careerRoles = [];
      }
    } catch (e) {
      _error = 'Error fetching career roles: ${e.toString()}';
      _careerRoles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply for Job
  Future<Map<String, dynamic>> applyForJob({
    required String jobId,
    required String fullName,
    required String email,
    required String phone,
    required String resumeFilePath,
    String? coverLetter,
    String? portfolioUrl,
    String? linkedinUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.applyForJob(
        jobId: jobId,
        fullName: fullName,
        email: email,
        phone: phone,
        resumeFilePath: resumeFilePath,
        coverLetter: coverLetter,
        portfolioUrl: portfolioUrl,
        linkedinUrl: linkedinUrl,
      );

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Error applying for job: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      return {
        'error': true,
        'message': _error,
        'data': null
      };
    }
  }

  /// Send Interview Invitation
  Future<Map<String, dynamic>> sendInterviewInvitation({
    required String userId,
    required String communityId,
    required String interviewStatus,
    required String mail,
    required String emailSubject,
    required String emailMessageHtml,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.sendInterviewInvitation(
        userId: userId,
        communityId: communityId,
        interviewStatus: interviewStatus,
        mail: mail,
        emailSubject: emailSubject,
        emailMessageHtml: emailMessageHtml,
      );

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Error sending interview invitation: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      return {
        'error': true,
        'message': _error,
        'success': false
      };
    }
  }

  /// Send Service Inquiry
  Future<Map<String, dynamic>> sendServiceInquiry({
    required String communityId,
    required String subject,
    required String content,
    required List<String> userServices,
    required List<String> recipients,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dashboardService.sendServiceInquiry(
        communityId: communityId,
        subject: subject,
        content: content,
        userServices: userServices,
        recipients: recipients,
      );

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Error sending service inquiry: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      return {
        'error': true,
        'message': _error,
        'data': false
      };
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear all dashboard data
  void clearAllData() {
    _studentDashboardData = {};
    _studentJourneyData = {};
    _studentProfileData = {};
    _hodDashboardData = {};
    _adminDashboardData = {};
    _leakageAnalysisData = {};
    _placementCellData = {};
    _careerRoles = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}