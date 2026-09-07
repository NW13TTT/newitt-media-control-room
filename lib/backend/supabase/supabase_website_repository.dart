import 'package:supabase_flutter/supabase_flutter.dart';

import '../../websites/website_model.dart';
import '../../websites/website_configuration.dart';
import '../website_repository.dart';

class SupabaseWebsiteRepository implements WebsiteRepository {
  SupabaseWebsiteRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Website>> listAccessibleWebsites() async {
    final rows = await client.from('websites').select('''
      id,
      tenant_id,
      name,
      domain,
      website_type,
      connection_status,
      online_status,
      ssl_status,
      domain_status,
      deployment_status,
      last_successful_deployment,
      critical_error_status,
      website_settings,
      site_lifecycle,
      description,
      expires_at,
      preview_token,
      website_templates(name),
      website_capabilities(capability)
    ''');

    return rows.map(_websiteFromRow).toList();
  }

  Website _websiteFromRow(Map<String, dynamic> row) {
    final capabilityRows = row['website_capabilities'] as List<dynamic>? ?? [];
    return Website(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      name: row['name'] as String,
      domain: row['domain'] as String,
      type: _websiteType(row['website_type'] as String),
      connectionStatus: _connectionStatus(row['connection_status'] as String),
      onlineStatus: _healthStatus(row['online_status'] as String),
      sslStatus: _sslStatus(row['ssl_status'] as String),
      domainStatus: _domainStatus(row['domain_status'] as String),
      deploymentStatus: _deploymentStatus(row['deployment_status'] as String),
      lastSuccessfulDeployment: _dateTime(row['last_successful_deployment']),
      criticalErrorStatus: _errorStatus(row['critical_error_status'] as String),
      capabilities: {
        for (final capabilityRow in capabilityRows)
          _capabilityFromString(capabilityRow['capability'] as String),
      },
      lifecycleStatus: _lifecycleStatus(row['site_lifecycle'] as String?),
      templateName: (row['website_templates'] as Map?)?['name'] as String?,
      description: row['description'] as String?,
      expiresAt: _dateTime(row['expires_at']),
      previewToken: row['preview_token'] as String?,
      configuration: WebsiteConfiguration.fromSettings(
        Map<String, dynamic>.from(row['website_settings'] as Map? ?? const {}),
        fallbackDomain: row['domain'] as String,
      ),
    );
  }

  static DateTime? _dateTime(Object? value) {
    return value == null ? null : DateTime.tryParse(value as String);
  }

  static WebsiteType _websiteType(String value) {
    return value == 'OWNER' ? WebsiteType.owner : WebsiteType.customer;
  }

  static WebsiteConnectionStatus _connectionStatus(String value) {
    switch (value) {
      case 'CONNECTED':
        return WebsiteConnectionStatus.connected;
      case 'NOT_CONNECTED':
        return WebsiteConnectionStatus.notConnected;
      default:
        return WebsiteConnectionStatus.developmentPreview;
    }
  }

  static WebsiteHealthStatus _healthStatus(String value) {
    switch (value) {
      case 'ONLINE':
        return WebsiteHealthStatus.online;
      case 'OFFLINE':
        return WebsiteHealthStatus.offline;
      default:
        return WebsiteHealthStatus.unknown;
    }
  }

  static WebsiteSslStatus _sslStatus(String value) {
    switch (value) {
      case 'ACTIVE':
        return WebsiteSslStatus.active;
      case 'INACTIVE':
        return WebsiteSslStatus.inactive;
      default:
        return WebsiteSslStatus.unknown;
    }
  }

  static WebsiteDomainStatus _domainStatus(String value) {
    switch (value) {
      case 'CONNECTED':
        return WebsiteDomainStatus.connected;
      case 'NOT_CONFIGURED':
        return WebsiteDomainStatus.notConfigured;
      default:
        return WebsiteDomainStatus.unknown;
    }
  }

  static WebsiteDeploymentStatus _deploymentStatus(String value) {
    switch (value) {
      case 'SUCCESSFUL':
        return WebsiteDeploymentStatus.successful;
      case 'PENDING':
        return WebsiteDeploymentStatus.pending;
      case 'FAILED':
        return WebsiteDeploymentStatus.failed;
      default:
        return WebsiteDeploymentStatus.unknown;
    }
  }

  static WebsiteCriticalErrorStatus _errorStatus(String value) {
    switch (value) {
      case 'ACTIVE':
        return WebsiteCriticalErrorStatus.errorsReported;
      case 'INACTIVE':
        return WebsiteCriticalErrorStatus.noneReported;
      default:
        return WebsiteCriticalErrorStatus.unknown;
    }
  }

  static WebsiteLifecycleStatus _lifecycleStatus(String? value) =>
      switch (value) {
        'BUILDING' => WebsiteLifecycleStatus.building,
        'PREVIEW' => WebsiteLifecycleStatus.preview,
        'PENDING_APPROVAL' => WebsiteLifecycleStatus.pendingApproval,
        'APPROVED' => WebsiteLifecycleStatus.approved,
        'PUBLISHED' => WebsiteLifecycleStatus.published,
        'EXPIRED' => WebsiteLifecycleStatus.expired,
        'ARCHIVED' => WebsiteLifecycleStatus.archived,
        'SUSPENDED' => WebsiteLifecycleStatus.suspended,
        _ => WebsiteLifecycleStatus.draft,
      };

  static WebsiteCapability _capabilityFromString(String value) {
    return WebsiteCapability.values.firstWhere(
      (capability) => capability.name == value,
      orElse: () => WebsiteCapability.pages,
    );
  }
}
