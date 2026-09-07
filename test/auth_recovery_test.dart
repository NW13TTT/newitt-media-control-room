import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newitt_media_control_room/app/app.dart';
import 'package:newitt_media_control_room/auth/auth_controller.dart';
import 'package:newitt_media_control_room/auth/auth_gate.dart';
import 'package:newitt_media_control_room/auth/auth_models.dart';
import 'package:newitt_media_control_room/auth/auth_service.dart';
import 'package:newitt_media_control_room/backend/supabase/supabase_config.dart';

import 'auth_reset_service_test_helper.dart';

void main() {
  test('native password reset redirect remains the recovery callback', () {
    expect(
      SupabaseConfig.validatedPasswordResetRedirectUrl,
      'newittcontrolroom://auth-callback/',
    );
  });

  test('an unset auth storage scope preserves production storage', () {
    expect(SupabaseConfig.scopedSessionStorageKey, isNull);
  });

  test('recovery callback is captured while Supabase initializes', () {
    expect(
      SupabaseConfig.detectPasswordRecoveryCallback(
        Uri.parse('newittcontrolroom://auth-callback/?code=opaque'),
      ),
      isTrue,
    );
    expect(SupabaseConfig.consumePasswordRecoveryCallback(), isTrue);
  });

  testWidgets('a restored recovery session opens the password screen', (
    tester,
  ) async {
    final service = PasswordResetServiceTestHelper(
      currentSessionFuture: Future<AuthSession?>.value(_session()),
    );
    final controller = AuthController(
      service: service,
      hasPasswordRecoveryCallback: true,
    );
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });

    await controller.initialize();
    await tester.pumpWidget(
      NewittApp(
        home: AuthGate(
          controller: controller,
          authenticatedBuilder: (_, _) => const Text('Control Room'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.text('Control Room'), findsNothing);
  });

  testWidgets('a recovery password update returns to normal login', (
    tester,
  ) async {
    final service = PasswordResetServiceTestHelper(
      currentSessionFuture: Future<AuthSession?>.value(_session()),
      passwordUpdateResult: const AuthResult.message(
        passwordRecoveryUpdatedMessage,
      ),
    );
    final controller = AuthController(
      service: service,
      hasPasswordRecoveryCallback: true,
    );
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });

    await controller.initialize();
    await controller.completePasswordRecovery(newPassword: 'new-password');

    expect(controller.passwordRecoveryActive, isFalse);
    expect(controller.state, AuthState.signedOut);
  });

  testWidgets('a recovery event replaces the reset request screen', (
    tester,
  ) async {
    final service = PasswordResetServiceTestHelper();
    final controller = AuthController(service: service);
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });

    await controller.initialize();
    await tester.pumpWidget(
      NewittApp(
        home: AuthGate(
          controller: controller,
          authenticatedBuilder: (_, _) => const Text('Control Room'),
        ),
      ),
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);

    service.emitPasswordRecovery();
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.text('Reset password'), findsNothing);
  });
}

AuthSession _session() => AuthSession(
  sessionId: 'session',
  authenticatedAt: DateTime(2026),
  profile: const AccountProfile(
    accountId: 'account',
    displayName: 'Account',
    email: 'account@example.invalid',
    role: AuthRole.masterAdmin,
    tenantId: 'tenant',
    websiteIds: {'website'},
  ),
);