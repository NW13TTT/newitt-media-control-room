import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../backend/control_room_repository.dart';
import '../help/smart_help_button.dart';
import '../websites/website_model.dart';

class GitHubScreen extends StatefulWidget {
  const GitHubScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.websites,
  });

  final ControlRoomRepository? repository;
  final AuthSession? session;
  final List<Website> websites;

  @override
  State<GitHubScreen> createState() => _GitHubScreenState();
}

class _GitHubScreenState extends State<GitHubScreen> {
  late Future<List<GitHubConnectionRecord>> _connections = _loadConnections();
  late Future<List<GitHubRepositoryRecord>> _repositories = _loadRepositories();
  late Future<List<GitHubMappingRecord>> _mappings = _loadMappings();
  String? _message;

  bool get _isMasterAdmin =>
      widget.session?.profile.role == AuthRole.masterAdmin;
  Future<List<GitHubConnectionRecord>> _loadConnections() =>
      widget.repository!.listGitHubConnections();
  Future<List<GitHubRepositoryRecord>> _loadRepositories() =>
      widget.repository!.listGitHubRepositories();
  Future<List<GitHubMappingRecord>> _loadMappings() =>
      widget.repository!.listGitHubMappings();
  void _refresh() => setState(() {
    _connections = _loadConnections();
    _repositories = _loadRepositories();
    _mappings = _loadMappings();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: widget.repository == null
                ? const _GitHubEmpty(
                    'GitHub unavailable',
                    'Connect Supabase and sign in to view GitHub status.',
                  )
                : _buildBody(),
          ),
        ),
      ),
    ),
  );

  Widget _buildBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _isMasterAdmin ? 'GitHub' : 'Website development connection',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const SmartHelpButton(
            guideId: 'github-integration',
            tooltip: 'GitHub Integration help',
          ),
        ],
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<GitHubConnectionRecord>>(
        future: _connections,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _GitHubLoading();
          final active = snapshot.data!.any(
            (connection) => connection.status == 'CONNECTED',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active
                    ? 'GitHub connection: Active'
                    : 'GitHub connection: Not currently active',
                style: const TextStyle(color: Color(0xFF8A99A5)),
              ),
              if (_isMasterAdmin) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check connection'),
                ),
                if (snapshot.data!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'GitHub is ready for setup. Install the NEWITT Media GitHub App to enable repository access.',
                      style: TextStyle(color: Color(0xFFE9B949)),
                    ),
                  ),
                ...snapshot.data!.map(
                  (connection) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.code, color: Color(0xFF00D9F5)),
                    title: Text(connection.name),
                    subtitle: Text(
                      '${connection.owner ?? 'No account connected'} | ${_label(connection.status)}',
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      if (_isMasterAdmin)
        _buildRepositoryMappings()
      else
        const Text(
          'GitHub repositories, branches, commits, and sync controls are managed by NEWITT Media.',
          style: TextStyle(color: Color(0xFF8A99A5)),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _message!,
            style: const TextStyle(color: Color(0xFF00D9F5)),
          ),
        ),
    ],
  );

  Widget
  _buildRepositoryMappings() => FutureBuilder<List<GitHubRepositoryRecord>>(
    future: _repositories,
    builder: (context, repositorySnapshot) {
      if (!repositorySnapshot.hasData) return const _GitHubLoading();
      return FutureBuilder<List<GitHubMappingRecord>>(
        future: _mappings,
        builder: (context, mappingSnapshot) {
          if (!mappingSnapshot.hasData) return const _GitHubLoading();
          final mappings = mappingSnapshot.data!;
          if (repositorySnapshot.data!.isEmpty) {
            return const _GitHubEmpty(
              'No repositories available',
              'Complete GitHub App setup to discover repositories.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Repositories and website mappings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...repositorySnapshot.data!.map((repository) {
                final mapping = mappings
                    .where((item) => item.repositoryId == repository.id)
                    .firstOrNull;
                final linkedWebsite = widget.websites
                    .where((website) => website.id == mapping?.websiteId)
                    .firstOrNull;
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.source_outlined,
                      color: Color(0xFF00D9F5),
                    ),
                    title: Text('${repository.owner}/${repository.name}'),
                    subtitle: Text(
                      '${repository.private ? 'Private' : 'Public'} | ${repository.branch} | ${_label(mapping?.syncStatus ?? 'NOT_CONNECTED')}${repository.latestCommit == null ? '' : ' | ${repository.latestCommit}'}',
                    ),
                    trailing: mapping == null
                        ? PopupMenuButton<String>(
                            tooltip: 'Link repository',
                            onSelected: (websiteId) =>
                                _link(websiteId, repository.id),
                            itemBuilder: (context) => widget.websites
                                .where((website) => website.id != null)
                                .map(
                                  (website) => PopupMenuItem(
                                    value: website.id,
                                    child: Text('Link ${website.name}'),
                                  ),
                                )
                                .toList(),
                          )
                        : TextButton(
                            onPressed: () => _unlink(
                              mapping.websiteId,
                              linkedWebsite?.name ?? 'website',
                            ),
                            child: Text(
                              'Unlink ${linkedWebsite?.name ?? 'website'}',
                            ),
                          ),
                  ),
                );
              }),
            ],
          );
        },
      );
    },
  );

  Future<void> _link(String websiteId, String repositoryId) async {
    try {
      await widget.repository!.linkGitHubRepository(
        websiteId: websiteId,
        repositoryId: repositoryId,
      );
      if (mounted) setState(() => _message = 'Repository linked.');
      _refresh();
    } catch (_) {
      if (mounted) setState(() => _message = 'Unable to link this repository.');
    }
  }

  Future<void> _unlink(String websiteId, String websiteName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlink $websiteName?'),
        content: const Text(
          'The website source mapping will be removed. No repository will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository!.unlinkGitHubRepository(websiteId);
      if (mounted) {
        setState(() => _message = 'Repository unlinked.');
      }
      _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to unlink this repository.');
      }
    }
  }
}

class _GitHubLoading extends StatelessWidget {
  const _GitHubLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _GitHubEmpty extends StatelessWidget {
  const _GitHubEmpty(this.title, this.message);
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.code_off_outlined, color: Color(0xFF00D9F5)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8A99A5)),
        ),
      ],
    ),
  );
}

String _label(String value) => value
    .split('_')
    .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
    .join(' ');
