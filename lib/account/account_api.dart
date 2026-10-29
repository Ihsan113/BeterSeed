import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const accountApiUrl = String.fromEnvironment('BETTERSEED_API_URL');
const googleWebClientId =
    String.fromEnvironment('BETTERSEED_GOOGLE_WEB_CLIENT_ID');

class AccountException implements Exception {
  const AccountException(this.code, [this.details]);
  final String code;
  final Map<String, dynamic>? details;
  @override
  String toString() => accountErrorMessage(code);
}

String accountErrorMessage(String code) => switch (code) {
      'catalog_changed' => 'This pack has changed. Refresh the Shop and review its new price before trying again.',
      'pack_unavailable' => 'This pack is not available to unlock right now.',
      'app_update_required' => 'Update BetterSeed to unlock this pack safely.',
      'terms_required' =>
        'Please review and accept the current Terms and Privacy policy.',
      'account_suspended' =>
        'This account is paused. Contact support for help.',
      'local_storage_failed' =>
        'Your phone could not save this change. Free up some storage and try again.',
      'invalid_credentials' =>
        'Email or password is incorrect, or the email is not verified yet.',
      'invalid_or_expired_code' =>
        'The code is incorrect or expired. Request a new code. If enabled, include your authenticator or recovery code.',
      'invalid_factor' =>
        'Use a new authenticator code or an unused recovery code.',
      'rate_limited' => 'Too many attempts. Please wait before trying again.',
      'unauthorized' ||
      'session_expired' =>
        'Please sign in again. Your unsynced garden is kept on this device.',
      'sync_conflict' =>
        'Another device changed this garden. Choose which version to keep.',
      'reauthentication_failed' =>
        'Identity could not be confirmed. Check your password and authenticator code.',
      'use_original_sign_in' =>
        'This email already uses another sign-in method. Use the original method.',
      'insufficient_coins' => 'You need more Leaf Coins to unlock this pack.',
      'purchase_pending' =>
        'Google Play is still processing this purchase. Delivery will retry.',
      'purchase_account_mismatch' ||
      'purchase_unavailable' =>
        'This purchase belongs to another account. Sign in to the account used when buying.',
      'purchase_voided' ||
      'purchase_not_completed' =>
        'Google Play has not approved this purchase, or it was refunded.',
      'purchase_already_consumed' =>
        'This purchase has already been delivered. If coins are missing, contact support with your Google Play receipt.',
      'billing_unavailable' ||
      'play_verification_unavailable' =>
        'Purchase verification is temporarily unavailable. No extra purchase is needed; retry delivery later.',
      'not_configured' =>
        'Sign-in is unavailable right now. You can continue as a guest.',
      'google_unavailable' =>
        'Google sign-in is unavailable right now. Please try again later.',
      'google_canceled' => 'Google sign-in was canceled.',
      'offline' =>
        'You appear to be offline. Your garden is saved on this phone; try again when connected.',
      'invalid_request' =>
        'Please check the entered information. Passwords must contain 12–128 characters.',
      'setup_expired' => 'Authenticator setup expired. Start again.',
      _ => 'The request could not be completed. Please try again.',
    };

abstract class SessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic>? session);
}

class SecureSessionStore implements SessionStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'betterseed_account_session_v1';
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> write(Map<String, dynamic>? session) async {
    if (session == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: jsonEncode(session));
    }
  }
}

class AccountApi {
  AccountApi({String baseUrl = accountApiUrl, http.Client? client})
      : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  bool get configured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  Future<Map<String, dynamic>> send(String method, String path,
      {Map<String, dynamic>? body, String? accessToken}) async {
    if (!configured) throw const AccountException('not_configured');
    final abort = Completer<void>();
    try {
      final request = http.AbortableRequest(method, Uri.parse('$baseUrl$path'),
          abortTrigger: abort.future)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json';
      if (accessToken != null)
        request.headers['Authorization'] = 'Bearer $accessToken';
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async {
        final streamed = await _client.send(request);
        final bytes = <int>[];
        await for (final chunk in streamed.stream) {
          if (bytes.length + chunk.length > 5 * 1024 * 1024)
            throw const AccountException('invalid_response');
          bytes.addAll(chunk);
        }
        return http.Response.bytes(bytes, streamed.statusCode,
            headers: streamed.headers);
      })()
          .timeout(const Duration(seconds: 25));
      final result =
          Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AccountException(
            result['error'] as String? ?? 'request_failed',
            result['details'] is Map
                ? Map<String, dynamic>.from(result['details'] as Map)
                : null);
      }
      return result;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw const AccountException('offline');
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }
}

class GoogleAccountIdentity {
  static Future<void>? _initializing;
  static Future<String> authenticate() async {
    if (googleWebClientId.isEmpty)
      throw const AccountException('google_unavailable');
    try {
      await (_initializing ??=
          GoogleSignIn.instance.initialize(serverClientId: googleWebClientId));
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AccountException('google_unavailable');
      return token;
    } on GoogleSignInException catch (e) {
      throw AccountException(e.code == GoogleSignInExceptionCode.canceled
          ? 'google_canceled'
          : 'google_unavailable');
    }
  }
}
