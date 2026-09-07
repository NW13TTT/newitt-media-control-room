import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.repository});

  final ControlRoomRepository? repository;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String query = '';
  String? action;
  String? resourceType;

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    if (repository == null) {
      return const Center(child: Text('Audit log unavailable.'));
    }

    return FutureBuilder<List<AuditEventRecord>>(
      future: repository.listAuditEvents(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data!
            .where(
              (event) => '${event.action} ${event.resourceType}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .where((event) => action == null || event.action == action)
            .where(
              (event) =>
                  resourceType == null || event.resourceType == resourceType,
            )
            .toList();
        final actions = snapshot.data!.map((event) => event.action).toSet();
        final resourceTypes = snapshot.data!
            .map((event) => event.resourceType)
            .toSet();
        return ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audit Log',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search safe audit events',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _AuditFilter(
                    label: 'All actions',
                    value: action,
                    values: actions,
                    onChanged: (value) => setState(() => action = value),
                  ),
                  _AuditFilter(
                    label: 'All resources',
                    value: resourceType,
                    values: resourceTypes,
                    onChanged: (value) => setState(() => resourceType = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: events
                      .map(
                        (event) => ListTile(
                          leading: const Icon(Icons.history_outlined),
                          title: Text(event.action),
                          subtitle: Text(
                            '${event.resourceType} | ${event.createdAt?.toLocal().toString() ?? 'Time unavailable'}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuditFilter extends StatelessWidget {
  const _AuditFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Set<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: constraints.maxWidth < 500 ? constraints.maxWidth : 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: null, child: Text(label)),
          ...values.map(
            (item) => DropdownMenuItem(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}
