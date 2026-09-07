import 'dart:async';
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newitt_media_control_room/app/app.dart';
import 'package:newitt_media_control_room/ai_control/ai_control_screen.dart';
import 'package:newitt_media_control_room/ai_control/ai_service.dart';
import 'package:newitt_media_control_room/ai_control/ai_permissions.dart';
import 'package:newitt_media_control_room/auth/auth_controller.dart';
import 'package:newitt_media_control_room/auth/auth_gate.dart';
import 'package:newitt_media_control_room/auth/auth_models.dart';
import 'package:newitt_media_control_room/auth/auth_permissions.dart';
import 'package:newitt_media_control_room/backend/control_room_repository.dart';
import 'package:newitt_media_control_room/backend/website_repository.dart';
import 'package:newitt_media_control_room/control_room/managed_screens.dart';
import 'package:newitt_media_control_room/control_room/content_section_editor.dart';
import 'package:newitt_media_control_room/control_room/contact_enquiries_screen.dart';
import 'package:newitt_media_control_room/control_room/website_feature_inventory_screen.dart';
import 'package:newitt_media_control_room/content_safety/content_safety_screen.dart';
import 'package:newitt_media_control_room/help/help_screen.dart';
import 'package:newitt_media_control_room/help/smart_help_button.dart';
import 'package:newitt_media_control_room/dashboard/dashboard_screen.dart';
import 'package:newitt_media_control_room/main.dart';
import 'package:newitt_media_control_room/security/audit_log_screen.dart';
import 'package:newitt_media_control_room/security/security_screen.dart';
import 'package:newitt_media_control_room/websites/website_model.dart';

void main() {
  testWidgets('Control Room home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NewittApp(home: ControlRoomHome()));
    await tester.pumpAndSettle();

    expect(find.text('Control Room'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.tap(find.text('AI Control').first);
    await tester.pumpAndSettle();
    expect(find.text('AI Control'), findsWidgets);

    await tester.tap(find.text('Websites').first);
    await tester.pumpAndSettle();
    expect(find.text('Control Room unavailable'), findsOneWidget);
  });

  testWidgets('Control Room navigation opens every section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NewittApp(home: ControlRoomHome()));
    await tester.pumpAndSettle();

    for (final section in [
      'Websites',
      'Media',
      'Analytics',
      'Support',
      'How To',
      'Settings',
    ]) {
      final navigationItem = find.text(section).first;
      await tester.ensureVisible(navigationItem);
      await tester.tap(navigationItem);
      await tester.pumpAndSettle();
      expect(find.text(section), findsWidgets);
    }
  });

  testWidgets('Security and Audit Log are only shown to administrators', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      NewittApp(
        home: ControlRoomHome(
          session: _session(AuthRole.customer),
          websiteRepository: _WebsiteRepository(),
          controlRoomRepositoryFactory: _RepositoryFactory(_Repository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: find.text('Security'), matching: find.byType(ListTile)),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Audit Log'),
        matching: find.byType(ListTile),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      NewittApp(
        home: ControlRoomHome(
          session: _session(AuthRole.masterAdmin),
          websiteRepository: _WebsiteRepository(),
          controlRoomRepositoryFactory: _RepositoryFactory(_AuditRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: find.text('Security'), matching: find.byType(ListTile)),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Audit Log'),
        matching: find.byType(ListTile),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Security and Audit Log display only safe event fields', (
    tester,
  ) async {
    final repository = _AuditRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(body: SecurityScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recent security activity: 2'), findsOneWidget);
    expect(find.text('website.updated'), findsOneWidget);

    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(body: AuditLogScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('website.updated'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'support');
    await tester.pumpAndSettle();
    expect(find.text('support.request.created'), findsOneWidget);
    expect(find.text('website.updated'), findsNothing);
  });

  testWidgets('repository failures show a safe retry state', (tester) async {
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: WebsiteManagementScreen(
            websites: const [],
            repository: _FailingContentRepository(),
            session: _session(AuthRole.customer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load this information'), findsOneWidget);
    expect(find.textContaining('database'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('Master Admin can manage existing customer users safely', (
    tester,
  ) async {
    final repository = _CustomerUsersRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: PlatformAdminScreen(
            websites: const [],
            repository: repository,
            onWebsitesChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Essex Paranormal'), findsOneWidget);
    expect(find.text('Manage users'), findsOneWidget);
    await tester.tap(find.text('Manage users'));
    await tester.pumpAndSettle();

    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Access token'), findsNothing);
    expect(find.text('Disable'), findsOneWidget);

    await tester.tap(find.text('Invite customer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('create their own password'), findsWidgets);
    expect(find.text('Password'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Authentication preview supports profile and logout', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(developmentPreviewEnabled: true);
    await tester.pumpWidget(
      NewittApp(
        home: AuthGate(
          controller: controller,
          authenticatedBuilder: (session, controller) => ControlRoomHome(
            session: session,
            controller: controller,
            onLogout: controller.signOut,
          ),
        ),
      ),
    );

    expect(find.text('Sign in'), findsWidgets);
    final previewButton = find.text('Open development preview');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    expect(find.text('Control Room'), findsOneWidget);

    await tester.tap(find.text('NEWITT Platform Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Account profile'), findsOneWidget);
    final signOutButton = find.text('Sign out');
    await tester.ensureVisible(signOutButton);
    await tester.tap(signOutButton);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  test('Authorization scopes private customer content', () {
    final masterSession = AuthSession(
      sessionId: 'master',
      authenticatedAt: DateTime(2026),
      profile: const AccountProfile(
        accountId: 'master',
        displayName: 'Master Admin',
        email: 'master@example.invalid',
        role: AuthRole.masterAdmin,
        tenantId: 'platform',
        websiteIds: {'newitt-media', 'essex-paranormal'},
      ),
    );
    final customerSession = AuthSession(
      sessionId: 'customer',
      authenticatedAt: DateTime(2026),
      profile: const AccountProfile(
        accountId: 'customer',
        displayName: 'Essex Paranormal',
        email: 'customer@example.invalid',
        role: AuthRole.customer,
        tenantId: 'essex-paranormal',
        websiteIds: {'essex-paranormal'},
      ),
    );

    expect(
      RolePermissionChecker(masterSession).canAccessWebsite(
        'essex-paranormal',
        WebsiteDataAccess.privateContent,
        ownerWebsite: false,
      ),
      isFalse,
    );
    expect(
      RolePermissionChecker(customerSession).canAccessWebsite(
        'essex-paranormal',
        WebsiteDataAccess.privateContent,
        ownerWebsite: false,
      ),
      isTrue,
    );
    expect(
      RolePermissionChecker(masterSession).canAccessWebsite(
        'essex-paranormal',
        WebsiteDataAccess.operationalHealth,
        ownerWebsite: false,
      ),
      isTrue,
    );
    expect(
      RolePermissionChecker(masterSession).canAccessWebsite(
        'newitt-media',
        WebsiteDataAccess.privateContent,
        ownerWebsite: true,
      ),
      isTrue,
    );
  });

  test('development preview is disabled unless explicitly enabled', () {
    final controller = AuthController();

    controller.enterDevelopmentPreview(AuthRole.masterAdmin);

    expect(controller.state, AuthState.signedOut);
    expect(controller.session, isNull);
  });

  test('AI policy derives actions from session scope, never a request', () {
    final customer = AiPermissionPolicy(_session(AuthRole.customer));
    final admin = AiPermissionPolicy(_session(AuthRole.masterAdmin));

    expect(customer.allows(AiAction.explain), isTrue);
    expect(
      customer.allows(AiAction.draftContent, websiteId: 'website'),
      isTrue,
    );
    expect(
      customer.allows(AiAction.draftContent, websiteId: 'other-tenant'),
      isFalse,
    );
    expect(customer.allows(AiAction.publishContent), isFalse);
    expect(admin.allows(AiAction.publishContent), isTrue);
    expect(admin.requiresHumanApproval(AiAction.publishContent), isTrue);
    expect(admin.allows(AiAction.infrastructure), isFalse);
  });

  testWidgets('AI Control stays local when no provider is configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NewittApp(home: Scaffold(body: AiControlScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI not configured'), findsWidgets);
    expect(find.textContaining('no AI provider is contacted'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Draft a welcome message',
    );
    await tester.pumpAndSettle();
    final sendRequest = find.text('Send request');
    await tester.ensureVisible(sendRequest);
    await tester.tap(sendRequest);
    await tester.pumpAndSettle();
    expect(find.text('Request received'), findsOneWidget);
    expect(
      find.text('AI is not configured for this Control Room.'),
      findsOneWidget,
    );
    final clearConversation = find.text('Clear conversation');
    await tester.ensureVisible(clearConversation);
    await tester.tap(clearConversation);
    await tester.pumpAndSettle();
    expect(find.text('Request received'), findsNothing);
  });

  testWidgets('AI Control shows a safe provider error', (tester) async {
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(body: AiControlScreen(service: _FailingAiService())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Help');
    await tester.pumpAndSettle();
    final sendRequest = find.text('Send request');
    await tester.ensureVisible(sendRequest);
    await tester.tap(sendRequest);
    await tester.pumpAndSettle();
    expect(find.text('AI is temporarily unavailable.'), findsOneWidget);
  });

  testWidgets('How-To guides search, filter, and open guide detail', (
    tester,
  ) async {
    await tester.pumpWidget(const NewittApp(home: HelpScreen()));
    await tester.pumpAndSettle();
    expect(find.text('How To'), findsOneWidget);
    expect(find.text('Media Library'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'media');
    await tester.pumpAndSettle();
    expect(find.text('Media Library'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media Library'));
    await tester.pumpAndSettle();
    expect(find.text('All guides'), findsOneWidget);
    expect(find.textContaining('Media stays private'), findsOneWidget);
  });

  testWidgets('How-To shows no-results and contextual help opens guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      NewittApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => openHelpGuide(context, 'ai-permissions'),
                child: const Text('Help'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('AI Permissions'), findsOneWidget);
    await tester.tap(find.text('All guides'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-guide');
    await tester.pumpAndSettle();
    expect(find.text('No guides found'), findsOneWidget);
  });

  testWidgets('Smart Help is accessible, shows tooltip, and opens its guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NewittApp(
        home: Scaffold(
          body: SmartHelpButton(
            guideId: 'dashboard',
            tooltip: 'Dashboard help',
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Help: Dashboard'), findsOneWidget);
    await tester.longPress(find.byTooltip('Dashboard help'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard help'), findsOneWidget);
    await tester.tap(find.byTooltip('Dashboard help'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('Dashboard contextual help opens its existing guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NewittApp(home: Scaffold(body: DashboardScreen())),
    );
    await tester.tap(find.byTooltip('Dashboard help'));
    await tester.pumpAndSettle();
    expect(find.text('Clear guidance for your Control Room.'), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('customer navigation loads only tenant scoped workspace', (
    WidgetTester tester,
  ) async {
    final customer = _session(AuthRole.customer);
    await tester.pumpWidget(
      NewittApp(
        home: ControlRoomHome(
          session: customer,
          websiteRepository: _WebsiteRepository(),
          controlRoomRepositoryFactory: _RepositoryFactory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform Admin'), findsNothing);
    await tester.tap(find.text('Websites').first);
    await tester.pumpAndSettle();
    expect(find.text('Customer website'), findsOneWidget);
    expect(find.text('Other customer website'), findsNothing);
  });

  testWidgets('master admin can open platform administration', (
    WidgetTester tester,
  ) async {
    final admin = _session(AuthRole.masterAdmin);
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      NewittApp(
        home: ControlRoomHome(
          session: admin,
          websiteRepository: _WebsiteRepository(),
          controlRoomRepositoryFactory: _RepositoryFactory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final platformAdmin = find.text('Platform Admin');
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(platformAdmin);
    await tester.pumpAndSettle();
    expect(find.text('Platform admin'), findsOneWidget);
    expect(find.text('Customers'), findsWidgets);
  });

  testWidgets('master admin validates and provisions a customer invitation', (
    WidgetTester tester,
  ) async {
    final repository = _RecordingRepository();
    await _pumpAdmin(tester, repository);

    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an organisation name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Future Studio');
    await tester.enterText(find.byType(TextFormField).at(1), 'Future Studio');
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use lowercase letters, numbers and single hyphens.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(1), 'future-studio');
    await tester.enterText(find.byType(TextFormField).at(2), 'Jamie Taylor');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'jamie@future.example',
    );
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(repository.provisionedRequest?.organizationName, 'Future Studio');
    expect(repository.provisionedRequest?.accountSlug, 'future-studio');
    expect(repository.provisionedRequest?.contactEmail, 'jamie@future.example');
    expect(
      find.text('Invitation sent to jamie@future.example for Future Studio.'),
      findsOneWidget,
    );
  });

  testWidgets('master admin receives a safe provisioning conflict error', (
    WidgetTester tester,
  ) async {
    final repository = _RecordingRepository(failProvisioning: true);
    await _pumpAdmin(tester, repository);

    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Future Studio');
    await tester.enterText(find.byType(TextFormField).at(1), 'future-studio');
    await tester.enterText(find.byType(TextFormField).at(2), 'Jamie Taylor');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'jamie@future.example',
    );
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to send this invitation. The customer or email may already exist.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('master admin creates a website for the selected customer', (
    WidgetTester tester,
  ) async {
    final repository = _RecordingRepository();
    await _pumpAdmin(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create website'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Customer site');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'customer-site.example',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create website'));
    await tester.pumpAndSettle();

    expect(repository.createdWebsite?.tenantId, 'tenant');
    expect(repository.createdWebsite?.name, 'Customer site');
    expect(repository.createdWebsite?.domain, 'customer-site.example');
  });

  testWidgets('master admin can search and inspect customer operations', (
    WidgetTester tester,
  ) async {
    await _pumpAdmin(tester, _Repository());

    await tester.enterText(find.byType(TextField).last, 'customer');
    await tester.pumpAndSettle();
    expect(find.text('Customer'), findsOneWidget);

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Operational websites'), findsOneWidget);
    expect(find.text('Customer website'), findsWidgets);
    expect(
      find.textContaining('private content, media and support requests'),
      findsOneWidget,
    );
  });

  testWidgets('customer social link validation and save stay tenant scoped', (
    WidgetTester tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: SocialLinksScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a platform and a valid website link.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'Instagram');
    await tester.enterText(
      find.byType(TextField).at(1),
      'https://instagram.com/customer',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.savedSocialWebsiteId, 'website');
    expect(repository.savedSocialPlatform, 'Instagram');
    expect(find.text('Social link saved.'), findsOneWidget);
  });

  testWidgets('media metadata editor loads and saves supported metadata', (
    WidgetTester tester,
  ) async {
    final repository = _MediaRecordingRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: MediaLibraryScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit media details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit media details'), findsOneWidget);
    expect(find.text('Existing caption'), findsOneWidget);
    expect(find.text('heritage'), findsOneWidget);

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), 'Updated photo');
    await tester.enterText(dialogFields.at(4), '2026-09-04');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedMediaTitle, 'Updated photo');
    expect(repository.savedMediaMetadata?['caption'], 'Existing caption');
    expect(repository.savedMediaMetadata?['category'], 'heritage');
    expect(repository.savedMediaMetadata?['date'], '2026-09-04');
    expect(find.text('Media details saved.'), findsOneWidget);
  });

  testWidgets('media metadata editor rejects an empty title', (
    WidgetTester tester,
  ) async {
    final repository = _MediaRecordingRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: MediaLibraryScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit media details'));
    await tester.pumpAndSettle();
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedMediaTitle, isNull);
    expect(find.text('Edit media details'), findsOneWidget);
  });

  testWidgets('media filters combine type, category, and search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: MediaLibraryScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: _FilteredMediaRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(find.text('Night video'), findsOneWidget);
    expect(find.text('Morning photo'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fieldwork'));
    await tester.pumpAndSettle();
    expect(find.text('Morning photo'), findsOneWidget);
    expect(find.text('Night video'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching media'), findsOneWidget);
  });

  testWidgets('media preview falls back to local type icons', (tester) async {
    await _pumpMedia(tester, _FilteredMediaRepository());

    expect(find.byIcon(Icons.image_outlined), findsWidgets);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
  });

  testWidgets('page sections can be added and reused from Media Library', (
    tester,
  ) async {
    List<Map<String, dynamic>> sections = [];
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: ContentSectionEditor(
            repository: _MediaRecordingRepository(),
            initialSections: const [],
            onChanged: (value) => sections = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heading'));
    await tester.pumpAndSettle();
    expect(find.text('Heading'), findsOneWidget);
    expect(sections.single['type'], 'heading');

    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Image from Media Library'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from Media Library'), findsOneWidget);
    await tester.tap(find.text('Existing photo'));
    await tester.pumpAndSettle();

    expect(sections.length, 2);
    expect(sections.last['type'], 'image');
    expect(sections.last['mediaId'], 'media');
  });

  testWidgets(
    'contact enquiries show private details and save internal notes',
    (tester) async {
      final repository = _ContactEnquiryRepository();
      await tester.pumpWidget(
        NewittApp(home: ContactEnquiriesScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Skyline Media'), findsOneWidget);
      await tester.tap(find.textContaining('Skyline Media'));
      await tester.pumpAndSettle();
      expect(find.text('visitor@example.com'), findsOneWidget);
      expect(find.text('Private internal note'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('READ').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Private internal note',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.updatedStatus, 'READ');
      expect(repository.updatedNotes, 'Private internal note');
    },
  );

  testWidgets('website feature inventory keeps uncertain features in review', (
    tester,
  ) async {
    await tester.pumpWidget(
      NewittApp(
        home: WebsiteFeatureInventoryScreen(
          repository: _FeatureInventoryRepository(),
          websiteId: 'website',
          websiteName: 'Existing website',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing website features'), findsOneWidget);
    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('NEEDS_REVIEW'), findsWidgets);
    expect(find.text('Not connected'), findsWidgets);
  });

  testWidgets('content engine filters, publishes, and deletes tenant content', (
    tester,
  ) async {
    final repository = _ContentRecordingRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: WebsiteManagementScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('draft'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Draft home'), findsOneWidget);
    expect(find.text('Published about'), findsNothing);

    final publishContent = find.byTooltip('Publish content').first;
    await tester.ensureVisible(publishContent);
    await tester.tap(publishContent);
    await tester.pumpAndSettle();
    expect(repository.publishedKey, 'home');

    final deleteContent = find.byTooltip('Delete content').first;
    await tester.ensureVisible(deleteContent);
    await tester.tap(deleteContent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(repository.deletedId, 'draft');
  });

  testWidgets(
    'customer website workspace has private page work without lifecycle or publishing controls',
    (tester) async {
      await tester.pumpWidget(
        NewittApp(
          home: Scaffold(
            body: WebsiteManagementScreen(
              websites: await _WebsiteRepository().listAccessibleWebsites(),
              repository: _ContentRecordingRepository(),
              session: _session(AuthRole.customer),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Website'), findsOneWidget);
      expect(find.byTooltip('Private preview'), findsOneWidget);
      expect(find.byTooltip('Add page'), findsOneWidget);
      expect(find.byTooltip('Manage lifecycle'), findsNothing);
      expect(find.byTooltip('Publish content'), findsNothing);
    },
  );

  testWidgets(
    'Master Admin can access temporary website and lifecycle controls',
    (tester) async {
      await tester.pumpWidget(
        NewittApp(
          home: Scaffold(
            body: WebsiteManagementScreen(
              websites: await _WebsiteRepository().listAccessibleWebsites(),
              repository: _Repository(),
              session: _session(AuthRole.masterAdmin),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Create temporary website'), findsOneWidget);
      expect(find.byTooltip('Manage lifecycle'), findsOneWidget);
      await tester.tap(find.byTooltip('Create temporary website'));
      await tester.pumpAndSettle();
      expect(find.text('Create temporary website'), findsOneWidget);
    },
  );

  testWidgets('content areas label and filter reusable sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: WebsiteManagementScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: _ContentRecordingRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Services  |  Service overview'),
      findsOneWidget,
    );

    final contentArea = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Content area',
    );
    await tester.ensureVisible(contentArea);
    await tester.tap(contentArea);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Services').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Service overview'), findsOneWidget);
    expect(find.text('Draft home'), findsNothing);
  });

  testWidgets('content preview renders draft data without publishing', (
    tester,
  ) async {
    final repository = _ContentRecordingRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: WebsiteManagementScreen(
            websites: await _WebsiteRepository().listAccessibleWebsites(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewContent = find.byTooltip('Preview content').first;
    await tester.ensureVisible(previewContent);
    await tester.tap(previewContent);
    await tester.pumpAndSettle();
    expect(find.text('Draft preview'), findsOneWidget);
    expect(find.text('Draft home'), findsOneWidget);
    expect(find.text('Draft copy'), findsWidgets);
    expect(repository.publishedKey, isNull);
  });

  testWidgets('media deletion confirms, refreshes, and reports success', (
    tester,
  ) async {
    final repository = _DeletableMediaRepository();
    await _pumpMedia(tester, repository);
    await tester.tap(find.byTooltip('Delete media'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Existing photo?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(find.text('Media removed.'), findsOneWidget);
    expect(find.text('No media found'), findsOneWidget);
  });

  testWidgets('media deletion prevents duplicate requests and shows failure', (
    tester,
  ) async {
    final repository = _DeletableMediaRepository(fail: true, pending: true);
    await _pumpMedia(tester, repository);
    await tester.tap(find.byTooltip('Delete media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(repository.deleteCalls, 1);
    repository.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Media removal could not be completed. Refresh before retrying.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('customer support reply field renders', (tester) async {
    await _pumpSupportTicket(tester, _SupportReplyRepository());

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Write your reply'), findsOneWidget);
    expect(find.text('Send reply'), findsOneWidget);
  });

  testWidgets('customer support reply rejects an empty message', (
    tester,
  ) async {
    final repository = _SupportReplyRepository();
    await _pumpSupportTicket(tester, repository);

    final sendReply = find.text('Send reply');
    await tester.ensureVisible(sendReply);
    await tester.tap(sendReply);
    await tester.pumpAndSettle();

    expect(find.text('Enter a reply before sending.'), findsOneWidget);
    expect(repository.addCalls, 0);
  });

  testWidgets('customer support reply rejects whitespace-only messages', (
    tester,
  ) async {
    final repository = _SupportReplyRepository();
    await _pumpSupportTicket(tester, repository);

    await tester.enterText(find.byType(TextField).last, '   \n  ');
    final sendReply = find.text('Send reply');
    await tester.ensureVisible(sendReply);
    await tester.tap(sendReply);
    await tester.pumpAndSettle();

    expect(find.text('Enter a reply before sending.'), findsOneWidget);
    expect(repository.addCalls, 0);
  });

  testWidgets('customer support reply sends a visible non-internal message', (
    tester,
  ) async {
    final repository = _SupportReplyRepository();
    await _pumpSupportTicket(tester, repository);

    final replyField = find.byType(TextField).last;
    await tester.enterText(replyField, '  Please share an update.  ');
    final sendReply = find.text('Send reply');
    await tester.ensureVisible(sendReply);
    await tester.tap(sendReply);
    await tester.pumpAndSettle();

    expect(repository.addCalls, 1);
    expect(repository.lastRequestId, 'request');
    expect(repository.lastBody, 'Please share an update.');
    expect(repository.lastInternal, isFalse);
    expect(repository.listCalls, greaterThanOrEqualTo(2));
    expect(find.text('Please share an update.'), findsOneWidget);
    expect(tester.widget<TextField>(replyField).controller!.text, isEmpty);
  });

  testWidgets('customer support reply prevents duplicate pending submissions', (
    tester,
  ) async {
    final repository = _SupportReplyRepository(pending: true);
    await _pumpSupportTicket(tester, repository);

    await tester.enterText(find.byType(TextField).last, 'Need help');
    final sendReply = find.text('Send reply');
    await tester.ensureVisible(sendReply);
    await tester.tap(sendReply);
    await tester.pump();
    expect(find.text('Sending...'), findsOneWidget);
    await tester.tap(find.text('Sending...'));
    await tester.pump();
    expect(repository.addCalls, 1);

    repository.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('customer support reply displays a submission error', (
    tester,
  ) async {
    final repository = _SupportReplyRepository(fail: true);
    await _pumpSupportTicket(tester, repository);

    await tester.enterText(find.byType(TextField).last, 'Need help');
    final sendReply = find.text('Send reply');
    await tester.ensureVisible(sendReply);
    await tester.tap(sendReply);
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to send your reply. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Need help',
    );
  });

  testWidgets('Master Admin support list shows operational ticket filters', (
    tester,
  ) async {
    final repository = _AdminSupportRepository();
    await _pumpAdminSupport(tester, repository);

    expect(find.text('Admin website request'), findsOneWidget);
    expect(find.textContaining('Tenant tenant-a'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'billing');
    await tester.pumpAndSettle();
    expect(find.text('Billing question'), findsOneWidget);
    expect(find.text('Admin website request'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Admin website request'), findsOneWidget);
    expect(find.text('Billing question'), findsNothing);
  });

  testWidgets('Master Admin manages replies notes and ticket status', (
    tester,
  ) async {
    final repository = _AdminSupportRepository();
    await _pumpAdminSupport(tester, repository);
    await tester.tap(find.text('Admin website request'));
    await tester.pumpAndSettle();

    expect(find.text('Customer visible'), findsWidgets);
    expect(find.text('Customer update'), findsOneWidget);
    expect(find.text('Internal note'), findsWidgets);
    expect(find.text('Private triage note'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Customer response');
    final replyButton = find.text('Send reply');
    await tester.ensureVisible(replyButton);
    await tester.tap(replyButton);
    await tester.pumpAndSettle();
    expect(repository.addedMessages.last.isInternal, isFalse);
    expect(find.text('Customer response'), findsOneWidget);

    await tester.enterText(fields.at(1), 'Admin-only context');
    final noteButton = find.text('Add internal note');
    await tester.ensureVisible(noteButton);
    await tester.tap(noteButton);
    await tester.pumpAndSettle();
    expect(repository.addedMessages.last.isInternal, isTrue);
    expect(find.text('Admin-only context'), findsOneWidget);

    final resolve = find.text('Resolve');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pumpAndSettle();
    expect(repository.statusUpdates.last, 'RESOLVED');
    final close = find.text('Close');
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(repository.statusUpdates.last, 'CLOSED');
  });

  testWidgets('Master Admin support actions show friendly errors', (
    tester,
  ) async {
    final repository = _AdminSupportRepository(
      failMessages: true,
      failStatus: true,
    );
    await _pumpAdminSupport(tester, repository);
    await tester.tap(find.text('Admin website request'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Customer response');
    final replyButton = find.text('Send reply');
    await tester.ensureVisible(replyButton);
    await tester.tap(replyButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to send this message. Please try again.'),
      findsOneWidget,
    );

    final resolve = find.text('Resolve');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to update the ticket status. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'customer support hides Master Admin controls and internal notes',
    (tester) async {
      final repository = _AdminSupportRepository();
      await _pumpCustomerSupport(tester, repository);

      expect(find.text('Private triage note'), findsNothing);
      expect(find.text('Add internal note'), findsNothing);
      expect(find.text('Resolve'), findsNothing);
      expect(find.text('Close'), findsNothing);
      expect(find.text('Customer update'), findsOneWidget);
    },
  );

  testWidgets('customer sees tenant-scoped content safety guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: ContentSafetyScreen(
            repository: _SafetyRepository(),
            session: _session(AuthRole.customer),
            websites: await _WebsiteRepository().listAccessibleWebsites(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('homepage'), findsOneWidget);
    expect(
      find.text('This content needs review before it can be published.'),
      findsOneWidget,
    );
    await tester.tap(find.text('homepage'));
    await tester.pumpAndSettle();
    expect(find.text('Update review'), findsNothing);
    expect(find.text('Add finding'), findsNothing);
  });

  testWidgets('Master Admin can manage content safety findings', (
    tester,
  ) async {
    final repository = _SafetyRepository();
    await tester.pumpWidget(
      NewittApp(
        home: Scaffold(
          body: ContentSafetyScreen(
            repository: repository,
            session: _session(AuthRole.masterAdmin),
            websites: await _WebsiteRepository().listAccessibleWebsites(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create review'), findsOneWidget);
    await tester.tap(find.text('homepage'));
    await tester.pumpAndSettle();
    expect(find.text('Update review'), findsOneWidget);
    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    expect(repository.findingStatus, 'RESOLVED');
  });
}

class _FailingAiService implements AiService {
  @override
  bool get isConfigured => true;
  @override
  Future<AiResponse> submit(String request) =>
      Future<AiResponse>.error(StateError('provider'));
}

Future<void> _pumpMedia(
  WidgetTester tester,
  ControlRoomRepository repository,
) async {
  await tester.pumpWidget(
    NewittApp(
      home: Scaffold(
        body: MediaLibraryScreen(
          websites: await _WebsiteRepository().listAccessibleWebsites(),
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSupportTicket(
  WidgetTester tester,
  ControlRoomRepository repository,
) async {
  await tester.pumpWidget(
    NewittApp(
      home: Scaffold(
        body: SupportScreen(
          websites: await _WebsiteRepository().listAccessibleWebsites(),
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Customer support request'));
  await tester.pumpAndSettle();
}

Future<void> _pumpAdminSupport(
  WidgetTester tester,
  ControlRoomRepository repository,
) async {
  await tester.pumpWidget(
    NewittApp(
      home: Scaffold(
        body: SupportScreen(
          websites: await _WebsiteRepository().listAccessibleWebsites(),
          repository: repository,
          session: _session(AuthRole.masterAdmin),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCustomerSupport(
  WidgetTester tester,
  ControlRoomRepository repository,
) async {
  await _pumpAdminSupport(tester, repository);
  await tester.pumpWidget(
    NewittApp(
      home: Scaffold(
        body: SupportScreen(
          websites: await _WebsiteRepository().listAccessibleWebsites(),
          repository: repository,
          session: _session(AuthRole.customer),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Admin website request'));
  await tester.pumpAndSettle();
}

Future<void> _pumpAdmin(
  WidgetTester tester,
  ControlRoomRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    NewittApp(
      home: ControlRoomHome(
        session: _session(AuthRole.masterAdmin),
        websiteRepository: _WebsiteRepository(),
        controlRoomRepositoryFactory: _RepositoryFactory(repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final platformAdmin = find.text('Platform Admin');
  await tester.drag(find.byType(ListView).first, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(platformAdmin);
  await tester.pumpAndSettle();
}

AuthSession _session(AuthRole role) => AuthSession(
  sessionId: 'session',
  authenticatedAt: DateTime(2026),
  profile: AccountProfile(
    accountId: 'account',
    displayName: 'Account',
    email: 'account@example.invalid',
    role: role,
    tenantId: 'tenant',
    websiteIds: const {'website'},
  ),
);

class _WebsiteRepository implements WebsiteRepository {
  @override
  Future<List<Website>> listAccessibleWebsites() async => const [
    Website(
      id: 'website',
      tenantId: 'tenant',
      name: 'Customer website',
      domain: 'customer.example.invalid',
      type: WebsiteType.customer,
      connectionStatus: WebsiteConnectionStatus.connected,
      onlineStatus: WebsiteHealthStatus.online,
      sslStatus: WebsiteSslStatus.active,
      domainStatus: WebsiteDomainStatus.connected,
      deploymentStatus: WebsiteDeploymentStatus.successful,
      lastSuccessfulDeployment: null,
      criticalErrorStatus: WebsiteCriticalErrorStatus.noneReported,
      capabilities: {},
    ),
  ];
}

class _RepositoryFactory implements ControlRoomRepositoryFactory {
  _RepositoryFactory([this.repository]);

  final ControlRoomRepository? repository;

  @override
  ControlRoomRepository forProfile(AccountProfile profile) =>
      repository ?? _Repository();
}

class _RecordingRepository extends _Repository {
  _RecordingRepository({this.failProvisioning = false});

  final bool failProvisioning;
  ProvisionCustomerRequest? provisionedRequest;
  CreateWebsiteRequest? createdWebsite;
  String? savedSocialWebsiteId;
  String? savedSocialPlatform;

  @override
  Future<ProvisionedCustomer> provisionCustomer(
    ProvisionCustomerRequest request,
  ) async {
    provisionedRequest = request;
    if (failProvisioning) throw StateError('duplicate');
    return ProvisionedCustomer(
      customer: CustomerRecord(
        id: 'created-tenant',
        name: request.organizationName,
        slug: request.accountSlug,
        createdAt: DateTime(2026),
      ),
      invitationEmail: request.contactEmail,
    );
  }

  @override
  Future<void> createCustomerWebsite(CreateWebsiteRequest request) async {
    createdWebsite = request;
  }

  @override
  Future<void> saveSocialLink({
    String? id,
    required String websiteId,
    required String platform,
    required String url,
  }) async {
    savedSocialWebsiteId = websiteId;
    savedSocialPlatform = platform;
  }
}

class _MediaRecordingRepository extends _Repository {
  String? savedMediaTitle;
  Map<String, dynamic>? savedMediaMetadata;

  @override
  Future<List<MediaRecord>> listMedia({String? query}) async => const [
    MediaRecord(
      id: 'media',
      websiteId: 'website',
      storagePath: 'tenant/website/photo.jpg',
      title: 'Existing photo',
      metadata: {
        'type': 'image/jpeg',
        'caption': 'Existing caption',
        'category': 'heritage',
        'location': 'Colchester',
        'featured': true,
      },
      createdAt: null,
    ),
  ];

  @override
  Future<void> saveMediaMetadata({
    required String id,
    required String title,
    required Map<String, dynamic> metadata,
  }) async {
    savedMediaTitle = title;
    savedMediaMetadata = metadata;
  }
}

class _FilteredMediaRepository extends _Repository {
  @override
  Future<List<MediaRecord>> listMedia({String? query}) async => const [
    MediaRecord(
      id: 'photo',
      websiteId: 'website',
      storagePath: 'tenant/website/photo.jpg',
      title: 'Morning photo',
      metadata: {'type': 'image/jpeg', 'category': 'fieldwork'},
      createdAt: null,
    ),
    MediaRecord(
      id: 'video',
      websiteId: 'website',
      storagePath: 'tenant/website/video.mp4',
      title: 'Night video',
      metadata: {'type': 'video/mp4', 'category': 'archive'},
      createdAt: null,
    ),
    MediaRecord(
      id: 'audio',
      websiteId: 'website',
      storagePath: 'tenant/website/audio.mp3',
      title: 'Audio note',
      metadata: {'type': 'audio/mpeg', 'category': 'fieldwork'},
      createdAt: null,
    ),
  ];
}

class _ContentRecordingRepository extends _Repository {
  String? publishedKey;
  String? deletedId;

  @override
  Future<List<ContentRecord>> listContent() async => const [
    ContentRecord(
      id: 'draft',
      websiteId: 'website',
      contentKey: 'home',
      content: {'title': 'Draft home', 'text': 'Draft copy'},
      updatedAt: null,
      status: 'DRAFT',
    ),
    ContentRecord(
      id: 'published',
      websiteId: 'website',
      contentKey: 'about',
      content: {'title': 'Published about', 'text': 'Public copy'},
      updatedAt: null,
      status: 'PUBLISHED',
    ),
    ContentRecord(
      id: 'services',
      websiteId: 'website',
      contentKey: 'services',
      content: {
        'section': 'Services',
        'title': 'Service overview',
        'text': 'Service copy',
        'featured': true,
      },
      updatedAt: null,
      status: 'DRAFT',
    ),
  ];

  @override
  Future<void> publishContent({
    required String websiteId,
    required String contentKey,
  }) async {
    publishedKey = contentKey;
  }

  @override
  Future<void> deleteContent(String id) async {
    deletedId = id;
  }
}

class _DeletableMediaRepository extends _MediaRecordingRepository {
  _DeletableMediaRepository({this.fail = false, this.pending = false});
  final bool fail;
  final bool pending;
  final Completer<void> _completer = Completer<void>();
  int deleteCalls = 0;
  bool deleted = false;
  void complete() => _completer.complete();
  @override
  Future<void> deleteMedia(String id) async {
    deleteCalls++;
    if (pending) await _completer.future;
    if (fail) throw StateError('failed');
    deleted = true;
  }

  @override
  Future<List<MediaRecord>> listMedia({String? query}) async =>
      deleted ? const [] : await super.listMedia(query: query);
}

class _SupportReplyRepository extends _Repository {
  _SupportReplyRepository({this.fail = false, this.pending = false});

  final bool fail;
  final bool pending;
  final Completer<void> _completer = Completer<void>();
  final List<SupportMessageRecord> _messages = [];
  int addCalls = 0;
  int listCalls = 0;
  String? lastRequestId;
  String? lastBody;
  bool? lastInternal;

  void complete() => _completer.complete();

  @override
  Future<List<SupportRequestRecord>> listSupportRequests() async => [
    SupportRequestRecord(
      id: 'request',
      tenantId: 'tenant',
      websiteId: 'website',
      subject: 'Customer support request',
      body: 'Please help with the website.',
      status: 'OPEN',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      category: 'WEBSITE',
    ),
  ];

  @override
  Future<List<SupportMessageRecord>> listSupportMessages(
    String requestId,
  ) async {
    listCalls++;
    return _messages;
  }

  @override
  Future<void> addSupportMessage({
    required String requestId,
    required String body,
    required bool internal,
  }) async {
    addCalls++;
    lastRequestId = requestId;
    lastBody = body;
    lastInternal = internal;
    if (pending) await _completer.future;
    if (fail) throw StateError('failed');
    _messages.add(
      SupportMessageRecord(
        id: 'message-$addCalls',
        body: body,
        isInternal: internal,
        createdAt: DateTime(2026),
      ),
    );
  }
}

class _AdminSupportRepository extends _Repository {
  _AdminSupportRepository({this.failMessages = false, this.failStatus = false});

  final bool failMessages;
  final bool failStatus;
  final List<SupportMessageRecord> messages = [
    SupportMessageRecord(
      id: 'visible',
      body: 'Customer update',
      isInternal: false,
      createdAt: DateTime(2026),
    ),
    SupportMessageRecord(
      id: 'internal',
      body: 'Private triage note',
      isInternal: true,
      createdAt: DateTime(2026),
    ),
  ];
  final List<SupportMessageRecord> addedMessages = [];
  final List<String> statusUpdates = [];

  @override
  Future<List<SupportRequestRecord>> listSupportRequests() async => [
    SupportRequestRecord(
      id: 'admin-request',
      tenantId: 'tenant-a',
      websiteId: 'website',
      subject: 'Admin website request',
      body: 'Website support request.',
      status: 'OPEN',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      category: 'WEBSITE',
    ),
    SupportRequestRecord(
      id: 'billing-request',
      tenantId: 'tenant-b',
      websiteId: null,
      subject: 'Billing question',
      body: 'Billing support request.',
      status: 'NEW',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      category: 'PAYMENTS',
    ),
  ];

  @override
  Future<List<SupportMessageRecord>> listSupportMessages(
    String requestId,
  ) async => messages;

  @override
  Future<void> addSupportMessage({
    required String requestId,
    required String body,
    required bool internal,
  }) async {
    if (failMessages) throw StateError('message failure');
    final message = SupportMessageRecord(
      id: 'added-${addedMessages.length}',
      body: body,
      isInternal: internal,
      createdAt: DateTime(2026),
    );
    addedMessages.add(message);
    messages.add(message);
  }

  @override
  Future<void> updateSupportStatus({
    required String requestId,
    required String status,
  }) async {
    if (failStatus) throw StateError('status failure');
    statusUpdates.add(status);
  }
}

class _SafetyRepository extends _Repository {
  String? findingStatus;

  @override
  Future<List<ContentSafetyReviewRecord>> listContentSafetyReviews() async => [
    ContentSafetyReviewRecord(
      id: 'review',
      tenantId: 'tenant',
      contentId: 'content',
      contentKey: 'homepage',
      websiteId: 'website',
      decision: 'REVIEW',
      explanation: 'Review the claim before publishing.',
      recommendedAction: 'Add supporting evidence.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<ContentSafetyFindingRecord>> listContentSafetyFindings(
    String reviewId,
  ) async => [
    ContentSafetyFindingRecord(
      id: 'finding',
      reviewId: reviewId,
      category: 'MISLEADING_CLAIMS',
      severity: 'HIGH',
      status: 'OPEN',
      explanation: 'This claim needs review.',
      recommendedAction: 'Add evidence.',
      requiresReview: true,
      createdAt: DateTime(2026),
    ),
  ];

  @override
  Future<void> updateContentSafetyFindingStatus({
    required String id,
    required String status,
  }) async {
    findingStatus = status;
  }
}

class _Repository implements ControlRoomRepository {
  @override
  Future<List<AuditEventRecord>> listAuditEvents() async => const [];
  @override
  Future<List<ContactEnquiryRecord>> listContactEnquiries() async => const [];
  @override
  Future<void> updateContactEnquiry({
    required String id,
    required String status,
    String? internalNotes,
  }) async {}
  @override
  Future<List<WebsiteFeatureRecord>> listWebsiteFeatures(
    String websiteId,
  ) async => const [];
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
  }) async {}
  @override
  Future<List<CustomerUserRecord>> listCustomerUsers(String customerId) async =>
      const [];
  @override
  Future<CustomerUserRecord> inviteCustomerUser({
    required String customerId,
    required String email,
    required String displayName,
  }) async => CustomerUserRecord(
    email: email,
    displayName: displayName,
    role: 'CUSTOMER',
    status: 'INVITED',
    createdAt: DateTime(2026),
    lastActiveAt: null,
  );
  @override
  Future<CustomerUserRecord> setCustomerUserDisabled({
    required String customerId,
    required String email,
    required bool disabled,
  }) async => CustomerUserRecord(
    email: email,
    displayName: 'Customer',
    role: 'CUSTOMER',
    status: disabled ? 'DISABLED' : 'ACTIVE',
    createdAt: DateTime(2026),
    lastActiveAt: null,
  );
  @override
  Future<SecuritySummaryRecord> getSecuritySummary() async =>
      const SecuritySummaryRecord(
        recentAuditEvents: 0,
        latestAuditEventAt: null,
      );
  @override
  Future<AnalyticsSummaryRecord> getAnalyticsSummary() async =>
      const AnalyticsSummaryRecord(
        websites: 0,
        content: 0,
        published: 0,
        media: 0,
        supportOpen: 0,
      );
  @override
  Future<List<CloudflareAccountRecord>> listCloudflareAccounts() async =>
      const [];
  @override
  Future<List<CloudflareZoneRecord>> listCloudflareZones() async => const [];
  @override
  Future<List<CloudflareDeploymentRecord>> listCloudflareDeployments() async =>
      const [];
  @override
  Future<List<GitHubConnectionRecord>> listGitHubConnections() async =>
      const [];
  @override
  Future<List<GitHubRepositoryRecord>> listGitHubRepositories() async =>
      const [];
  @override
  Future<List<GitHubMappingRecord>> listGitHubMappings() async => const [];
  @override
  Future<void> linkGitHubRepository({
    required String websiteId,
    required String repositoryId,
  }) async {}
  @override
  Future<void> unlinkGitHubRepository(String websiteId) async {}
  @override
  Future<void> deleteWebsitePage(String id) async {}
  @override
  Future<void> deleteWebsiteTemplate(String id) async {}
  @override
  Future<WebsiteMetrics> getWebsiteMetrics() async => const WebsiteMetrics(
    total: 0,
    published: 0,
    expiringSoon: 0,
    suspended: 0,
    online: 0,
  );
  @override
  Future<WebsitePreviewRecord> getWebsitePreview(String websiteId) async =>
      WebsitePreviewRecord(
        websiteId: websiteId,
        pages: const [],
        content: const [],
      );
  @override
  Future<List<WebsitePageRecord>> listWebsitePages(String websiteId) async =>
      const [];
  @override
  Future<List<WebsiteTemplateRecord>> listWebsiteTemplates() async => const [];
  @override
  Future<void> reorderWebsitePages(List<WebsitePageRecord> pages) async {}
  @override
  Future<void> saveWebsitePage({
    String? id,
    required String websiteId,
    required String title,
    required String slug,
    required String type,
    required bool visible,
    required int sortOrder,
  }) async {}
  @override
  Future<void> saveWebsiteTemplate({
    String? id,
    required String name,
    String? description,
    required String type,
    required String version,
    required bool active,
  }) async {}
  @override
  Future<void> updateWebsite({
    required String id,
    required String name,
    required String domain,
    String? siteSlug,
    String? description,
  }) async {}
  @override
  Future<void> updateWebsiteManagement({
    required String id,
    required String lifecycle,
    String? templateId,
    DateTime? expiresAt,
    String? commercialAgreementId,
  }) async {}
  @override
  Future<void> changeCommercialAgreementStatus({
    required String id,
    required String status,
    String? cancellationReason,
  }) async {}
  @override
  Future<void> deleteCommercialAgreementItem(String id) async {}
  @override
  Future<CommercialAgreementRecord?> getCommercialAgreement(String id) async =>
      null;
  @override
  Future<List<CommercialAgreementDocumentRecord>>
  listCommercialAgreementDocuments(String agreementId) async => const [];
  @override
  Future<List<CommercialAgreementHistoryRecord>> listCommercialAgreementHistory(
    String agreementId,
  ) async => const [];
  @override
  Future<List<CommercialAgreementItemRecord>> listCommercialAgreementItems(
    String agreementId,
  ) async => const [];
  @override
  Future<List<CommercialAgreementRecord>> listCommercialAgreements() async =>
      const [];
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
  }) async {}
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
  }) async {}
  @override
  Future<void> createContentSafetyFinding({
    required String reviewId,
    required String category,
    required String severity,
    required String explanation,
    String? recommendedAction,
    bool requiresReview = false,
  }) async {}

  @override
  Future<void> addSupportMessage({
    required String requestId,
    required String body,
    required bool internal,
  }) async {}

  @override
  Future<void> deleteContent(String id) async {}

  @override
  Future<void> deleteMedia(String id) async {}

  @override
  Future<void> createCustomerWebsite(CreateWebsiteRequest request) async {}

  @override
  Future<void> publishContent({
    required String websiteId,
    required String contentKey,
  }) async {}

  @override
  Future<ProvisionedCustomer> provisionCustomer(
    ProvisionCustomerRequest request,
  ) async => ProvisionedCustomer(
    customer: CustomerRecord(
      id: 'created-tenant',
      name: request.organizationName,
      slug: request.accountSlug,
      createdAt: DateTime(2026),
    ),
    invitationEmail: request.contactEmail,
  );

  @override
  Future<void> createSupportRequest({
    String? websiteId,
    required String subject,
    required String body,
    String category = 'OTHER',
  }) async {}
  @override
  Future<ContentSafetySummary> getContentSafetySummary() async =>
      const ContentSafetySummary(
        safe: 0,
        review: 0,
        blocked: 0,
        openFindings: 0,
        criticalFindings: 0,
      );
  @override
  Future<void> deleteSocialLink(String id) async {}
  @override
  Future<List<CustomerRecord>> listCustomers() async => const [
    CustomerRecord(
      id: 'tenant',
      name: 'Customer',
      slug: 'customer',
      createdAt: null,
    ),
  ];
  @override
  Future<List<ContentRecord>> listContent() async => const [];
  @override
  Future<List<ContentSafetyFindingRecord>> listContentSafetyFindings(
    String reviewId,
  ) async => const [];
  @override
  Future<List<ContentSafetyFindingRecord>>
  listAllContentSafetyFindings() async => const [];
  @override
  Future<List<ContentSafetyReviewRecord>> listContentSafetyReviews() async =>
      const [];
  @override
  Future<List<MediaRecord>> listMedia({String? query}) async => const [];
  @override
  Future<void> saveMediaMetadata({
    required String id,
    required String title,
    required Map<String, dynamic> metadata,
  }) async {}
  @override
  Future<List<PlatformActivityRecord>> listPlatformActivity() async => const [];
  @override
  Future<List<SupportRequestRecord>> listSupportRequests() async => const [];
  @override
  Future<List<SupportMessageRecord>> listSupportMessages(
    String requestId,
  ) async => const [];
  @override
  Future<List<SocialLinkRecord>> listSocialLinks() async => const [];
  @override
  Future<void> saveContent({
    required String websiteId,
    required String contentKey,
    required Map<String, dynamic> content,
  }) async {}
  @override
  Future<void> saveContentSafetyReview({
    String? id,
    required String contentId,
    required String decision,
    String? explanation,
    String? recommendedAction,
  }) async {}
  @override
  Future<void> saveSocialLink({
    String? id,
    required String websiteId,
    required String platform,
    required String url,
  }) async {}
  @override
  Future<void> uploadMedia(MediaUploadRequest request) async {}
  @override
  Future<void> updateSupportStatus({
    required String requestId,
    required String status,
  }) async {}
  @override
  Future<void> updateContentSafetyFindingStatus({
    required String id,
    required String status,
  }) async {}
}

class _AuditRepository extends _Repository {
  @override
  Future<List<AuditEventRecord>> listAuditEvents() async => [
    AuditEventRecord(
      action: 'website.updated',
      resourceType: 'website',
      createdAt: DateTime(2026),
    ),
    AuditEventRecord(
      action: 'support.request.created',
      resourceType: 'support_request',
      createdAt: DateTime(2026),
    ),
  ];

  @override
  Future<SecuritySummaryRecord> getSecuritySummary() async =>
      const SecuritySummaryRecord(
        recentAuditEvents: 2,
        latestAuditEventAt: null,
      );
}

class _FailingContentRepository extends _Repository {
  @override
  Future<List<ContentRecord>> listContent() => Future.error(
    StateError('database connection details must not reach the UI'),
  );
}

class _CustomerUsersRepository extends _Repository {
  @override
  Future<List<CustomerRecord>> listCustomers() async => [
    CustomerRecord(
      id: 'essex-paranormal',
      name: 'Essex Paranormal',
      slug: 'essex-paranormal',
      createdAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<CustomerUserRecord>> listCustomerUsers(String customerId) async =>
      [
        CustomerUserRecord(
          email: 'customer@example.com',
          displayName: 'Essex Customer',
          role: 'CUSTOMER',
          status: 'ACTIVE',
          createdAt: DateTime(2026),
          lastActiveAt: DateTime(2026, 9, 5),
        ),
      ];
}

class _ContactEnquiryRepository extends _Repository {
  String? updatedStatus;
  String? updatedNotes;

  @override
  Future<List<ContactEnquiryRecord>> listContactEnquiries() async => [
    ContactEnquiryRecord(
      id: 'enquiry',
      websiteId: 'website',
      area: 'Skyline Media',
      name: 'Visitor',
      email: 'visitor@example.com',
      message: 'A private enquiry',
      status: 'NEW',
      internalNotes: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<void> updateContactEnquiry({
    required String id,
    required String status,
    String? internalNotes,
  }) async {
    updatedStatus = status;
    updatedNotes = internalNotes;
  }
}

class _FeatureInventoryRepository extends _Repository {
  @override
  Future<List<WebsiteFeatureRecord>> listWebsiteFeatures(
    String websiteId,
  ) async => [
    const WebsiteFeatureRecord(
      id: 'feature',
      websiteId: 'website',
      featureKey: 'homepage',
      evidenceStatus: 'NEEDS_REVIEW',
      connected: false,
      enabled: false,
      evidence: null,
      notes: null,
    ),
  ];
}
