import 'dart:io';

import 'package:flutter/services.dart';

class AudioFxService {
  static const _channel = MethodChannel('avdibook/audio_fx');

  Future<void> setAudioSessionId(int? sessionId) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setAudioSessionId', {
      'id': sessionId,
    });
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setEqualizerEnabled', {
      'enabled': enabled,
    });
  }

  Future<void> setEqualizerPreset(int preset) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setEqualizerPreset', {
      'preset': preset,
    });
  }

  Future<List<String>> getEqualizerPresets() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('getEqualizerPresets');
    return raw?.whereType<String>().toList() ?? const [];
  }

  Future<void> setLoudnessBoost(double normalizedBoost) async {
    if (!Platform.isAndroid) return;
    final gainMb = (normalizedBoost.clamp(0.0, 1.0) * 1500).round();
    await _channel.invokeMethod<void>('setLoudnessBoost', {
      'gainMb': gainMb,
    });
  }
}
