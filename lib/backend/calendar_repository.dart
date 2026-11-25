import 'control_room_repository.dart';

class CalendarBooking {
  const CalendarBooking({
    required this.reference,
    required this.eventId,
    required this.customer,
    required this.email,
    required this.places,
    required this.status,
    required this.payment,
  });

  final String reference;
  final String eventId;
  final String customer;
  final String email;
  final int places;
  final String status;
  final String payment;
}

class WebsiteCalendarData {
  const WebsiteCalendarData({
    required this.content,
    required this.capacity,
    required this.bookings,
  });

  final List<ContentRecord> content;
  final Map<String, int> capacity;
  final List<CalendarBooking> bookings;
}

abstract interface class WebsiteCalendarRepository {
  Future<WebsiteCalendarData> loadWebsiteCalendar(String websiteId);
}
