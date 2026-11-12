import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Address of the Next.js backend. Set it when building:
///   flutter run --dart-define=API_BASE=https://your-backend.vercel.app
/// The default works with the Android emulator and `npm run dev` on the same computer.
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:3000');

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  bool get signedOut => status == 401 && code == 'signed_out';

  @override
  String toString() => message;
}

class Api {
  String? token;
  final http.Client _client = http.Client();

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final Map<String, String> q = <String, String>{};
    query?.forEach((String k, String v) {
      if (v.isNotEmpty) q[k] = v;
    });
    return Uri.parse('$apiBase/api$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) {
    return _send(() => _client.get(_uri(path, query), headers: _headers));
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return _send(() => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() run) async {
    http.Response res;
    try {
      res = await run().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException(0, 'timeout', 'This is taking too long. Check your connection and try again.');
    } catch (_) {
      throw ApiException(0, 'offline', 'We could not connect. Check your internet and try again.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException(res.statusCode, 'bad_answer', 'Something went wrong. Please try again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    final Map<String, dynamic>? err = data is Map ? asMap(data['error']) : null;
    throw ApiException(res.statusCode, str(err?['code'], 'error'), str(err?['message'], 'Something went wrong. Please try again.'));
  }
}

/* Small helpers for reading JSON safely. */
String str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final String s = v.toString();
  return s.isEmpty ? fallback : s;
}

int num0(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse('$v') ?? 0;
}

bool yes(dynamic v) => v == true || v == 1 || v == '1';

Map<String, dynamic>? asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> rows(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e)).toList();
}

List<String> strings(dynamic v) => v is List ? v.map((dynamic e) => e.toString()).toList() : <String>[];
