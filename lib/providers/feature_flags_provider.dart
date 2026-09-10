import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feature_flags_model.dart';
import '../services/storage_service.dart';

/// Persisted, opt-in switches for extensions that are not part of SpinWave's
/// original behaviour. Keeping this state separate from playback state means a
/// disabled extension cannot affect local playback.
class FeatureFlagsNotifier extends StateNotifier<FeatureFlags> {
  FeatureFlagsNotifier() : super(StorageService.getFeatureFlags());

  Future<void> update(FeatureFlags flags) async {
    state = flags;
    await StorageService.setFeatureFlags(flags);
  }

  Future<void> setAdvancedSearch(bool enabled) =>
      update(state.copyWith(enableAdvancedSearch: enabled));
}

final featureFlagsProvider =
    StateNotifierProvider<FeatureFlagsNotifier, FeatureFlags>((ref) {
  return FeatureFlagsNotifier();
});
