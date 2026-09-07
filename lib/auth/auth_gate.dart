import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_models.dart';
import 'password_recovery_screen.dart';
import 'auth_screens.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.authenticatedBuilder,
  });

  final AuthController controller;
  final Widget Function(AuthSession session, AuthController controller)
  authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final session = controller.session;
        if (controller.state == AuthState.initializing) {
          return const _AuthLoadingScreen();
        }
        if (controller.passwordRecoveryActive) {
          return PasswordRecoveryScreen(controller: controller);
        }
        if (controller.state == AuthState.signedIn && session != null) {
          return authenticatedBuilder(session, controller);
        }
        return LoginScreen(controller: controller);
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
