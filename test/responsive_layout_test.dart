import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newitt_media_control_room/dashboard/dashboard_screen.dart';
import 'package:newitt_media_control_room/websites/website_model.dart';
import 'package:newitt_media_control_room/websites/websites_screen.dart';

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(360, 800),
    Size(768, 1024),
    Size(1440, 900),
    Size(2560, 1400),
  ];

  testWidgets(
    'dashboard remains renderable at phone, tablet, and desktop widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: DashboardScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Control Room'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'website cards remain renderable at phone, tablet, and desktop widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const website = Website(
        id: 'website',
        tenantId: 'tenant',
        name: 'Responsive website',
        domain: 'responsive.example.invalid',
        type: WebsiteType.customer,
        connectionStatus: WebsiteConnectionStatus.connected,
        onlineStatus: WebsiteHealthStatus.online,
        sslStatus: WebsiteSslStatus.active,
        domainStatus: WebsiteDomainStatus.connected,
        deploymentStatus: WebsiteDeploymentStatus.successful,
        lastSuccessfulDeployment: null,
        criticalErrorStatus: WebsiteCriticalErrorStatus.noneReported,
        capabilities: {},
      );

      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: WebsitesScreen(websites: [website])),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Responsive website'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
