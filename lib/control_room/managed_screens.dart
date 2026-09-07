import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, StorageException;

import '../auth/auth_models.dart';
import '../backend/control_room_repository.dart';
import 'content_section_editor.dart';
import 'contact_enquiries_screen.dart';
import 'media_picker_options.dart';
import 'website_feature_inventory_screen.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';
import '../websites/website_model.dart';

const _canvas = Color(0xFF080B10);
const _panel = Color(0xFF0D141C);
const _border = Color(0xFF1B2A35);
const _muted = Color(0xFF8A99A5);
const _cyan = Color(0xFF00D9F5);

/// Matches the Supabase project storage upload limit.
const _maxUploadBytes = 50 * 1024 * 1024;
const _messageDuration = Duration(seconds: 6);

const _supportedMediaTypes = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'wav': 'audio/wav',
};

String _sizeLabel(int bytes) {
  final megabytes = bytes / (1024 * 1024);
  return '${megabytes >= 10 ? megabytes.round() : megabytes.toStringAsFixed(1)} MB';
}

class WebsiteManagementScreen extends StatelessWidget {
  const WebsiteManagementScreen({
    super.key,
    required this.websites,
    required this.repository,
    this.session,
  });

  final List<Website> websites;
  final ControlRoomRepository? repository;
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final activeSession = session;
    final isCustomer = activeSession?.profile.role == AuthRole.customer;
    final configuration = websites.isEmpty
        ? null
        : websites.first.configuration;
    return _PageFrame(
      title: isCustomer ? 'My Website' : 'Websites',
      subtitle: configuration?.tagline.isNotEmpty == true
          ? '${configuration!.brandName} | ${configuration.tagline}'
          : isCustomer
          ? 'Your private website workspace and page records.'
          : 'Website lifecycle, templates, pages and content records.',
      icon: Icons.language_outlined,
      child: repository == null
          ? const _UnavailableState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WebsiteAnalyticsSummary(repository: repository!),
                const SizedBox(height: 12),
                _WebsiteCloudflareStatus(
                  repository: repository!,
                  websites: websites,
                ),
                const SizedBox(height: 24),
                _ContentWorkspace(
                  websites: websites,
                  repository: repository!,
                  isMasterAdmin:
                      activeSession == null ||
                      activeSession.profile.role == AuthRole.masterAdmin,
                ),
              ],
            ),
    );
  }
}

class _WebsiteAnalyticsSummary extends StatelessWidget {
  const _WebsiteAnalyticsSummary({required this.repository});
  final ControlRoomRepository repository;
  @override
  Widget build(BuildContext context) => FutureBuilder<AnalyticsSummaryRecord>(
    future: repository.getAnalyticsSummary(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final data = snapshot.data!;
      return Text(
        'Operational analytics: ${data.content} content | ${data.published} published | ${data.media} media',
        style: const TextStyle(color: _muted, fontSize: 12),
      );
    },
  );
}

class _WebsiteCloudflareStatus extends StatelessWidget {
  const _WebsiteCloudflareStatus({
    required this.repository,
    required this.websites,
  });
  final ControlRoomRepository repository;
  final List<Website> websites;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<CloudflareZoneRecord>>(
    future: repository.listCloudflareZones(),
    builder: (context, zones) {
      if (!zones.hasData || zones.data!.isEmpty) {
        return const Text(
          'Cloudflare: Not Configured',
          style: TextStyle(color: _muted),
        );
      }
      return FutureBuilder<List<CloudflareDeploymentRecord>>(
        future: repository.listCloudflareDeployments(),
        builder: (context, deployments) {
          if (!deployments.hasData) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cloudflare infrastructure',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...zones.data!.map((zone) {
                final site = websites
                    .where((website) => website.id == zone.websiteId)
                    .firstOrNull;
                final deployment = deployments.data!
                    .where((item) => item.websiteId == zone.websiteId)
                    .firstOrNull;
                return Text(
                  '${site?.name ?? zone.domain}: ${zone.domain} | Zone ${zone.status ?? 'Unknown'} | SSL/TLS ${zone.sslStatus ?? 'Unknown'} | Deployment ${deployment?.status ?? 'NOT_CONNECTED'}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                );
              }),
            ],
          );
        },
      );
    },
  );
}

class _ContentWorkspace extends StatefulWidget {
  const _ContentWorkspace({
    required this.websites,
    required this.repository,
    required this.isMasterAdmin,
  });
  final List<Website> websites;
  final ControlRoomRepository repository;
  final bool isMasterAdmin;

  @override
  State<_ContentWorkspace> createState() => _ContentWorkspaceState();
}

class _ContentWorkspaceState extends State<_ContentWorkspace> {
  late Future<List<ContentRecord>> _future = widget.repository.listContent();
  String _query = '';
  String _status = 'All';
  String _section = 'All';
  String? _busyId;

  void _refresh() => setState(() {
    _future = widget.repository.listContent();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ContentRecord>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _LoadingState();
      }
      if (snapshot.hasError) return _ErrorState(onRetry: _refresh);
      final records = snapshot.data!;
      final visible = records.where((record) {
        final searchable =
            '${record.contentKey} ${record.content['title'] ?? ''} ${record.content['text'] ?? ''}'
                .toLowerCase();
        return (_status == 'All' || record.status == _status) &&
            (_section == 'All' || _contentSection(record) == _section) &&
            searchable.contains(_query.trim().toLowerCase());
      }).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WebsiteManagementPanel(
            websites: widget.websites,
            repository: widget.repository,
            isMasterAdmin: widget.isMasterAdmin,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Content records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: widget.websites.isEmpty ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add content'),
              ),
              const SmartHelpButton(
                guideId: 'website-management',
                tooltip: 'Website management help',
              ),
              const SmartHelpButton(
                guideId: 'content-management',
                tooltip: 'Content management help',
              ),
              const SmartHelpButton(
                guideId: 'staging-approval',
                tooltip: 'Staging and approval help',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search content',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final status in const ['All', 'DRAFT', 'PUBLISHED'])
                ChoiceChip(
                  label: Text(status == 'All' ? 'All' : status.toLowerCase()),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _section,
            decoration: const InputDecoration(labelText: 'Content area'),
            items: _contentSections
                .map(
                  (section) =>
                      DropdownMenuItem(value: section, child: Text(section)),
                )
                .toList(),
            onChanged: (value) => setState(() => _section = value!),
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const _EmptyState(
              icon: Icons.article_outlined,
              title: 'No website content yet',
              message: 'Create a homepage or page content record to begin managing website copy.',
            )
          else if (visible.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_outlined,
              title: 'No matching content',
              message: 'Try changing your search or status filter.',
            )
          else
            ...visible.map(
              (record) => _RecordTile(
                icon: Icons.article_outlined,
                title: record.contentKey,
                subtitle:
                    '${_contentSection(record)}  |  ${record.content['title'] ?? 'Website content record'}',
                detail: '${record.content['text'] ?? ''}',
                badge: record.status,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit content',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _busyId == null
                          ? () => _openEditor(record)
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Preview content',
                      icon: const Icon(Icons.preview_outlined),
                      onPressed: _busyId == null
                          ? () => _preview(record)
                          : null,
                    ),
                    if (widget.isMasterAdmin)
                      IconButton(
                        tooltip: 'Publish content',
                        icon: const Icon(Icons.publish_outlined),
                        onPressed:
                            _busyId == null && record.status != 'PUBLISHED'
                            ? () => _publish(record)
                            : null,
                      ),
                    IconButton(
                      tooltip: 'Delete content',
                      icon: _busyId == record.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      onPressed: _busyId == null ? () => _delete(record) : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _openEditor([ContentRecord? record]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ContentDialog(
        websites: widget.websites,
        repository: widget.repository,
        record: record,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _preview(ContentRecord record) => showDialog<void>(
    context: context,
    builder: (_) => _ContentPreviewDialog(record: record),
  );

  Future<void> _publish(ContentRecord record) async {
    setState(() => _busyId = record.id);
    try {
      await widget.repository.publishContent(
        websiteId: record.websiteId,
        contentKey: record.contentKey,
      );
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Content published.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to publish this content.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(ContentRecord record) async {
    if (!await _confirm(
      context,
      'Delete ${record.contentKey}?',
      'This content and its published snapshot will be removed.',
    )) {
      return;
    }
    setState(() => _busyId = record.id);
    try {
      await widget.repository.deleteContent(record.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Content removed.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove this content.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _ContentPreviewDialog extends StatelessWidget {
  const _ContentPreviewDialog({required this.record});

  final ContentRecord record;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Draft preview'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(label: record.status),
            const SizedBox(height: 16),
            Text(
              _contentSection(record),
              style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${record.content['title'] ?? record.contentKey}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _FormattedContent(text: '${record.content['text'] ?? ''}'),
            if (record.content['category'] != null) ...[
              const SizedBox(height: 16),
              Text(
                '${record.content['category']}',
                style: const TextStyle(color: _muted),
              ),
            ],
            if (record.content['featured'] == true) ...[
              const SizedBox(height: 12),
              const Text('Featured content', style: TextStyle(color: _cyan)),
            ],
            if (record.content['sections'] is List) ...[
              const SizedBox(height: 20),
              const Text(
                'Page sections',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...((record.content['sections'] as List).whereType<Map>().map(
                (section) => _PreviewSection(
                  section: Map<String, dynamic>.from(section),
                ),
              )),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.section});
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final type = section['type'] as String? ?? 'text';
    final title = section['title'] as String?;
    final url = section['url'] as String?;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B2A35)),
      ),
      child: Row(
        children: [
          Icon(
            type == 'image' || type == 'gallery'
                ? Icons.image_outlined
                : type == 'video' || type == 'external_video'
                ? Icons.videocam_outlined
                : type == 'button'
                ? Icons.link_outlined
                : Icons.view_agenda_outlined,
            color: _cyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title ?? url ?? type.replaceAll('_', ' '),
              style: const TextStyle(color: Color(0xFFD7E3E8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormattedContent extends StatelessWidget {
  const _FormattedContent({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: text.split('\n').map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            trimmed.substring(2),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        );
      }
      if (trimmed.startsWith('- ')) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '• '),
                ..._formattedSpans(trimmed.substring(2)),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: _formattedSpans(line))),
      );
    }).toList(),
  );
}

List<InlineSpan> _formattedSpans(String value) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'(\*\*|__)(.+?)\1|([*_])(.+?)\3');
  var cursor = 0;
  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }
    final isBold = match.group(1) != null;
    spans.add(
      TextSpan(
        text: isBold ? match.group(2) : match.group(4),
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: isBold ? FontStyle.normal : FontStyle.italic,
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
  return spans;
}

const _contentSections = [
  'All',
  'Homepage',
  'About',
  'Services',
  'News / Updates',
  'Featured Content',
];

String _contentSection(ContentRecord record) {
  final stored = record.content['section'];
  if (stored is String && _contentSections.contains(stored)) return stored;
  return switch (record.contentKey.toLowerCase()) {
    'homepage' || 'home' => 'Homepage',
    'about' => 'About',
    'services' => 'Services',
    'news' || 'updates' => 'News / Updates',
    'featured' => 'Featured Content',
    _ => 'Homepage',
  };
}

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({
    super.key,
    required this.repository,
    required this.websites,
  });
  final ControlRoomRepository? repository;
  final List<Website> websites;
  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  String _query = '';
  String _typeFilter = 'All';
  String? _categoryFilter;
  bool _uploading = false;
  int _uploadedCount = 0;
  int _uploadTotal = 0;
  String? _deletingId;
  Future<void> _edit(MediaRecord item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _MediaMetadataDialog(item: item, repository: widget.repository!),
    );
    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Media details saved.')));
    }
  }

  Future<void> _delete(MediaRecord item) async {
    if (_deletingId != null) return;
    final confirmed = await _confirm(
      context,
      'Delete ${item.title ?? 'this media'}?',
      'This will remove the media from your library.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deletingId = item.id);
    try {
      await widget.repository!.deleteMedia(item.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Media removed.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Media removal could not be completed. Refresh before retrying.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _upload() async {
    if (_uploading || widget.websites.isEmpty) return;
    // An unrestricted picker is the only variant iOS, iPadOS and Android all
    // open on the photo library and camera; the selection is checked below.
    final files = await FilePicker.pickFiles(
      type: FileType.any,
      webOptions: mediaPickerWebOptions(),
    );
    if (files.isEmpty) return;

    final accepted = <({PlatformFile file, String mediaType})>[];
    final rejected = <String>[];
    for (final file in files) {
      final mediaType = _mediaType(file.extension);
      if (mediaType == null) {
        rejected.add('${file.name} is not a supported format');
        continue;
      }
      final size = await file.length();
      if (size > _maxUploadBytes) {
        rejected.add('${file.name} is ${_sizeLabel(size)}');
        continue;
      }
      accepted.add((file: file, mediaType: mediaType));
    }

    if (rejected.isNotEmpty && mounted) {
      _showMessage(
        '${rejected.join('. ')}. Photos may be JPG, PNG, HEIC, WebP or GIF, '
        'video MP4 or MOV, audio MP3, M4A or WAV, up to ${_sizeLabel(_maxUploadBytes)} each.',
      );
    }
    if (accepted.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadedCount = 0;
      _uploadTotal = accepted.length;
    });
    final failures = <String>[];
    try {
      for (final entry in accepted) {
        try {
          final bytes = await entry.file.readAsBytes();
          if (bytes.isEmpty) {
            throw const FormatException(
              'the file could not be read. If it is stored in the cloud, '
              'download it to this device first.',
            );
          }
          await widget.repository!.uploadMedia(
            MediaUploadRequest(
              websiteId: widget.websites.first.id!,
              fileName: entry.file.name,
              bytes: bytes,
              mediaType: entry.mediaType,
            ),
          );
          if (mounted) setState(() => _uploadedCount++);
        } catch (error) {
          failures.add('${entry.file.name}: ${_failureReason(error)}');
        }
      }
      if (mounted) {
        _showMessage(
          failures.isEmpty
              ? 'Media uploaded.'
              : 'Uploaded $_uploadedCount of ${accepted.length}. ${failures.first}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadedCount = 0;
          _uploadTotal = 0;
        });
      }
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), duration: _messageDuration));

  String _failureReason(Object error) {
    final reason = switch (error) {
      StorageException(:final message) => message,
      PostgrestException(:final message) => message,
      StateError(:final message) => message,
      FormatException(:final message) => message,
      _ => '',
    }.trim();
    return reason.isEmpty ? 'Upload could not be completed.' : reason;
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Media library',
    subtitle: 'Browse tenant media and its metadata.',
    icon: Icons.photo_library_outlined,
    child: widget.repository == null
        ? const _UnavailableState()
        : Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SmartHelpButton(
                      guideId: 'media-library',
                      tooltip: 'Media Library help',
                    ),
                    FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _uploading
                            ? 'Uploading $_uploadedCount/$_uploadTotal...'
                            : 'Upload media',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search media by title',
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<MediaRecord>>(
                future: widget.repository!.listMedia(query: _query),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _LoadingState();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: () => setState(() {}));
                  }
                  final media = snapshot.data!;
                  if (media.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.perm_media_outlined,
                      title: 'No media found',
                      message:
                          'Upload images, video or audio to use them in this website.',
                    );
                  }
                  final categories =
                      media
                          .map(
                            (item) =>
                                '${item.metadata['category'] ?? ''}'.trim(),
                          )
                          .where((category) => category.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort();
                  final filtered = media.where((item) {
                    final type = '${item.metadata['type'] ?? ''}';
                    final category = '${item.metadata['category'] ?? ''}';
                    final matchesQuery =
                        _query.trim().isEmpty ||
                        (item.title ?? '').toLowerCase().contains(
                          _query.trim().toLowerCase(),
                        );
                    final matchesType =
                        _typeFilter == 'All' ||
                        (_typeFilter == 'Photos' &&
                            type.startsWith('image/')) ||
                        (_typeFilter == 'Video' && type.startsWith('video/')) ||
                        (_typeFilter == 'Audio' && type.startsWith('audio/'));
                    return matchesQuery &&
                        matchesType &&
                        (_categoryFilter == null ||
                            category == _categoryFilter);
                  }).toList();
                  return Column(
                    children: [
                      _MediaFilters(
                        typeFilter: _typeFilter,
                        categories: categories,
                        categoryFilter: _categoryFilter,
                        onTypeChanged: (value) =>
                            setState(() => _typeFilter = value),
                        onCategoryChanged: (value) =>
                            setState(() => _categoryFilter = value),
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        const _EmptyState(
                          icon: Icons.filter_list_off_outlined,
                          title: 'No matching media',
                          message: 'Try changing your search or filters.',
                        )
                      else
                        ...filtered.map(
                          (item) => _MediaLibraryItem(
                            item: item,
                            deleting: _deletingId == item.id,
                            actionsDisabled: _deletingId != null,
                            onEdit: () => _edit(item),
                            onDelete: () => _delete(item),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
  );
  String? _mediaType(String? extension) =>
      _supportedMediaTypes[extension?.toLowerCase()];
}

class _MediaLibraryItem extends StatelessWidget {
  const _MediaLibraryItem({
    required this.item,
    required this.deleting,
    required this.actionsDisabled,
    required this.onEdit,
    required this.onDelete,
  });

  final MediaRecord item;
  final bool deleting;
  final bool actionsDisabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = '${item.metadata['type'] ?? ''}';
    final displayUrl = item.metadata['display_url'];
    final canPreview =
        type.startsWith('image/') &&
        displayUrl is String &&
        displayUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: canPreview
                  ? Image.network(
                      displayUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const _MediaTypeIcon(type: 'image/'),
                    )
                  : _MediaTypeIcon(type: type),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? 'Untitled media',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  item.storagePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit media details',
            icon: const Icon(Icons.edit_outlined),
            onPressed: actionsDisabled ? null : onEdit,
          ),
          IconButton(
            tooltip: 'Delete media',
            icon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: actionsDisabled ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

class _MediaTypeIcon extends StatelessWidget {
  const _MediaTypeIcon({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF102B35),
    child: Center(
      child: Icon(
        type.startsWith('video/')
            ? Icons.videocam_outlined
            : type.startsWith('audio/')
            ? Icons.audiotrack_outlined
            : Icons.image_outlined,
        color: _cyan,
      ),
    ),
  );
}

class _MediaFilters extends StatelessWidget {
  const _MediaFilters({
    required this.typeFilter,
    required this.categories,
    required this.categoryFilter,
    required this.onTypeChanged,
    required this.onCategoryChanged,
  });
  final String typeFilter;
  final List<String> categories;
  final String? categoryFilter;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final type in const ['All', 'Photos', 'Video', 'Audio'])
        ChoiceChip(
          label: Text(type),
          selected: typeFilter == type,
          onSelected: (_) => onTypeChanged(type),
        ),
      if (categories.isNotEmpty)
        DropdownButton<String>(
          value: categoryFilter,
          hint: const Text('All categories'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All categories')),
            ...categories.map(
              (category) =>
                  DropdownMenuItem(value: category, child: Text(category)),
            ),
          ],
          onChanged: onCategoryChanged,
        ),
    ],
  );
}

class _MediaMetadataDialog extends StatefulWidget {
  const _MediaMetadataDialog({required this.item, required this.repository});
  final MediaRecord item;
  final ControlRoomRepository repository;
  @override
  State<_MediaMetadataDialog> createState() => _MediaMetadataDialogState();
}

class _MediaMetadataDialogState extends State<_MediaMetadataDialog> {
  late final title = TextEditingController(text: widget.item.title);
  late final description = TextEditingController(
    text: '${widget.item.metadata['description'] ?? ''}',
  );
  late final caption = TextEditingController(
    text: '${widget.item.metadata['caption'] ?? ''}',
  );
  late final category = TextEditingController(
    text: '${widget.item.metadata['category'] ?? ''}',
  );
  late final location = TextEditingController(
    text: '${widget.item.metadata['location'] ?? ''}',
  );
  late final date = TextEditingController(
    text: '${widget.item.metadata['date'] ?? ''}',
  );
  late final investigation = TextEditingController(
    text: '${widget.item.metadata['investigation'] ?? ''}',
  );
  late final credits = TextEditingController(
    text: '${widget.item.metadata['credits'] ?? ''}',
  );
  late String type;
  late bool featured;
  late bool published;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    type = '${widget.item.metadata['type'] ?? 'image/jpeg'}';
    featured = widget.item.metadata['featured'] == true;
    published = widget.item.metadata['published'] == true;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    caption.dispose();
    category.dispose();
    location.dispose();
    date.dispose();
    investigation.dispose();
    credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Edit media details'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                'image/jpeg',
                'video/mp4',
                'audio/mpeg',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => type = v!),
              decoration: const InputDecoration(labelText: 'Media type'),
            ),
            TextField(
              controller: caption,
              decoration: const InputDecoration(
                labelText: 'Caption or description',
              ),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: date,
              decoration: const InputDecoration(
                labelText: 'Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: investigation,
              decoration: const InputDecoration(labelText: 'Investigation'),
            ),
            TextField(
              controller: credits,
              decoration: const InputDecoration(labelText: 'Credits'),
            ),
            SwitchListTile(
              value: featured,
              onChanged: (v) => setState(() => featured = v),
              title: const Text('Featured'),
            ),
            SwitchListTile(
              value: published,
              onChanged: (v) => setState(() => published = v),
              title: const Text('Publish on website'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving...' : 'Save'),
      ),
    ],
  );
  Future<void> _save() async {
    if (title.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await widget.repository.saveMediaMetadata(
        id: widget.item.id,
        title: title.text,
        metadata: {
          ...widget.item.metadata,
          'type': type,
          'caption': caption.text,
          'description': description.text,
          'category': category.text,
          'location': location.text,
          'date': date.text,
          'investigation': investigation.text,
          'credits': credits.text,
          'featured': featured,
          'published': published,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
    }
  }
}

class SocialLinksScreen extends StatefulWidget {
  const SocialLinksScreen({
    super.key,
    required this.websites,
    required this.repository,
  });
  final List<Website> websites;
  final ControlRoomRepository? repository;
  @override
  State<SocialLinksScreen> createState() => _SocialLinksScreenState();
}

class _SocialLinksScreenState extends State<SocialLinksScreen> {
  late Future<List<SocialLinkRecord>> _future = _load();
  String? _deletingId;
  Future<List<SocialLinkRecord>> _load() =>
      widget.repository!.listSocialLinks();
  void _refresh() => setState(() {
    _future = _load();
  });
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Social links',
    subtitle: 'Manage links shown on your website.',
    icon: Icons.share_outlined,
    child: widget.repository == null
        ? const _UnavailableState()
        : FutureBuilder<List<SocialLinkRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingState();
              }
              if (snapshot.hasError) return _ErrorState(onRetry: _refresh);
              final links = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: widget.websites.isEmpty ? null : () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add link'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (links.isEmpty)
                    const _EmptyState(
                      icon: Icons.share_outlined,
                      title: 'No social links yet',
                      message: 'Add the social destinations that belong to this website.',
                    )
                  else
                    ...links.map(
                      (link) => _RecordTile(
                        icon: Icons.link_outlined,
                        title: link.platform,
                        subtitle: link.url,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit link',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(link),
                            ),
                            IconButton(
                              tooltip: 'Delete link',
                              icon: _deletingId == link.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              onPressed: _deletingId == null
                                  ? () => _delete(link)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
  );
  Future<void> _edit([SocialLinkRecord? link]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SocialDialog(
        websites: widget.websites,
        repository: widget.repository!,
        link: link,
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Social link saved.')));
    }
  }

  Future<void> _delete(SocialLinkRecord link) async {
    final confirmed = await _confirm(
      context,
      'Delete ${link.platform}?',
      'This social link will be removed from the Control Room.',
    );
    if (confirmed) {
      setState(() => _deletingId = link.id);
      try {
        await widget.repository!.deleteSocialLink(link.id);
        if (mounted) {
          _refresh();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Social link removed.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to remove this social link.')),
          );
        }
      } finally {
        if (mounted) setState(() => _deletingId = null);
      }
    }
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.websites,
    required this.repository,
    this.session,
  });
  final List<Website> websites;
  final ControlRoomRepository? repository;
  final AuthSession? session;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<List<SupportRequestRecord>> _future = _load();
  SupportRequestRecord? _selected;
  String _query = '';
  String _status = 'All';
  String _category = 'All';
  Future<List<SupportRequestRecord>> _load() =>
      widget.repository!.listSupportRequests();
  void _refresh() => setState(() => _future = _load());
  bool get _isMasterAdmin =>
      widget.session?.profile.role == AuthRole.masterAdmin;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Support',
    subtitle: _isMasterAdmin
        ? 'Manage customer support requests across the Control Room.'
        : 'Send a request and track your support work.',
    icon: Icons.support_agent_outlined,
    child: _selected != null
        ? _SupportTicketDetail(
            request: _selected!,
            onBack: () => setState(() => _selected = null),
            repository: widget.repository!,
            websites: widget.websites,
            isMasterAdmin: _isMasterAdmin,
          )
        : widget.repository == null
        ? const _UnavailableState()
        : FutureBuilder<List<SupportRequestRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingState();
              }
              if (snapshot.hasError) return _ErrorState(onRetry: _refresh);
              final requests = snapshot.data!;
              final visible = _isMasterAdmin
                  ? requests.where((request) {
                      final searchable =
                          '${request.subject} ${request.tenantId} '
                                  '${request.websiteId ?? ''} ${request.category} '
                                  '${request.status}'
                              .toLowerCase();
                      return searchable.contains(_query.trim().toLowerCase()) &&
                          (_status == 'All' || request.status == _status) &&
                          (_category == 'All' || request.category == _category);
                    }).toList()
                  : requests;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ContactEnquiriesScreen(
                          repository: widget.repository,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Contact enquiries'),
                  ),
                  const SizedBox(height: 12),
                  if (!_isMasterAdmin)
                    FilledButton.icon(
                      onPressed: () => _create(),
                      icon: const Icon(Icons.add),
                      label: const Text('New support request'),
                    )
                  else ...[
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText:
                            'Search tickets, tenants, websites, or status',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in _supportStatuses)
                          ChoiceChip(
                            label: Text(_supportStatusLabel(status)),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = status),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _supportCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(_supportCategoryLabel(category)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'All'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    const _EmptyState(
                      icon: Icons.support_agent_outlined,
                      title: 'No support requests yet',
                      message: 'When you need help, create a request and it will appear here.',
                    )
                  else if (visible.isEmpty)
                    const _EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No matching support requests',
                      message: 'Try changing the search or support filters.',
                    )
                  else
                    ...visible.map(
                      (request) => InkWell(
                        onTap: () => setState(() => _selected = request),
                        child: _RecordTile(
                          icon: Icons.confirmation_number_outlined,
                          title: request.subject,
                          subtitle: _supportCategoryLabel(request.category),
                          detail:
                              '${_isMasterAdmin ? 'Tenant ${request.tenantId}  |  ${_supportWebsiteLabel(request, widget.websites)}  |  ' : ''}${_supportStatusLabel(request.status)}  |  Created ${_supportDate(request.createdAt)}  |  Updated ${_supportDate(request.updatedAt)}',
                          badge: _supportStatusLabel(request.status),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
  );
  Future<void> _create() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SupportDialog(
        websites: widget.websites,
        repository: widget.repository!,
      ),
    );
    if (saved == true) _refresh();
  }
}

class _SupportTicketDetail extends StatefulWidget {
  const _SupportTicketDetail({
    required this.request,
    required this.onBack,
    required this.repository,
    required this.websites,
    required this.isMasterAdmin,
  });
  final SupportRequestRecord request;
  final VoidCallback onBack;
  final ControlRoomRepository repository;
  final List<Website> websites;
  final bool isMasterAdmin;

  @override
  State<_SupportTicketDetail> createState() => _SupportTicketDetailState();
}

class _SupportTicketDetailState extends State<_SupportTicketDetail> {
  late Future<List<SupportMessageRecord>> _messagesFuture = widget.repository
      .listSupportMessages(widget.request.id);
  final _reply = TextEditingController();
  String? _replyError;
  bool _sending = false;
  late String _status = widget.request.status;
  String? _statusError;
  bool _updatingStatus = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_sending) return;
    final reply = _reply.text.trim();
    if (reply.isEmpty) {
      setState(() => _replyError = 'Enter a reply before sending.');
      return;
    }
    setState(() {
      _sending = true;
      _replyError = null;
    });
    try {
      await widget.repository.addSupportMessage(
        requestId: widget.request.id,
        body: reply,
        internal: false,
      );
      if (mounted) {
        setState(() {
          _reply.clear();
          _messagesFuture = widget.repository.listSupportMessages(
            widget.request.id,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _replyError = 'Unable to send your reply. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAdminMessage(String body, {required bool internal}) async {
    await widget.repository.addSupportMessage(
      requestId: widget.request.id,
      body: body,
      internal: internal,
    );
    if (mounted) {
      setState(() {
        _messagesFuture = widget.repository.listSupportMessages(
          widget.request.id,
        );
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_updatingStatus || status == _status) return;
    setState(() {
      _updatingStatus = true;
      _statusError = null;
    });
    try {
      await widget.repository.updateSupportStatus(
        requestId: widget.request.id,
        status: status,
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        setState(
          () => _statusError =
              'Unable to update the ticket status. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to support'),
      ),
      const SizedBox(height: 16),
      Text(
        widget.request.subject,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          _Badge(label: _supportCategoryLabel(widget.request.category)),
          _Badge(label: _supportStatusLabel(widget.request.status)),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'Created ${_supportDate(widget.request.createdAt)}  |  Updated ${_supportDate(widget.request.updatedAt)}',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      if (widget.isMasterAdmin) ...[
        const SizedBox(height: 16),
        Text(
          'Tenant ${widget.request.tenantId}  |  ${_supportWebsiteLabel(widget.request, widget.websites)}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Ticket status'),
          items: _supportStatuses
              .skip(1)
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(_supportStatusLabel(status)),
                ),
              )
              .toList(),
          onChanged: _updatingStatus
              ? null
              : (status) {
                  if (status != null) _updateStatus(status);
                },
        ),
        if (_statusError != null) ...[
          const SizedBox(height: 8),
          Text(_statusError!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _updatingStatus
                  ? null
                  : () => _updateStatus('RESOLVED'),
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Resolve'),
            ),
            FilledButton.icon(
              onPressed: _updatingStatus ? null : () => _updateStatus('CLOSED'),
              icon: const Icon(Icons.lock_outline),
              label: Text(_updatingStatus ? 'Updating...' : 'Close'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      const Text('Your request', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        widget.request.body,
        style: const TextStyle(height: 1.5, color: Color(0xFFD7E3E8)),
      ),
      const SizedBox(height: 24),
      const Text('Conversation', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      FutureBuilder<List<SupportMessageRecord>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return const Text(
              'Unable to load conversation.',
              style: TextStyle(color: Color(0xFFE9B949)),
            );
          }
          final messages = snapshot.data!;
          final visibleMessages = messages
              .where((message) => !message.isInternal)
              .toList();
          if (!widget.isMasterAdmin && visibleMessages.isEmpty) {
            return const Text(
              'No replies yet.',
              style: TextStyle(color: _muted),
            );
          }
          if (!widget.isMasterAdmin) {
            return _SupportMessageList(messages: visibleMessages);
          }
          final internalMessages = messages
              .where((message) => message.isInternal)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer visible',
                style: TextStyle(color: _cyan, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _SupportMessageList(
                messages: visibleMessages,
                emptyMessage: 'No customer-visible replies yet.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Internal notes',
                style: TextStyle(
                  color: Color(0xFFE9B949),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _SupportMessageList(
                messages: internalMessages,
                emptyMessage: 'No internal notes yet.',
                internal: true,
              ),
            ],
          );
        },
      ),
      if (!widget.isMasterAdmin) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reply',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reply,
                enabled: !_sending,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) {
                  if (_replyError != null) setState(() => _replyError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Write your reply',
                  errorText: _replyError,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _sendReply,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_sending ? 'Sending...' : 'Send reply'),
                ),
              ),
            ],
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        _SupportMessageComposer(
          title: 'Customer-visible reply',
          hintText: 'Write a reply for the customer',
          actionLabel: 'Send reply',
          onSend: (body) => _sendAdminMessage(body, internal: false),
        ),
        const SizedBox(height: 12),
        _SupportMessageComposer(
          title: 'Internal note',
          hintText: 'Write an internal note',
          actionLabel: 'Add internal note',
          onSend: (body) => _sendAdminMessage(body, internal: true),
          internal: true,
        ),
      ],
    ],
  );
}

class _SupportMessageList extends StatelessWidget {
  const _SupportMessageList({
    required this.messages,
    this.emptyMessage,
    this.internal = false,
  });

  final List<SupportMessageRecord> messages;
  final String? emptyMessage;
  final bool internal;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Text(
        emptyMessage ?? 'No replies yet.',
        style: const TextStyle(color: _muted),
      );
    }
    return Column(
      children: messages
          .map(
            (message) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: internal ? const Color(0xFF211D12) : _panel,
                border: Border.all(
                  color: internal ? const Color(0xFF5C4B22) : _border,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    internal ? 'Internal note' : 'Customer visible',
                    style: TextStyle(
                      color: internal ? const Color(0xFFE9B949) : _cyan,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(message.body),
                  if (message.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _supportDate(message.createdAt),
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SupportMessageComposer extends StatefulWidget {
  const _SupportMessageComposer({
    required this.title,
    required this.hintText,
    required this.actionLabel,
    required this.onSend,
    this.internal = false,
  });

  final String title;
  final String hintText;
  final String actionLabel;
  final Future<void> Function(String body) onSend;
  final bool internal;

  @override
  State<_SupportMessageComposer> createState() =>
      _SupportMessageComposerState();
}

class _SupportMessageComposerState extends State<_SupportMessageComposer> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final body = _controller.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Enter a message before sending.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(body);
      if (mounted) _controller.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to send this message. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(
        color: widget.internal ? const Color(0xFF5C4B22) : _border,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          enabled: !_sending,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    widget.internal
                        ? Icons.note_add_outlined
                        : Icons.send_outlined,
                  ),
            label: Text(_sending ? 'Sending...' : widget.actionLabel),
          ),
        ),
      ],
    ),
  );
}

String _supportCategoryLabel(String value) => switch (value) {
  'All' => 'All categories',
  'WEBSITE' => 'Website',
  'CONTENT' => 'Content',
  'MEDIA' => 'Media',
  'ACCOUNT' => 'Account',
  'PAYMENTS' => 'Payments',
  'TECHNICAL' => 'Technical',
  _ => 'Other',
};

const _supportStatuses = [
  'All',
  'NEW',
  'OPEN',
  'IN_PROGRESS',
  'WAITING_FOR_CUSTOMER',
  'RESOLVED',
  'CLOSED',
];

const _supportCategories = [
  'All',
  'WEBSITE',
  'CONTENT',
  'MEDIA',
  'ACCOUNT',
  'PAYMENTS',
  'TECHNICAL',
  'OTHER',
];

String _supportWebsiteLabel(
  SupportRequestRecord request,
  List<Website> websites,
) {
  if (request.websiteId == null) return 'General support';
  return websites
          .where((website) => website.id == request.websiteId)
          .map((website) => website.name)
          .firstOrNull ??
      'Website ${request.websiteId}';
}

String _supportStatusLabel(String value) => switch (value) {
  'All' => 'All statuses',
  'NEW' => 'New',
  'OPEN' => 'Open',
  'IN_PROGRESS' => 'In Progress',
  'WAITING_FOR_CUSTOMER' => 'Waiting for Customer',
  'RESOLVED' => 'Resolved',
  'CLOSED' => 'Closed',
  _ => value,
};
String _supportDate(DateTime? value) => value == null
    ? 'Not available'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class PlatformAdminScreen extends StatefulWidget {
  const PlatformAdminScreen({
    super.key,
    required this.websites,
    required this.repository,
    required this.onWebsitesChanged,
  });
  final List<Website> websites;
  final ControlRoomRepository? repository;
  final VoidCallback onWebsitesChanged;

  @override
  State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
  late Future<List<CustomerRecord>> _customersFuture = _loadCustomers();
  String _customerQuery = '';

  Future<List<CustomerRecord>> _loadCustomers() =>
      widget.repository!.listCustomers();

  void _refresh() => setState(() {
    _customersFuture = _loadCustomers();
  });

  Future<void> _addCustomer() async {
    final provisioned = await showDialog<ProvisionedCustomer>(
      context: context,
      builder: (_) => _CustomerInvitationDialog(repository: widget.repository!),
    );
    if (provisioned != null && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitation sent to ${provisioned.invitationEmail} for ${provisioned.customer.name}.',
          ),
        ),
      );
    }
  }

  Future<void> _addWebsite(CustomerRecord customer) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerWebsiteDialog(
        customer: customer,
        repository: widget.repository!,
      ),
    );
    if (created == true && mounted) {
      widget.onWebsitesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Website created for ${customer.name}.')),
      );
    }
  }

  Future<void> _showCustomerDetails(CustomerRecord customer) =>
      showDialog<void>(
        context: context,
        builder: (_) => _CustomerDetailsDialog(
          customer: customer,
          websites: widget.websites
              .where((website) => website.tenantId == customer.id)
              .toList(),
          onCreateWebsite: () {
            Navigator.pop(context);
            _addWebsite(customer);
          },
        ),
      );

  Future<void> _showCustomerUsers(CustomerRecord customer) => showDialog<void>(
    context: context,
    builder: (_) => _CustomerUsersDialog(
      customer: customer,
      repository: widget.repository!,
    ),
  );

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Platform admin',
    subtitle: 'Customers, websites and platform operational status.',
    icon: Icons.admin_panel_settings_outlined,
    child: widget.repository == null
        ? const _UnavailableState()
        : FutureBuilder<List<CustomerRecord>>(
            future: _customersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingState();
              }
              if (snapshot.hasError) return _ErrorState(onRetry: _refresh);
              final customers = snapshot.data!;
              final query = _customerQuery.trim().toLowerCase();
              final visibleCustomers = customers
                  .where(
                    (customer) =>
                        customer.name.toLowerCase().contains(query) ||
                        customer.slug.toLowerCase().contains(query),
                  )
                  .toList();
              final onlineWebsites = widget.websites
                  .where(
                    (website) =>
                        website.onlineStatus == WebsiteHealthStatus.online,
                  )
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminSummary(
                    customers: customers.length,
                    websites: widget.websites.length,
                    onlineWebsites: onlineWebsites,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Customers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addCustomer,
                        icon: const Icon(Icons.add),
                        label: const Text('Add customer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _customerQuery = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search customers',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (customers.isEmpty)
                    _EmptyState(
                      icon: Icons.business_outlined,
                      title: 'No customers yet',
                      message: 'Create a customer account before adding its first website.',
                    )
                  else if (visibleCustomers.isEmpty)
                    const _EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No matching customers',
                      message:
                          'Try a different organisation name or account slug.',
                    )
                  else
                    ...visibleCustomers.map((customer) {
                      final owned = widget.websites
                          .where((website) => website.tenantId == customer.id)
                          .toList();
                      return _CustomerTile(
                        icon: Icons.business_outlined,
                        customer: customer,
                        websites: owned,
                        onAddWebsite: () => _addWebsite(customer),
                        onOpen: () => _showCustomerDetails(customer),
                        onManageUsers: () => _showCustomerUsers(customer),
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text(
                    'Websites',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (widget.websites.isEmpty)
                    const _EmptyState(
                      icon: Icons.language_outlined,
                      title: 'No websites yet',
                      message: 'Create a website from a customer record when it is ready.',
                    )
                  else
                    ...widget.websites.map(
                      (website) => _RecordTile(
                        icon: Icons.language_outlined,
                        title: website.name,
                        subtitle: website.domain,
                        detail:
                            'Health: ${website.onlineStatus.name}  |  Deployment: ${website.deploymentStatus.name}',
                        badge: website.onlineStatus.name.toUpperCase(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent platform activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _PlatformActivityPanel(repository: widget.repository!),
                  const SizedBox(height: 24),
                  const Text(
                    'System information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const _RecordTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Tenant security',
                    subtitle: 'Database-enforced row-level security is active for all customer data.',
                    badge: 'RLS',
                  ),
                ],
              );
            },
          ),
  );
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.icon,
    required this.customer,
    required this.websites,
    required this.onAddWebsite,
    required this.onOpen,
    required this.onManageUsers,
  });

  final IconData icon;
  final CustomerRecord customer;
  final List<Website> websites;
  final VoidCallback onAddWebsite;
  final VoidCallback onOpen;
  final VoidCallback onManageUsers;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _cyan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(customer.slug, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
            const _Badge(label: 'ACTIVE'),
          ],
        ),
        const SizedBox(height: 14),
        _CustomerDetail(
          label: 'Created',
          value: _dateLabel(customer.createdAt),
        ),
        _CustomerDetail(label: 'Last activity', value: 'No activity recorded'),
        _CustomerDetail(
          label: 'Website',
          value: websites.isEmpty
              ? 'No website yet'
              : websites.map((website) => website.name).join(', '),
        ),
        _CustomerDetail(
          label: 'Website status',
          value: websites.isEmpty
              ? 'Not configured'
              : websites.map((website) => website.onlineStatus.name).join(', '),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onOpen, child: const Text('View details')),
              OutlinedButton.icon(
                onPressed: onManageUsers,
                icon: const Icon(Icons.people_outline),
                label: const Text('Manage users'),
              ),
              OutlinedButton.icon(
                onPressed: onAddWebsite,
                icon: const Icon(Icons.language_outlined),
                label: const Text('Create website'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _dateLabel(DateTime? value) {
    if (value == null) return 'Not available';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _CustomerDetailsDialog extends StatelessWidget {
  const _CustomerDetailsDialog({
    required this.customer,
    required this.websites,
    required this.onCreateWebsite,
  });

  final CustomerRecord customer;
  final List<Website> websites;
  final VoidCallback onCreateWebsite;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(customer.name),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(customer.slug, style: const TextStyle(color: _muted)),
          const SizedBox(height: 16),
          const Text(
            'Operational websites',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (websites.isEmpty)
            const Text(
              'No websites have been created for this customer.',
              style: TextStyle(color: _muted),
            )
          else
            ...websites.map(
              (website) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_outlined, color: _cyan),
                title: Text(website.name),
                subtitle: Text(
                  '${website.domain}  |  ${website.onlineStatus.name}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Customer profile, private content, media and support requests are not shown in this platform overview.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: onCreateWebsite,
        icon: const Icon(Icons.add),
        label: const Text('Create website'),
      ),
    ],
  );
}

class _PlatformActivityPanel extends StatelessWidget {
  const _PlatformActivityPanel({required this.repository});

  final ControlRoomRepository repository;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<PlatformActivityRecord>>(
        future: repository.listPlatformActivity(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.history_toggle_off_outlined,
              title: 'Activity unavailable',
              message: 'Recent platform activity could not be loaded.',
            );
          }
          final activity = snapshot.data!;
          if (activity.isEmpty) {
            return const _EmptyState(
              icon: Icons.history_outlined,
              title: 'No platform activity yet',
              message: 'Authorised operational activity will appear here.',
            );
          }
          return Column(
            children: activity
                .map(
                  (record) => _RecordTile(
                    icon: Icons.history_outlined,
                    title: record.action.replaceAll('_', ' '),
                    subtitle: record.resourceType.replaceAll('_', ' '),
                    detail: _activityDate(record.createdAt),
                    badge: 'AUDIT',
                  ),
                )
                .toList(),
          );
        },
      );

  static String _activityDate(DateTime? value) {
    if (value == null) return 'Time not available';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _CustomerDetail extends StatelessWidget {
  const _CustomerDetail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: _muted),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class _CustomerUsersDialog extends StatefulWidget {
  const _CustomerUsersDialog({
    required this.customer,
    required this.repository,
  });

  final CustomerRecord customer;
  final ControlRoomRepository repository;

  @override
  State<_CustomerUsersDialog> createState() => _CustomerUsersDialogState();
}

class _CustomerUsersDialogState extends State<_CustomerUsersDialog> {
  late Future<List<CustomerUserRecord>> _users = widget.repository
      .listCustomerUsers(widget.customer.id);

  void _refresh() => setState(() {
    _users = widget.repository.listCustomerUsers(widget.customer.id);
  });

  Future<void> _invite() async {
    final result = await showDialog<CustomerUserRecord>(
      context: context,
      builder: (_) => _InviteCustomerUserDialog(
        customer: widget.customer,
        repository: widget.repository,
      ),
    );
    if (result != null && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to ${result.email}.')),
      );
    }
  }

  Future<void> _setDisabled(CustomerUserRecord user) async {
    final disabled = user.status != 'DISABLED';
    final updated = await widget.repository.setCustomerUserDisabled(
      customerId: widget.customer.id,
      email: user.email,
      disabled: disabled,
    );
    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == 'DISABLED'
                ? 'Customer access disabled.'
                : 'Customer access enabled.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.customer.name} users'),
    content: SizedBox(
      width: 620,
      child: FutureBuilder<List<CustomerUserRecord>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.error_outline,
              title: 'Users unavailable',
              message: 'Customer users could not be loaded. Please try again.',
            );
          }
          final users = snapshot.data ?? const <CustomerUserRecord>[];
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite a person to manage ${widget.customer.name}. They create their own password from the secure email invitation.',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 16),
                if (users.isEmpty)
                  const _EmptyState(
                    icon: Icons.person_add_outlined,
                    title: 'No customer users yet',
                    message: 'Invite the first customer user to this existing tenant.',
                  )
                else
                  ...users.map(
                    (user) => _CustomerUserTile(
                      user: user,
                      onToggle: () => _setDisabled(user),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: _invite,
        icon: const Icon(Icons.mail_outline),
        label: const Text('Invite customer'),
      ),
    ],
  );
}

class _CustomerUserTile extends StatelessWidget {
  const _CustomerUserTile({required this.user, required this.onToggle});

  final CustomerUserRecord user;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.person_outline, color: _cyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(user.displayName, style: const TextStyle(color: _muted)),
              const SizedBox(height: 4),
              Text(
                '${user.role} | Created ${_supportDate(user.createdAt)} | Last active ${_supportDate(user.lastActiveAt)}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Badge(label: user.status),
            TextButton(
              onPressed: onToggle,
              child: Text(user.status == 'DISABLED' ? 'Enable' : 'Disable'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InviteCustomerUserDialog extends StatefulWidget {
  const _InviteCustomerUserDialog({
    required this.customer,
    required this.repository,
  });

  final CustomerRecord customer;
  final ControlRoomRepository repository;

  @override
  State<_InviteCustomerUserDialog> createState() =>
      _InviteCustomerUserDialogState();
}

class _InviteCustomerUserDialogState extends State<_InviteCustomerUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await widget.repository.inviteCustomerUser(
        customerId: widget.customer.id,
        email: _email.text.trim(),
        displayName: _name.text.trim(),
      );
      if (mounted) Navigator.pop(context, user);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The invitation could not be sent. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite customer'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite a person to manage ${widget.customer.name}. They will receive an email and create their own password.',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Customer name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the customer name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFE9B949))),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Sending...' : 'Send invitation'),
      ),
    ],
  );
}

class _CustomerInvitationDialog extends StatefulWidget {
  const _CustomerInvitationDialog({required this.repository});
  final ControlRoomRepository repository;
  @override
  State<_CustomerInvitationDialog> createState() =>
      _CustomerInvitationDialogState();
}

class _CustomerInvitationDialogState extends State<_CustomerInvitationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _organizationName = TextEditingController();
  final _slug = TextEditingController();
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _websiteName = TextEditingController();
  final _websiteDomain = TextEditingController();
  bool _existingWebsite = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _organizationName.dispose();
    _slug.dispose();
    _contactName.dispose();
    _contactEmail.dispose();
    _websiteName.dispose();
    _websiteDomain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add customer'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _organizationName,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Organisation name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an organisation name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Account slug',
                hintText: 'your-organisation',
              ),
              validator: (value) {
                final slug = value?.trim() ?? '';
                if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
                  return 'Use lowercase letters, numbers and single hyphens.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Primary contact name',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a primary contact name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Primary contact email',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteName,
              decoration: const InputDecoration(labelText: 'Website name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteDomain,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website domain',
                hintText: 'example.com',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              initialValue: _existingWebsite,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Does this customer already have a website?',
              ),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: Text('No - create new website'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text('Yes - preserve and improve existing website'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _existingWebsite = value ?? false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Sending...' : 'Send invitation'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final provisioned = await widget.repository.provisionCustomer(
        ProvisionCustomerRequest(
          organizationName: _organizationName.text,
          accountSlug: _slug.text,
          contactName: _contactName.text,
          contactEmail: _contactEmail.text,
          websiteName: _websiteName.text.trim().isEmpty
              ? null
              : _websiteName.text,
          websiteDomain: _websiteDomain.text.trim().isEmpty
              ? null
              : _websiteDomain.text,
          websiteSettings: {
            'websiteStatus': _existingWebsite ? 'EXISTING' : 'NOT_STARTED',
            'managementMode': _existingWebsite
                ? 'PRESERVE_IMPROVE_EXISTING'
                : 'CREATE_NEW',
          },
        ),
      );
      if (mounted) Navigator.pop(context, provisioned);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to send this invitation. The customer or email may already exist.';
        });
      }
    }
  }
}

class _CustomerWebsiteDialog extends StatefulWidget {
  const _CustomerWebsiteDialog({
    required this.customer,
    required this.repository,
  });
  final CustomerRecord customer;
  final ControlRoomRepository repository;
  @override
  State<_CustomerWebsiteDialog> createState() => _CustomerWebsiteDialogState();
}

class _CustomerWebsiteDialogState extends State<_CustomerWebsiteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _domain = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _domain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Create website for ${widget.customer.name}'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Website name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a website name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domain,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Domain',
                hintText: 'example.co.uk',
              ),
              validator: (value) {
                final domain = value?.trim() ?? '';
                return RegExp(
                      r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
                    ).hasMatch(domain)
                    ? null
                    : 'Enter a domain without http:// or a path.';
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Creating...' : 'Create website'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createCustomerWebsite(
        CreateWebsiteRequest(
          tenantId: widget.customer.id,
          name: _name.text,
          domain: _domain.text,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to create this website. The domain may already be in use.';
        });
      }
    }
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    color: _canvas,
    child: SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF102B35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _cyan),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    ),
  );
}

class _WebsiteManagementPanel extends StatefulWidget {
  const _WebsiteManagementPanel({
    required this.websites,
    required this.repository,
    required this.isMasterAdmin,
  });

  final List<Website> websites;
  final ControlRoomRepository repository;
  final bool isMasterAdmin;

  @override
  State<_WebsiteManagementPanel> createState() =>
      _WebsiteManagementPanelState();
}

class _WebsiteManagementPanelState extends State<_WebsiteManagementPanel> {
  String _query = '';
  String _lifecycle = 'All';
  String? _selectedId;
  late Future<List<WebsiteTemplateRecord>> _templates;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.websites.firstOrNull?.id;
    _templates = widget.repository.listWebsiteTemplates();
  }

  Website? get _selected =>
      widget.websites.where((website) => website.id == _selectedId).firstOrNull;

  void _refreshTemplates() => setState(() {
    _templates = widget.repository.listWebsiteTemplates();
  });

  @override
  Widget build(BuildContext context) {
    final visible = widget.websites.where((website) {
      final search = '${website.name} ${website.domain} ${website.tenantId}'
          .toLowerCase();
      return (_lifecycle == 'All' ||
              website.lifecycleStatus.name == _lifecycle) &&
          search.contains(_query.toLowerCase());
    }).toList();
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.isMasterAdmin ? 'Website administration' : 'My website',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SmartHelpButton(
              guideId: 'temporary-websites',
              tooltip: 'Temporary Websites help',
            ),
            if (widget.isMasterAdmin)
              IconButton(
                tooltip: 'Create temporary website',
                onPressed: _createTemporaryWebsite,
                icon: const Icon(Icons.add_business_outlined),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.isMasterAdmin) ...[
          TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search websites or customer context',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _lifecycle,
            decoration: const InputDecoration(labelText: 'Lifecycle filter'),
            items:
                [
                      'All',
                      ...WebsiteLifecycleStatus.values.map((item) => item.name),
                    ]
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _lifecycle = value ?? 'All'),
          ),
          const SizedBox(height: 12),
        ],
        if (visible.isEmpty)
          const _EmptyState(
            icon: Icons.language_outlined,
            title: 'No websites match',
            message: 'Change the filters or create a temporary website.',
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: visible
                .map(
                  (website) => ChoiceChip(
                    label: Text(
                      widget.isMasterAdmin
                          ? '${website.name} (${website.tenantId})'
                          : website.domain,
                    ),
                    selected: website.id == _selectedId,
                    onSelected: (_) => setState(() => _selectedId = website.id),
                  ),
                )
                .toList(),
          ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          _WebsiteHealthGrid(websites: [selected]),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                tooltip: 'Private preview',
                onPressed: () => _preview(selected),
                icon: const Icon(Icons.preview_outlined),
              ),
              IconButton(
                tooltip: 'Map existing website features',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WebsiteFeatureInventoryScreen(
                      repository: widget.repository,
                      websiteId: selected.id!,
                      websiteName: selected.name,
                    ),
                  ),
                ),
                icon: const Icon(Icons.account_tree_outlined),
              ),
              if (widget.isMasterAdmin) ...[
                IconButton(
                  tooltip: 'Edit website',
                  onPressed: () => _editWebsite(selected),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Manage lifecycle',
                  onPressed: () => _manageLifecycle(selected),
                  icon: const Icon(Icons.update_outlined),
                ),
              ],
            ],
          ),
          _WebsitePagesPanel(website: selected, repository: widget.repository),
        ],
        if (widget.isMasterAdmin) ...[
          const SizedBox(height: 22),
          _TemplateManagementPanel(
            templates: _templates,
            repository: widget.repository,
            onChanged: _refreshTemplates,
          ),
        ],
      ],
    );
  }

  Future<void> _preview(Website website) => showDialog<void>(
    context: context,
    builder: (_) => _PrivateWebsitePreviewDialog(
      website: website,
      preview: widget.repository.getWebsitePreview(website.id!),
    ),
  );

  Future<void> _editWebsite(Website website) async {
    final name = TextEditingController(text: website.name);
    final domain = TextEditingController(text: website.domain);
    final description = TextEditingController(text: website.description);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit website'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: domain,
              decoration: const InputDecoration(labelText: 'Domain'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.updateWebsite(
                id: website.id!,
                name: name.text,
                domain: domain.text,
                siteSlug: website.siteSlug,
                description: description.text,
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    domain.dispose();
    description.dispose();
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _manageLifecycle(Website website) async {
    var lifecycle = website.lifecycleStatus.name.toUpperCase();
    final expiry = TextEditingController(
      text: website.expiresAt?.toIso8601String() ?? '',
    );
    final agreement = TextEditingController(
      text: website.commercialAgreementId ?? '',
    );
    final templates = await _templates;
    String? templateId = website.templateId;
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Lifecycle: ${website.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: lifecycle,
                decoration: const InputDecoration(labelText: 'Lifecycle'),
                items: WebsiteLifecycleStatus.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name.toUpperCase(),
                        child: Text(_websiteLifecycleLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => lifecycle = value!),
              ),
              DropdownButtonFormField<String?>(
                initialValue: templateId,
                decoration: const InputDecoration(labelText: 'Template'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No template'),
                  ),
                  ...templates.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setDialogState(() => templateId = value),
              ),
              TextField(
                controller: expiry,
                decoration: const InputDecoration(
                  labelText: 'Expiry (ISO 8601, optional)',
                ),
              ),
              TextField(
                controller: agreement,
                decoration: const InputDecoration(
                  labelText: 'Commercial agreement ID (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.updateWebsiteManagement(
                  id: website.id!,
                  lifecycle: lifecycle,
                  templateId: templateId,
                  expiresAt: DateTime.tryParse(expiry.text),
                  commercialAgreementId: agreement.text.trim().isEmpty
                      ? null
                      : agreement.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    expiry.dispose();
    agreement.dispose();
  }

  Future<void> _createTemporaryWebsite() async {
    final tenant = TextEditingController();
    final name = TextEditingController();
    final domain = TextEditingController();
    final expiry = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create temporary website'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tenant,
              decoration: const InputDecoration(
                labelText: 'Customer tenant ID',
              ),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Website name'),
            ),
            TextField(
              controller: domain,
              decoration: const InputDecoration(labelText: 'Domain'),
            ),
            TextField(
              controller: expiry,
              decoration: const InputDecoration(labelText: 'Expiry (ISO 8601)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.createCustomerWebsite(
                CreateWebsiteRequest(
                  tenantId: tenant.text,
                  name: name.text,
                  domain: domain.text,
                  expiresAt: DateTime.tryParse(expiry.text),
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    tenant.dispose();
    name.dispose();
    domain.dispose();
    expiry.dispose();
  }
}

class _PrivateWebsitePreviewDialog extends StatelessWidget {
  const _PrivateWebsitePreviewDialog({
    required this.website,
    required this.preview,
  });
  final Website website;
  final Future<WebsitePreviewRecord> preview;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${website.name} private preview'),
    content: SizedBox(
      width: 520,
      child: FutureBuilder<WebsitePreviewRecord>(
        future: preview,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              Text(
                website.description ?? 'Private workspace preview.',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              for (final page in snapshot.data!.pages.where(
                (page) => page.visible,
              ))
                ListTile(
                  title: Text(page.title),
                  subtitle: Text('/${page.slug}'),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _WebsitePagesPanel extends StatefulWidget {
  const _WebsitePagesPanel({required this.website, required this.repository});
  final Website website;
  final ControlRoomRepository repository;
  @override
  State<_WebsitePagesPanel> createState() => _WebsitePagesPanelState();
}

class _WebsitePagesPanelState extends State<_WebsitePagesPanel> {
  late Future<List<WebsitePageRecord>> _pages = widget.repository
      .listWebsitePages(widget.website.id!);
  void _refresh() => setState(
    () => _pages = widget.repository.listWebsitePages(widget.website.id!),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<List<WebsitePageRecord>>(
    future: _pages,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      final pages = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pages',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Add page',
                onPressed: () => _editPage(),
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
          if (pages.isEmpty)
            const Text('No pages yet.', style: TextStyle(color: _muted)),
          for (var index = 0; index < pages.length; index++)
            _RecordTile(
              icon: pages[index].visible
                  ? Icons.article_outlined
                  : Icons.visibility_off_outlined,
              title: pages[index].title,
              subtitle: '/${pages[index].slug} | ${pages[index].type}',
              badge: pages[index].visible ? 'Visible' : 'Hidden',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move page up',
                    onPressed: index == 0
                        ? null
                        : () => _move(pages, index, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Move page down',
                    onPressed: index == pages.length - 1
                        ? null
                        : () => _move(pages, index, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Edit page',
                    onPressed: () => _editPage(pages[index]),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete page',
                    onPressed: () async {
                      await widget.repository.deleteWebsitePage(
                        pages[index].id,
                      );
                      _refresh();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
  Future<void> _move(
    List<WebsitePageRecord> pages,
    int index,
    int delta,
  ) async {
    final reordered = [...pages];
    final page = reordered.removeAt(index);
    reordered.insert(index + delta, page);
    await widget.repository.reorderWebsitePages(reordered);
    _refresh();
  }

  Future<void> _editPage([WebsitePageRecord? page]) async {
    final title = TextEditingController(text: page?.title);
    final slug = TextEditingController(text: page?.slug);
    var visible = page?.visible ?? true;
    var type = page?.type ?? 'CUSTOM';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(page == null ? 'Add page' : 'Edit page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: slug,
                decoration: const InputDecoration(labelText: 'Slug'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Page type'),
                items:
                    const [
                          'HOME',
                          'ABOUT',
                          'SERVICES',
                          'CONTACT',
                          'NEWS',
                          'CUSTOM',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setDialogState(() => type = value!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible'),
                value: visible,
                onChanged: (value) => setDialogState(() => visible = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.saveWebsitePage(
                  id: page?.id,
                  websiteId: widget.website.id!,
                  title: title.text,
                  slug: slug.text,
                  type: type,
                  visible: visible,
                  sortOrder: page?.sortOrder ?? 0,
                );
                if (context.mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    slug.dispose();
  }
}

class _TemplateManagementPanel extends StatelessWidget {
  const _TemplateManagementPanel({
    required this.templates,
    required this.repository,
    required this.onChanged,
  });
  final Future<List<WebsiteTemplateRecord>> templates;
  final ControlRoomRepository repository;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<WebsiteTemplateRecord>>(
        future: templates,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add template',
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                ],
              ),
              for (final template in snapshot.data!)
                _RecordTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: template.name,
                  subtitle: '${template.type} | v${template.version}',
                  badge: template.active ? 'Active' : 'Inactive',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit template',
                        onPressed: () => _edit(context, template),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete template',
                        onPressed: () async {
                          await repository.deleteWebsiteTemplate(template.id);
                          onChanged();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
  Future<void> _edit(
    BuildContext context, [
    WebsiteTemplateRecord? template,
  ]) async {
    final name = TextEditingController(text: template?.name);
    final description = TextEditingController(text: template?.description);
    final version = TextEditingController(text: template?.version ?? '1.0');
    var type = template?.type ?? 'STANDARD';
    var active = template?.active ?? true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(template == null ? 'Add template' : 'Edit template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: version,
                decoration: const InputDecoration(labelText: 'Version'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Template type'),
                items:
                    const [
                          'STANDARD',
                          'BUSINESS',
                          'PHOTOGRAPHY',
                          'PARANORMAL',
                          'PORTFOLIO',
                          'EVENT',
                          'LANDING',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setDialogState(() => type = value!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await repository.saveWebsiteTemplate(
                  id: template?.id,
                  name: name.text,
                  description: description.text,
                  type: type,
                  version: version.text,
                  active: active,
                );
                if (context.mounted) Navigator.pop(context);
                onChanged();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    version.dispose();
  }
}

class _WebsiteHealthGrid extends StatelessWidget {
  const _WebsiteHealthGrid({required this.websites});
  final List<Website> websites;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth > 680
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: websites
            .map(
              (website) => SizedBox(
                width: width,
                child: _RecordTile(
                  icon: Icons.public_outlined,
                  title: website.name,
                  subtitle:
                      '${website.domain}  |  ${website.templateName ?? 'No template'}',
                  detail:
                      'Lifecycle: ${_websiteLifecycleLabel(website.lifecycleStatus)}  |  ${website.expiresAt == null ? 'No expiry' : 'Expires ${_supportDate(website.expiresAt)}'}',
                  badge: _websiteLifecycleLabel(website.lifecycleStatus),
                  trailing: IconButton(
                    tooltip: 'Preview website',
                    icon: const Icon(Icons.preview_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _WebsitePreviewDialog(website: website),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _WebsitePreviewDialog extends StatelessWidget {
  const _WebsitePreviewDialog({required this.website});
  final Website website;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${website.name} preview'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _websiteLifecycleLabel(website.lifecycleStatus),
            style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            website.description ?? 'This private preview will display the website content managed in the Control Room.',
          ),
          const SizedBox(height: 12),
          const Text('Domain: Not connected', style: TextStyle(color: _muted)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

String _websiteLifecycleLabel(WebsiteLifecycleStatus value) => switch (value) {
  WebsiteLifecycleStatus.pendingApproval => 'Pending Approval',
  _ => value.name[0].toUpperCase() + value.name.substring(1),
};

class _AdminSummary extends StatelessWidget {
  const _AdminSummary({
    required this.customers,
    required this.websites,
    required this.onlineWebsites,
  });
  final int customers;
  final int websites;
  final int onlineWebsites;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      _MetricCard(
        label: 'Customers',
        value: '$customers',
        icon: Icons.business_outlined,
      ),
      _MetricCard(
        label: 'Websites',
        value: '$websites',
        icon: Icons.language_outlined,
      ),
      _MetricCard(
        label: 'Websites online',
        value: '$onlineWebsites',
        icon: Icons.monitor_heart_outlined,
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: _cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.detail,
    this.trailing,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? detail;
  final Widget? trailing;
  final String? badge;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _cyan),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted),
              ),
              if (detail case final String detail)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    detail,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
            ],
          ),
        ),
        if (badge != null) _Badge(label: badge!),
        if (trailing case final Widget trailing) trailing,
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF102B35),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: _cyan,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState();
  @override
  Widget build(BuildContext context) => const _EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Control Room unavailable',
    message:
        'Connect Supabase and sign in to load protected Control Room data.',
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Icon(icon, size: 34, color: _cyan),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _EmptyState(
    icon: Icons.error_outline,
    title: 'Unable to load this information',
    message: 'Check your connection and permissions, then try again.',
  );
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class _ContentDialog extends StatefulWidget {
  const _ContentDialog({
    required this.websites,
    required this.repository,
    this.record,
  });
  final List<Website> websites;
  final ControlRoomRepository repository;
  final ContentRecord? record;
  @override
  State<_ContentDialog> createState() => _ContentDialogState();
}

class _ContentDialogState extends State<_ContentDialog> {
  late final TextEditingController _key = TextEditingController(
    text: widget.record?.contentKey,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.record?.content['text'] as String? ?? '',
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.record?.content['title'] as String? ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.record?.content['category'] as String? ?? '',
  );
  late final TextEditingController _date = TextEditingController(
    text: widget.record?.content['date'] as String? ?? '',
  );
  late String _websiteId =
      widget.record?.websiteId ?? widget.websites.first.id!;
  late String _section;
  late bool _featured;
  late List<Map<String, dynamic>> _sections;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _section = widget.record == null
        ? 'Homepage'
        : _contentSection(widget.record!);
    _featured = widget.record?.content['featured'] == true;
    _sections = (widget.record?.content['sections'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((section) => Map<String, dynamic>.from(section))
        .toList();
  }

  @override
  void dispose() {
    _key.dispose();
    _text.dispose();
    _title.dispose();
    _category.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? 'Add content' : 'Edit content'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _websiteId,
            items: widget.websites
                .where((item) => item.id != null)
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _websiteId = value!),
            decoration: const InputDecoration(labelText: 'Website'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _section,
            items: _contentSections
                .skip(1)
                .map(
                  (section) =>
                      DropdownMenuItem(value: section, child: Text(section)),
                )
                .toList(),
            onChanged: (value) => setState(() => _section = value!),
            decoration: const InputDecoration(labelText: 'Content area'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: const InputDecoration(
              labelText: 'Content key',
              hintText: 'homepage',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Content text'),
          ),
          const SizedBox(height: 8),
          _RichTextToolbar(controller: _text),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _date,
            decoration: const InputDecoration(
              labelText: 'Date',
              hintText: 'YYYY-MM-DD',
            ),
          ),
          SwitchListTile(
            value: _featured,
            onChanged: (value) => setState(() => _featured = value),
            title: const Text('Featured content'),
          ),
          const SizedBox(height: 12),
          ContentSectionEditor(
            repository: widget.repository,
            initialSections: _sections,
            onChanged: (sections) => _sections = sections,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Save'),
      ),
    ],
  );
  Future<void> _save() async {
    if (_key.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveContent(
        websiteId: _websiteId,
        contentKey: _key.text.trim(),
        content: {
          if (widget.record != null) ...widget.record!.content,
          'section': _section,
          'title': _title.text,
          'text': _text.text,
          'category': _category.text,
          'date': _date.text,
          'featured': _featured,
          'sections': _sections,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RichTextToolbar extends StatelessWidget {
  const _RichTextToolbar({required this.controller});
  final TextEditingController controller;

  void _wrap(String marker) {
    final selection = controller.selection;
    final value = controller.text;
    if (!selection.isValid || selection.isCollapsed) return;
    final selected = value.substring(selection.start, selection.end);
    final replacement = '$marker$selected$marker';
    controller.value = controller.value.copyWith(
      text: value.replaceRange(selection.start, selection.end, replacement),
      selection: TextSelection.collapsed(
        offset: selection.start + replacement.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      IconButton(
        tooltip: 'Bold selected text',
        icon: const Icon(Icons.format_bold),
        onPressed: () => _wrap('**'),
      ),
      IconButton(
        tooltip: 'Italic selected text',
        icon: const Icon(Icons.format_italic),
        onPressed: () => _wrap('*'),
      ),
      IconButton(
        tooltip: 'Add bullet line',
        icon: const Icon(Icons.format_list_bulleted),
        onPressed: () {
          final value = controller.text;
          controller.value = controller.value.copyWith(
            text: '$value\n- ',
            selection: TextSelection.collapsed(offset: value.length + 3),
          );
        },
      ),
      const Padding(
        padding: EdgeInsets.only(left: 8, top: 12),
        child: Text(
          'Select text for bold/italic. Use # for headings and - for bullets.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ),
    ],
  );
}

class _SocialDialog extends StatefulWidget {
  const _SocialDialog({
    required this.websites,
    required this.repository,
    this.link,
  });
  final List<Website> websites;
  final ControlRoomRepository repository;
  final SocialLinkRecord? link;
  @override
  State<_SocialDialog> createState() => _SocialDialogState();
}

class _SocialDialogState extends State<_SocialDialog> {
  late final TextEditingController _platform = TextEditingController(
    text: widget.link?.platform,
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.link?.url,
  );
  late String _websiteId = widget.link?.websiteId ?? widget.websites.first.id!;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _platform.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.link == null ? 'Add social link' : 'Edit social link'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _websiteId,
            items: widget.websites
                .where((item) => item.id != null)
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _websiteId = value!),
            decoration: const InputDecoration(labelText: 'Website'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _platform,
            decoration: const InputDecoration(labelText: 'Platform'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'URL'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Save'),
      ),
    ],
  );
  Future<void> _save() async {
    final url = Uri.tryParse(_url.text.trim());
    if (_platform.text.trim().isEmpty ||
        url == null ||
        (url.scheme != 'https' && url.scheme != 'http') ||
        url.host.isEmpty) {
      setState(() => _error = 'Enter a platform and a valid website link.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveSocialLink(
        id: widget.link?.id,
        websiteId: _websiteId,
        platform: _platform.text,
        url: _url.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save this social link. Please try again.';
        });
      }
    }
  }
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog({required this.websites, required this.repository});
  final List<Website> websites;
  final ControlRoomRepository repository;
  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String? _websiteId;
  bool _saving = false;
  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New support request'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('General support'),
              ),
              ...widget.websites
                  .where((item) => item.id != null)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
            ],
            onChanged: (value) => _websiteId = value,
            decoration: const InputDecoration(labelText: 'Website'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'How can we help?'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Sending...' : 'Send request'),
      ),
    ],
  );
  Future<void> _save() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createSupportRequest(
        websiteId: _websiteId,
        subject: _subject.text,
        body: _body.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}
