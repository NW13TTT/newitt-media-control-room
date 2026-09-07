import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.repository});

  final ControlRoomRepository? repository;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildWelcome(),
            const SizedBox(height: 24),
            _buildAiControlBox(),
            const SizedBox(height: 24),
            _buildStatusRow(),
            const SizedBox(height: 24),
            if (repository != null) ...[
              _SafetySummary(repository: repository!),
              const SizedBox(height: 24),
              _AgreementSummary(repository: repository!),
              const SizedBox(height: 24),
              _CloudflareSummary(repository: repository!),
              const SizedBox(height: 24),
              _AnalyticsSummary(repository: repository!),
              const SizedBox(height: 24),
              _SecuritySummary(repository: repository!),
              const SizedBox(height: 24),
            ],
            _buildFeatureCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = Row(
          children: [
            const Expanded(
              child: Text(
                'Control Room',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
            ),
            const SmartHelpButton(
              guideId: 'dashboard',
              tooltip: 'Dashboard help',
            ),
            const SizedBox(width: 12),
            _operationalBadge(),
          ],
        );
        if (constraints.maxWidth >= ControlRoomBreakpoints.phone) {
          return header;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Control Room',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SmartHelpButton(
                  guideId: 'dashboard',
                  tooltip: 'Dashboard help',
                ),
                _operationalBadge(),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _operationalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10251C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: Color(0xFF4ADE80)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'All systems operational',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Color(0xFF8DE7AA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(fontSize: 15, color: Color(0xFF7F8B95)),
        ),
        SizedBox(height: 5),
        Text(
          'What would you like to do?',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAiControlBox() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101A22), Color(0xFF0C131A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF17404A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF00D9F5), size: 21),
              Text(
                'AI Control Box',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell the Control Room what you need in normal language.',
            style: TextStyle(color: Color(0xFF84919B), fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'For example: Add these photos to my wedding gallery...',
              hintStyle: const TextStyle(
                color: Color(0xFF596670),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFF080D12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF25333D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF25333D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00A8C4)),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () {},
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00A8C4),
                  ),
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    if (repository != null) {
      return _WebsiteMetricsRow(repository: repository!);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _statusCard(
            'Website',
            'Online',
            Icons.language,
            const Color(0xFF4ADE80),
          ),
          _statusCard(
            'Content',
            'Up to date',
            Icons.check_circle_outline,
            const Color(0xFF4ADE80),
          ),
          _statusCard(
            'Last publish',
            'Ready',
            Icons.cloud_done_outlined,
            const Color(0xFF00D9F5),
          ),
        ];

        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                if (card != cards.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index < cards.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _statusCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2730)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF71808B)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _featureCard(
                Icons.photo_library_outlined,
                'Media Library',
                'Manage images and videos',
              ),
              _featureCard(
                Icons.public_outlined,
                'Website',
                'View and manage your site',
              ),
              _featureCard(
                Icons.support_agent_outlined,
                'NEWITT Support',
                'Request help or access',
              ),
            ];

            if (constraints.maxWidth < 700) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    if (card != cards.last) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (int index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index < cards.length - 1) const SizedBox(width: 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _featureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2730)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00C6E6), size: 25),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: Color(0xFF73808A)),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummary extends StatelessWidget {
  const _AnalyticsSummary({required this.repository});
  final ControlRoomRepository repository;
  @override
  Widget build(BuildContext context) => FutureBuilder<AnalyticsSummaryRecord>(
    future: repository.getAnalyticsSummary(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final data = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SafetyMetric(
                label: 'Websites',
                value: data.websites,
                color: const Color(0xFF00D9F5),
              ),
              _SafetyMetric(
                label: 'Content',
                value: data.content,
                color: const Color(0xFF4ADE80),
              ),
              _SafetyMetric(
                label: 'Published',
                value: data.published,
                color: const Color(0xFF4ADE80),
              ),
              _SafetyMetric(
                label: 'Media',
                value: data.media,
                color: const Color(0xFF00D9F5),
              ),
              _SafetyMetric(
                label: 'Open support',
                value: data.supportOpen,
                color: const Color(0xFFE9B949),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _SecuritySummary extends StatelessWidget {
  const _SecuritySummary({required this.repository});

  final ControlRoomRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<SecuritySummaryRecord>(
    future: repository.getSecuritySummary(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _SafetyMetric(
            label: 'Recent audit events',
            value: snapshot.data!.recentAuditEvents,
            color: const Color(0xFF00D9F5),
          ),
        ],
      );
    },
  );
}

class _CloudflareSummary extends StatelessWidget {
  const _CloudflareSummary({required this.repository});
  final ControlRoomRepository repository;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<CloudflareAccountRecord>>(
        future: repository.listCloudflareAccounts(),
        builder: (context, accountSnapshot) =>
            FutureBuilder<List<CloudflareZoneRecord>>(
              future: repository.listCloudflareZones(),
              builder: (context, zoneSnapshot) =>
                  FutureBuilder<List<CloudflareDeploymentRecord>>(
                    future: repository.listCloudflareDeployments(),
                    builder: (context, deploymentSnapshot) {
                      if (!accountSnapshot.hasData ||
                          !zoneSnapshot.hasData ||
                          !deploymentSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final accounts = accountSnapshot.data!;
                      final zones = zoneSnapshot.data!;
                      final deployments = deploymentSnapshot.data!;
                      final errors = deployments
                          .where((item) => item.status == 'ERROR')
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cloudflare',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _SafetyMetric(
                                label: 'Connection',
                                value:
                                    accounts.any(
                                      (item) => item.status == 'CONNECTED',
                                    )
                                    ? 1
                                    : 0,
                                color: const Color(0xFF00D9F5),
                              ),
                              _SafetyMetric(
                                label: 'Known zones',
                                value: zones.length,
                                color: const Color(0xFF4ADE80),
                              ),
                              _SafetyMetric(
                                label: 'Deployments',
                                value: deployments.length,
                                color: const Color(0xFF00D9F5),
                              ),
                              _SafetyMetric(
                                label: 'Infrastructure errors',
                                value: errors,
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
            ),
      );
}

class _WebsiteMetricsRow extends StatelessWidget {
  const _WebsiteMetricsRow({required this.repository});
  final ControlRoomRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<WebsiteMetrics>(
    future: repository.getWebsiteMetrics(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 84,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final metrics = snapshot.data!;
      return LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            _metricCard(
              'Websites',
              metrics.total,
              Icons.language_outlined,
              const Color(0xFF00D9F5),
            ),
            _metricCard(
              'Published',
              metrics.published,
              Icons.public_outlined,
              const Color(0xFF4ADE80),
            ),
            _metricCard(
              'Expiring soon',
              metrics.expiringSoon,
              Icons.event_outlined,
              const Color(0xFFE9B949),
            ),
            _metricCard(
              'Suspended',
              metrics.suspended,
              Icons.pause_circle_outline,
              Colors.redAccent,
            ),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: cards);
        },
      );
    },
  );

  Widget _metricCard(String label, int value, IconData icon, Color color) =>
      Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D141B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1B2730)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF71808B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AgreementSummary extends StatelessWidget {
  const _AgreementSummary({required this.repository});
  final ControlRoomRepository repository;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<CommercialAgreementRecord>>(
        future: repository.listCommercialAgreements(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final agreements = snapshot.data!;
          int count(String status) =>
              agreements.where((item) => item.status == status).length;
          final renewals = agreements
              .where(
                (item) =>
                    item.renewalDate != null &&
                    !item.renewalDate!.isAfter(
                      DateTime.now().add(const Duration(days: 30)),
                    ),
              )
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Commercial Agreements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SafetyMetric(
                    label: 'Active Agreements',
                    value: count('ACTIVE'),
                    color: const Color(0xFF4ADE80),
                  ),
                  _SafetyMetric(
                    label: 'Draft Agreements',
                    value: count('DRAFT'),
                    color: const Color(0xFFE9B949),
                  ),
                  _SafetyMetric(
                    label: 'Renewals Due',
                    value: renewals,
                    color: const Color(0xFF00D9F5),
                  ),
                  _SafetyMetric(
                    label: 'Suspended Agreements',
                    value: count('SUSPENDED'),
                    color: Colors.redAccent,
                  ),
                  _SafetyMetric(
                    label: 'Cancelled Agreements',
                    value: count('CANCELLED'),
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ],
          );
        },
      );
}

class _SafetySummary extends StatelessWidget {
  const _SafetySummary({required this.repository});

  final ControlRoomRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<ContentSafetySummary>(
    future: repository.getContentSafetySummary(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final summary = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Safety',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SafetyMetric(
                label: 'Safe',
                value: summary.safe,
                color: const Color(0xFF4ADE80),
              ),
              _SafetyMetric(
                label: 'Needs Review',
                value: summary.review,
                color: const Color(0xFFE9B949),
              ),
              _SafetyMetric(
                label: 'Blocked',
                value: summary.blocked,
                color: Colors.redAccent,
              ),
              _SafetyMetric(
                label: 'Open Findings',
                value: summary.openFindings,
                color: const Color(0xFF00D9F5),
              ),
              _SafetyMetric(
                label: 'Critical Findings',
                value: summary.criticalFindings,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _SafetyMetric extends StatelessWidget {
  const _SafetyMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0D141B),
      border: Border.all(color: const Color(0xFF1B2730)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF71808B), fontSize: 12),
        ),
      ],
    ),
  );
}
