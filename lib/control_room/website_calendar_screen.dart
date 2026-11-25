import 'package:flutter/material.dart';

import '../backend/calendar_repository.dart';
import '../backend/control_room_repository.dart';

class WebsiteCalendarScreen extends StatefulWidget {
  const WebsiteCalendarScreen({
    super.key,
    required this.websiteId,
    required this.websiteName,
    required this.repository,
    this.initialMonth,
  });

  final String websiteId;
  final String websiteName;
  final WebsiteCalendarRepository repository;
  final DateTime? initialMonth;

  @override
  State<WebsiteCalendarScreen> createState() => _WebsiteCalendarScreenState();
}

class _WebsiteCalendarScreenState extends State<WebsiteCalendarScreen> {
  late final DateTime today = widget.initialMonth ?? DateTime.now();
  late DateTime month = DateTime.utc(today.year, today.month);
  late Future<WebsiteCalendarData> data = _load();

  Future<WebsiteCalendarData> _load() =>
      widget.repository.loadWebsiteCalendar(widget.websiteId);

  void changeMonth(int offset) =>
      setState(() => month = DateTime.utc(month.year, month.month + offset));

  void refresh() => setState(() => data = _load());

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.websiteName} calendar'),
        actions: [
          IconButton(
            onPressed: refresh,
            tooltip: 'Refresh calendar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Text(
                'Event dates use Europe/London. Booking details are private.',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => changeMonth(-1),
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(localizations.formatMonthYear(month)),
                IconButton(
                  onPressed: () => changeMonth(1),
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<WebsiteCalendarData>(
                future: data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: refresh,
                        child: const Text('Calendar unavailable. Retry'),
                      ),
                    );
                  }
                  final records = snapshot.data!;
                  final next = DateTime.utc(month.year, month.month + 1);
                  final events =
                      records.content
                          .map(_CalendarEvent.fromContent)
                          .whereType<_CalendarEvent>()
                          .where(
                            (record) =>
                                record.start.isBefore(next) &&
                                !record.end.isBefore(month),
                          )
                          .toList()
                        ..sort((a, b) => a.start.compareTo(b.start));
                  if (events.isEmpty)
                    return const Center(
                      child: Text('No calendar entries this month.'),
                    );
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final bookings = records.bookings
                          .where((row) => row.eventId == event.id)
                          .toList();
                      final booked = bookings
                          .where((item) => item.status == 'CONFIRMED')
                          .fold(0, (sum, row) => sum + row.places);
                      final capacity = records.capacity[event.id];
                      final dates = [
                        localizations.formatShortDate(event.start),
                        if (event.start != event.end)
                          localizations.formatShortDate(event.end),
                      ].join(' – ');
                      final status = [
                        dates,
                        event.kind,
                        event.status,
                        if (capacity != null)
                          '$booked confirmed places / $capacity total',
                        if (capacity != null && booked >= capacity) 'Sold out',
                      ].join(' · ');
                      return Card(
                        child: ExpansionTile(
                          title: Text(event.title),
                          subtitle: Text(status),
                          children: [
                            if (bookings.isEmpty)
                              const ListTile(title: Text('No booking records')),
                            for (final booking in bookings)
                              ListTile(
                                title: Text(booking.customer),
                                subtitle: Text(
                                  '${booking.reference}\n${booking.email}\n'
                                  '${booking.places} places · ${booking.status} · ${booking.payment}',
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent(
    this.id,
    this.title,
    this.start,
    this.end,
    this.kind,
    this.status,
  );

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String kind;
  final String status;

  static _CalendarEvent? fromContent(ContentRecord record) {
    final data = record.content;
    final recordType = data['recordType'] ?? data['section'];
    if (![
      'event',
      'events',
      'investigation',
      'appointment',
      'convention',
    ].contains(recordType))
      return null;
    final start = _date(data['date']);
    if (start == null) return null;
    final end = _date(data['endDate']) ?? start;
    final type = data['eventType'] ?? recordType;
    final kind = switch (type) {
      'private' => 'Private investigation',
      'appointment' => 'Internal appointment',
      'convention' => 'Convention',
      'promotion' => 'Announcement',
      'investigation' => 'Investigation',
      _ => 'Public event',
    };
    final title = data['title']?.toString().trim();
    return _CalendarEvent(
      record.id,
      title == null || title.isEmpty ? record.contentKey : title,
      start,
      end.isBefore(start) ? start : end,
      kind,
      data['eventStatus']?.toString() ?? record.status,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
      return null;
    final date = DateTime.tryParse('${value}T00:00:00Z');
    return date?.toIso8601String().split('T').first == value ? date : null;
  }
}
