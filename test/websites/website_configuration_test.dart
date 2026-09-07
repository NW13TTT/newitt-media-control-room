import 'package:flutter_test/flutter_test.dart';
import 'package:newitt_media_control_room/websites/website_configuration.dart';

void main() {
  test('NEWITT configuration keeps the three enquiry areas', () {
    final config = WebsiteConfiguration.fromDomain('newittmedia.co.uk');

    expect(config.brandName, 'NEWITT Media');
    expect(config.tagline, contains('FROM ABOVE'));
    expect(config.contactAreas, contains('NEWITT Skyline Media'));
    expect(config.contactAreas, contains("NEWITT's Paranormal Adventures"));
    expect(config.contactAreas, contains('NEWITT Media Photography'));
  });

  test('Essex configuration remains separate from NEWITT configuration', () {
    final essex = WebsiteConfiguration.fromDomain('essexparanormal.com');
    final newitt = WebsiteConfiguration.fromDomain('newittmedia.co.uk');

    expect(essex.brandName, 'Essex Paranormal');
    expect(essex.contentAreas, contains('Investigations'));
    expect(essex.contentAreas, contains('Evidence'));
    expect(essex.brandName, isNot(newitt.brandName));
    expect(essex.contactAreas, isNot(equals(newitt.contactAreas)));
  });

  test(
    'stored settings override defaults without changing domain ownership',
    () {
      final config = WebsiteConfiguration.fromSettings(const {
        'brandName': 'Configured tenant',
        'contactAreas': ['General enquiry', 'Bookings'],
      }, fallbackDomain: 'essexparanormal.com');

      expect(config.brandName, 'Configured tenant');
      expect(config.contactAreas, ['General enquiry', 'Bookings']);
      expect(config.contentAreas, contains('Investigations'));
    },
  );
}
