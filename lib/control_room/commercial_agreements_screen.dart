import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../backend/control_room_repository.dart';
import '../help/smart_help_button.dart';

class CommercialAgreementsScreen extends StatefulWidget {
  const CommercialAgreementsScreen({
    super.key,
    required this.repository,
    required this.session,
  });
  final ControlRoomRepository? repository;
  final AuthSession? session;
  @override
  State<CommercialAgreementsScreen> createState() =>
      _CommercialAgreementsScreenState();
}

class _CommercialAgreementsScreenState
    extends State<CommercialAgreementsScreen> {
  late Future<List<CommercialAgreementRecord>> _future = _load();
  CommercialAgreementRecord? _selected;
  String _query = '';
  String _status = 'All';
  String _type = 'All';
  bool get _admin => widget.session?.profile.role == AuthRole.masterAdmin;
  Future<List<CommercialAgreementRecord>> _load() =>
      widget.repository!.listCommercialAgreements();
  void _reload() => setState(() => _future = _load());
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: widget.repository == null
                ? const Text('Commercial Agreements unavailable')
                : _selected == null
                ? _list()
                : _detail(_selected!),
          ),
        ),
      ),
    ),
  );
  Widget _list() => FutureBuilder<List<CommercialAgreementRecord>>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!
          .where(
            (a) =>
                (_status == 'All' || a.status == _status) &&
                (_type == 'All' || a.type == _type) &&
                '${a.title} ${a.referenceNumber} ${a.tenantId}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _admin ? 'Commercial Agreements' : 'My Agreements',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SmartHelpButton(
                guideId: 'commercial-agreements',
                tooltip: 'Commercial Agreements help',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _admin
                ? 'Manage customer commercial terms and services.'
                : 'Review your agreement and included services.',
            style: const TextStyle(color: Color(0xFF8A99A5)),
          ),
          const SizedBox(height: 20),
          if (_admin) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search agreements, references, or tenants',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final status in const [
                  'All',
                  'DRAFT',
                  'ACTIVE',
                  'PENDING_RENEWAL',
                  'EXPIRED',
                  'SUSPENDED',
                  'CANCELLED',
                ])
                  ChoiceChip(
                    label: Text(_label(status)),
                    selected: status == _status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
                DropdownButton<String>(
                  value: _type,
                  items:
                      const [
                            'All',
                            'WEBSITE',
                            'HOSTING',
                            'SUPPORT',
                            'MEDIA',
                            'PHOTOGRAPHY',
                            'DRONE',
                            'OTHER',
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(_label(v)),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (rows.isEmpty)
            const Text(
              'No agreements found.',
              style: TextStyle(color: Color(0xFF8A99A5)),
            )
          else
            ...rows.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF00D9F5),
                ),
                title: Text(a.title ?? 'Commercial agreement'),
                subtitle: Text(
                  '${a.referenceNumber ?? 'No reference'} | ${_label(a.type)}${_admin ? ' | Tenant ${a.tenantId}' : ''}',
                ),
                trailing: Text(_label(a.status)),
                onTap: () => setState(() => _selected = a),
              ),
            ),
        ],
      );
    },
  );
  Widget _detail(CommercialAgreementRecord a) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => setState(() => _selected = null),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to agreements'),
      ),
      Text(
        a.title ?? 'Commercial agreement',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      Text(
        '${a.referenceNumber ?? 'No reference'} | ${_label(a.status)}',
        style: const TextStyle(color: Color(0xFF00D9F5)),
      ),
      const SizedBox(height: 12),
      Text(
        '${a.amount?.toStringAsFixed(2) ?? '0.00'} ${a.currency} | ${_label(a.billingFrequency)}',
      ),
      Text(
        'Start: ${_date(a.startsAt)} | End: ${_date(a.endsAt)} | Renewal: ${_date(a.renewalDate)}',
        style: const TextStyle(color: Color(0xFF8A99A5)),
      ),
      if (a.description != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(a.description!),
        ),
      if (a.paymentTerms != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(a.paymentTerms!),
        ),
      if (_admin && a.notes != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Internal notes: ${a.notes!}'),
        ),
      if (_admin) _actions(a),
      const SizedBox(height: 20),
      _items(a),
      const SizedBox(height: 20),
      _documents(a),
      if (_admin) ...[const SizedBox(height: 20), _history(a)],
    ],
  );
  Widget _actions(CommercialAgreementRecord a) => Wrap(
    spacing: 8,
    children: [
      OutlinedButton(
        onPressed: () => _change(a, 'ACTIVE'),
        child: const Text('Activate'),
      ),
      OutlinedButton(
        onPressed: () => _change(a, 'SUSPENDED'),
        child: const Text('Suspend'),
      ),
      OutlinedButton(
        onPressed: () => _change(a, 'PENDING_RENEWAL'),
        child: const Text('Renew'),
      ),
      FilledButton(onPressed: () => _cancel(a), child: const Text('Cancel')),
    ],
  );
  Future<void> _change(CommercialAgreementRecord a, String status) async {
    await widget.repository!.changeCommercialAgreementStatus(
      id: a.id,
      status: status,
    );
    _reload();
  }

  Future<void> _cancel(CommercialAgreementRecord a) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel agreement'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Cancellation reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => controller.text.trim().isEmpty
                ? null
                : Navigator.pop(context, controller.text.trim()),
            child: const Text('Cancel agreement'),
          ),
        ],
      ),
    );
    if (reason != null) await _change(a, 'CANCELLED');
  }

  Widget _items(
    CommercialAgreementRecord a,
  ) => FutureBuilder<List<CommercialAgreementItemRecord>>(
    future: widget.repository!.listCommercialAgreementItems(a.id),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (snapshot.data!.isEmpty)
            const Text('No services are recorded.')
          else
            ...snapshot.data!.map(
              (i) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i.serviceName),
                subtitle: Text(
                  '${i.quantity} x ${i.unitPrice.toStringAsFixed(2)} | ${_label(i.billingFrequency)}',
                ),
                trailing: Text(i.amount.toStringAsFixed(2)),
              ),
            ),
        ],
      );
    },
  );
  Widget _documents(CommercialAgreementRecord a) =>
      FutureBuilder<List<CommercialAgreementDocumentRecord>>(
        future: widget.repository!.listCommercialAgreementDocuments(a.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (snapshot.data!.isEmpty)
                const Text('No documents are available.')
              else
                ...snapshot.data!.map(
                  (d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(d.documentName),
                    subtitle: Text(d.documentType),
                  ),
                ),
            ],
          );
        },
      );
  Widget _history(CommercialAgreementRecord a) =>
      FutureBuilder<List<CommercialAgreementHistoryRecord>>(
        future: widget.repository!.listCommercialAgreementHistory(a.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agreement history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ...snapshot.data!.map(
                (h) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_label(h.action)),
                ),
              ),
            ],
          );
        },
      );
}

String _label(String value) => value
    .split('_')
    .map((p) => '${p[0]}${p.substring(1).toLowerCase()}')
    .join(' ');
String _date(DateTime? value) => value == null
    ? 'Not set'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
