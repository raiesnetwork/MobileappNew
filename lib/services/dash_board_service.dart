import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {

  Future<Map<String, dynamic>> getStudentDashboard({String? communityId}) async {
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


      String url = '${apiBaseUrl}api/cms-dashboard/student';
      if (communityId != null && communityId.isNotEmpty) {
        url += '?communityId=$communityId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getStudentDashboard - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Student dashboard data fetched successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch student dashboard',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getStudentDashboard: $e');
      return {
        'error': true,
        'message': 'Error fetching student dashboard: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 5.1 Get Student Journey
  /// GET /api/communities/student/journey/:communityId
  /// Retrieves student profile and journey information for the authenticated user.
  Future<Map<String, dynamic>> getStudentJourney(String communityId) async {
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
        Uri.parse('${apiBaseUrl}api/communities/student/journey/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getStudentJourney - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Student journey fetched successfully',
          'data': decoded['data']
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch student journey',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getStudentJourney: $e');
      return {
        'error': true,
        'message': 'Error fetching student journey: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 5.1.1 Update Welcome Note Status
  /// PUT /api/communities/student/journey-welcomenote/:communityId
  /// Marks the welcome screen as viewed (sets welcomeScreenShow to false).
  Future<Map<String, dynamic>> updateWelcomeNoteStatus(String communityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'success': false
        };
      }

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/communities/student/journey-welcomenote/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('updateWelcomeNoteStatus - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Welcome note status updated successfully',
          'success': decoded['success'] ?? true
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update welcome note status',
          'success': false
        };
      }
    } catch (e) {
      print('Error in updateWelcomeNoteStatus: $e');
      return {
        'error': true,
        'message': 'Error updating welcome note status: ${e.toString()}',
        'success': false
      };
    }
  }

  /// 5.6.1 Get Student Profile
  /// GET /api/communities/student-profile/:communityId/:userId
  /// Retrieves comprehensive student profile including personal info,
  /// academic details, projects, internships, and certifications.
  Future<Map<String, dynamic>> getStudentProfile({
    required String communityId,
    required String userId,
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

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/student-profile/$communityId/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getStudentProfile - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Student profile fetched successfully',
          'data': decoded['data']
        };
      } else if (response.statusCode == 404) {
        return {
          'error': true,
          'message': 'Student community data not found',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch student profile',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getStudentProfile: $e');
      return {
        'error': true,
        'message': 'Error fetching student profile: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 5.6.2 Update Student Profile
  /// PUT /api/communities/student-profile/:communityId/:userId
  /// Updates student profile information. Only specified fields will be updated.
  Future<Map<String, dynamic>> updateStudentProfile({
    required String communityId,
    required String userId,
    Map<String, dynamic>? profileData,
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

      if (profileData == null || profileData.isEmpty) {
        return {
          'error': true,
          'message': 'No valid fields provided for update',
          'data': null
        };
      }

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/communities/student-profile/$communityId/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(profileData),
      );

      print('updateStudentProfile - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Student profile updated successfully',
          'data': decoded['data']
        };
      } else if (response.statusCode == 400) {
        return {
          'error': true,
          'message': 'No valid fields provided for update',
          'data': null
        };
      } else if (response.statusCode == 404) {
        return {
          'error': true,
          'message': 'Student community data not found',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update student profile',
          'data': null
        };
      }
    } catch (e) {
      print('Error in updateStudentProfile: $e');
      return {
        'error': true,
        'message': 'Error updating student profile: ${e.toString()}',
        'data': null
      };
    }
  }

  // ==================== HOD DASHBOARD APIS ====================

  /// 4.2 HOD Dashboard
  /// GET /api/cms-dashboard/hod
  /// Retrieves dashboard data for Heads of Department including mentor assignments,
  /// total student count, and mandatory actions.
  Future<Map<String, dynamic>> getHODDashboard({String? communityId}) async {
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

      // Build URL with optional communityId query parameter
      String url = '${apiBaseUrl}api/cms-dashboard/hod';
      if (communityId != null && communityId.isNotEmpty) {
        url += '?communityId=$communityId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getHODDashboard - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'HOD dashboard data fetched successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch HOD dashboard',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getHODDashboard: $e');
      return {
        'error': true,
        'message': 'Error fetching HOD dashboard: ${e.toString()}',
        'data': null
      };
    }
  }

  // ==================== ADMIN DASHBOARD APIS ====================

  /// 4.3 Admin Dashboard
  /// GET /api/cms-dashboard/admin
  /// Comprehensive dashboard for administrators showing revenue metrics,
  /// member statistics, campaign performance, and growth trends.
  Future<Map<String, dynamic>> getAdminDashboard({required String communityId}) async {
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
        Uri.parse('${apiBaseUrl}api/cms-dashboard/admin?communityId=$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getAdminDashboard - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Admin dashboard data fetched successfully',
          'data': decoded
        };
      } else if (response.statusCode == 400) {
        return {
          'error': true,
          'message': 'Community ID is required and must be a valid ObjectId',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch admin dashboard',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getAdminDashboard: $e');
      return {
        'error': true,
        'message': 'Error fetching admin dashboard: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 4.4 Activation, Leakage & Quadrant Analysis
  /// GET /api/cms-dashboard/admin/leakage
  /// Advanced analytics endpoint providing activation rate, revenue leakage analysis,
  /// weekly trends, and revenue quadrant breakdown.
  Future<Map<String, dynamic>> getLeakageAnalysis({required String communityId}) async {
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
        Uri.parse('${apiBaseUrl}api/cms-dashboard/admin/leakage?communityId=$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getLeakageAnalysis - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Leakage analysis data fetched successfully',
          'data': decoded
        };
      } else if (response.statusCode == 400) {
        return {
          'error': true,
          'message': 'Community ID is required',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch leakage analysis',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getLeakageAnalysis: $e');
      return {
        'error': true,
        'message': 'Error fetching leakage analysis: ${e.toString()}',
        'data': null
      };
    }
  }

  // ==================== PLACEMENT CELL DASHBOARD APIS ====================

  /// 5.2 Placement Cell Dashboard
  /// GET /api/communities/placementCell/:communityId
  /// Comprehensive placement cell dashboard showing students, employers,
  /// positions, and hiring funnel data.
  Future<Map<String, dynamic>> getPlacementCellDashboard(String communityId) async {
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
        Uri.parse('${apiBaseUrl}api/communities/placementCell/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getPlacementCellDashboard - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Placement cell dashboard data fetched successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch placement cell dashboard',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getPlacementCellDashboard: $e');
      return {
        'error': true,
        'message': 'Error fetching placement cell dashboard: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 5.3 Get Career Roles
  /// GET /api/communities/carrier-roles/:communityId
  /// Fetches available career tracks from assessments.
  /// Used while creating a service under Educational Service category.
  Future<Map<String, dynamic>> getCareerRoles(String communityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'carrierRole': []
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/communities/carrier-roles/$communityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getCareerRoles - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Career roles fetched successfully',
          'carrierRole': decoded['carrierRole'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch career roles',
          'carrierRole': []
        };
      }
    } catch (e) {
      print('Error in getCareerRoles: $e');
      return {
        'error': true,
        'message': 'Error fetching career roles: ${e.toString()}',
        'carrierRole': []
      };
    }
  }

  /// 5.4 Apply for Job
  /// POST /api/communities/student/job-apply
  /// Submit job application with resume upload. Sends confirmation email to applicant.
  /// Used in the Announcement section when a job poster is available.
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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${apiBaseUrl}api/communities/student/job-apply'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['jobId'] = jobId;
      request.fields['fullName'] = fullName;
      request.fields['email'] = email;
      request.fields['phone'] = phone;

      if (coverLetter != null && coverLetter.isNotEmpty) {
        request.fields['coverLetter'] = coverLetter;
      }
      if (portfolioUrl != null && portfolioUrl.isNotEmpty) {
        request.fields['portfolioUrl'] = portfolioUrl;
      }
      if (linkedinUrl != null && linkedinUrl.isNotEmpty) {
        request.fields['linkedinUrl'] = linkedinUrl;
      }

      // Add resume file
      var resumeFile = await http.MultipartFile.fromPath(
        'resumeFile',
        resumeFilePath,
      );
      request.files.add(resumeFile);

      print('Applying for job - JobId: $jobId');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('applyForJob - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Job applied successfully',
          'data': decoded['data']
        };
      } else if (response.statusCode == 400) {
        return {
          'error': true,
          'message': 'Resume file is required',
          'data': null
        };
      } else if (response.statusCode == 404) {
        return {
          'error': true,
          'message': 'Job not found',
          'data': null
        };
      } else if (response.statusCode == 409) {
        return {
          'error': true,
          'message': 'You have already applied for this job',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to apply for job',
          'data': null
        };
      }
    } catch (e) {
      print('Error in applyForJob: $e');
      return {
        'error': true,
        'message': 'Error applying for job: ${e.toString()}',
        'data': null
      };
    }
  }

  /// 5.5 Send Interview Invitation
  /// POST /api/communities/send-interview-invitation-mail
  /// Send interview invitation email and update student profile with interview details.
  Future<Map<String, dynamic>> sendInterviewInvitation({
    required String userId,
    required String communityId,
    required String interviewStatus,
    required String mail,
    required String emailSubject,
    required String emailMessageHtml,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'success': false
        };
      }

      final body = {
        'userId': userId,
        'communityId': communityId,
        'interviewStatus': interviewStatus,
        'interviewData': {
          'mail': mail,
          'emailSubject': emailSubject,
          'emailMessageHtml': emailMessageHtml,
        }
      };

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/communities/send-interview-invitation-mail'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('sendInterviewInvitation - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Invitation sent successfully',
          'success': true
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send interview invitation',
          'success': false
        };
      }
    } catch (e) {
      print('Error in sendInterviewInvitation: $e');
      return {
        'error': true,
        'message': 'Error sending interview invitation: ${e.toString()}',
        'success': false
      };
    }
  }

  /// 5.7 Send Service Inquiry Email
  /// POST /api/communities/send-service-inquiry
  /// Send service inquiry emails to multiple recipients.
  /// Used in Community Member section to send inquiry about services.
  Future<Map<String, dynamic>> sendServiceInquiry({
    required String communityId,
    required String subject,
    required String content,
    required List<String> userServices,
    required List<String> recipients,
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

      final body = {
        'communityId': communityId,
        'emailData': {
          'subject': subject,
          'content': content,
          'userServices': userServices,
          'recipients': recipients,
        }
      };

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/communities/send-service-inquiry'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('sendServiceInquiry - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Successfully sent inquiry emails',
          'data': decoded['data'] ?? true,
          'details': decoded['details']
        };
      } else if (response.statusCode == 207) {
        // Partial success
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Partially sent inquiry emails',
          'data': decoded['data'] ?? false,
          'details': decoded['details']
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send service inquiry',
          'data': false
        };
      }
    } catch (e) {
      print('Error in sendServiceInquiry: $e');
      return {
        'error': true,
        'message': 'Error sending service inquiry: ${e.toString()}',
        'data': false
      };
    }
  }
}