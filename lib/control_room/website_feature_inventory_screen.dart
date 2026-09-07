import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';

const _featureKeys = <String, String>{
  'homepage': 'Homepage',
  'navigation': 'Navigation',
  'branding': 'Branding',
  'hero': 'Hero',
  'about': 'About',
  'contact': 'Contact',
  'social_links': 'Social links',
  'youtube': 'YouTube',
  'tiktok': 'TikTok',
  'galleries': 'Galleries',
  'photography': 'Photography',
  'videos': 'Videos',
  'investigations': 'Investigations',
  'locations': 'Locations',
  'events': 'Events',
  'bookings': 'Bookings',
  'live': 'Live',
  'news': 'News / Updates',
  'featured': 'Featured content',
  'media_library': 'Media Library',
  'contact_enquiries': 'Contact enquiries',
};

class WebsiteFeatureInventoryScreen extends StatefulWidget {
  const WebsiteFeatureInventoryScreen({
    super.key,
    required this.repository,
    required this.websiteId,
    required this.websiteName,
  });

  final ControlRoomRepository? repository;
  final String websiteId;
  final String websiteName;

  @override
  State<WebsiteFeatureInventoryScreen> createState() =>
      _WebsiteFeatureInventoryScreenState();
}

class _WebsiteFeatureInventoryScreenState
    extends State<WebsiteFeatureInventoryScreen> {
  late Future<List<WebsiteFeatureRecord>> _future = widget.repository!
      .listWebsiteFeatures(widget.websiteId);

  void _refresh() => setState(() {
    _future = widget.repository!.listWebsiteFeatures(widget.websiteId);
  });

  @override
  Widget build(BuildContext context) {
    if (widget.repository == null) {
      return const Center(child: Text('Feature mapping unavailable.'));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: SingleChildScrollView(
        child: ResponsiveContent(
          child: FutureBuilder<List<WebsiteFeatureRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final existing = {
                for (final feature in snapshot.data!)
                  feature.featureKey: feature,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.websiteName} features',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh feature mapping',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Map existing website capabilities without replacing or creating duplicates.',
                    style: TextStyle(color: Color(0xFF8A99A5)),
                  ),
                  const SizedBox(height: 20),
                  ..._featureKeys.entries.map(
                    (entry) => _FeatureTile(
                      label: entry.value,
                      feature: existing[entry.key],
                      onSave: (status, connected, enabled, notes) async {
                        await widget.repository!.saveWebsiteFeature(
                          id: existing[entry.key]?.id,
                          websiteId: widget.websiteId,
                          featureKey: entry.key,
                          evidenceStatus: status,
                          connected: connected,
                          enabled: enabled,
                          notes: notes,
                        );
                        if (mounted) _refresh();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatefulWidget {
  const _FeatureTile({
    required this.label,
    required this.feature,
    required this.onSave,
  });
  final String label;
  final WebsiteFeatureRecord? feature;
  final Future<void> Function(String, bool, bool, String?) onSave;

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  late String status = widget.feature?.evidenceStatus ?? 'NEEDS_REVIEW';
  late bool connected = widget.feature?.connected ?? false;
  late bool enabled = widget.feature?.enabled ?? false;
  bool saving = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DropdownButton<String>(
            value: status,
            items:
                const [
                      'EXISTING',
                      'AVAILABLE',
                      'NEEDS_REVIEW',
                      'DISABLED',
                      'PLANNED',
                    ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: saving
                ? null
                : (value) => setState(() => status = value!),
          ),
          FilterChip(
            label: Text(connected ? 'Connected' : 'Not connected'),
            selected: connected,
            onSelected: saving
                ? null
                : (value) => setState(() => connected = value),
          ),
          FilterChip(
            label: Text(enabled ? 'Enabled' : 'Opt-in'),
            selected: enabled,
            onSelected: saving
                ? null
                : (value) => setState(() => enabled = value),
          ),
          IconButton(
            tooltip: 'Save feature mapping',
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    await widget.onSave(status, connected, enabled, null);
                    if (mounted) setState(() => saving = false);
                  },
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
    ),
  );
}
