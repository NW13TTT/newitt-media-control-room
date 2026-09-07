import 'website_configuration.dart';

enum WebsiteType { owner, customer }

enum WebsiteConnectionStatus { connected, developmentPreview, notConnected }

enum WebsiteHealthStatus { online, offline, unknown }

enum WebsiteSslStatus { active, inactive, unknown }

enum WebsiteDomainStatus { connected, notConfigured, unknown }

enum WebsiteDeploymentStatus { successful, pending, failed, unknown }

enum WebsiteCriticalErrorStatus { noneReported, errorsReported, unknown }

enum WebsiteLifecycleStatus {
  draft,
  building,
  preview,
  pendingApproval,
  approved,
  published,
  expired,
  archived,
  suspended,
}

enum WebsiteCapability {
  pages,
  gallery,
  photography,
  investigations,
  socialMedia,
  youtube,
  contact,
  seo,
  analytics,
}

class Website {
  const Website({
    this.id,
    this.tenantId,
    required this.name,
    required this.domain,
    required this.type,
    required this.connectionStatus,
    required this.onlineStatus,
    required this.sslStatus,
    required this.domainStatus,
    required this.deploymentStatus,
    required this.lastSuccessfulDeployment,
    required this.criticalErrorStatus,
    required this.capabilities,
    this.lifecycleStatus = WebsiteLifecycleStatus.draft,
    this.templateName,
    this.templateId,
    this.description,
    this.expiresAt,
    this.previewToken,
    this.siteSlug,
    this.commercialAgreementId,
    this.configuration,
  });

  final String? id;
  final String? tenantId;
  final String name;
  final String domain;
  final WebsiteType type;
  final WebsiteConnectionStatus connectionStatus;
  final WebsiteHealthStatus onlineStatus;
  final WebsiteSslStatus sslStatus;
  final WebsiteDomainStatus domainStatus;
  final WebsiteDeploymentStatus deploymentStatus;
  final DateTime? lastSuccessfulDeployment;
  final WebsiteCriticalErrorStatus criticalErrorStatus;
  final Set<WebsiteCapability> capabilities;
  final WebsiteLifecycleStatus lifecycleStatus;
  final String? templateName;
  final String? templateId;
  final String? description;
  final DateTime? expiresAt;
  final String? previewToken;
  final String? siteSlug;
  final String? commercialAgreementId;
  final WebsiteConfiguration? configuration;

  bool get isExpired =>
      lifecycleStatus == WebsiteLifecycleStatus.expired ||
      (expiresAt != null && !expiresAt!.isAfter(DateTime.now()));
}

extension WebsiteTypeLabel on WebsiteType {
  String get label {
    switch (this) {
      case WebsiteType.owner:
        return 'Owner website';
      case WebsiteType.customer:
        return 'Customer website';
    }
  }
}

extension WebsiteCapabilityLabel on WebsiteCapability {
  String get label {
    switch (this) {
      case WebsiteCapability.pages:
        return 'Pages';
      case WebsiteCapability.gallery:
        return 'Gallery';
      case WebsiteCapability.photography:
        return 'Photography';
      case WebsiteCapability.investigations:
        return 'Investigations';
      case WebsiteCapability.socialMedia:
        return 'Social Media';
      case WebsiteCapability.youtube:
        return 'YouTube';
      case WebsiteCapability.contact:
        return 'Contact';
      case WebsiteCapability.seo:
        return 'SEO';
      case WebsiteCapability.analytics:
        return 'Analytics';
    }
  }
}
