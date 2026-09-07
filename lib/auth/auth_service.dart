import 'auth_models.dart';

const passwordResetRequestedMessage =
    'If an account exists for this email, a password reset email has been sent.';
const passwordResetRateLimitedMessage =
    'Too many password reset requests have been made. Please wait and try again.';
const passwordResetConfigurationMessage =
    'Password reset is temporarily unavailable. Please try again later.';
const passwordRecoveryUpdatedMessage =
    'Password updated. Sign in with your new password.';

abstract interface class AuthenticationService {
  Future<AuthSession?> get currentSession;

  Stream<AuthSession?> get sessionChanges;

  Stream<void> get passwordRecoveryEvents;

  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthResult> requestPasswordReset({required String email});

  Future<AuthResult> completePasswordReset({
    required String resetCode,
    required String newPassword,
  });

  Future<void> signOut();
}

class AuthResult {
  const AuthResult.success(this.session) : message = null;

  const AuthResult.failure(this.message) : session = null;

  const AuthResult.message(this.message) : session = null;

  final AuthSession? session;
  final String? message;

  bool get isSuccess => session != null;
}

class UnconfiguredAuthenticationService implements AuthenticationService {
  const UnconfiguredAuthenticationService();

  static const String _message =
      'Authentication backend is not configured. Use the development preview to view the UI.';

  @override
  Future<AuthSession?> get currentSession async => null;

  @override
  Stream<AuthSession?> get sessionChanges => const Stream<AuthSession?>.empty();

  @override
  Stream<void> get passwordRecoveryEvents => const Stream<void>.empty();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthResult.failure(_message);
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return const AuthResult.failure(_message);
  }

  @override
  Future<AuthResult> requestPasswordReset({required String email}) async {
    return const AuthResult.failure(_message);
  }

  @override
  Future<AuthResult> completePasswordReset({
    required String resetCode,
    required String newPassword,
  }) async {
    return const AuthResult.failure(_message);
  }

  @override
  Future<void> signOut() async {}
}

class UnavailableAuthenticationService implements AuthenticationService {
  const UnavailableAuthenticationService();

  static const String _message =
      'Authentication service is temporarily unavailable. Please try again.';

  @override
  Future<AuthSession?> get currentSession async => null;

  @override
  Stream<AuthSession?> get sessionChanges => const Stream<AuthSession?>.empty();

  @override
  Stream<void> get passwordRecoveryEvents => const Stream<void>.empty();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async => const AuthResult.failure(_message);

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const AuthResult.failure(_message);

  @override
  Future<AuthResult> requestPasswordReset({required String email}) async =>
      const AuthResult.failure(_message);

  @override
  Future<AuthResult> completePasswordReset({
    required String resetCode,
    required String newPassword,
  }) async => const AuthResult.failure(_message);

  @override
  Future<void> signOut() async {}
}
