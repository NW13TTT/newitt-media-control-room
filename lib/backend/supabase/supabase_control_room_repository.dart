import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_models.dart';
import '../control_room_repository.dart';

class SupabaseControlRoomRepository
    implements ControlRoomRepository, ControlRoomRepositoryFactory {
  SupabaseControlRoomRepository(this.client, [this._profile]);

  final SupabaseClient client;
  final AccountProfile? _profile;

  AccountProfile get profile {
    final profile = _profile;
    if (profile == null) {
      throw StateError('An authenticated profile is required.');
    }
    return profile;
  }

  @override
  Future<AnalyticsSummaryRecord> getAnalyticsSummary() async {
    final websites = await client.from('websites').select('id');
    final content = await client
        .from('website_content')
        .select('content_status');
    final media = await client.from('media').select('id');
    final support = await client.from('support_requests').select('status');
    return AnalyticsSummaryRecord(
      websites: websites.length,
      content: content.length,
      published: content
          .where((row) => row['content_status'] == 'PUBLISHED')
          .length,
      media: media.length,
      supportOpen: support
          .where(
            (row) => row['status'] != 'RESOLVED' && row['status'] != 'CLOSED',
          )
          .length,
    );
  }

  @override
  Future<List<CloudflareAccountRecord>> listCloudflareAccounts() async {
    final rows = await client
        .from('cloudflare_accounts')
        .select('display_name, status, last_checked_at');
    return rows
        .map(
          (r) => CloudflareAccountRecord(
            name: r['display_name'],
            status: r['status'],
            lastCheckedAt: DateTime.tryParse(r['last_checked_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<List<CloudflareZoneRecord>> listCloudflareZones() async {
    final rows = await client
        .from('cloudflare_zones')
        .select('website_id, domain, status, ssl_status, last_checked_at');
    return rows
        .map(
          (r) => CloudflareZoneRecord(
            websiteId: r['website_id'],
            domain: r['domain'],
            status: r['status'],
            sslStatus: r['ssl_status'],
            lastCheckedAt: DateTime.tryParse(r['last_checked_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<List<CloudflareDeploymentRecord>> listCloudflareDeployments() async {
    final rows = await client
        .from('cloudflare_deployments')
        .select('website_id, environment, status, deployed_at, safe_error');
    return rows
        .map(
          (r) => CloudflareDeploymentRecord(
            websiteId: r['website_id'],
            environment: r['environment'],
            status: r['status'],
            deployedAt: DateTime.tryParse(r['deployed_at'] ?? ''),
            error: r['safe_error'],
          ),
        )
        .toList();
  }

  @override
  Future<List<GitHubConnectionRecord>> listGitHubConnections() async {
    final rows = await client
        .from('github_connections')
        .select('id, connection_name, github_owner, status, last_checked_at');
    return rows
        .map(
          (r) => GitHubConnectionRecord(
            id: r['id'],
            name: r['connection_name'],
            owner: r['github_owner'],
            status: r['status'],
            lastCheckedAt: DateTime.tryParse(r['last_checked_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<List<GitHubRepositoryRecord>> listGitHubRepositories() async {
    final rows = await client
        .from('github_repositories')
        .select(
          'id, connection_id, owner, name, private, default_branch, repository_url, latest_commit, latest_commit_at',
        );
    return rows
        .map(
          (r) => GitHubRepositoryRecord(
            id: r['id'],
            connectionId: r['connection_id'],
            owner: r['owner'],
            name: r['name'],
            private: r['private'],
            branch: r['default_branch'],
            url: r['repository_url'],
            latestCommit: r['latest_commit'],
            latestCommitAt: DateTime.tryParse(r['latest_commit_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<List<GitHubMappingRecord>> listGitHubMappings() async {
    final rows = await client
        .from('website_github_mappings')
        .select('website_id, repository_id, sync_status, last_synced_at');
    return rows
        .map(
          (r) => GitHubMappingRecord(
            websiteId: r['website_id'],
            repositoryId: r['repository_id'],
            syncStatus: r['sync_status'],
            lastSyncedAt: DateTime.tryParse(r['last_synced_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<void> linkGitHubRepository({
    required String websiteId,
    required String repositoryId,
  }) => client.from('website_github_mappings').insert({
    'website_id': websiteId,
    'repository_id': repositoryId,
  });
  @override
  Future<void> unlinkGitHubRepository(String websiteId) => client
      .from('website_github_mappings')
      .delete()
      .eq('website_id', websiteId);

  CommercialAgreementRecord _agreement(Map<String, dynamic> row) =>
      CommercialAgreementRecord(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        referenceNumber: row['reference_number'] as String?,
        title: row['title'] as String?,
        type: row['agreement_type'] as String,
        status: row['status'] as String,
        description: row['description'] as String?,
        startsAt: DateTime.tryParse(row['starts_at'] as String? ?? ''),
        endsAt: DateTime.tryParse(row['ends_at'] as String? ?? ''),
        renewalDate: DateTime.tryParse(row['renewal_date'] as String? ?? ''),
        billingFrequency: row['billing_frequency'] as String,
        amount: row['amount'] as num?,
        currency: row['currency'] as String,
        paymentTerms: row['payment_terms'] as String?,
        notes: row['notes'] as String?,
      );
  @override
  Future<List<CommercialAgreementRecord>> listCommercialAgreements() async {
    final rows = await client
        .from('commercial_agreements')
        .select(
          'id, tenant_id, reference_number, title, agreement_type, status, description, starts_at, ends_at, renewal_date, billing_frequency, amount, currency, payment_terms, notes',
        )
        .order('created_at', ascending: false);
    return rows.map(_agreement).toList();
  }

  @override
  Future<CommercialAgreementRecord?> getCommercialAgreement(String id) async {
    final row = await client
        .from('commercial_agreements')
        .select(
          'id, tenant_id, reference_number, title, agreement_type, status, description, starts_at, ends_at, renewal_date, billing_frequency, amount, currency, payment_terms, notes',
        )
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _agreement(row);
  }

  @override
  Future<void> saveCommercialAgreement({
    String? id,
    required String tenantId,
    String? referenceNumber,
    String? title,
    required String type,
    required String status,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? renewalDate,
    required String billingFrequency,
    num? amount,
    String currency = 'GBP',
    String? paymentTerms,
    String? notes,
  }) => client.from('commercial_agreements').upsert({
    'id': ?id,
    'tenant_id': tenantId,
    'reference_number': ?referenceNumber?.trim(),
    'title': ?title?.trim(),
    'agreement_type': type,
    'status': status,
    'description': ?description?.trim(),
    'starts_at': ?startsAt?.toIso8601String(),
    'ends_at': ?endsAt?.toIso8601String(),
    'renewal_date': ?renewalDate?.toIso8601String(),
    'billing_frequency': billingFrequency,
    'amount': ?amount,
    'currency': currency,
    'payment_terms': ?paymentTerms?.trim(),
    'notes': ?notes?.trim(),
  });
  @override
  Future<void> changeCommercialAgreementStatus({
    required String id,
    required String status,
    String? cancellationReason,
  }) => client
      .from('commercial_agreements')
      .update({
        'status': status,
        if (status == 'CANCELLED')
          'cancellation_reason': cancellationReason?.trim(),
      })
      .eq('id', id);
  @override
  Future<List<CommercialAgreementItemRecord>> listCommercialAgreementItems(
    String agreementId,
  ) async {
    final rows = await client
        .from('commercial_agreement_items')
        .select(
          'id, agreement_id, service_name, description, quantity, unit_price, amount, billing_frequency, active',
        )
        .eq('agreement_id', agreementId);
    return rows
        .map(
          (r) => CommercialAgreementItemRecord(
            id: r['id'],
            agreementId: r['agreement_id'],
            serviceName: r['service_name'],
            description: r['description'],
            quantity: r['quantity'],
            unitPrice: r['unit_price'],
            amount: r['amount'],
            billingFrequency: r['billing_frequency'],
            active: r['active'],
          ),
        )
        .toList();
  }

  @override
  Future<void> saveCommercialAgreementItem({
    String? id,
    required String agreementId,
    required String serviceName,
    String? description,
    required num quantity,
    required num unitPrice,
    required String billingFrequency,
    bool active = true,
  }) => client.from('commercial_agreement_items').upsert({
    'id': ?id,
    'agreement_id': agreementId,
    'service_name': serviceName.trim(),
    'description': ?description?.trim(),
    'quantity': quantity,
    'unit_price': unitPrice,
    'billing_frequency': billingFrequency,
    'active': active,
  });
  @override
  Future<void> deleteCommercialAgreementItem(String id) =>
      client.from('commercial_agreement_items').delete().eq('id', id);
  @override
  Future<List<CommercialAgreementDocumentRecord>>
  listCommercialAgreementDocuments(String agreementId) async {
    final rows = await client
        .from('commercial_agreement_documents')
        .select('id, document_name, document_type, storage_path, uploaded_at')
        .eq('agreement_id', agreementId);
    return rows
        .map(
          (r) => CommercialAgreementDocumentRecord(
            id: r['id'],
            documentName: r['document_name'],
            documentType: r['document_type'],
            storagePath: r['storage_path'],
            uploadedAt: DateTime.tryParse(r['uploaded_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<List<CommercialAgreementHistoryRecord>> listCommercialAgreementHistory(
    String agreementId,
  ) async {
    final rows = await client
        .from('commercial_agreement_history')
        .select('id, action, created_at')
        .eq('agreement_id', agreementId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (r) => CommercialAgreementHistoryRecord(
            id: r['id'],
            action: r['action'],
            createdAt: DateTime.tryParse(r['created_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  ControlRoomRepository forProfile(AccountProfile profile) =>
      SupabaseControlRoomRepository(client, profile);

  @override
  Future<List<CustomerRecord>> listCustomers() async {
    final rows = await client
        .from('customer_accounts')
        .select('id, name, slug, created_at')
        .order('name');
    return rows
        .map(
          (row) => CustomerRecord(
            id: row['id'] as String,
            name: row['name'] as String,
            slug: row['slug'] as String,
            createdAt: DateTime.tryParse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  CustomerUserRecord _customerUser(Map<String, dynamic> row) =>
      CustomerUserRecord(
        email: row['email'] as String,
        displayName: row['displayName'] as String,
        role: row['role'] as String,
        status: row['status'] as String,
        createdAt: DateTime.tryParse(row['createdAt'] as String? ?? ''),
        lastActiveAt: DateTime.tryParse(row['lastActiveAt'] as String? ?? ''),
      );

  Future<Map<String, dynamic>> _customerUserAction(
    Map<String, dynamic> body,
  ) async {
    final response = await client.functions.invoke(
      'customer-account-management',
      body: body,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<List<CustomerUserRecord>> listCustomerUsers(String customerId) async {
    final data = await _customerUserAction({
      'action': 'list_users',
      'customerId': customerId,
    });
    final users = data['users'] as List<dynamic>? ?? const [];
    return users
        .map((user) => _customerUser(Map<String, dynamic>.from(user as Map)))
        .toList();
  }

  @override
  Future<CustomerUserRecord> inviteCustomerUser({
    required String customerId,
    required String email,
    required String displayName,
  }) async {
    final data = await _customerUserAction({
      'action': 'invite_user',
      'customerId': customerId,
      'email': email,
      'displayName': displayName,
    });
    return _customerUser(Map<String, dynamic>.from(data['user'] as Map));
  }

  @override
  Future<CustomerUserRecord> setCustomerUserDisabled({
    required String customerId,
    required String email,
    required bool disabled,
  }) async {
    final data = await _customerUserAction({
      'action': 'set_status',
      'customerId': customerId,
      'email': email,
      'disabled': disabled,
    });
    return _customerUser(Map<String, dynamic>.from(data['user'] as Map));
  }

  @override
  Future<List<PlatformActivityRecord>> listPlatformActivity() async {
    final rows = await client
        .from('audit_logs')
        .select('action, resource_type, created_at')
        .order('created_at', ascending: false)
        .limit(8);
    return rows
        .map(
          (row) => PlatformActivityRecord(
            action: row['action'] as String,
            resourceType: row['resource_type'] as String,
            createdAt: DateTime.tryParse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<AuditEventRecord>> listAuditEvents() async {
    final rows = await client
        .from('audit_logs')
        .select('action, resource_type, created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map(
          (row) => AuditEventRecord(
            action: row['action'],
            resourceType: row['resource_type'],
            createdAt: DateTime.tryParse(row['created_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<SecuritySummaryRecord> getSecuritySummary() async {
    final events = await listAuditEvents();
    return SecuritySummaryRecord(
      recentAuditEvents: events.length,
      latestAuditEventAt: events.isEmpty ? null : events.first.createdAt,
    );
  }

  @override
  Future<ProvisionedCustomer> provisionCustomer(
    ProvisionCustomerRequest request,
  ) async {
    final response = await client.functions.invoke(
      'provision-customer',
      body: {
        'organizationName': request.organizationName.trim(),
        'accountSlug': request.accountSlug.trim().toLowerCase(),
        'contactName': request.contactName.trim(),
        'contactEmail': request.contactEmail.trim().toLowerCase(),
        'websiteName': request.websiteName?.trim(),
        'websiteDomain': request.websiteDomain?.trim().toLowerCase(),
        'websiteSettings': request.websiteSettings,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final customer = Map<String, dynamic>.from(data['customer'] as Map);
    final invitation = Map<String, dynamic>.from(data['invitation'] as Map);
    return ProvisionedCustomer(
      customer: CustomerRecord(
        id: customer['id'] as String,
        name: customer['name'] as String,
        slug: customer['slug'] as String,
        createdAt: DateTime.tryParse(customer['createdAt'] as String),
      ),
      invitationEmail: invitation['email'] as String,
    );
  }

  @override
  Future<void> createCustomerWebsite(CreateWebsiteRequest request) =>
      client.from('websites').insert({
        'tenant_id': request.tenantId,
        'name': request.name.trim(),
        'domain': request.domain.trim().toLowerCase(),
        'site_slug': ?request.siteSlug?.trim().toLowerCase(),
        'description': ?request.description?.trim(),
        'template_id': ?request.templateId,
        'expires_at': ?request.expiresAt?.toIso8601String(),
        'commercial_agreement_id': ?request.commercialAgreementId,
        'website_type': 'CUSTOMER',
        'connection_status': 'NOT_CONNECTED',
        'online_status': 'UNKNOWN',
        'ssl_status': 'UNKNOWN',
        'domain_status': 'NOT_CONFIGURED',
        'deployment_status': 'UNKNOWN',
        'critical_error_status': 'UNKNOWN',
      });

  @override
  Future<void> updateWebsite({
    required String id,
    required String name,
    required String domain,
    String? siteSlug,
    String? description,
  }) => client
      .from('websites')
      .update({
        'name': name.trim(),
        'domain': domain.trim().toLowerCase(),
        'site_slug': ?siteSlug?.trim().toLowerCase(),
        'description': ?description?.trim(),
      })
      .eq('id', id);

  @override
  Future<void> updateWebsiteManagement({
    required String id,
    required String lifecycle,
    String? templateId,
    DateTime? expiresAt,
    String? commercialAgreementId,
  }) => client
      .from('websites')
      .update({
        'site_lifecycle': lifecycle,
        'template_id': ?templateId,
        'expires_at': ?expiresAt?.toIso8601String(),
        'commercial_agreement_id': ?commercialAgreementId,
      })
      .eq('id', id);

  @override
  Future<List<WebsiteTemplateRecord>> listWebsiteTemplates() async {
    final rows = await client
        .from('website_templates')
        .select('id, name, description, template_type, version, active')
        .order('name');
    return rows
        .map(
          (row) => WebsiteTemplateRecord(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String?,
            type: row['template_type'] as String,
            version: row['version'] as String,
            active: row['active'] as bool,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveWebsiteTemplate({
    String? id,
    required String name,
    String? description,
    required String type,
    required String version,
    required bool active,
  }) => client.from('website_templates').upsert({
    'id': ?id,
    'name': name.trim(),
    'description': ?description?.trim(),
    'template_type': type,
    'version': version.trim(),
    'active': active,
  });

  @override
  Future<void> deleteWebsiteTemplate(String id) =>
      client.from('website_templates').delete().eq('id', id);

  @override
  Future<List<WebsitePageRecord>> listWebsitePages(String websiteId) async {
    final rows = await client
        .from('website_pages')
        .select(
          'id, website_id, title, slug, page_type, visibility, sort_order, published',
        )
        .eq('website_id', websiteId)
        .order('sort_order');
    return rows.map(_websitePage).toList();
  }

  WebsitePageRecord _websitePage(Map<String, dynamic> row) => WebsitePageRecord(
    id: row['id'] as String,
    websiteId: row['website_id'] as String,
    title: row['title'] as String,
    slug: row['slug'] as String,
    type: row['page_type'] as String,
    visible: row['visibility'] as bool,
    sortOrder: row['sort_order'] as int,
    published: row['published'] as bool,
  );

  @override
  Future<void> saveWebsitePage({
    String? id,
    required String websiteId,
    required String title,
    required String slug,
    required String type,
    required bool visible,
    required int sortOrder,
  }) => client.from('website_pages').upsert({
    'id': ?id,
    'website_id': websiteId,
    'title': title.trim(),
    'slug': slug.trim().toLowerCase(),
    'page_type': type,
    'visibility': visible,
    'sort_order': sortOrder,
  });

  @override
  Future<void> deleteWebsitePage(String id) =>
      client.from('website_pages').delete().eq('id', id);

  @override
  Future<void> reorderWebsitePages(List<WebsitePageRecord> pages) async {
    for (var index = 0; index < pages.length; index++) {
      await client
          .from('website_pages')
          .update({'sort_order': index})
          .eq('id', pages[index].id);
    }
  }

  @override
  Future<WebsiteMetrics> getWebsiteMetrics() async {
    final rows = await client
        .from('websites')
        .select('site_lifecycle, expires_at, online_status');
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));
    return WebsiteMetrics(
      total: rows.length,
      published: rows
          .where((row) => row['site_lifecycle'] == 'PUBLISHED')
          .length,
      suspended: rows
          .where((row) => row['site_lifecycle'] == 'SUSPENDED')
          .length,
      online: rows.where((row) => row['online_status'] == 'ONLINE').length,
      expiringSoon: rows.where((row) {
        final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
        return expiry != null && expiry.isAfter(now) && !expiry.isAfter(soon);
      }).length,
    );
  }

  @override
  Future<WebsitePreviewRecord> getWebsitePreview(String websiteId) async {
    final results = await Future.wait([
      listWebsitePages(websiteId),
      listContent(),
    ]);
    return WebsitePreviewRecord(
      websiteId: websiteId,
      pages: results[0] as List<WebsitePageRecord>,
      content: (results[1] as List<ContentRecord>)
          .where((record) => record.websiteId == websiteId)
          .toList(),
    );
  }

  @override
  Future<List<ContentRecord>> listContent() async {
    final rows = await client
        .from('website_content')
        .select(
          'id, website_id, content_key, content, updated_at, content_status',
        )
        .order('updated_at', ascending: false);
    return rows
        .map(
          (row) => ContentRecord(
            id: row['id'] as String,
            websiteId: row['website_id'] as String,
            contentKey: row['content_key'] as String,
            content: Map<String, dynamic>.from(row['content'] as Map),
            updatedAt: DateTime.tryParse(row['updated_at'] as String),
            status: row['content_status'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<ContentSafetySummary> getContentSafetySummary() async {
    final reviews = await client
        .from('content_safety_reviews')
        .select('decision');
    final findings = await client
        .from('content_safety_findings')
        .select('severity, status');
    return ContentSafetySummary(
      safe: reviews.where((review) => review['decision'] == 'SAFE').length,
      review: reviews.where((review) => review['decision'] == 'REVIEW').length,
      blocked: reviews
          .where((review) => review['decision'] == 'BLOCKED')
          .length,
      openFindings: findings
          .where(
            (finding) =>
                finding['status'] == 'OPEN' || finding['status'] == 'REVIEWING',
          )
          .length,
      criticalFindings: findings
          .where(
            (finding) =>
                finding['severity'] == 'CRITICAL' &&
                finding['status'] != 'RESOLVED' &&
                finding['status'] != 'DISMISSED',
          )
          .length,
    );
  }

  @override
  Future<List<ContentSafetyReviewRecord>> listContentSafetyReviews() async {
    final rows = await client
        .from('content_safety_reviews')
        .select(
          'id, tenant_id, website_content_id, decision, explanation, recommended_action, created_at, updated_at, website_content!inner(content_key, website_id)',
        )
        .order('updated_at', ascending: false);
    return rows.map((row) {
      final content = Map<String, dynamic>.from(row['website_content'] as Map);
      return ContentSafetyReviewRecord(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        contentId: row['website_content_id'] as String,
        contentKey: content['content_key'] as String,
        websiteId: content['website_id'] as String,
        decision: row['decision'] as String,
        explanation: row['explanation'] as String?,
        recommendedAction: row['recommended_action'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String),
        updatedAt: DateTime.tryParse(row['updated_at'] as String),
      );
    }).toList();
  }

  @override
  Future<List<ContentSafetyFindingRecord>> listContentSafetyFindings(
    String reviewId,
  ) async {
    final rows = await client
        .from('content_safety_findings')
        .select(
          'id, review_id, category, severity, status, explanation, recommended_action, requires_review, created_at',
        )
        .eq('review_id', reviewId)
        .order('created_at', ascending: false);
    return _contentSafetyFindings(rows);
  }

  @override
  Future<List<ContentSafetyFindingRecord>>
  listAllContentSafetyFindings() async {
    final rows = await client
        .from('content_safety_findings')
        .select(
          'id, review_id, category, severity, status, explanation, recommended_action, requires_review, created_at',
        )
        .order('created_at', ascending: false);
    return _contentSafetyFindings(rows);
  }

  List<ContentSafetyFindingRecord> _contentSafetyFindings(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map(
          (row) => ContentSafetyFindingRecord(
            id: row['id'] as String,
            reviewId: row['review_id'] as String,
            category: row['category'] as String,
            severity: row['severity'] as String,
            status: row['status'] as String,
            explanation: row['explanation'] as String,
            recommendedAction: row['recommended_action'] as String?,
            requiresReview: row['requires_review'] as bool,
            createdAt: DateTime.tryParse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveContentSafetyReview({
    String? id,
    required String contentId,
    required String decision,
    String? explanation,
    String? recommendedAction,
  }) => client.from('content_safety_reviews').upsert({
    'id': ?id,
    'website_content_id': contentId,
    'decision': decision,
    'explanation': ?explanation?.trim(),
    'recommended_action': ?recommendedAction?.trim(),
  }, onConflict: 'website_content_id');

  @override
  Future<void> createContentSafetyFinding({
    required String reviewId,
    required String category,
    required String severity,
    required String explanation,
    String? recommendedAction,
    bool requiresReview = false,
  }) => client.from('content_safety_findings').insert({
    'review_id': reviewId,
    'category': category,
    'severity': severity,
    'explanation': explanation.trim(),
    'recommended_action': ?recommendedAction?.trim(),
    'requires_review': requiresReview,
  });

  @override
  Future<void> updateContentSafetyFindingStatus({
    required String id,
    required String status,
  }) => client
      .from('content_safety_findings')
      .update({'status': status})
      .eq('id', id);

  @override
  Future<void> saveContent({
    required String websiteId,
    required String contentKey,
    required Map<String, dynamic> content,
  }) => client.from('website_content').upsert({
    'tenant_id': profile.tenantId,
    'website_id': websiteId,
    'content_key': contentKey,
    'content': content,
  }, onConflict: 'website_id,content_key');

  @override
  Future<void> publishContent({
    required String websiteId,
    required String contentKey,
  }) => client.rpc(
    'publish_website_content',
    params: {
      'requested_website_id': websiteId,
      'requested_content_key': contentKey,
    },
  );

  @override
  Future<void> deleteContent(String id) =>
      client.from('website_content').delete().eq('id', id);

  @override
  Future<List<MediaRecord>> listMedia({String? query}) async {
    var request = client
        .from('media')
        .select('id, website_id, storage_path, title, metadata, created_at');
    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('title', '%${query.trim()}%');
    }
    final rows = await request.order('created_at', ascending: false);
    return Future.wait(
      rows.map((row) async {
        final metadata = Map<String, dynamic>.from(row['metadata'] as Map);
        final storagePath = row['storage_path'] as String;
        if ('${metadata['type'] ?? ''}'.startsWith('image/')) {
          try {
            metadata['display_url'] = await client.storage
                .from('website-media')
                .createSignedUrl(storagePath, 3600);
          } catch (_) {}
        }
        return MediaRecord(
          id: row['id'] as String,
          websiteId: row['website_id'] as String,
          storagePath: storagePath,
          title: row['title'] as String?,
          metadata: metadata,
          createdAt: DateTime.tryParse(row['created_at'] as String),
        );
      }),
    );
  }

  @override
  Future<void> uploadMedia(MediaUploadRequest request) async {
    if (!profile.websiteIds.contains(request.websiteId)) {
      throw const MediaUploadException(
        MediaUploadStage.authorisation,
        'the selected website is not available to this account',
      );
    }
    final safeName = request.fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final path =
        '${profile.tenantId}/${request.websiteId}/${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}_$safeName';
    try {
      await client.storage
          .from('website-media')
          .uploadBinary(
            path,
            request.bytes,
            fileOptions: FileOptions(contentType: request.mediaType),
          );
    } catch (error) {
      throw MediaUploadException(
        MediaUploadStage.storage,
        _safeReason(error),
      );
    }
    try {
      await client.from('media').insert({
        'tenant_id': profile.tenantId,
        'website_id': request.websiteId,
        'storage_path': path,
        'title': request.fileName,
        'metadata': {'type': request.mediaType},
      });
    } catch (error) {
      await client.storage.from('website-media').remove([path]);
      throw MediaUploadException(
        MediaUploadStage.metadata,
        _safeReason(error),
      );
    }
  }

  static String _safeReason(Object error) => switch (error) {
    StorageException(:final message) => message,
    PostgrestException(:final message) => message,
    _ => '',
  }.trim();

  @override
  Future<void> saveMediaMetadata({
    required String id,
    required String title,
    required Map<String, dynamic> metadata,
  }) => client
      .from('media')
      .update({'title': title.trim(), 'metadata': metadata})
      .eq('id', id);

  @override
  Future<void> deleteMedia(String id) =>
      client.functions.invoke('delete-media', body: {'mediaId': id});

  @override
  Future<List<SocialLinkRecord>> listSocialLinks() async {
    final rows = await client
        .from('social_links')
        .select('id, website_id, platform, url')
        .order('platform');
    return rows
        .map(
          (row) => SocialLinkRecord(
            id: row['id'] as String,
            websiteId: row['website_id'] as String,
            platform: row['platform'] as String,
            url: row['url'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveSocialLink({
    String? id,
    required String websiteId,
    required String platform,
    required String url,
  }) => client.from('social_links').upsert({
    'id': ?id,
    'tenant_id': profile.tenantId,
    'website_id': websiteId,
    'platform': platform.trim(),
    'url': url.trim(),
  });

  @override
  Future<void> deleteSocialLink(String id) =>
      client.from('social_links').delete().eq('id', id);

  @override
  Future<List<SupportRequestRecord>> listSupportRequests() async {
    final rows = await client
        .from('support_requests')
        .select(
          'id, tenant_id, website_id, subject, body, status, category, created_at, updated_at',
        )
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => SupportRequestRecord(
            id: row['id'] as String,
            tenantId: row['tenant_id'] as String,
            websiteId: row['website_id'] as String?,
            subject: row['subject'] as String,
            body: row['body'] as String,
            status: row['status'] as String,
            createdAt: DateTime.tryParse(row['created_at'] as String),
            updatedAt: DateTime.tryParse(row['updated_at'] as String),
            category: row['category'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<ContactEnquiryRecord>> listContactEnquiries() async {
    final rows = await client
        .from('contact_enquiries')
        .select(
          'id, website_id, area, name, email, message, status, internal_notes, created_at, updated_at',
        )
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => ContactEnquiryRecord(
            id: row['id'],
            websiteId: row['website_id'],
            area: row['area'],
            name: row['name'],
            email: row['email'],
            message: row['message'],
            status: row['status'],
            internalNotes: row['internal_notes'],
            createdAt: DateTime.tryParse(row['created_at'] ?? ''),
            updatedAt: DateTime.tryParse(row['updated_at'] ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<void> updateContactEnquiry({
    required String id,
    required String status,
    String? internalNotes,
  }) => client
      .from('contact_enquiries')
      .update({'status': status, 'internal_notes': internalNotes?.trim()})
      .eq('id', id);

  @override
  Future<List<WebsiteFeatureRecord>> listWebsiteFeatures(
    String websiteId,
  ) async {
    final rows = await client
        .from('website_feature_inventory')
        .select(
          'id, website_id, feature_key, evidence_status, connected, enabled, evidence, notes',
        )
        .eq('website_id', websiteId)
        .order('feature_key');
    return rows
        .map(
          (row) => WebsiteFeatureRecord(
            id: row['id'],
            websiteId: row['website_id'],
            featureKey: row['feature_key'],
            evidenceStatus: row['evidence_status'],
            connected: row['connected'],
            enabled: row['enabled'],
            evidence: row['evidence'],
            notes: row['notes'],
          ),
        )
        .toList();
  }

  @override
  Future<void> saveWebsiteFeature({
    String? id,
    required String websiteId,
    required String featureKey,
    required String evidenceStatus,
    required bool connected,
    required bool enabled,
    String? evidence,
    String? notes,
  }) => client.from('website_feature_inventory').upsert({
    'id': ?id,
    'tenant_id': profile.tenantId,
    'website_id': websiteId,
    'feature_key': featureKey,
    'evidence_status': evidenceStatus,
    'connected': connected,
    'enabled': enabled,
    'evidence': ?evidence?.trim(),
    'notes': ?notes?.trim(),
  });

  @override
  Future<List<SupportMessageRecord>> listSupportMessages(
    String requestId,
  ) async {
    final rows = await client
        .from('support_messages')
        .select('id, body, is_internal, created_at')
        .eq('support_request_id', requestId)
        .order('created_at');
    return rows
        .map(
          (row) => SupportMessageRecord(
            id: row['id'] as String,
            body: row['body'] as String,
            isInternal: row['is_internal'] as bool,
            createdAt: DateTime.tryParse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<void> addSupportMessage({
    required String requestId,
    required String body,
    required bool internal,
  }) => client.from('support_messages').insert({
    'support_request_id': requestId,
    'tenant_id': profile.tenantId,
    'author_id': profile.accountId,
    'body': body.trim(),
    'is_internal': internal,
  });

  @override
  Future<void> updateSupportStatus({
    required String requestId,
    required String status,
  }) => client
      .from('support_requests')
      .update({'status': status})
      .eq('id', requestId);

  @override
  Future<void> createSupportRequest({
    String? websiteId,
    required String subject,
    required String body,
    String category = 'OTHER',
  }) => client.from('support_requests').insert({
    'tenant_id': profile.tenantId,
    'website_id': ?websiteId,
    'requester_id': profile.accountId,
    'subject': subject.trim(),
    'body': body.trim(),
    'category': category,
  });
}
