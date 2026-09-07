import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newitt_media_control_room/app/routing/control_room_router.dart';
import 'package:newitt_media_control_room/app/routing/control_room_navigation.dart';
import 'package:newitt_media_control_room/auth/auth_models.dart';

void main() {
  test('customer navigation excludes infrastructure and admin sections', () {
    final labels = ControlRoomNavigation.items(AuthRole.customer)
        .map((item) => item.label)
        .toList();

    expect(labels, contains('Settings'));
    expect(labels, isNot(contains('GitHub')));
    expect(labels, isNot(contains('Cloudflare')));
    expect(labels, isNot(contains('Security')));
    expect(labels, isNot(contains('Audit Log')));
    expect(labels, isNot(contains('Platform Admin')));
  });

  test('master admin navigation preserves protected sections', () {
    final labels = ControlRoomNavigation.items(AuthRole.masterAdmin)
        .map((item) => item.label)
        .toList();

    expect(
      labels,
      containsAll(<String>[
        'GitHub',
        'Cloudflare',
        'Security',
        'Audit Log',
        'Platform Admin',
      ]),
    );
    expect(labels.indexOf('Security'), lessThan(labels.indexOf('Audit Log')));
    expect(labels.indexOf('Audit Log'), lessThan(labels.indexOf('Settings')));
  });

  testWidgets('customer route cannot render Security or Platform Admin', (
    tester,
  ) async {
    final session = _session(AuthRole.customer);
    await tester.pumpWidget(
      MaterialApp(
        home: ControlRoomRouter.build(
          ControlRoomRouteContext(
            selectedIndex: 11,
            websites: const [],
            repository: null,
            session: session,
            controller: null,
            onLogout: null,
            onWebsitesChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access restricted'), findsOneWidget);
    expect(find.text('Security'), findsNothing);
  });

  testWidgets('Master Admin route can render Security', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ControlRoomRouter.build(
          ControlRoomRouteContext(
            selectedIndex: 11,
            websites: const [],
            repository: null,
            session: _session(AuthRole.masterAdmin),
            controller: null,
            onLogout: null,
            onWebsitesChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Security status unavailable.'), findsOneWidget);
  });
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
