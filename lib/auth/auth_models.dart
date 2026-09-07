enum AuthRole { masterAdmin, owner, customer }

enum AuthState { initializing, signedOut, signingIn, signedIn }

enum WebsiteDataAccess { operationalHealth, privateContent }

class AccountProfile {
  const AccountProfile({
    required this.accountId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.websiteIds,
  });

  final String accountId;
  final String displayName;
  final String email;
  final AuthRole role;
  final String tenantId;
  final Set<String> websiteIds;

  String get roleLabel {
    switch (role) {
      case AuthRole.masterAdmin:
        return 'MASTER ADMIN';
      case AuthRole.owner:
        return 'OWNER';
      case AuthRole.customer:
        return 'CUSTOMER';
    }
  }
}

class AuthSession {
  const AuthSession({
    required this.sessionId,
    required this.profile,
    required this.authenticatedAt,
  });

  final String sessionId;
  final AccountProfile profile;
  final DateTime authenticatedAt;
}
