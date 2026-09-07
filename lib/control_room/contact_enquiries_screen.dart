import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';

class ContactEnquiriesScreen extends StatefulWidget {
  const ContactEnquiriesScreen({super.key, required this.repository});

  final ControlRoomRepository? repository;

  @override
  State<ContactEnquiriesScreen> createState() => _ContactEnquiriesScreenState();
}

class _ContactEnquiriesScreenState extends State<ContactEnquiriesScreen> {
  late Future<List<ContactEnquiryRecord>> _future = _load();
  String _query = '';
  String _status = 'All';

  Future<List<ContactEnquiryRecord>> _load() =>
      widget.repository!.listContactEnquiries();

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: repository == null
          ? const Center(child: Text('Contact enquiries unavailable.'))
          : SingleChildScrollView(
              child: ResponsiveContent(
                child: FutureBuilder<List<ContactEnquiryRecord>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact Enquiries',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Enquiries could not be loaded. Please try again.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      );
                    }
                    final enquiries =
                        snapshot.data ?? const <ContactEnquiryRecord>[];
                    final visible = enquiries.where((item) {
                      final text =
                          '${item.name} ${item.area} ${item.email} ${item.message} ${item.status}'
                              .toLowerCase();
                      return (_status == 'All' || item.status == _status) &&
                          text.contains(_query.trim().toLowerCase());
                    }).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Contact Enquiries',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh enquiries',
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Private enquiries for the authenticated website scope.',
                          style: TextStyle(color: Color(0xFF8A99A5)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search enquiries',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final status in const [
                              'All',
                              'NEW',
                              'READ',
                              'RESPONDED',
                              'CLOSED',
                            ])
                              ChoiceChip(
                                label: Text(
                                  status == 'All' ? status : _label(status),
                                ),
                                selected: _status == status,
                                onSelected: (_) =>
                                    setState(() => _status = status),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (visible.isEmpty)
                          const _EnquiryEmpty()
                        else
                          ...visible.map(
                            (item) => _EnquiryTile(
                              enquiry: item,
                              onOpen: () => _open(item),
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

  Future<void> _open(ContactEnquiryRecord enquiry) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EnquiryDialog(repository: widget.repository!, enquiry: enquiry),
    );
    if (updated == true && mounted) _refresh();
  }

  String _label(String value) => value[0] + value.substring(1).toLowerCase();
}

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({required this.enquiry, required this.onOpen});
  final ContactEnquiryRecord enquiry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onOpen,
      leading: const Icon(Icons.mail_outline),
      title: Text(enquiry.name),
      subtitle: Text('${enquiry.area} | ${enquiry.email}'),
      trailing: Chip(label: Text(enquiry.status)),
    ),
  );
}

class _EnquiryDialog extends StatefulWidget {
  const _EnquiryDialog({required this.repository, required this.enquiry});
  final ControlRoomRepository repository;
  final ContactEnquiryRecord enquiry;
  @override
  State<_EnquiryDialog> createState() => _EnquiryDialogState();
}

class _EnquiryDialogState extends State<_EnquiryDialog> {
  late String status = widget.enquiry.status;
  late final TextEditingController notes = TextEditingController(
    text: widget.enquiry.internalNotes ?? '',
  );
  bool saving = false;

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.repository.updateContactEnquiry(
        id: widget.enquiry.id,
        status: status,
        internalNotes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.enquiry.area),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.enquiry.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.enquiry.email,
              style: const TextStyle(color: Color(0xFF8A99A5)),
            ),
            const SizedBox(height: 16),
            Text(widget.enquiry.message),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['NEW', 'READ', 'RESPONDED', 'CLOSED']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() => status = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Internal notes',
                helperText: 'Visible only inside the authorised Control Room.',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving...' : 'Save'),
      ),
    ],
  );
}

class _EnquiryEmpty extends StatelessWidget {
  const _EnquiryEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(child: Text('No contact enquiries match this view.')),
  );
}
