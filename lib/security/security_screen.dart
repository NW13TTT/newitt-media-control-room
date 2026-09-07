import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.repository});
  final ControlRoomRepository? repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Center(
            child: repository == null
                ? const Text('Security status unavailable.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Security',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SmartHelpButton(
                            guideId: 'security',
                            tooltip: 'Security help',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tenant isolation, RLS, audit logging, and privileged access are enforced by the Control Room backend.',
                        style: TextStyle(color: Color(0xFF8A99A5)),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<SecuritySummaryRecord>(
                        future: repository!.getSecuritySummary(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent security activity: ${snapshot.data!.recentAuditEvents}',
                                style: const TextStyle(
                                  color: Color(0xFF00D9F5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<List<AuditEventRecord>>(
                                future: repository!.listAuditEvents(),
                                builder: (context, eventsSnapshot) {
                                  if (!eventsSnapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    children: eventsSnapshot.data!
                                        .take(8)
                                        .map(
                                          (event) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.verified_user_outlined,
                                            ),
                                            title: Text(event.action),
                                            subtitle: Text(event.resourceType),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
