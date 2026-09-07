import 'auth_models.dart';

enum Permission {
  viewOwnAccount,
  changeOwnPassword,
  viewOperationalHealth,
  manageOwnWebsite,
  viewPrivateWebsiteContent,
  manageCustomers,
  manageWebsites,
  managePermissions,
  manageSupportAccess,
  managePlatformSettings,
}

abstract interface class PermissionChecker {
  bool can(Permission permission);

  bool canAccessWebsite(
    String websiteId,
    WebsiteDataAccess access, {
    required bool ownerWebsite,
  });
}

class RolePermissionChecker implements PermissionChecker {
  const RolePermissionChecker(this.session);

  final AuthSession session;

  @override
  bool can(Permission permission) {
    switch (session.profile.role) {
      case AuthRole.masterAdmin:
        return permission != Permission.viewPrivateWebsiteContent;
      case AuthRole.owner:
        return {
          Permission.viewOwnAccount,
          Permission.changeOwnPassword,
          Permission.viewOperationalHealth,
          Permission.manageOwnWebsite,
          Permission.viewPrivateWebsiteContent,
        }.contains(permission);
      case AuthRole.customer:
        return {
          Permission.viewOwnAccount,
          Permission.changeOwnPassword,
          Permission.viewOperationalHealth,
          Permission.manageOwnWebsite,
          Permission.viewPrivateWebsiteContent,
        }.contains(permission);
    }
  }

  @override
  bool canAccessWebsite(
    String websiteId,
    WebsiteDataAccess access, {
    required bool ownerWebsite,
  }) {
    final bool scopedToAccount =
        session.profile.websiteIds.contains(websiteId) ||
        session.profile.role == AuthRole.masterAdmin;
    if (!scopedToAccount) {
      return false;
    }

    if (access == WebsiteDataAccess.operationalHealth) {
      return can(Permission.viewOperationalHealth);
    }

    if (session.profile.role == AuthRole.masterAdmin) {
      return ownerWebsite;
    }

    return can(Permission.viewPrivateWebsiteContent);
  }
}
