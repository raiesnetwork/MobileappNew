import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicesService {
  Future<Map<String, dynamic>> getAllServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final response = await http.get(
        Uri.parse('https://api.ixes.ai/api/service/fetchallservices'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? true,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch services',
          'data': []
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error fetching services: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> getAllCommunityServices({String? communityId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final uri = communityId != null && communityId.isNotEmpty
          ? Uri.parse('${apiBaseUrl}api/service/allservices?communityId=$communityId')
          : Uri.parse('${apiBaseUrl}api/service/allservices');

      print('🔍 Community ID: $communityId');
      print('🌐 Request URI: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // FIXED: Handle different response structures
        List<dynamic> allServices = [];

        // Check if response has services directly
        if (decoded['services'] != null) {
          allServices = decoded['services'];
        } else {
          // Otherwise combine different service types
          final communityServices = decoded['communityServices'] ?? [];
          final userServices = decoded['userServices'] ?? [];
          final memberServices = decoded['memberServices'] ?? [];
          allServices = [...communityServices, ...userServices, ...memberServices];
        }

        print('✅ Combined Services Length: ${allServices.length}');
        print('📋 First service (if any): ${allServices.isNotEmpty ? allServices[0] : 'None'}');

        return {
          'error': false, // FIXED: Ensure error is false on success
          'message': decoded['message'] ?? 'Services fetched successfully',
          'data': allServices
        };
      } else {
        try {
          final decoded = jsonDecode(response.body);
          print('⚠️ Error from API: ${decoded['message']}');
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to fetch services',
            'data': []
          };
        } catch (e) {
          print('⚠️ Failed to decode error response: $e');
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
            'data': []
          };
        }
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> createService({
    required String name,
    required String description,
    required String location,
    String? communityId,
    required String category,
    required String subCategory,
    required String openHourFrom,
    required String openHourEnd,
    required String cost,
    required String slots,
    required String currency,
    required String costPer,
    required String serviceProvider,
    required List<String> availableDays,
    File? image,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('🔑 Token: $token');

      if (token == null || token.isEmpty) {
        print('❌ Token missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/create-service');
      print('📤 API URL: $uri');

      final Map<String, dynamic> bodyData = {
        'name': name,
        'description': description,
        'location': location,
        if (communityId != null && communityId.isNotEmpty)
          'communityId': communityId,
        'mainCategory': category,
        'subCategory': subCategory,
        'openHourFrom': openHourFrom,
        'openHourEnd': openHourEnd,
        'cost': cost,
        'slots': slots,
        'currency': currency,
        'costPer': costPer,
        'serviceProvider': serviceProvider,
        'availableDays': availableDays,
      };

      // 🔧 FIX: Proper image handling
      if (image != null) {
        try {
          print('📸 Processing image: ${image.path}');

          // Check if file exists
          if (!await image.exists()) {
            print('❌ Image file does not exist');
            return {
              'error': true,
              'message': 'Selected image file does not exist',
            };
          }

          // Get file size
          final fileSize = await image.length();
          print('📏 Image file size: ${fileSize} bytes');

          // Check file size (limit to 5MB)
          if (fileSize > 5 * 1024 * 1024) {
            print('❌ Image file too large');
            return {
              'error': true,
              'message':
                  'Image file is too large. Please select an image smaller than 5MB',
            };
          }

          // Read image bytes
          final bytes = await image.readAsBytes();
          print('📦 Image bytes length: ${bytes.length}');

          // Convert to base64
          final base64Image = base64Encode(bytes);
          print(
              '🔄 Base64 conversion successful. Length: ${base64Image.length}');

          // Get file extension
          final extension = image.path.split('.').last.toLowerCase();
          String mimeType;
          switch (extension) {
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'png':
              mimeType = 'image/png';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
            default:
              mimeType = 'image/jpeg'; // Default fallback
          }

          // Add proper data URL format
          bodyData['image'] = 'data:$mimeType;base64,$base64Image';
          print('✅ Image added to body with mime type: $mimeType');
          print('🧾 Image path: ${image.path}');
          print('🧾 Is absolute: ${image.path.startsWith('/')}');
          print('🧾 Exists: ${await image.exists()}');
        } catch (e) {
          print('💥 Image processing error: $e');
          return {
            'error': true,
            'message': 'Failed to process image: ${e.toString()}',
          };
        }
      } else {
        print('⚠️ No image selected');
        // Don't add image field if no image is selected
      }

      print('📤 Sending body data...');
      // Don't log the full body as it might be too large with base64 image
      print('📦 Body keys: ${bodyData.keys.toList()}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 201) {
        print('✅ Service created successfully');

        // Check if image was properly saved
        if (decoded['service'] != null && decoded['service']['image'] != null) {
          final savedImage = decoded['service']['image'];
        }

        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Service created successfully',
          'data': decoded['service'] ?? {},
        };
      } else {
        print('⚠️ Service creation failed');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create service',
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error creating service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> editService({
    required String id,
    String? name,
    String? description,
    List<String>? image,
    String? location,
    String? communityId,
    String? category,
    String? subCategory,
    num? cost,
    num? slots,
    String? currency,
    List<String>? availableDays,
    String? costPer,
    String? openHourFrom,
    String? openHourEnd,
    String? serviceProvider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final body = {
        '_id': id,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
        if (location != null) 'location': location,
        if (communityId != null) 'communityId': communityId,
        if (category != null) 'category': category,
        if (subCategory != null) 'subCategory': subCategory,
        if (cost != null) 'cost': cost,
        if (slots != null) 'slots': slots,
        if (currency != null) 'currency': currency,
        if (availableDays != null) 'availableDays': availableDays,
        if (costPer != null) 'costPer': costPer,
        if (openHourFrom != null) 'openHourFrom': openHourFrom,
        if (openHourEnd != null) 'openHourEnd': openHourEnd,
        if (serviceProvider != null) 'serviceProvider': serviceProvider,
      };

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/service/edit-service'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service updated successfully',
          'service': decoded['service'] ?? {},
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update service',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> deleteService({
    required String serviceId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {'err': true, 'message': 'Authentication token is missing'};
      }

      final response = await http.get(
        Uri.parse(
            '${apiBaseUrl}api/service/deleteService?serviceId=$serviceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service deleted successfully',
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to delete service',
        };
      }
    } catch (e) {
      return {
        'err': true,
        'message': 'Error deleting service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getMyServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'myServices': []
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/myservices');
      print('🔍 Fetching my services from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Success',
          'myServices': decoded['myServices'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch my services',
          'myServices': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching my services: ${e.toString()}',
        'myServices': []
      };
    }
  }
  Future<Map<String, dynamic>> activateService(String serviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'service': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/activateService?serviceId=$serviceId');
      print('🔍 Activating service from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service activated successfully',
          'service': decoded['service'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to activate service',
          'service': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error activating service: ${e.toString()}',
        'service': {}
      };
    }
  }

  Future<Map<String, dynamic>> deactivateService(String serviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'service': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/deactivateService?serviceId=$serviceId');
      print('🔍 Deactivating service from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service deactivated successfully',
          'service': decoded['service'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to deactivate service',
          'service': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error deactivating service: ${e.toString()}',
        'service': {}
      };
    }
  }
  Future<Map<String, dynamic>> getServiceDetails(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/details/$id');
      print('🔍 Fetching service details from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Service details fetched successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch service details',
          'data': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching service details: ${e.toString()}',
        'data': {}
      };
    }
  }
  Future<Map<String, dynamic>> getMyProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': [],
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/myproducts');
      print('🔍 Fetching my products from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Products fetched successfully',
          'data': decoded['myProducts'] ?? [],
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch products',
          'data': [],
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching products: ${e.toString()}',
        'data': [],
      };
    }
  }
}

