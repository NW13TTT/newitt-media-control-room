import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_service.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _message;
  bool _saving = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    debugPrint('RECOVERY_SCREEN_SHOWN');
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_password.text.isEmpty || _confirmation.text.isEmpty) {
      setState(() => _message = 'Enter and confirm your new password.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _message = 'Use a password with at least 8 characters.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = 'New passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final message = await widget.controller.completePasswordRecovery(
      newPassword: _password.text,
    );
    _password.clear();
    _confirmation.clear();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _complete = message == passwordRecoveryUpdatedMessage;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set a new password',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a new password for your Control Room account.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_complete,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmation,
                obscureText: true,
                enabled: !_complete,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _complete
                        ? const Color(0xFF54D68B)
                        : const Color(0xFFE9B949),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || _complete ? null : _save,
                  child: Text(
                    _saving ? 'Updating password...' : 'Set new password',
                  ),
                ),
              ),
              if (_complete) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Return to sign in'),
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
