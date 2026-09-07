import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_models.dart';
import 'auth_permissions.dart';
import 'auth_screens.dart';

class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({
    super.key,
    required this.session,
    required this.controller,
    required this.onLogout,
  });

  final AuthSession session;
  final AuthController controller;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final policy = RolePermissionChecker(session);
    return Scaffold(
      appBar: AppBar(title: const Text('Account profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(profile: session.profile),
                const SizedBox(height: 20),
                _ProfilePanel(
                  title: 'Account details',
                  children: [
                    _DetailRow(
                      label: 'Name',
                      value: session.profile.displayName,
                    ),
                    _DetailRow(label: 'Email', value: session.profile.email),
                    _DetailRow(label: 'Role', value: session.profile.roleLabel),
                    _DetailRow(
                      label: 'Tenant scope',
                      value: session.profile.tenantId,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfilePanel(
                  title: 'Access boundary',
                  children: [
                    Text(
                      _scopeMessage(session.profile.role),
                      style: const TextStyle(
                        color: Color(0xFFB6C3CB),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PermissionRow(
                      label: 'View operational website health',
                      allowed: policy.can(Permission.viewOperationalHealth),
                    ),
                    _PermissionRow(
                      label: 'View private customer content',
                      allowed: policy.can(Permission.viewPrivateWebsiteContent),
                    ),
                    _PermissionRow(
                      label: 'Manage customer accounts',
                      allowed: policy.can(Permission.manageCustomers),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfilePanel(
                  title: 'Security',
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ChangePasswordScreen(controller: controller),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Change password'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _scopeMessage(AuthRole role) {
    switch (role) {
      case AuthRole.masterAdmin:
        return 'This preview role can review platform operations, but private customer website content remains outside its default access scope.';
      case AuthRole.owner:
        return 'This account is scoped to NEWITT Media and its own website. Customer data is not included.';
      case AuthRole.customer:
        return 'This account is scoped to its own tenant and website only. Other customer data is not available.';
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFF123B45),
          child: Icon(Icons.person_outline, color: Color(0xFF00D9F5), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.roleLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF00D9F5),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2A35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF82909B), fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.allowed});

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 18,
            color: allowed ? const Color(0xFF54D68B) : const Color(0xFFE9B949),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB6C3CB)),
            ),
          ),
          Text(
            allowed ? 'Allowed' : 'Restricted',
            style: TextStyle(
              fontSize: 11,
              color: allowed
                  ? const Color(0xFF54D68B)
                  : const Color(0xFFE9B949),
            ),
          ),
        ],
      ),
    );
  }
}
