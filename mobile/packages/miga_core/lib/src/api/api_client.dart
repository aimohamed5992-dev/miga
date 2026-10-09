import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Error from the MIGA API. [message] is Arabic and safe to show; [code] is stable for branching
/// (e.g. `otp_invalid`, `already_joined`, `network`).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  bool get isNetwork => code == 'network';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiConfig {
  ApiConfig._();

  /// `--dart-define=MIGA_API_URL=https://api.miga.sa` in release builds.
  /// Defaults: iOS simulator / desktop reach the Mac directly; the Android emulator uses 10.0.2.2.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('MIGA_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5296';
    return 'http://localhost:5296';
  }

  /// Uploaded images come back as `/uploads/...`; bundled demo images are plain file names.
  static String? imageUrl(String? path) =>
      path == null || path.isEmpty
          ? null
          : path.startsWith('http')
          ? path
          : path.startsWith('/')
          ? '$baseUrl$path'
          : null;
}

/// Where access / refresh tokens live. Secure storage = iOS Keychain / Android Keystore.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureTokenStore implements TokenStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null ? _storage.delete(key: key) : _storage.write(key: key, value: value);
}

class MemoryTokenStore implements TokenStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async => value == null ? _values.remove(key) : _values[key] = value;
}

/// JSON-over-HTTP client: bearer token, one automatic refresh on 401 (shared by concurrent calls),
/// ProblemDetails → [ApiException] with the API's Arabic title.
class ApiClient {
  ApiClient({http.Client? httpClient, TokenStore? tokens, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      tokens = tokens ?? SecureTokenStore(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static const accessKey = 'miga_access_token';
  static const refreshKey = 'miga_refresh_token';
  static const _timeout = Duration(seconds: 20);

  final http.Client _http;
  final TokenStore tokens;
  final String baseUrl;

  /// Called when the refresh token is rejected — the app should return to the login screen.
  VoidCallback? onSessionExpired;

  Future<bool>? _refreshing;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Multipart image upload → returns the stored URL path (e.g. `/uploads/products/2026-10/…jpg`).
  Future<String> uploadImage(String folder, String filePath) => _upload(folder, () => http.MultipartFile.fromPath('file', filePath));

  /// Same as [uploadImage] for in-memory files (Flutter Web has no file paths).
  Future<String> uploadImageBytes(String folder, List<int> bytes, String filename) =>
      _upload(folder, () async => http.MultipartFile.fromBytes('file', bytes, filename: filename));

  Future<String> _upload(String folder, Future<http.MultipartFile> Function() file, {bool retried = false}) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/uploads/$folder'))
          ..headers['Accept'] = 'application/json'
          ..files.add(await file());
    final token = await tokens.read(accessKey);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 60)));
    } on SocketException {
      throw const ApiException(0, 'network', 'لا يوجد اتصال بالإنترنت، تحقق من الشبكة وحاول مرة أخرى');
    } on TimeoutException {
      throw const ApiException(0, 'network', 'انتهت مهلة رفع الصورة، حاول مرة أخرى');
    }
    if (response.statusCode == 401 && !retried && await _refresh()) return _upload(folder, file, retried: true);
    final decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) return decoded['url'] as String;
    if (decoded is Map<String, dynamic>) {
      throw ApiException(response.statusCode, decoded['code'] as String? ?? 'error', decoded['title'] as String? ?? 'تعذّر رفع الصورة');
    }
    throw ApiException(response.statusCode, 'error', 'تعذّر رفع الصورة');
  }

  Future<void> saveTokens(String access, String refresh) async {
    await tokens.write(accessKey, access);
    await tokens.write(refreshKey, refresh);
  }

  Future<void> clearTokens() async {
    await tokens.write(accessKey, null);
    await tokens.write(refreshKey, null);
  }

  Future<bool> get hasSession async => (await tokens.read(refreshKey)) != null;

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, Object?>? query, bool retried = false}) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters:
          query == null
              ? null
              : {
                for (final e in query.entries)
                  if (e.value != null) e.key: '${e.value}',
              },
    );
    final request = http.Request(method, uri)..headers['Accept'] = 'application/json';
    final token = await tokens.read(accessKey);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on SocketException {
      throw const ApiException(0, 'network', 'لا يوجد اتصال بالإنترنت، تحقق من الشبكة وحاول مرة أخرى');
    } on TimeoutException {
      throw const ApiException(0, 'network', 'انتهت مهلة الاتصال بالخادم، حاول مرة أخرى');
    } on http.ClientException {
      throw const ApiException(0, 'network', 'تعذّر الاتصال بالخادم');
    }

    if (response.statusCode == 401 && !retried && !path.startsWith('/api/auth/') && await _refresh()) {
      return _send(method, path, body: body, query: query, retried: true);
    }
    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        decoded['code'] as String? ?? 'error',
        decoded['title'] as String? ?? 'حدث خطأ، حاول مرة أخرى',
      );
    }
    throw ApiException(response.statusCode, response.statusCode == 401 ? 'unauthorized' : 'error', 'حدث خطأ، حاول مرة أخرى');
  }

  /// Single-flight refresh: concurrent 401s wait for the same refresh call.
  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = await tokens.read(refreshKey);
    if (refresh == null) return false;
    try {
      final r = await _http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (r.statusCode != 200) {
        await clearTokens();
        onSessionExpired?.call();
        return false;
      }
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      await saveTokens(json['accessToken'] as String, json['refreshToken'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}
