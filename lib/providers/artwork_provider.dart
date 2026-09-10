import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artwork_model.dart';
import '../models/track_model.dart';
import '../services/artwork_service.dart';

final artworkServiceProvider = Provider<ArtworkService>((ref) => ArtworkService());

final artworkProvider = FutureProvider.autoDispose.family<ArtworkModel, Track>((ref, track) {
  return ref.watch(artworkServiceProvider).resolve(track);
});
