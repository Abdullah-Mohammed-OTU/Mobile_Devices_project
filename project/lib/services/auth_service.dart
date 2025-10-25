import 'dart:convert';

import 'package:http/http.dart' as http;

/// Basic API client for the authentication endpoints exposed by the FastAPI backend.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'http://127.0.0.1:8000';

  Future<http.Response> _post(String path, Map<String, String> query) {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _client.post(uri);
  }

  /// Performs a login against the backend and returns the issued JWT token.
  Future<String> login({required String email, required String password}) async {
    final response = await _post('/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> payload = jsonDecode(response.body) as Map<String, dynamic>;
      final token = payload['token'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Token missing from response.');
      }
      return token;
    }

    final Map<String, dynamic>? payload =
        response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
    final message = payload != null && payload['detail'] is String ? payload['detail'] as String : 'Login failed';
    throw AuthException(message);
  }

  /// Registers a new user and returns the backend success message.
  Future<String> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _post('/register', {
      'email': email,
      'username': username,
      'password': password,
    });

    final Map<String, dynamic>? payload =
        response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;

    if (response.statusCode == 200 && payload != null && payload['message'] is String) {
      return payload['message'] as String;
    }

    final message =
        payload != null && payload['detail'] is String ? payload['detail'] as String : 'Registration failed';
    throw AuthException(message);
  }

  /// Requests a password reset email for the provided address.
  Future<String> requestPasswordReset({required String email}) async {
    final response = await _post('/forgot-password', {'email': email});

    final Map<String, dynamic>? payload =
        response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;

    if (response.statusCode == 200 && payload != null && payload['message'] is String) {
      return payload['message'] as String;
    }

    final message =
        payload != null && payload['detail'] is String ? payload['detail'] as String : 'Request failed';
    throw AuthException(message);
  }

  /// Resets the password using the token sent to the user's email.
  Future<String> resetPassword({required String token, required String newPassword}) async {
    final response = await _post('/reset-password/$token', {'new_password': newPassword});

    final Map<String, dynamic>? payload =
        response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;

    if (response.statusCode == 200 && payload != null && payload['message'] is String) {
      return payload['message'] as String;
    }

    final message =
        payload != null && payload['detail'] is String ? payload['detail'] as String : 'Reset failed';
    throw AuthException(message);
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
