import 'package:flutter/material.dart';

import '../../auth/auth_models.dart';

class ControlRoomNavigationItem {
  const ControlRoomNavigationItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

abstract final class ControlRoomNavigation {
  static List<ControlRoomNavigationItem> items(AuthRole? role) {
    final isMasterAdmin = role == AuthRole.masterAdmin;
    return [
      const ControlRoomNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'AI Control',
        icon: Icons.auto_awesome_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Websites',
        icon: Icons.language_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Media',
        icon: Icons.photo_library_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Analytics',
        icon: Icons.analytics_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Support',
        icon: Icons.support_agent_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Content Safety',
        icon: Icons.gpp_good_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'How To',
        icon: Icons.menu_book_outlined,
      ),
      const ControlRoomNavigationItem(
        label: 'Commercial Agreements',
        icon: Icons.description_outlined,
      ),
      if (isMasterAdmin)
        const ControlRoomNavigationItem(label: 'GitHub', icon: Icons.code),
      if (isMasterAdmin)
        const ControlRoomNavigationItem(
          label: 'Cloudflare',
          icon: Icons.cloud_outlined,
        ),
      if (isMasterAdmin)
        const ControlRoomNavigationItem(
          label: 'Security',
          icon: Icons.verified_user_outlined,
        ),
      if (isMasterAdmin)
        const ControlRoomNavigationItem(
          label: 'Audit Log',
          icon: Icons.history_outlined,
        ),
      const ControlRoomNavigationItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
      ),
      if (isMasterAdmin)
        const ControlRoomNavigationItem(
          label: 'Platform Admin',
          icon: Icons.admin_panel_settings_outlined,
        ),
    ];
  }
}
