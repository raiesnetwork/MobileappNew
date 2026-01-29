
 const String apiBaseUrl = 'https://api.ixes.ai/';
//const String apiBaseUrl = "http://192.168.0.199:5000/";
const String SIGNUP = 'api/auth/signup';
const String GETALLPOST = 'api/mobile/posts';
const String GETALLNOTIFICATIONS = 'api/notifications';
const String SOCKET_URL = 'https://api.ixes.ai/fileUrl';
const String socketBaseUrl = "wss://api.ixes.ai";
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