import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_models.dart';
import '../../auth/auth_service.dart';
import 'supabase_config.dart';

class SupabaseAuthenticationService implements AuthenticationService {
  SupabaseAuthenticationService(this.client);

  final SupabaseClient client;
  late final _authStateChanges = client.auth.onAuthStateChange
      .asBroadcastStream();

  @override
  Stream<AuthSession?> get sessionChanges => _authStateChanges.asyncMap(
    (event) => _sessionFromSupabase(event.session),
  );

  @override
  Stream<void> get passwordRecoveryEvents => _authStateChanges
      .where((event) => event.event == AuthChangeEvent.passwordRecovery)
      .map((event) {
        debugPrint('CALLBACK_RECEIVED');
        if (event.session != null && client.auth.currentSession != null) {
          debugPrint('RECOVERY_SESSION_PRESENT');
        }
        debugPrint('PASSWORD_RECOVERY_EVENT');
      });

  @override
  Future<AuthSession?> get currentSession =>
      _sessionFromSupabase(client.auth.currentSession);

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return await _resultFromSession(response.session);
    } on AuthException catch (error) {
      return AuthResult.failure(_friendlyAuthError(error.message));
    } catch (_) {
      return const AuthResult.failure(
        'Sign-in is temporarily unavailable. Please try again.',
      );
    }
  }

  static String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'The email or password is incorrect.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    return 'Unable to sign in. Please check your details and try again.';
  }

  static String _resetFailureMessage(AuthException error) {
    final message = error.statusCode == '429'
        ? passwordResetRateLimitedMessage
        : passwordResetConfigurationMessage;
    if (!kDebugMode) return message;
    final diagnosticMessage = error is AuthRetryableFetchException
        ? _safeRetryableFetchDiagnostic(error.message)
        : _safeDiagnosticValue(error.message);
    return '$message\n'
        'Debug: type=${error.runtimeType}; message=$diagnosticMessage; '
        'statusCode=${error.statusCode ?? 'NONE'}; code=${error.code ?? 'NONE'}';
  }

  static String _safeRetryableFetchDiagnostic(String value) {
    if (value.trim().isEmpty) return '(empty)';
    var sanitized = value
        .replaceAll(
          RegExp(r'[a-z][a-z0-9+.-]*://\S*[?#]', caseSensitive: false),
          '[REDACTED URL]',
        )
        .replaceAll(
          RegExp(
            r'(?:access|refresh|recovery)?[ _-]?token\s*[:=]\s*\S+|'
            r'(?:password|secret|api[ _-]?key|recovery[ _-]?code|authorization)\s*[:=]\s*\S+|'
            r'sb_(?:publishable|secret)_[a-zA-Z0-9_-]+|'
            r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}',
            caseSensitive: false,
          ),
          '[REDACTED]',
        );
    if (sanitized.length > 200) sanitized = '${sanitized.substring(0, 200)}...';
    return sanitized;
  }

  static String _safeDiagnosticValue(String value) {
    final containsSensitiveData = RegExp(
      r'(?:access|refresh|recovery)?[ _-]?token\s*[:=]\s*\S+|'
      r'(?:password|secret|api[ _-]?key|recovery[ _-]?code|authorization)\s*[:=]\s*\S+|'
      r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}|'
      r'[a-z][a-z0-9+.-]*://\S*[?#]',
      caseSensitive: false,
    ).hasMatch(value);
    return containsSensitiveData ? 'REDACTED' : value;
  }

  static void _logResetFailure(Object error) {
    if (!kDebugMode) return;
    if (error is AuthException) {
      debugPrint(
        'RESET_REQUEST_FAILED type=${error.runtimeType} '
        'message=${_safeDiagnosticValue(error.message)} status=${error.statusCode ?? 'NONE'} '
        'code=${error.code ?? 'NONE'}',
      );
      return;
    }

    final details = error.toString();
    final containsSensitiveData = RegExp(
      r'token|secret|password|api[ _-]?key|recovery[ _-]?code|authorization|[a-z][a-z0-9+.-]*://\S*[?#]',
      caseSensitive: false,
    ).hasMatch(details);
    if (!containsSensitiveData) {
      debugPrint('RESET_REQUEST_FAILED type=${error.runtimeType} $details');
    }
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    return _resultFromSession(
      client.auth.currentSession,
      userId: user.user?.id,
    );
  }

  @override
  Future<AuthResult> requestPasswordReset({required String email}) async {
    final redirectUrl = SupabaseConfig.validatedPasswordResetRedirectUrl;
    debugPrint('RESET_REQUEST_STARTED');
    try {
      await client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
      debugPrint('RESET_REQUEST_SENT');
      return const AuthResult.message(passwordResetRequestedMessage);
    } on AuthException catch (error) {
      _logResetFailure(error);
      return AuthResult.failure(_resetFailureMessage(error));
    } catch (error) {
      _logResetFailure(error);
      return const AuthResult.failure(passwordResetConfigurationMessage);
    }
  }

  @override
  Future<AuthResult> completePasswordReset({
    required String resetCode,
    required String newPassword,
  }) async {
    if (client.auth.currentSession == null) {
      debugPrint('PASSWORD_UPDATE_FAILED');
      return const AuthResult.failure(
        'Password update could not be completed. Please try again.',
      );
    }
    try {
      debugPrint('PASSWORD_UPDATE_STARTED');
      await client.auth.updateUser(UserAttributes(password: newPassword));
      debugPrint('PASSWORD_UPDATE_SUCCESS');
      return const AuthResult.message(passwordRecoveryUpdatedMessage);
    } catch (_) {
      debugPrint('PASSWORD_UPDATE_FAILED');
      return const AuthResult.failure(
        'Password update could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  Future<AuthResult> _resultFromSession(
    Session? supabaseSession, {
    String? userId,
  }) async {
    final session = await _sessionFromSupabase(supabaseSession, userId: userId);
    return session == null
        ? const AuthResult.failure('No authenticated session was returned.')
        : AuthResult.success(session);
  }

  Future<AuthSession?> _sessionFromSupabase(
    Session? supabaseSession, {
    String? userId,
  }) async {
    if (supabaseSession == null) return null;
    final user = supabaseSession.user;
    final profile = await client
        .from('profiles')
        .select('id, display_name, email, role, tenant_id')
        .eq('id', userId ?? user.id)
        .maybeSingle();
    if (profile == null) return null;

    final websites = await client
        .from('websites')
        .select('id')
        .eq('tenant_id', profile['tenant_id']);
    return AuthSession(
      sessionId: supabaseSession.accessToken,
      authenticatedAt: DateTime.fromMillisecondsSinceEpoch(
        supabaseSession.expiresAt == null
            ? DateTime.now().millisecondsSinceEpoch
            : supabaseSession.expiresAt! * 1000,
      ),
      profile: AccountProfile(
        accountId: profile['id'] as String,
        displayName: profile['display_name'] as String,
        email: profile['email'] as String,
        role: _roleFromDatabase(profile['role'] as String),
        tenantId: profile['tenant_id'] as String,
        websiteIds: {for (final website in websites) website['id'] as String},
      ),
    );
  }

  static AuthRole _roleFromDatabase(String value) {
    switch (value.toUpperCase()) {
      case 'MASTER_ADMIN':
        return AuthRole.masterAdmin;
      case 'OWNER':
        return AuthRole.owner;
      default:
        return AuthRole.customer;
    }
  }
}
