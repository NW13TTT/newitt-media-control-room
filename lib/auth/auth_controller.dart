import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    AuthenticationService? service,
    this._developmentPreviewEnabled = false,
    this.initializationTimeout = const Duration(seconds: 8),
    this.hasPasswordRecoveryCallback = false,
  }) : _service = service ?? const UnconfiguredAuthenticationService() {
    _sessionSubscription = _service.sessionChanges.listen(_onSessionChanged);
    _passwordRecoverySubscription = _service.passwordRecoveryEvents.listen((_) {
      debugPrint('PASSWORD_RECOVERY_EVENT');
      passwordRecoveryActive = true;
      notifyListeners();
    });
  }

  final AuthenticationService _service;
  final bool _developmentPreviewEnabled;
  final Duration initializationTimeout;
  final bool hasPasswordRecoveryCallback;
  AuthState state = AuthState.signedOut;
  AuthSession? session;
  String? errorMessage;
  bool passwordRecoveryActive = false;
  late final StreamSubscription<AuthSession?> _sessionSubscription;
  late final StreamSubscription<void> _passwordRecoverySubscription;

  bool get canUseDevelopmentPreview => kDebugMode && _developmentPreviewEnabled;

  Future<void> initialize() async {
    state = AuthState.initializing;
    notifyListeners();
    try {
      final restoredSession = await _service.currentSession.timeout(
        initializationTimeout,
      );
      session = restoredSession;
      passwordRecoveryActive =
          hasPasswordRecoveryCallback && restoredSession != null;
      state = restoredSession == null
          ? AuthState.signedOut
          : AuthState.signedIn;
    } on TimeoutException {
      session = null;
      state = AuthState.signedOut;
      errorMessage = 'Authentication session restoration timed out. Please retry.';
    } catch (_) {
      session = null;
      state = AuthState.signedOut;
      errorMessage = 'Unable to restore the authentication session.';
    }
    notifyListeners();
  }

  void _onSessionChanged(AuthSession? updatedSession) {
    session = updatedSession;
    state = updatedSession == null ? AuthState.signedOut : AuthState.signedIn;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = AuthState.signingIn;
    errorMessage = null;
    notifyListeners();
    AuthResult result;
    try {
      result = await _service.signIn(email: email, password: password);
    } catch (_) {
      result = const AuthResult.failure(
        'Sign-in is temporarily unavailable. Please try again.',
      );
    }
    if (result.isSuccess) {
      session = result.session;
      state = AuthState.signedIn;
    } else {
      state = AuthState.signedOut;
      errorMessage = result.message;
    }
    notifyListeners();
  }

  void enterDevelopmentPreview(AuthRole role) {
    if (!canUseDevelopmentPreview) return;

    final bool customer = role == AuthRole.customer;
    final bool owner = role == AuthRole.owner;
    session = AuthSession(
      sessionId: 'development-preview-session',
      authenticatedAt: DateTime.now(),
      profile: AccountProfile(
        accountId: customer
            ? 'preview-customer-account'
            : owner
            ? 'preview-owner-account'
            : 'preview-master-admin-account',
        displayName: customer
            ? 'Essex Paranormal'
            : owner
            ? 'NEWITT Media'
            : 'NEWITT Platform Admin',
        email: customer
            ? 'customer.preview@development.invalid'
            : owner
            ? 'owner.preview@development.invalid'
            : 'admin.preview@development.invalid',
        role: role,
        tenantId: customer
            ? 'preview-essex-paranormal-tenant'
            : owner
            ? 'preview-newitt-media-tenant'
            : 'platform-tenant',
        websiteIds: customer
            ? {'essex-paranormal'}
            : owner
            ? {'newitt-media'}
            : {'newitt-media', 'essex-paranormal'},
      ),
    );
    errorMessage = null;
    state = AuthState.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _service.signOut();
    } catch (_) {}
    session = null;
    state = AuthState.signedOut;
    errorMessage = null;
    notifyListeners();
  }

  Future<String?> requestPasswordReset({required String email}) async {
    try {
      final result = await _service.requestPasswordReset(email: email);
      return result.message;
    } catch (_) {
      return 'Password reset is temporarily unavailable. Please try again.';
    }
  }

  Future<String?> completePasswordReset({
    required String resetCode,
    required String newPassword,
  }) async {
    final result = await _service.completePasswordReset(
      resetCode: resetCode,
      newPassword: newPassword,
    );
    return result.message;
  }

  Future<String?> completePasswordRecovery({
    required String newPassword,
  }) async {
    try {
      final result = await _service.completePasswordReset(
        resetCode: '',
        newPassword: newPassword,
      );
      if (result.message != passwordRecoveryUpdatedMessage) {
        return result.message;
      }
      passwordRecoveryActive = false;
      try {
        await _service.signOut();
      } catch (_) {}
      session = null;
      state = AuthState.signedOut;
      errorMessage = passwordRecoveryUpdatedMessage;
      notifyListeners();
      return passwordRecoveryUpdatedMessage;
    } catch (_) {
      return 'Password update could not be completed. Please try again.';
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return result.message;
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    _passwordRecoverySubscription.cancel();
    super.dispose();
  }
}
