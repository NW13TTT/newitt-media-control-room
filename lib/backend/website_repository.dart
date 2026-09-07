import '../websites/website_model.dart';

abstract interface class WebsiteRepository {
  Future<List<Website>> listAccessibleWebsites();
}
