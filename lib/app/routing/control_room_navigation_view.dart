import 'package:flutter/material.dart';

import '../../auth/auth_models.dart';
import '../../backend/supabase/supabase_config.dart';
import '../theme/app_theme.dart';
import 'control_room_navigation.dart';

class ControlRoomSidebar extends StatelessWidget {
  const ControlRoomSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.connectionStatus,
    required this.session,
    required this.onProfile,
  });

  final List<ControlRoomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final SupabaseConnectionStatus connectionStatus;
  final AuthSession? session;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBackground,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Semantics(
            image: true,
            label: 'NEWITT Media Control Room',
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/newitt_media_control_room_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONTROL ROOM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                  color: Color(0xFF697783),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final selected = selectedIndex == index;
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      selected: selected,
                      selectedTileColor: const Color(0xFF102B35),
                      leading: Icon(
                        item.icon,
                        size: 21,
                        color: selected
                            ? const Color(0xFF00D9F5)
                            : AppTheme.muted,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFADB6BD),
                        ),
                      ),
                      onTap: () => onSelected(index),
                    ),
                  ),
                );
              },
            ),
          ),
          _ConnectionStatus(status: connectionStatus),
          Semantics(
            button: onProfile != null,
            label: onProfile == null
                ? 'Local preview account'
                : 'Open account profile',
            child: GestureDetector(
              onTap: onProfile,
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.panelRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF123B45),
                      child: Icon(
                        Icons.person_outline,
                        color: Color(0xFF00D9F5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session?.profile.displayName ?? 'Preview account',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            session == null
                                ? 'Local shell'
                                : session!.profile.roleLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF54D68B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session != null)
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF697783),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlRoomMobileNavigation extends StatelessWidget {
  const ControlRoomMobileNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ControlRoomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppTheme.sidebarBackground,
      indicatorColor: const Color(0xFF102B35),
      selectedIndex: selectedIndex < 4 ? selectedIndex : 4,
      onDestinationSelected: (index) {
        if (index == 4) {
          _showSectionMenu(context);
        } else {
          onSelected(index);
        }
      },
      destinations: [
        NavigationDestination(
          icon: Icon(items[0].icon),
          selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF00D9F5)),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(items[1].icon),
          selectedIcon: const Icon(
            Icons.auto_awesome,
            color: Color(0xFF00D9F5),
          ),
          label: 'AI',
        ),
        NavigationDestination(
          icon: Icon(items[2].icon),
          selectedIcon: const Icon(Icons.language, color: Color(0xFF00D9F5)),
          label: 'Websites',
        ),
        NavigationDestination(
          icon: Icon(items[3].icon),
          selectedIcon: const Icon(
            Icons.photo_library,
            color: Color(0xFF00D9F5),
          ),
          label: 'Media',
        ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz, color: Color(0xFF00D9F5)),
          label: 'More',
        ),
      ],
    );
  }

  void _showSectionMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.sidebarBackground,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Semantics(
                      image: true,
                      label: 'NEWITT Media Control Room',
                      child: Image.asset(
                        'assets/images/newitt_media_control_room_logo.png',
                        width: 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Text(
                      'CONTROL ROOM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                        color: Color(0xFF697783),
                      ),
                    ),
                  ),
                  for (int index = 4; index < items.length; index++)
                    ListTile(
                      selected: selectedIndex == index,
                      selectedTileColor: const Color(0xFF102B35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(
                        items[index].icon,
                        color: selectedIndex == index
                            ? const Color(0xFF00D9F5)
                            : AppTheme.muted,
                      ),
                      title: Text(items[index].label),
                      onTap: () {
                        onSelected(index);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.status});

  final SupabaseConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final connected = status == SupabaseConnectionStatus.connected;
    final statusText = switch (status) {
      SupabaseConnectionStatus.connected => 'Supabase connected',
      SupabaseConnectionStatus.unavailable => 'Supabase unavailable',
      SupabaseConnectionStatus.timedOut => 'Supabase connection timed out',
      SupabaseConnectionStatus.notConfigured => 'Supabase not configured',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Icon(
            connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 15,
            color: connected
                ? const Color(0xFF54D68B)
                : const Color(0xFFFFB454),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              statusText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}
