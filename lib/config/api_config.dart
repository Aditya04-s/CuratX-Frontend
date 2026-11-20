class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

  static Map<String, String> get multipartHeaders => {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

  static String resolveUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$baseUrl$path';
  }
}