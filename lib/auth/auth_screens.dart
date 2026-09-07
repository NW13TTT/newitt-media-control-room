import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_models.dart';
import 'auth_service.dart';

const _cyan = Color(0xFF00D9F5);
const _panel = Color(0xFF0D141C);
const _muted = Color(0xFF82909B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthRole _previewRole = AuthRole.masterAdmin;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    await widget.controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    _passwordController.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool signingIn = widget.controller.state == AuthState.signingIn;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandLockup(),
                const SizedBox(height: 36),
                const Text(
                  'Sign in',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access the NEWITT Media Control Room securely.',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                _AuthPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        controller: _emailController,
                        label: 'Email address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _passwordController,
                        label: 'Password',
                        obscureText: true,
                      ),
                      if (widget.controller.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.controller.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE9B949),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: signingIn ? null : _signIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(signingIn ? 'Signing in...' : 'Sign in'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PasswordResetScreen(
                                controller: widget.controller,
                              ),
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.controller.canUseDevelopmentPreview) ...[
                  const SizedBox(height: 20),
                  _AuthPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Development preview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No credentials are accepted or stored. Choose a role to inspect the UI and authorization boundaries.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<AuthRole>(
                          initialValue: _previewRole,
                          decoration: const InputDecoration(
                            labelText: 'Preview role',
                          ),
                          items: AuthRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role)),
                                ),
                              )
                              .toList(),
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _previewRole = role);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => widget.controller
                                .enterDevelopmentPreview(_previewRole),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Open development preview'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _requesting = false;
  bool _requested = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_showRecoveryScreen);
    _showRecoveryScreen();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_showRecoveryScreen);
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showRecoveryScreen() {
    if (!widget.controller.passwordRecoveryActive || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.passwordRecoveryActive) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _requestCode() async {
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _message = null;
    });
    final message = await widget.controller.requestPasswordReset(
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _requested = message == passwordResetRequestedMessage;
      _message = message ?? passwordResetConfigurationMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Reset password',
      subtitle: 'Request a secure email and create your own new password.',
      children: [
        _Field(
          controller: _emailController,
          label: 'Email address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _requesting || _requested ? null : _requestCode,
            child: Text(_requesting ? 'Requesting reset...' : 'Request reset'),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          Text(
            _message!,
            style: TextStyle(
              color: _requested
                  ? const Color(0xFF54D68B)
                  : const Color(0xFFE9B949),
              fontSize: 12,
            ),
          ),
        ],
        if (_requested) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to sign in'),
            ),
          ),
        ],
      ],
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newController.text != _confirmationController.text) {
      setState(() => _message = 'New passwords do not match.');
      return;
    }
    final message = await widget.controller.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    _currentController.clear();
    _newController.clear();
    _confirmationController.clear();
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Change password',
      subtitle: 'Password values are submitted transiently to the future backend and never stored here.',
      children: [
        _Field(
          controller: _currentController,
          label: 'Current password',
          obscureText: true,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _newController,
          label: 'New password',
          obscureText: true,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _confirmationController,
          label: 'Confirm new password',
          obscureText: true,
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          Text(
            _message!,
            style: const TextStyle(color: Color(0xFFE9B949), fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _changePassword,
            child: const Text('Change password'),
          ),
        ),
      ],
    );
  }
}

class PlatformAdminScreen extends StatelessWidget {
  const PlatformAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Platform Admin',
      subtitle:
          'Master Admin controls are separated from customer website content.',
      children: const [
        _AdminCapability(
          icon: Icons.people_outline,
          label: 'Manage customer accounts',
        ),
        _AdminCapability(
          icon: Icons.language_outlined,
          label: 'Manage website profiles',
        ),
        _AdminCapability(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Manage permissions and support access',
        ),
        _AdminCapability(
          icon: Icons.settings_outlined,
          label: 'Manage platform settings',
        ),
        SizedBox(height: 12),
        Text(
          'Backend authorization is required before any administrative action is enabled.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline, color: _cyan, size: 38),
            SizedBox(height: 14),
            Text(
              'Access restricted',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'This area requires explicit authorization for the current account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCapability extends StatelessWidget {
  const _AdminCapability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _cyan),
      title: Text(label),
      trailing: const Icon(Icons.lock_outline, size: 17, color: _muted),
    );
  }
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'NEWITT Media Control Room',
      child: Image.asset(
        'assets/images/newitt_media_control_room_logo.png',
        width: 150,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2A35)),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

String _roleLabel(AuthRole role) {
  switch (role) {
    case AuthRole.masterAdmin:
      return 'Master Admin';
    case AuthRole.owner:
      return 'Owner';
    case AuthRole.customer:
      return 'Customer';
  }
}
