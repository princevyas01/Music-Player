import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recommendation_service.dart';
import 'audio_provider.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService(ref.watch(historyServiceProvider));
});
