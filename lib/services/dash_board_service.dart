import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {

  Future<Map<String, dynamic>> getStudentDashboard({String? communityId}) async {
    try {
      final query = (communityId != null && communityId.isNotEmpty)
          ? '?communityId=$communityId'
          : '';

      final response = await ApiService.get('/api/cms-dashboard/student$query');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getStudentJourney(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/student/journey/$communityId');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> updateWelcomeNoteStatus(String communityId) async {
    try {
      final response = await ApiService.put(
          '/api/communities/student/journey-welcomenote/$communityId', {});
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getStudentProfile({
    required String communityId,
    required String userId,
  }) async {
    try {
      final response = await ApiService.get(
          '/api/communities/student-profile/$communityId/$userId');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> updateStudentProfile({
    required String communityId,
    required String userId,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      if (profileData == null || profileData.isEmpty) {
        return {
          'error': true,
          'message': 'No valid fields provided for update',
          'data': null
        };
      }

      final response = await ApiService.put(
          '/api/communities/student-profile/$communityId/$userId', profileData);
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getHODDashboard({String? communityId}) async {
    try {
      final query = (communityId != null && communityId.isNotEmpty)
          ? '?communityId=$communityId'
          : '';

      final response = await ApiService.get('/api/cms-dashboard/hod$query');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getAdminDashboard({required String communityId}) async {
    try {
      final response = await ApiService.get(
          '/api/cms-dashboard/admin?communityId=$communityId');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getLeakageAnalysis({required String communityId}) async {
    try {
      final response = await ApiService.get(
          '/api/cms-dashboard/admin/leakage?communityId=$communityId');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getPlacementCellDashboard(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/placementCell/$communityId');
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> getCareerRoles(String communityId) async {
    try {
      final response = await ApiService.get(
          '/api/communities/carrier-roles/$communityId');
      ApiService.checkResponse(response);

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

      request.headers['Authorization'] = 'Bearer $token';
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

      request.files.add(await http.MultipartFile.fromPath(
          'resumeFile', resumeFilePath));

      print('Applying for job - JobId: $jobId');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      ApiService.checkResponse(response); // ✅ 401 check

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
        return {'error': true, 'message': 'Resume file is required', 'data': null};
      } else if (response.statusCode == 404) {
        return {'error': true, 'message': 'Job not found', 'data': null};
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

  Future<Map<String, dynamic>> sendInterviewInvitation({
    required String userId,
    required String communityId,
    required String interviewStatus,
    required String mail,
    required String emailSubject,
    required String emailMessageHtml,
  }) async {
    try {
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

      final response = await ApiService.post(
          '/api/communities/send-interview-invitation-mail', body);
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> sendServiceInquiry({
    required String communityId,
    required String subject,
    required String content,
    required List<String> userServices,
    required List<String> recipients,
  }) async {
    try {
      final body = {
        'communityId': communityId,
        'emailData': {
          'subject': subject,
          'content': content,
          'userServices': userServices,
          'recipients': recipients,
        }
      };

      final response = await ApiService.post(
          '/api/communities/send-service-inquiry', body);
      ApiService.checkResponse(response);

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