import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../backend/control_room_repository.dart';
import '../help/smart_help_button.dart';
import '../websites/website_model.dart';

class CloudflareScreen extends StatelessWidget {
  const CloudflareScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.websites,
  });
  final ControlRoomRepository? repository;
  final AuthSession? session;
  final List<Website> websites;
  bool get _admin => session?.profile.role == AuthRole.masterAdmin;

  @override
  Widget build(BuildContext context) {
    final data = repository;
    return Scaffold(
      body: Container(
        color: const Color(0xFF080B10),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: data == null
                  ? const Text('Cloudflare unavailable.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _admin
                                    ? 'Cloudflare'
                                    : 'Website infrastructure',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SmartHelpButton(
                              guideId: 'cloudflare',
                              tooltip: 'Cloudflare help',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _Connection(repository: data),
                        const SizedBox(height: 24),
                        _Infrastructure(
                          repository: data,
                          websites: websites,
                          admin: _admin,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Connection extends StatelessWidget {
  const _Connection({required this.repository});
  final ControlRoomRepository repository;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<CloudflareAccountRecord>>(
        future: repository.listCloudflareAccounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return const Text(
              'Cloudflare is not configured. NEWITT Media manages infrastructure setup.',
              style: TextStyle(color: Color(0xFFE9B949)),
            );
          }
          final account = snapshot.data!.first;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined, color: Color(0xFF00D9F5)),
            title: Text('Connection: ${account.status}'),
            subtitle: Text(
              account.name ?? 'Account metadata is not available.',
            ),
          );
        },
      );
}

class _Infrastructure extends StatelessWidget {
  const _Infrastructure({
    required this.repository,
    required this.websites,
    required this.admin,
  });
  final ControlRoomRepository repository;
  final List<Website> websites;
  final bool admin;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<CloudflareZoneRecord>>(
    future: repository.listCloudflareZones(),
    builder: (context, zones) {
      if (!zones.hasData) return const CircularProgressIndicator();
      return FutureBuilder<List<CloudflareDeploymentRecord>>(
        future: repository.listCloudflareDeployments(),
        builder: (context, deployments) {
          if (!deployments.hasData) return const CircularProgressIndicator();
          if (zones.data!.isEmpty) {
            return const Text(
              'No Cloudflare infrastructure is recorded for your websites.',
              style: TextStyle(color: Color(0xFF8A99A5)),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Domains and deployments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ...zones.data!.map((zone) {
                final website = websites
                    .where((site) => site.id == zone.websiteId)
                    .firstOrNull;
                final deployment = deployments.data!
                    .where((item) => item.websiteId == zone.websiteId)
                    .firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(website?.name ?? zone.domain),
                  subtitle: Text(
                    'Domain: ${zone.domain} | Zone: ${zone.status ?? 'Unknown'} | SSL/TLS: ${zone.sslStatus ?? 'Unknown'} | Deployment: ${deployment?.status ?? 'NOT_CONNECTED'}${deployment?.error == null ? '' : ' | ${deployment!.error}'}',
                  ),
                );
              }),
            ],
          );
        },
      );
    },
  );
}
