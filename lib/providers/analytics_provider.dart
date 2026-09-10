import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_report_service.dart';

final analyticsReportServiceProvider = Provider<AnalyticsReportService>((ref) {
  return AnalyticsReportService();
});
