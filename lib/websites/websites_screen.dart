import 'package:flutter/material.dart';

import '../core/layout/responsive.dart';
import 'website_model.dart';

class WebsitesScreen extends StatelessWidget {
  const WebsitesScreen({super.key, required this.websites});

  final List<Website> websites;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildPreviewNotice(),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: websites
                          .map(
                            (website) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: WebsiteStatusCard(website: website),
                            ),
                          )
                          .toList(),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: websites.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.92,
                        ),
                    itemBuilder: (context, index) {
                      return WebsiteStatusCard(website: websites[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF102B35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.language_outlined,
            color: Color(0xFF00D9F5),
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Websites',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage website profiles and review operational health.',
                style: TextStyle(fontSize: 13, color: Color(0xFF7F8B95)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263543)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: Color(0xFF00D9F5), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Development preview. No live website connections are active. Customer cards show operational placeholders only; private website content is not exposed here.',
              style: TextStyle(
                color: Color(0xFFB6C3CB),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebsiteStatusCard extends StatelessWidget {
  const WebsiteStatusCard({super.key, required this.website});

  final Website website;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2A35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      website.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      website.domain,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8B95),
                      ),
                    ),
                  ],
                ),
              ),
              _WebsiteTypeBadge(type: website.type),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF1B2730), height: 1),
          const SizedBox(height: 16),
          _StatusLine(
            icon: Icons.link_outlined,
            label: 'Connection',
            value: _connectionLabel(website.connectionStatus),
            color: const Color(0xFFE9B949),
          ),
          _StatusLine(
            icon: Icons.language_outlined,
            label: 'Website online',
            value: _healthLabel(website.onlineStatus),
            color: _healthColor(website.onlineStatus),
          ),
          _StatusLine(
            icon: Icons.lock_outline,
            label: 'SSL status',
            value: _sslLabel(website.sslStatus),
            color: _sslColor(website.sslStatus),
          ),
          _StatusLine(
            icon: Icons.public_outlined,
            label: 'Domain status',
            value: _domainLabel(website.domainStatus),
            color: _domainColor(website.domainStatus),
          ),
          _StatusLine(
            icon: Icons.rocket_launch_outlined,
            label: 'Deployment',
            value: _deploymentLabel(website.deploymentStatus),
            color: _deploymentColor(website.deploymentStatus),
          ),
          _StatusLine(
            icon: Icons.error_outline,
            label: 'Critical errors',
            value: _errorLabel(website.criticalErrorStatus),
            color: _errorColor(website.criticalErrorStatus),
          ),
          const SizedBox(height: 14),
          const Text(
            'CAPABILITIES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6,
              color: Color(0xFF697783),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: website.capabilities
                .map((capability) => _CapabilityChip(label: capability.label))
                .toList(),
          ),
        ],
      ),
    );
  }

  static String _connectionLabel(WebsiteConnectionStatus status) {
    switch (status) {
      case WebsiteConnectionStatus.connected:
        return 'Connected';
      case WebsiteConnectionStatus.developmentPreview:
        return 'Development preview';
      case WebsiteConnectionStatus.notConnected:
        return 'Not connected';
    }
  }

  static String _healthLabel(WebsiteHealthStatus status) {
    switch (status) {
      case WebsiteHealthStatus.online:
        return 'Online';
      case WebsiteHealthStatus.offline:
        return 'Offline';
      case WebsiteHealthStatus.unknown:
        return 'Not checked';
    }
  }

  static String _sslLabel(WebsiteSslStatus status) {
    switch (status) {
      case WebsiteSslStatus.active:
        return 'Active';
      case WebsiteSslStatus.inactive:
        return 'Inactive';
      case WebsiteSslStatus.unknown:
        return 'Not checked';
    }
  }

  static String _domainLabel(WebsiteDomainStatus status) {
    switch (status) {
      case WebsiteDomainStatus.connected:
        return 'Connected';
      case WebsiteDomainStatus.notConfigured:
        return 'Not configured';
      case WebsiteDomainStatus.unknown:
        return 'Not checked';
    }
  }

  static String _deploymentLabel(WebsiteDeploymentStatus status) {
    switch (status) {
      case WebsiteDeploymentStatus.successful:
        return 'Successful';
      case WebsiteDeploymentStatus.pending:
        return 'Pending';
      case WebsiteDeploymentStatus.failed:
        return 'Failed';
      case WebsiteDeploymentStatus.unknown:
        return 'Not available';
    }
  }

  static String _errorLabel(WebsiteCriticalErrorStatus status) {
    switch (status) {
      case WebsiteCriticalErrorStatus.noneReported:
        return 'None reported';
      case WebsiteCriticalErrorStatus.errorsReported:
        return 'Errors reported';
      case WebsiteCriticalErrorStatus.unknown:
        return 'Not checked';
    }
  }

  static Color _healthColor(WebsiteHealthStatus status) {
    return status == WebsiteHealthStatus.unknown
        ? const Color(0xFFE9B949)
        : const Color(0xFF54D68B);
  }

  static Color _sslColor(WebsiteSslStatus status) {
    return status == WebsiteSslStatus.unknown
        ? const Color(0xFFE9B949)
        : const Color(0xFF54D68B);
  }

  static Color _domainColor(WebsiteDomainStatus status) {
    return status == WebsiteDomainStatus.unknown
        ? const Color(0xFFE9B949)
        : const Color(0xFF54D68B);
  }

  static Color _deploymentColor(WebsiteDeploymentStatus status) {
    return status == WebsiteDeploymentStatus.unknown
        ? const Color(0xFFE9B949)
        : const Color(0xFF54D68B);
  }

  static Color _errorColor(WebsiteCriticalErrorStatus status) {
    return status == WebsiteCriticalErrorStatus.unknown
        ? const Color(0xFFE9B949)
        : const Color(0xFF54D68B);
  }
}

class _WebsiteTypeBadge extends StatelessWidget {
  const _WebsiteTypeBadge({required this.type});

  final WebsiteType type;

  @override
  Widget build(BuildContext context) {
    final bool owner = type == WebsiteType.owner;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: owner ? const Color(0xFF102B35) : const Color(0xFF202534),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: owner ? const Color(0xFF00D9F5) : const Color(0xFFC0C8D0),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF82909B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFAEB9C1)),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF111D26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF20313D)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF9EABB4)),
      ),
    );
  }
}
