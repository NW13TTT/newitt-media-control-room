class WebsiteConfiguration {
  const WebsiteConfiguration({
    required this.brandName,
    required this.tagline,
    required this.contentAreas,
    required this.contactAreas,
    required this.socialPlatforms,
  });

  final String brandName;
  final String tagline;
  final List<String> contentAreas;
  final List<String> contactAreas;
  final List<String> socialPlatforms;

  static const newittMedia = WebsiteConfiguration(
    brandName: 'NEWITT Media',
    tagline: 'FROM ABOVE. AFTER DARK. AND EVERYTHING IN BETWEEN.',
    contentAreas: [
      'Homepage',
      'About',
      'NEWITT Skyline Media',
      "NEWITT's Paranormal Adventures",
      'NEWITT Media Photography',
      'Contact',
      'News / Updates',
    ],
    contactAreas: [
      'NEWITT Skyline Media',
      "NEWITT's Paranormal Adventures",
      'NEWITT Media Photography',
    ],
    socialPlatforms: ['YouTube', 'TikTok', 'Instagram', 'Facebook'],
  );

  static const essexParanormal = WebsiteConfiguration(
    brandName: 'Essex Paranormal',
    tagline: 'Investigations, evidence and stories from across Essex.',
    contentAreas: [
      'Homepage',
      'About',
      'Investigations',
      'Locations',
      'Evidence',
      'Gallery',
      'Events',
      'Podcast',
      'News / Updates',
      'Contact',
    ],
    contactAreas: ['General enquiry', 'Investigation enquiry', 'Media enquiry'],
    socialPlatforms: [
      'Facebook',
      'Instagram',
      'TikTok',
      'YouTube',
      'Spotify',
      'Podcast platforms',
    ],
  );

  static const empty = WebsiteConfiguration(
    brandName: '',
    tagline: '',
    contentAreas: ['Homepage', 'About', 'Contact', 'News / Updates'],
    contactAreas: ['General enquiry'],
    socialPlatforms: [],
  );

  factory WebsiteConfiguration.fromSettings(
    Map<String, dynamic> settings, {
    required String fallbackDomain,
  }) {
    final fallback = fromDomain(fallbackDomain);
    return WebsiteConfiguration(
      brandName: settings['brandName'] as String? ?? fallback.brandName,
      tagline: settings['tagline'] as String? ?? fallback.tagline,
      contentAreas: _strings(settings['contentAreas'], fallback.contentAreas),
      contactAreas: _strings(settings['contactAreas'], fallback.contactAreas),
      socialPlatforms: _strings(
        settings['socialPlatforms'],
        fallback.socialPlatforms,
      ),
    );
  }

  static WebsiteConfiguration fromDomain(String domain) {
    switch (domain.toLowerCase()) {
      case 'newittmedia.co.uk':
        return newittMedia;
      case 'essexparanormal.com':
        return essexParanormal;
      default:
        return empty;
    }
  }

  static List<String> _strings(Object? value, List<String> fallback) {
    if (value is! List) return fallback;
    final result = value
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
    return result.isEmpty ? fallback : result;
  }
}
