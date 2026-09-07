import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';
import '../websites/website_model.dart';

const _canvas = Color(0xFF080B10);
const _panel = Color(0xFF0D141C);
const _border = Color(0xFF1B2A35);
const _muted = Color(0xFF8A99A5);
const _cyan = Color(0xFF00D9F5);
const _decisions = ['All', 'SAFE', 'REVIEW', 'BLOCKED'];
const _categories = [
  'VIOLENCE',
  'HATE_DISCRIMINATION',
  'SEXUAL_CONTENT',
  'CHILD_SAFETY',
  'HARASSMENT_ABUSE',
  'ILLEGAL_ACTIVITY',
  'DANGEROUS_INSTRUCTIONS',
  'SELF_HARM',
  'PRIVACY_PERSONAL_INFORMATION',
  'FRAUD_DECEPTION',
  'DEFAMATION_UNSUPPORTED_ALLEGATIONS',
  'COPYRIGHT_INTELLECTUAL_PROPERTY',
  'SPAM_MALICIOUS_CONTENT',
  'MISLEADING_CLAIMS',
  'OTHER',
];
const _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

class ContentSafetyScreen extends StatefulWidget {
  const ContentSafetyScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.websites,
  });

  final ControlRoomRepository? repository;
  final AuthSession? session;
  final List<Website> websites;

  @override
  State<ContentSafetyScreen> createState() => _ContentSafetyScreenState();
}

class _ContentSafetyScreenState extends State<ContentSafetyScreen> {
  late Future<
    ({
      List<ContentSafetyReviewRecord> reviews,
      List<ContentSafetyFindingRecord> findings,
    })
  >
  _data = _load();
  ContentSafetyReviewRecord? _selected;
  String _query = '';
  String _decision = 'All';
  String _category = 'All';
  String _severity = 'All';
  String _findingStatus = 'All';

  bool get _admin => widget.session?.profile.role == AuthRole.masterAdmin;
  Future<
    ({
      List<ContentSafetyReviewRecord> reviews,
      List<ContentSafetyFindingRecord> findings,
    })
  >
  _load() async => (
    reviews: await widget.repository!.listContentSafetyReviews(),
    findings: _admin
        ? await widget.repository!.listAllContentSafetyFindings()
        : const <ContentSafetyFindingRecord>[],
  );
  void _refresh() => setState(() => _data = _load());

  Future<void> _createReview() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NewReviewDialog(repository: widget.repository!),
    );
    if (created == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => _SafetyFrame(
    child: widget.repository == null
        ? const _SafetyEmpty(
            title: 'Content Safety unavailable',
            message: 'Connect Supabase and sign in to view protected safety information.',
          )
        : _selected == null
        ? _buildList()
        : _SafetyDetail(
            review: _selected!,
            repository: widget.repository!,
            admin: _admin,
            websites: widget.websites,
            onBack: () => setState(() => _selected = null),
            onChanged: _refresh,
          ),
  );

  Widget _buildList() => FutureBuilder<List<ContentSafetyReviewRecord>>(
    future: _data.then((data) => data.reviews),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _SafetyLoading();
      }
      if (snapshot.hasError) {
        return _SafetyEmpty(
          title: 'Safety information unavailable',
          message: 'Check your connection and permissions, then try again.',
        );
      }
      final visible = snapshot.data!
          .where(
            (review) =>
                (_decision == 'All' || review.decision == _decision) &&
                '${review.contentKey} ${review.tenantId} ${review.decision}'
                    .toLowerCase()
                    .contains(_query.trim().toLowerCase()),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Content Safety',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              const SmartHelpButton(
                guideId: 'content-safety',
                tooltip: 'Content Safety help',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _admin ? 'Review content safety findings across customer content.' : 'Review the safety status of your content before publication.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          if (_admin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _createReview,
                icon: const Icon(Icons.add),
                label: const Text('Create review'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search content or tenant',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final decision in _decisions)
                  ChoiceChip(
                    label: Text(_decisionLabel(decision)),
                    selected: _decision == decision,
                    onSelected: (_) => setState(() => _decision = decision),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ContentSafetyFindingRecord>>(
              future: _data.then((data) => data.findings),
              builder: (context, findingSnapshot) {
                final filteredReviews = findingSnapshot.hasData
                    ? visible
                          .where(
                            (review) =>
                                (_category == 'All' &&
                                    _severity == 'All' &&
                                    _findingStatus == 'All') ||
                                findingSnapshot.data!
                                    .where(
                                      (finding) =>
                                          finding.reviewId == review.id,
                                    )
                                    .any(
                                      (finding) =>
                                          (_category == 'All' ||
                                              finding.category == _category) &&
                                          (_severity == 'All' ||
                                              finding.severity == _severity) &&
                                          (_findingStatus == 'All' ||
                                              finding.status == _findingStatus),
                                    ),
                          )
                          .toList()
                    : visible;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: _category,
                          items: ['All', ..._categories]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item == 'All'
                                        ? 'All categories'
                                        : _categoryLabel(item),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _category = value!),
                        ),
                        DropdownButton<String>(
                          value: _severity,
                          items: ['All', ..._severities]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item == 'All'
                                        ? 'All severities'
                                        : _label(item),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _severity = value!),
                        ),
                        DropdownButton<String>(
                          value: _findingStatus,
                          items:
                              [
                                    'All',
                                    'OPEN',
                                    'REVIEWING',
                                    'RESOLVED',
                                    'DISMISSED',
                                  ]
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item == 'All'
                                            ? 'All finding statuses'
                                            : _label(item),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => _findingStatus = value!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (filteredReviews.isEmpty)
                      const _SafetyEmpty(
                        title: 'No matching safety reviews',
                        message: 'Try changing your safety filters.',
                      )
                    else
                      ...filteredReviews.map(
                        (review) => InkWell(
                          onTap: () => setState(() => _selected = review),
                          child: _SafetyTile(review: review, admin: _admin),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            if (visible.isEmpty)
              const _SafetyEmpty(
                title: 'No safety reviews found',
                message: 'Content will appear here when a safety review is recorded.',
              )
            else
              ...visible.map(
                (review) => InkWell(
                  onTap: () => setState(() => _selected = review),
                  child: _SafetyTile(review: review, admin: _admin),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _SafetyDetail extends StatefulWidget {
  const _SafetyDetail({
    required this.review,
    required this.repository,
    required this.admin,
    required this.websites,
    required this.onBack,
    required this.onChanged,
  });
  final ContentSafetyReviewRecord review;
  final ControlRoomRepository repository;
  final bool admin;
  final List<Website> websites;
  final VoidCallback onBack;
  final VoidCallback onChanged;
  @override
  State<_SafetyDetail> createState() => _SafetyDetailState();
}

class _SafetyDetailState extends State<_SafetyDetail> {
  late Future<List<ContentSafetyFindingRecord>> _findings = widget.repository
      .listContentSafetyFindings(widget.review.id);
  bool _busy = false;
  String? _error;
  void _reload() => setState(
    () => _findings = widget.repository.listContentSafetyFindings(
      widget.review.id,
    ),
  );
  Future<void> _setFinding(String id, String status) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.updateContentSafetyFindingStatus(
        id: id,
        status: status,
      );
      _reload();
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update this safety finding.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFinding() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _FindingDialog(
        repository: widget.repository,
        reviewId: widget.review.id,
      ),
    );
    if (created == true) {
      _reload();
      widget.onChanged();
    }
  }

  Future<void> _editReview() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReviewDialog(repository: widget.repository, review: widget.review),
    );
    if (saved == true) {
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to Content Safety'),
      ),
      const SizedBox(height: 12),
      Text(
        widget.review.contentKey,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      _DecisionBadge(decision: widget.review.decision),
      const SizedBox(height: 16),
      if (widget.admin)
        Text(
          'Tenant ${widget.review.tenantId}  |  Website ${_websiteName(widget.review.websiteId, widget.websites)}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      if (widget.review.explanation != null) ...[
        const SizedBox(height: 16),
        const Text(
          'Safety guidance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          widget.review.explanation!,
          style: const TextStyle(color: Color(0xFFD7E3E8)),
        ),
      ],
      if (widget.review.recommendedAction != null) ...[
        const SizedBox(height: 12),
        Text(
          widget.review.recommendedAction!,
          style: const TextStyle(color: _muted),
        ),
      ],
      if (widget.admin) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _editReview,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Update review'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _addFinding,
              icon: const Icon(Icons.add),
              label: const Text('Add finding'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      const Text(
        'Safety findings',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      FutureBuilder<List<ContentSafetyFindingRecord>>(
        future: _findings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SafetyLoading();
          }
          if (snapshot.hasError) {
            return const _SafetyEmpty(
              title: 'Findings unavailable',
              message: 'Safety findings could not be loaded.',
            );
          }
          if (snapshot.data!.isEmpty) {
            return const _SafetyEmpty(
              title: 'No findings',
              message:
                  'No specific safety findings are recorded for this content.',
            );
          }
          return Column(
            children: snapshot.data!
                .map(
                  (finding) => _FindingTile(
                    finding: finding,
                    admin: widget.admin,
                    busy: _busy,
                    onResolve: () => _setFinding(finding.id, 'RESOLVED'),
                    onDismiss: () => _setFinding(finding.id, 'DISMISSED'),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.repository, required this.review});
  final ControlRoomRepository repository;
  final ContentSafetyReviewRecord review;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late String _decision = widget.review.decision;
  late final _explanation = TextEditingController(
    text: widget.review.explanation,
  );
  late final _action = TextEditingController(
    text: widget.review.recommendedAction,
  );
  bool _saving = false;
  @override
  void dispose() {
    _explanation.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update safety review'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _decision,
            decoration: const InputDecoration(labelText: 'Decision'),
            items: _decisions
                .skip(1)
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_decisionLabel(item)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _decision = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _explanation,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Explanation'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _action,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Recommended action'),
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
    setState(() => _saving = true);
    try {
      await widget.repository.saveContentSafetyReview(
        id: widget.review.id,
        contentId: widget.review.contentId,
        decision: _decision,
        explanation: _explanation.text,
        recommendedAction: _action.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _NewReviewDialog extends StatefulWidget {
  const _NewReviewDialog({required this.repository});

  final ControlRoomRepository repository;

  @override
  State<_NewReviewDialog> createState() => _NewReviewDialogState();
}

class _NewReviewDialogState extends State<_NewReviewDialog> {
  late final Future<List<ContentRecord>> _content = widget.repository
      .listContent();
  String? _contentId;
  String _decision = 'REVIEW';
  final _explanation = TextEditingController();
  final _action = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _explanation.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contentId = _contentId;
    if (contentId == null) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveContentSafetyReview(
        contentId: contentId,
        decision: _decision,
        explanation: _explanation.text,
        recommendedAction: _action.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create safety review'),
    content: SingleChildScrollView(
      child: FutureBuilder<List<ContentRecord>>(
        future: _content,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _SafetyLoading();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Content record'),
                items: snapshot.data!
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.contentKey),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _contentId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _decision,
                decoration: const InputDecoration(labelText: 'Decision'),
                items: _decisions
                    .skip(1)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_decisionLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _decision = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _explanation,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Explanation'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _action,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Recommended action',
                ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Create review'),
      ),
    ],
  );
}

class _FindingDialog extends StatefulWidget {
  const _FindingDialog({required this.repository, required this.reviewId});
  final ControlRoomRepository repository;
  final String reviewId;
  @override
  State<_FindingDialog> createState() => _FindingDialogState();
}

class _FindingDialogState extends State<_FindingDialog> {
  String _category = _categories.first;
  String _severity = _severities.first;
  final _explanation = TextEditingController();
  final _action = TextEditingController();
  bool _requiresReview = false;
  bool _saving = false;
  @override
  void dispose() {
    _explanation.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add safety finding'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_categoryLabel(item)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: _severities
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(_label(item))),
                )
                .toList(),
            onChanged: (value) => setState(() => _severity = value!),
          ),
          TextField(
            controller: _explanation,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Explanation'),
          ),
          TextField(
            controller: _action,
            decoration: const InputDecoration(labelText: 'Recommended action'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresReview,
            onChanged: (value) => setState(() => _requiresReview = value),
            title: const Text('Requires review'),
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
        child: Text(_saving ? 'Saving...' : 'Add finding'),
      ),
    ],
  );
  Future<void> _save() async {
    if (_explanation.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createContentSafetyFinding(
        reviewId: widget.reviewId,
        category: _category,
        severity: _severity,
        explanation: _explanation.text,
        recommendedAction: _action.text,
        requiresReview: _requiresReview,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({required this.review, required this.admin});
  final ContentSafetyReviewRecord review;
  final bool admin;
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
        const Icon(Icons.gpp_good_outlined, color: _cyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.contentKey,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                admin
                    ? 'Tenant ${review.tenantId}'
                    : _customerMessage(review.decision),
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        _DecisionBadge(decision: review.decision),
      ],
    ),
  );
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({
    required this.finding,
    required this.admin,
    required this.busy,
    required this.onResolve,
    required this.onDismiss,
  });
  final ContentSafetyFindingRecord finding;
  final bool admin;
  final bool busy;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_categoryLabel(finding.category)} | ${_label(finding.severity)} | ${_label(finding.status)}',
          style: const TextStyle(color: _cyan, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(finding.explanation),
        if (finding.recommendedAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              finding.recommendedAction!,
              style: const TextStyle(color: _muted),
            ),
          ),
        if (admin &&
            (finding.status == 'OPEN' || finding.status == 'REVIEWING'))
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: busy ? null : onResolve,
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.decision});
  final String decision;
  @override
  Widget build(BuildContext context) {
    final color = decision == 'SAFE'
        ? const Color(0xFF4ADE80)
        : decision == 'REVIEW'
        ? const Color(0xFFE9B949)
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _decisionLabel(decision),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SafetyFrame extends StatelessWidget {
  const _SafetyFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    color: _canvas,
    child: SingleChildScrollView(child: ResponsiveContent(child: child)),
  );
}

class _SafetyEmpty extends StatelessWidget {
  const _SafetyEmpty({required this.title, required this.message});
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
        const Icon(Icons.gpp_maybe_outlined, color: _cyan),
        const SizedBox(height: 10),
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

class _SafetyLoading extends StatelessWidget {
  const _SafetyLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator()),
  );
}

String _decisionLabel(String value) => value == 'SAFE'
    ? 'Safe'
    : value == 'REVIEW'
    ? 'Needs Review'
    : value == 'BLOCKED'
    ? 'Blocked'
    : 'All decisions';
String _customerMessage(String value) => value == 'SAFE'
    ? 'Your content has no current safety flags.'
    : value == 'REVIEW'
    ? 'This content needs review before it can be published.'
    : 'This content cannot be published until the flagged issue is resolved.';
String _label(String value) => value
    .split('_')
    .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
    .join(' ');
String _categoryLabel(String value) => _label(value);
String _websiteName(String id, List<Website> websites) =>
    websites
        .where((website) => website.id == id)
        .map((website) => website.name)
        .firstOrNull ??
    'Website $id';
