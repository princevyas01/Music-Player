import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_effect_settings_model.dart';
import '../services/equalizer_service.dart';
import '../services/storage_service.dart';
import 'audio_provider.dart';

class AudioEffectState {
  final AudioEffectSettings settings;
  final bool isSupported;
  final String? error;

  const AudioEffectState({
    required this.settings,
    required this.isSupported,
    this.error,
  });
}

class AudioEffectNotifier extends StateNotifier<AudioEffectState> {
  final EqualizerService _service;

  AudioEffectNotifier(this._service)
      : super(AudioEffectState(
          settings: StorageService.getAudioEffectSettings(),
          isSupported: _service.isSupported,
        ));

  Future<void> update(AudioEffectSettings settings) async {
    final result = await _service.apply(settings);
    state = AudioEffectState(
      settings: settings,
      isSupported: result.isSupported,
      error: result.error,
    );
  }

  Future<void> selectPreset(String preset) async {
    final gains = AudioEffectSettings.presets[preset];
    if (gains == null) return;
    await update(state.settings.copyWith(
      enabled: true,
      selectedPreset: preset,
      bandGains: gains,
    ));
  }
}

final equalizerServiceProvider = Provider<EqualizerService>((ref) {
  return EqualizerService(ref.watch(audioHandlerProvider));
});

final audioEffectProvider =
    StateNotifierProvider<AudioEffectNotifier, AudioEffectState>((ref) {
  return AudioEffectNotifier(ref.watch(equalizerServiceProvider));
});
