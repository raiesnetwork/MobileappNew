// Keep your existing constants
const String apiBaseUrl = 'https://api.ixes.ai/';  // ✅ Keep trailing slash
const String SIGNUP = 'api/auth/signup';
const String GETALLPOST = 'api/mobile/posts';
const String GETALLNOTIFICATIONS = 'api/notifications';
const String SOCKET_URL = 'https://api.ixes.ai/fileUrl';
const String socketBaseUrl = "wss://api.ixes.ai";

/// Helper function to construct full URL from relative path
/// Handles both media files (which come with leading /) and API endpoints
String constructFullUrl(String? path) {
  if (path == null || path.isEmpty) {
    print('⚠️ constructFullUrl: Empty path provided');
    return '';
  }

  // If already a full URL, return as is
  if (path.startsWith('http://') || path.startsWith('https://')) {
    print('✅ constructFullUrl: Already full URL: $path');
    return path;
  }

  // For media files that come with leading slash (like /voice/xxx, /images/xxx)
  // Remove the leading slash to avoid double slash since apiBaseUrl ends with /
  String cleanPath = path;
  if (cleanPath.startsWith('/')) {
    cleanPath = cleanPath.substring(1); // Remove leading /
  }

  // Construct full URL
  // Since apiBaseUrl = 'https://api.ixes.ai/'
  // and cleanPath = 'voice/3770ed4a...'
  // Result = 'https://api.ixes.ai/voice/3770ed4a...'
  final fullUrl = '$apiBaseUrl$cleanPath';
  print('🔗 constructFullUrl: $path → $fullUrl');
  return fullUrl;
}

/// Helper for API endpoints (your existing usage pattern)
String apiUrl(String endpoint) {
  // For API endpoints like 'api/chat/friends'
  return '$apiBaseUrl$endpoint';
}