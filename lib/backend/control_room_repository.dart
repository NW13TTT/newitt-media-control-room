import 'dart:typed_data';

import '../auth/auth_models.dart';

class ContentRecord {
  const ContentRecord({
    required this.id,
    required this.websiteId,
    required this.contentKey,
    required this.content,
    required this.updatedAt,
    required this.status,
  });

  final String id;
  final String websiteId;
  final String contentKey;
  final Map<String, dynamic> content;
  final DateTime? updatedAt;
  final String status;
}

class ContentSafetyReviewRecord {
  const ContentSafetyReviewRecord({
    required this.id,
    required this.tenantId,
    required this.contentId,
    required this.contentKey,
    required this.websiteId,
    required this.decision,
    required this.explanation,
    required this.recommendedAction,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String contentId;
  final String contentKey;
  final String websiteId;
  final String decision;
  final String? explanation;
  final String? recommendedAction;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ContentSafetyFindingRecord {
  const ContentSafetyFindingRecord({
    required this.id,
    required this.reviewId,
    required this.category,
    required this.severity,
    required this.status,
    required this.explanation,
    required this.recommendedAction,
    required this.requiresReview,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String category;
  final String severity;
  final String status;
  final String explanation;
  final String? recommendedAction;
  final bool requiresReview;
  final DateTime? createdAt;
}

class ContentSafetySummary {
  const ContentSafetySummary({
    required this.safe,
    required this.review,
    required this.blocked,
    required this.openFindings,
    required this.criticalFindings,
  });

  final int safe;
  final int review;
  final int blocked;
  final int openFindings;
  final int criticalFindings;
}

class CommercialAgreementRecord {
  const CommercialAgreementRecord({
    required this.id,
    required this.tenantId,
    required this.referenceNumber,
    required this.title,
    required this.type,
    required this.status,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.renewalDate,
    required this.billingFrequency,
    required this.amount,
    required this.currency,
    required this.paymentTerms,
    required this.notes,
  });
  final String id;
  final String tenantId;
  final String? referenceNumber;
  final String? title;
  final String type;
  final String status;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? renewalDate;
  final String billingFrequency;
  final num? amount;
  final String currency;
  final String? paymentTerms;
  final String? notes;
}

class CommercialAgreementItemRecord {
  const CommercialAgreementItemRecord({
    required this.id,
    required this.agreementId,
    required this.serviceName,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.billingFrequency,
    required this.active,
  });
  final String id;
  final String agreementId;
  final String serviceName;
  final String? description;
  final num quantity;
  final num unitPrice;
  final num amount;
  final String billingFrequency;
  final bool active;
}

class CommercialAgreementDocumentRecord {
  const CommercialAgreementDocumentRecord({
    required this.id,
    required this.documentName,
    required this.documentType,
    required this.storagePath,
    required this.uploadedAt,
  });
  final String id;
  final String documentName;
  final String documentType;
  final String? storagePath;
  final DateTime? uploadedAt;
}

class CommercialAgreementHistoryRecord {
  const CommercialAgreementHistoryRecord({
    required this.id,
    required this.action,
    required this.createdAt,
  });
  final String id;
  final String action;
  final DateTime? createdAt;
}

class GitHubConnectionRecord {
  const GitHubConnectionRecord({
    required this.id,
    required this.name,
    required this.owner,
    required this.status,
    required this.lastCheckedAt,
  });
  final String id;
  final String name;
  final String? owner;
  final String status;
  final DateTime? lastCheckedAt;
}

class GitHubRepositoryRecord {
  const GitHubRepositoryRecord({
    required this.id,
    required this.connectionId,
    required this.owner,
    required this.name,
    required this.private,
    required this.branch,
    required this.url,
    required this.latestCommit,
    required this.latestCommitAt,
  });
  final String id;
  final String connectionId;
  final String owner;
  final String name;
  final bool private;
  final String branch;
  final String? url;
  final String? latestCommit;
  final DateTime? latestCommitAt;
}

class GitHubMappingRecord {
  const GitHubMappingRecord({
    required this.websiteId,
    required this.repositoryId,
    required this.syncStatus,
    required this.lastSyncedAt,
  });
  final String websiteId;
  final String repositoryId;
  final String syncStatus;
  final DateTime? lastSyncedAt;
}

class CloudflareAccountRecord {
  const CloudflareAccountRecord({
    required this.name,
    required this.status,
    required this.lastCheckedAt,
  });
  final String? name;
  final String status;
  final DateTime? lastCheckedAt;
}

class CloudflareZoneRecord {
  const CloudflareZoneRecord({
    required this.websiteId,
    required this.domain,
    required this.status,
    required this.sslStatus,
    required this.lastCheckedAt,
  });
  final String websiteId;
  final String domain;
  final String? status;
  final String? sslStatus;
  final DateTime? lastCheckedAt;
}

class CloudflareDeploymentRecord {
  const CloudflareDeploymentRecord({
    required this.websiteId,
    required this.environment,
    required this.status,
    required this.deployedAt,
    required this.error,
  });
  final String websiteId;
  final String environment;
  final String status;
  final DateTime? deployedAt;
  final String? error;
}

class AnalyticsSummaryRecord {
  const AnalyticsSummaryRecord({
    required this.websites,
    required this.content,
    required this.published,
    required this.media,
    required this.supportOpen,
  });
  final int websites;
  final int content;
  final int published;
  final int media;
  final int supportOpen;
}

class MediaRecord {
  const MediaRecord({
    required this.id,
    required this.websiteId,
    required this.storagePath,
    required this.title,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String websiteId;
  final String storagePath;
  final String? title;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
}

class SupportMessageRecord {
  const SupportMessageRecord({
    required this.id,
    required this.body,
    required this.isInternal,
    required this.createdAt,
  });
  final String id;
  final String body;
  final bool isInternal;
  final DateTime? createdAt;
}

class MediaUploadRequest {
  const MediaUploadRequest({
    required this.websiteId,
    required this.fileName,
    required this.bytes,
    required this.mediaType,
  });

  final String websiteId;
  final String fileName;
  final Uint8List bytes;
  final String mediaType;
}

enum MediaUploadStage {
  authorisation('checking your website access'),
  storage('sending the file to secure storage'),
  metadata('saving the media details');

  const MediaUploadStage(this.description);

  final String description;
}

/// Names the stage that failed so a beta tester can report it. Carries no
/// storage path, credential or other backend detail.
class MediaUploadException implements Exception {
  const MediaUploadException(this.stage, this.reason);

  final MediaUploadStage stage;
  final String reason;

  @override
  String toString() => 'failed while ${stage.description}'
      '${reason.isEmpty ? '' : ' ($reason)'}';
}

class SocialLinkRecord {
  const SocialLinkRecord({
    required this.id,
    required this.websiteId,
    required this.platform,
    required this.url,
  });

  final String id;
  final String websiteId;
  final String platform;
  final String url;
}

class SupportRequestRecord {
  const SupportRequestRecord({
    required this.id,
    required this.tenantId,
    required this.websiteId,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
  });

  final String id;
  final String tenantId;
  final String? websiteId;
  final String subject;
  final String body;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String category;
}

class ContactEnquiryRecord {
  const ContactEnquiryRecord({
    required this.id,
    required this.websiteId,
    required this.area,
    required this.name,
    required this.email,
    required this.message,
    required this.status,
    required this.internalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String websiteId;
  final String area;
  final String name;
  final String email;
  final String message;
  final String status;
  final String? internalNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class WebsiteFeatureRecord {
  const WebsiteFeatureRecord({
    required this.id,
    required this.websiteId,
    required this.featureKey,
    required this.evidenceStatus,
    required this.connected,
    required this.enabled,
    required this.evidence,
    required this.notes,
  });

  final String id;
  final String websiteId;
  final String featureKey;
  final String evidenceStatus;
  final bool connected;
  final bool enabled;
  final String? evidence;
  final String? notes;
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime? createdAt;
}

class CustomerUserRecord {
  const CustomerUserRecord({
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String email;
  final String displayName;
  final String role;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
}

class CreateWebsiteRequest {
  const CreateWebsiteRequest({
    required this.tenantId,
    required this.name,
    required this.domain,
    this.siteSlug,
    this.description,
    this.templateId,
    this.expiresAt,
    this.commercialAgreementId,
  });

  final String tenantId;
  final String name;
  final String domain;
  final String? siteSlug;
  final String? description;
  final String? templateId;
  final DateTime? expiresAt;
  final String? commercialAgreementId;
}

class WebsiteTemplateRecord {
  const WebsiteTemplateRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.version,
    required this.active,
  });

  final String id;
  final String name;
  final String? description;
  final String type;
  final String version;
  final bool active;
}

class WebsitePageRecord {
  const WebsitePageRecord({
    required this.id,
    required this.websiteId,
    required this.title,
    required this.slug,
    required this.type,
    required this.visible,
    required this.sortOrder,
    required this.published,
  });

  final String id;
  final String websiteId;
  final String title;
  final String slug;
  final String type;
  final bool visible;
  final int sortOrder;
  final bool published;
}

class WebsiteMetrics {
  const WebsiteMetrics({
    required this.total,
    required this.published,
    required this.expiringSoon,
    required this.suspended,
    required this.online,
  });

  final int total;
  final int published;
  final int expiringSoon;
  final int suspended;
  final int online;
}

class WebsitePreviewRecord {
  const WebsitePreviewRecord({
    required this.websiteId,
    required this.pages,
    required this.content,
  });

  final String websiteId;
  final List<WebsitePageRecord> pages;
  final List<ContentRecord> content;
}

class ProvisionCustomerRequest {
  const ProvisionCustomerRequest({
    required this.organizationName,
    required this.accountSlug,
    required this.contactName,
    required this.contactEmail,
    this.websiteName,
    this.websiteDomain,
    this.websiteSettings = const {},
  });

  final String organizationName;
  final String accountSlug;
  final String contactName;
  final String contactEmail;
  final String? websiteName;
  final String? websiteDomain;
  final Map<String, dynamic> websiteSettings;
}

class ProvisionedCustomer {
  const ProvisionedCustomer({
    required this.customer,
    required this.invitationEmail,
  });

  final CustomerRecord customer;
  final String invitationEmail;
}

class PlatformActivityRecord {
  const PlatformActivityRecord({
    required this.action,
    required this.resourceType,
    required this.createdAt,
  });

  final String action;
  final String resourceType;
  final DateTime? createdAt;
}

class AuditEventRecord {
  const AuditEventRecord({
    required this.action,
    required this.resourceType,
    required this.createdAt,
  });
  final String action;
  final String resourceType;
  final DateTime? createdAt;
}

class SecuritySummaryRecord {
  const SecuritySummaryRecord({
    required this.recentAuditEvents,
    required this.latestAuditEventAt,
  });

  final int recentAuditEvents;
  final DateTime? latestAuditEventAt;
}

abstract interface class ControlRoomRepository {
  Future<AnalyticsSummaryRecord> getAnalyticsSummary();
  Future<List<CloudflareAccountRecord>> listCloudflareAccounts();
  Future<List<CloudflareZoneRecord>> listCloudflareZones();
  Future<List<CloudflareDeploymentRecord>> listCloudflareDeployments();
  Future<List<GitHubConnectionRecord>> listGitHubConnections();
  Future<List<GitHubRepositoryRecord>> listGitHubRepositories();
  Future<List<GitHubMappingRecord>> listGitHubMappings();
  Future<void> linkGitHubRepository({
    required String websiteId,
    required String repositoryId,
  });
  Future<void> unlinkGitHubRepository(String websiteId);
  Future<List<CommercialAgreementRecord>> listCommercialAgreements();
  Future<CommercialAgreementRecord?> getCommercialAgreement(String id);
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
  });
  Future<void> changeCommercialAgreementStatus({
    required String id,
    required String status,
    String? cancellationReason,
  });
  Future<List<CommercialAgreementItemRecord>> listCommercialAgreementItems(
    String agreementId,
  );
  Future<void> saveCommercialAgreementItem({
    String? id,
    required String agreementId,
    required String serviceName,
    String? description,
    required num quantity,
    required num unitPrice,
    required String billingFrequency,
    bool active = true,
  });
  Future<void> deleteCommercialAgreementItem(String id);
  Future<List<CommercialAgreementDocumentRecord>>
  listCommercialAgreementDocuments(String agreementId);
  Future<List<CommercialAgreementHistoryRecord>> listCommercialAgreementHistory(
    String agreementId,
  );
  Future<List<CustomerRecord>> listCustomers();
  Future<List<CustomerUserRecord>> listCustomerUsers(String customerId);
  Future<CustomerUserRecord> inviteCustomerUser({
    required String customerId,
    required String email,
    required String displayName,
  });
  Future<CustomerUserRecord> setCustomerUserDisabled({
    required String customerId,
    required String email,
    required bool disabled,
  });
  Future<List<PlatformActivityRecord>> listPlatformActivity();
  Future<List<AuditEventRecord>> listAuditEvents();
  Future<SecuritySummaryRecord> getSecuritySummary();
  Future<ProvisionedCustomer> provisionCustomer(
    ProvisionCustomerRequest request,
  );
  Future<void> createCustomerWebsite(CreateWebsiteRequest request);
  Future<void> updateWebsite({
    required String id,
    required String name,
    required String domain,
    String? siteSlug,
    String? description,
  });
  Future<void> updateWebsiteManagement({
    required String id,
    required String lifecycle,
    String? templateId,
    DateTime? expiresAt,
    String? commercialAgreementId,
  });
  Future<List<WebsiteTemplateRecord>> listWebsiteTemplates();
  Future<void> saveWebsiteTemplate({
    String? id,
    required String name,
    String? description,
    required String type,
    required String version,
    required bool active,
  });
  Future<void> deleteWebsiteTemplate(String id);
  Future<List<WebsitePageRecord>> listWebsitePages(String websiteId);
  Future<void> saveWebsitePage({
    String? id,
    required String websiteId,
    required String title,
    required String slug,
    required String type,
    required bool visible,
    required int sortOrder,
  });
  Future<void> deleteWebsitePage(String id);
  Future<void> reorderWebsitePages(List<WebsitePageRecord> pages);
  Future<WebsiteMetrics> getWebsiteMetrics();
  Future<WebsitePreviewRecord> getWebsitePreview(String websiteId);
  Future<List<ContentRecord>> listContent();
  Future<ContentSafetySummary> getContentSafetySummary();
  Future<List<ContentSafetyReviewRecord>> listContentSafetyReviews();
  Future<List<ContentSafetyFindingRecord>> listContentSafetyFindings(
    String reviewId,
  );
  Future<List<ContentSafetyFindingRecord>> listAllContentSafetyFindings();
  Future<void> saveContentSafetyReview({
    String? id,
    required String contentId,
    required String decision,
    String? explanation,
    String? recommendedAction,
  });
  Future<void> createContentSafetyFinding({
    required String reviewId,
    required String category,
    required String severity,
    required String explanation,
    String? recommendedAction,
    bool requiresReview = false,
  });
  Future<void> updateContentSafetyFindingStatus({
    required String id,
    required String status,
  });
  Future<void> saveContent({
    required String websiteId,
    required String contentKey,
    required Map<String, dynamic> content,
  });
  Future<void> publishContent({
    required String websiteId,
    required String contentKey,
  });
  Future<void> deleteContent(String id);
  Future<List<MediaRecord>> listMedia({String? query});
  Future<void> uploadMedia(MediaUploadRequest request);
  Future<void> saveMediaMetadata({
    required String id,
    required String title,
    required Map<String, dynamic> metadata,
  });
  Future<void> deleteMedia(String id);
  Future<List<SocialLinkRecord>> listSocialLinks();
  Future<void> saveSocialLink({
    String? id,
    required String websiteId,
    required String platform,
    required String url,
  });
  Future<void> deleteSocialLink(String id);
  Future<List<SupportRequestRecord>> listSupportRequests();
  Future<List<SupportMessageRecord>> listSupportMessages(String requestId);
  Future<void> addSupportMessage({
    required String requestId,
    required String body,
    required bool internal,
  });
  Future<void> updateSupportStatus({
    required String requestId,
    required String status,
  });
  Future<List<ContactEnquiryRecord>> listContactEnquiries();
  Future<void> updateContactEnquiry({
    required String id,
    required String status,
    String? internalNotes,
  });
  Future<List<WebsiteFeatureRecord>> listWebsiteFeatures(String websiteId);
  Future<void> saveWebsiteFeature({
    String? id,
    required String websiteId,
    required String featureKey,
    required String evidenceStatus,
    required bool connected,
    required bool enabled,
    String? evidence,
    String? notes,
  });
  Future<void> createSupportRequest({
    String? websiteId,
    required String subject,
    required String body,
    String category = 'OTHER',
  });
}

abstract interface class ControlRoomRepositoryFactory {
  ControlRoomRepository forProfile(AccountProfile profile);
}
