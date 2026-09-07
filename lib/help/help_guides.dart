import 'package:flutter/material.dart';

class HelpGuide {
  const HelpGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.steps,
    required this.note,
    required this.icon,
  });
  final String id;
  final String title;
  final String category;
  final String summary;
  final List<String> steps;
  final String note;
  final IconData icon;
}

const helpCategories = [
  'All',
  'Getting started',
  'Website',
  'Content',
  'Safety',
  'Media',
  'Social',
  'AI',
  'Account',
];

const helpGuides = [
  HelpGuide(
    id: 'security',
    title: 'Security',
    category: 'Safety',
    summary:
        'Review the backend security controls and recent safe audit activity.',
    steps: [
      'Open Security from the administrator navigation.',
      'Review the recent activity count and safe event list.',
      'Use Audit Log to search recorded actions by action or resource type.',
    ],
    note: 'Audit details are limited to authorised administrators. The Control Room never exposes credentials, authentication data, or raw audit metadata here.',
    icon: Icons.verified_user_outlined,
  ),
  HelpGuide(
    id: 'analytics',
    title: 'Analytics',
    category: 'Getting started',
    summary: 'Review aggregate operational information for your Control Room.',
    steps: [
      'Open Analytics from the main navigation.',
      'Review operational counts for the current account scope.',
      'Visitor analytics remain unavailable until an external provider is connected.',
    ],
    note: 'Analytics is tenant-scoped. Visitor Analytics says Not Connected because no visitor tracking provider is configured.',
    icon: Icons.analytics_outlined,
  ),
  HelpGuide(
    id: 'cloudflare',
    title: 'Cloudflare',
    category: 'Website',
    summary: 'Cloudflare provides protected website infrastructure managed by NEWITT Media.',
    steps: [
      'Open Cloudflare to view the recorded connection and website infrastructure status.',
      'Connected means a verified configuration is available; Not Configured means setup is pending.',
      'Contact NEWITT Media if an SSL/TLS or deployment status shows an error.',
    ],
    note: 'Customers can view their website status but NEWITT Media manages Cloudflare infrastructure, domains, and deployment.',
    icon: Icons.cloud_outlined,
  ),
  HelpGuide(
    id: 'github-integration',
    title: 'GitHub Integration',
    category: 'Website',
    summary: 'GitHub keeps website source changes version controlled for NEWITT Media.',
    steps: [
      'NEWITT Media links an approved website to a selected repository.',
      'Use GitHub status to review the connection and version information.',
      'Cloudflare deployment is managed separately after source is ready.',
    ],
    note: 'Customers do not need GitHub access. Repository credentials remain protected and are never shown in the Control Room.',
    icon: Icons.code,
  ),
  HelpGuide(
    id: 'commercial-agreements',
    title: 'Commercial Agreements',
    category: 'Account',
    summary:
        'Review the services and commercial terms recorded for your account.',
    steps: [
      'Open Commercial Agreements from the main navigation.',
      'Review the agreement status, dates, services, and available documents.',
      'Contact NEWITT Media if you need to discuss a recorded agreement.',
    ],
    note: 'An agreement records commercial terms. It is not a payment page, and renewal dates do not renew an agreement automatically.',
    icon: Icons.description_outlined,
  ),
  HelpGuide(
    id: 'content-safety',
    title: 'Content Safety',
    category: 'Safety',
    summary: 'Review safety guidance before content is published.',
    steps: [
      'Open Content Safety from the main navigation.',
      'Review any safety status and recommended action for your content.',
      'Resolve flagged issues before returning content to the approval workflow.',
    ],
    note: 'Safety guidance does not publish content or replace the normal approval workflow.',
    icon: Icons.gpp_good_outlined,
  ),
  HelpGuide(
    id: 'dashboard',
    title: 'Dashboard',
    category: 'Getting started',
    summary: 'See the current state of your Control Room.',
    steps: [
      'Open Dashboard from the main navigation.',
      'Review website and content status cards.',
      'Use the navigation to continue to the area you need.',
    ],
    note: 'Dashboard information is scoped to your signed-in account.',
    icon: Icons.dashboard_outlined,
  ),
  HelpGuide(
    id: 'temporary-websites',
    title: 'Temporary Websites',
    category: 'Website',
    summary:
        'Manage time-limited websites within the normal approval boundary.',
    steps: [
      'Open Websites and select the customer website.',
      'Master Admin can set the lifecycle, template, agreement reference, and expiry.',
      'Use Private preview to review pages and drafts before publication.',
    ],
    note: 'Expiry and publication eligibility are enforced by the Control Room database. Temporary websites do not connect domains or deployment services.',
    icon: Icons.timer_outlined,
  ),
  HelpGuide(
    id: 'website-management',
    title: 'Website Management',
    category: 'Website',
    summary: 'Review website information and operational status.',
    steps: [
      'Open Websites.',
      'Choose the website you want to manage.',
      'Review its health and content records.',
    ],
    note: 'You can only manage websites available to your account.',
    icon: Icons.language_outlined,
  ),
  HelpGuide(
    id: 'content-management',
    title: 'Content Management',
    category: 'Content',
    summary: 'Create and manage structured website content.',
    steps: [
      'Open Websites and find Content records.',
      'Choose a content area and add or edit a record.',
      'Save your draft before requesting publication.',
    ],
    note: 'Saved drafts do not change published website content.',
    icon: Icons.article_outlined,
  ),
  HelpGuide(
    id: 'draft-preview-publish',
    title: 'Draft, Preview and Publish',
    category: 'Content',
    summary: 'Prepare content safely before it becomes live.',
    steps: [
      'Edit a content record to create a draft.',
      'Use Preview to review the current draft.',
      'Publish only when your approval process permits it.',
    ],
    note: 'Preview never publishes content.',
    icon: Icons.preview_outlined,
  ),
  HelpGuide(
    id: 'media-library',
    title: 'Media Library',
    category: 'Media',
    summary: 'Organise media used by your website.',
    steps: [
      'Open Media from the main navigation.',
      'Search or filter the tenant media library.',
      'Edit metadata before using an item in content.',
    ],
    note: 'Media stays private to your tenant.',
    icon: Icons.photo_library_outlined,
  ),
  HelpGuide(
    id: 'upload-media',
    title: 'Uploading Media',
    category: 'Media',
    summary: 'Add photos, video, or audio securely.',
    steps: [
      'Select Upload media.',
      'Choose supported files from your device.',
      'Wait for the upload confirmation before leaving the screen.',
    ],
    note: 'Only your accessible website path can receive uploads.',
    icon: Icons.upload_file_outlined,
  ),
  HelpGuide(
    id: 'media-information',
    title: 'Editing Media Information',
    category: 'Media',
    summary: 'Keep media clear and easy to find.',
    steps: [
      'Select Edit media details.',
      'Update title, type, caption, category, location, date, or featured state.',
      'Save your changes.',
    ],
    note: 'Editing information does not make media public.',
    icon: Icons.edit_outlined,
  ),
  HelpGuide(
    id: 'social-links',
    title: 'Social Media Links',
    category: 'Social',
    summary: 'Manage links displayed on your website.',
    steps: [
      'Open Social links.',
      'Add or edit a platform and website link.',
      'Save and confirm the link.',
    ],
    note: 'Do not enter social-media passwords in the Control Room.',
    icon: Icons.share_outlined,
  ),
  HelpGuide(
    id: 'ai-control',
    title: 'AI Control Box',
    category: 'AI',
    summary: 'Prepare requests with clear safety boundaries.',
    steps: [
      'Open AI Control.',
      'Describe the result you want.',
      'Review the local request result.',
    ],
    note: 'AI remains optional and may be unavailable.',
    icon: Icons.auto_awesome_outlined,
  ),
  HelpGuide(
    id: 'ai-permissions',
    title: 'AI Permissions',
    category: 'AI',
    summary: 'Understand what AI may assist with.',
    steps: [
      'Open AI Control.',
      'Read the current permission label.',
      'Treat publishing as an explicit human action.',
    ],
    note:
        'AI cannot change security, infrastructure, payments, or deployments.',
    icon: Icons.shield_outlined,
  ),
  HelpGuide(
    id: 'staging-approval',
    title: 'Staging and Approval',
    category: 'Content',
    summary: 'Keep important changes under human control.',
    steps: [
      'Save content as a draft.',
      'Preview it before submitting it for approval.',
      'Use the approved publication workflow when available.',
    ],
    note: 'Published content is not changed by a draft edit.',
    icon: Icons.approval_outlined,
  ),
  HelpGuide(
    id: 'settings',
    title: 'Settings',
    category: 'Account',
    summary: 'Manage account and security options.',
    steps: [
      'Open your account profile.',
      'Review your account boundary.',
      'Use Sign out when you finish on a shared device.',
    ],
    note: 'Your tenant and role are managed securely by the platform.',
    icon: Icons.settings_outlined,
  ),
];
