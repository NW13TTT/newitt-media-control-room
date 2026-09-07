import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static const initializationTimeout = Duration(seconds: 12);
  static const passwordResetCallbackUrl = 'newittcontrolroom://auth-callback/';

  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const passwordResetRedirectUrl = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
  );
  static const authStorageScope = String.fromEnvironment(
    'SUPABASE_AUTH_STORAGE_SCOPE',
  );
  static bool _passwordRecoveryCallbackDetected = false;
  static Future<void>? _clientInitialization;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String? get _validatedAuthStorageScope {
    final value = authStorageScope.trim();
    return RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(value) ? value : null;
  }

  static String? get scopedSessionStorageKey {
    final scope = _validatedAuthStorageScope;
    if (scope == null || url.isEmpty) return null;
    final projectRef = Uri.parse(url).host.split('.').first;
    return 'sb-$projectRef-auth-token-$scope';
  }

  static String? get validatedPasswordResetRedirectUrl {
    return validatedRedirectUrl(passwordResetRedirectUrl) ??
        passwordResetCallbackUrl;
  }

  static String? validatedRedirectUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.scheme == 'https'
        ? uri.toString()
        : null;
  }

  static bool detectPasswordRecoveryCallback(Uri uri) {
    final configuredRedirect = validatedRedirectUrl(passwordResetRedirectUrl);
    final configuredUri = configuredRedirect == null
      ? null
      : Uri.parse(configuredRedirect);
    final isNativeCallback = uri.scheme == 'newittcontrolroom' &&
      uri.host == 'auth-callback' &&
      uri.path == '/';
    final isWebCallback = configuredUri != null &&
      uri.scheme == configuredUri.scheme &&
      uri.host == configuredUri.host &&
      uri.port == configuredUri.port &&
      uri.path == configuredUri.path;
    final fragmentParameters = Uri.splitQueryString(uri.fragment);
    final hasAuthParameters =
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error') ||
        fragmentParameters.containsKey('code') ||
        fragmentParameters.containsKey('access_token') ||
        fragmentParameters.containsKey('error');
    if ((isNativeCallback || isWebCallback) && hasAuthParameters) {
      _passwordRecoveryCallbackDetected = true;
      return true;
    }
    return false;
  }

  static bool consumePasswordRecoveryCallback() {
    final detected = _passwordRecoveryCallbackDetected;
    _passwordRecoveryCallbackDetected = false;
    return detected;
  }

  static Future<SupabaseConnectionStatus> initialize({
    Future<void> Function()? initializeClient,
    Duration timeout = initializationTimeout,
  }) =>
      _initialize(
      initializeClient: initializeClient,
      timeout: timeout,
    );

  static Future<SupabaseConnectionStatus> _initialize({
    Future<void> Function()? initializeClient,
    required Duration timeout,
  }) async {
    if (!isConfigured && initializeClient == null) {
      return SupabaseConnectionStatus.notConfigured;
    }

    try {
      _passwordRecoveryCallbackDetected = false;
      final scope = _validatedAuthStorageScope;
      final initialization = initializeClient?.call() ??
          (_clientInitialization ??= Supabase.initialize(
            url: url,
            publishableKey: publishableKey,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              detectSessionInUriPredicate: detectPasswordRecoveryCallback,
              localStorage: scope == null
                  ? null
                  : SharedPreferencesLocalStorage(
                      persistSessionKey: scopedSessionStorageKey!,
                    ),
              pkceAsyncStorage: scope == null
                  ? null
                  : _ScopedGotrueAsyncStorage(scope),
            ),
            debug: false,
          ));
      await initialization
          .timeout(timeout);
      return SupabaseConnectionStatus.connected;
    } on TimeoutException {
      debugPrint('SUPABASE_INITIALIZATION_TIMEOUT');
      return SupabaseConnectionStatus.timedOut;
    } catch (error) {
      debugPrint('SUPABASE_INITIALIZATION_FAILED type=${error.runtimeType}');
      return SupabaseConnectionStatus.unavailable;
    }
  }
}

class _ScopedGotrueAsyncStorage extends GotrueAsyncStorage {
  _ScopedGotrueAsyncStorage(this._scope);

  final String _scope;
  final _storage = SharedPreferencesGotrueAsyncStorage();

  String _key(String key) => '$key-$_scope';

  @override
  Future<String?> getItem({required String key}) =>
    _storage.getItem(key: _key(key));

  @override
  Future<void> removeItem({required String key}) =>
    _storage.removeItem(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
    _storage.setItem(key: _key(key), value: value);
}

enum SupabaseConnectionStatus {
  notConfigured,
  connected,
  unavailable,
  timedOut,
}
