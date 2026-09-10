import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_effect_settings_model.dart';
import 'audio_player_handler.dart';
import 'storage_service.dart';

class AudioEffectApplyResult {
  final bool isSupported;
  final String? error;

  const AudioEffectApplyResult.supported() : isSupported = true, error = null;
  const AudioEffectApplyResult.unsupported()
      : isSupported = false,
        error = 'Audio effects are available on Android only.';
  const AudioEffectApplyResult.failed(this.error) : isSupported = true;
}

/// Android-only effects for the existing AudioPlayer pipeline. On every other
/// platform this is a successful no-op from the player's perspective.
class EqualizerService {
  final AudioPlayerHandler _handler;

  EqualizerService(this._handler);

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<AudioEffectApplyResult> apply(AudioEffectSettings settings) async {
    await StorageService.setAudioEffectSettings(settings);
    if (!isSupported) return const AudioEffectApplyResult.unsupported();
    try {
      final equalizer = _handler.equalizer;
      final loudness = _handler.loudnessEnhancer;
      final parameters = await equalizer.parameters;
      final bands = parameters.bands;
      for (var index = 0; index < bands.length && index < settings.bandGains.length; index++) {
        final gain = settings.bandGains[index]
            .clamp(parameters.minDecibels, parameters.maxDecibels)
            .toDouble();
        await bands[index].setGain(gain);
      }
      await equalizer.setEnabled(settings.enabled);
      await loudness.setTargetGain((settings.loudnessGain.clamp(0.0, 1.0) * 12.0).toDouble());
      await loudness.setEnabled(settings.enabled && settings.loudnessGain > 0);
      return const AudioEffectApplyResult.supported();
    } catch (error) {
      debugPrint('EqualizerService: unable to apply effects: $error');
      // Leave local playback alive even if an OEM exposes a broken effect API.
      return AudioEffectApplyResult.failed(error.toString());
    }
  }

  Future<AudioEffectApplyResult> applyPreset(String preset, {bool enabled = true}) {
    final gains = AudioEffectSettings.presets[preset];
    if (gains == null) return Future.value(const AudioEffectApplyResult.failed('Unknown preset'));
    final current = StorageService.getAudioEffectSettings();
    return apply(current.copyWith(
      enabled: enabled,
      selectedPreset: preset,
      bandGains: gains,
    ));
  }

  Future<AudioEffectApplyResult> disable() {
    return apply(StorageService.getAudioEffectSettings().copyWith(enabled: false));
  }
}
