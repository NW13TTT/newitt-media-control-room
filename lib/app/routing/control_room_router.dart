import 'package:flutter/material.dart';

import '../../ai_control/ai_control_screen.dart';
import '../../analytics/analytics_screen.dart';
import '../../auth/account_profile_screen.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/auth_permissions.dart';
import '../../auth/auth_screens.dart' hide PlatformAdminScreen;
import '../../content_safety/content_safety_screen.dart';
import '../../control_room/cloudflare_screen.dart';
import '../../control_room/commercial_agreements_screen.dart';
import '../../control_room/github_screen.dart';
import '../../control_room/managed_screens.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../help/help_screen.dart';
import '../../security/audit_log_screen.dart';
import '../../security/security_screen.dart';
import '../../backend/control_room_repository.dart';
import '../../websites/website_model.dart';

class ControlRoomRouteContext {
  const ControlRoomRouteContext({
    required this.selectedIndex,
    required this.websites,
    required this.repository,
    required this.session,
    required this.controller,
    required this.onLogout,
    required this.onWebsitesChanged,
    this.helpGuideId,
  });

  final int selectedIndex;
  final List<Website> websites;
  final ControlRoomRepository? repository;
  final AuthSession? session;
  final AuthController? controller;
  final Future<void> Function()? onLogout;
  final VoidCallback onWebsitesChanged;
  final String? helpGuideId;
}

abstract final class ControlRoomRouter {
  static Widget build(ControlRoomRouteContext context) {
    switch (context.selectedIndex) {
      case 0:
        return DashboardScreen(repository: context.repository);
      case 1:
        return AiControlScreen(session: context.session);
      case 2:
        return WebsiteManagementScreen(
          websites: context.websites,
          repository: context.repository,
          session: context.session,
        );
      case 3:
        return MediaLibraryScreen(
          repository: context.repository,
          websites: context.websites,
        );
      case 4:
        return AnalyticsScreen(repository: context.repository);
      case 5:
        return SupportScreen(
          websites: context.websites,
          repository: context.repository,
        );
      case 6:
        return ContentSafetyScreen(
          repository: context.repository,
          session: context.session,
          websites: context.websites,
        );
      case 7:
        return HelpScreen(
          key: ValueKey(context.helpGuideId),
          initialGuideId: context.helpGuideId,
        );
      case 8:
        return CommercialAgreementsScreen(
          repository: context.repository,
          session: context.session,
        );
      case 9:
        if (_isMasterAdmin(context.session)) {
          return GitHubScreen(
            repository: context.repository,
            session: context.session,
            websites: context.websites,
          );
        }
        return _accountProfile(context);
      case 10:
        if (_isMasterAdmin(context.session)) {
          return CloudflareScreen(
            repository: context.repository,
            session: context.session,
            websites: context.websites,
          );
        }
        return SocialLinksScreen(
          websites: context.websites,
          repository: context.repository,
        );
      case 11:
        if (_isMasterAdmin(context.session)) {
          return SecurityScreen(repository: context.repository);
        }
        return _platformAdminOrUnauthorized(context);
      case 12:
        if (_isMasterAdmin(context.session)) {
          return AuditLogScreen(repository: context.repository);
        }
        return const UnauthorizedScreen();
      case 13:
        if (_isMasterAdmin(context.session)) {
          return _accountProfile(context);
        }
        return const UnauthorizedScreen();
      case 14:
        return _platformAdminOrUnauthorized(context);
      default:
        return const DashboardScreen();
    }
  }

  static bool _isMasterAdmin(AuthSession? session) =>
      session?.profile.role == AuthRole.masterAdmin;

  static Widget _accountProfile(ControlRoomRouteContext context) {
    final session = context.session;
    final controller = context.controller;
    final onLogout = context.onLogout;
    if (session == null || controller == null || onLogout == null) {
      return const UnauthorizedScreen();
    }
    return AccountProfileScreen(
      session: session,
      controller: controller,
      onLogout: onLogout,
    );
  }

  static Widget _platformAdminOrUnauthorized(ControlRoomRouteContext context) {
    final session = context.session;
    if (session == null ||
        !RolePermissionChecker(session).can(Permission.manageCustomers)) {
      return const UnauthorizedScreen();
    }
    return PlatformAdminScreen(
      websites: context.websites,
      repository: context.repository,
      onWebsitesChanged: context.onWebsitesChanged,
    );
  }
}
