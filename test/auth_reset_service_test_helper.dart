import 'dart:async';

import 'package:newitt_media_control_room/auth/auth_models.dart';
import 'package:newitt_media_control_room/auth/auth_service.dart';

class PasswordResetServiceTestHelper implements AuthenticationService {
  PasswordResetServiceTestHelper({
    this.result,
    this.passwordUpdateResult,
    this.waitForCompletion = false,
    this.currentSessionFuture,
    this.signInResult,
  });

  final AuthResult? result;
  final AuthResult? passwordUpdateResult;
  final bool waitForCompletion;
  final Future<AuthSession?>? currentSessionFuture;
  final AuthResult? signInResult;
  final Completer<AuthResult> _completion = Completer<AuthResult>();
  final StreamController<void> _recoveryEvents =
      StreamController<void>.broadcast(sync: true);
  int requests = 0;

  @override
  Future<AuthSession?> get currentSession =>
      currentSessionFuture ?? Future<AuthSession?>.value(null);

  @override
  Stream<AuthSession?> get sessionChanges => const Stream<AuthSession?>.empty();

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryEvents.stream;

  void emitPasswordRecovery() => _recoveryEvents.add(null);

  @override
  Future<AuthResult> requestPasswordReset({required String email}) {
    requests++;
    return waitForCompletion
        ? _completion.future
        : Future<AuthResult>.value(result ?? const AuthResult.message('done'));
  }

  void complete(AuthResult value) => _completion.complete(value);

  void dispose() {
    _recoveryEvents.close();
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => Future<AuthResult>.value(const AuthResult.failure('unused'));

  @override
  Future<AuthResult> completePasswordReset({
    required String resetCode,
    required String newPassword,
  }) => Future<AuthResult>.value(
    passwordUpdateResult ?? const AuthResult.failure('unused'),
  );

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) => Future<AuthResult>.value(
    signInResult ?? const AuthResult.failure('unused'),
  );

  @override
  Future<void> signOut() async {}
}
