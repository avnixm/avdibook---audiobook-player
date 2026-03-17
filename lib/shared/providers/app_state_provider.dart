import 'dart:async';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/shared/providers/preferences_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Onboarding state ─────────────────────────────────────────────────────────

/// True once the user has completed the onboarding flow.
final isOnboardedProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(StorageKeys.isOnboarded) ?? false;
});

// ─── Library state ────────────────────────────────────────────────────────────

/// True once at least one audiobook has been imported.
final hasLibraryProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(StorageKeys.hasLibrary) ?? false;
});

// ─── Theme mode ───────────────────────────────────────────────────────────────

// 0 = system, 1 = light, 2 = dark
// Mutable — full implementation in Phase 10 (Settings).
class ThemeModeNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.themeMode)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getInt(StorageKeys.themeMode) ?? 0;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref.read(startupStorageServiceProvider).loadThemeModeSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.themeMode, fallback);
    state = fallback;
  }

  Future<void> setMode(int mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.themeMode, mode);
    await ref.read(startupStorageServiceProvider).saveThemeModeSnapshot(mode);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, int>(ThemeModeNotifier.new);

// ─── Skip interval preferences ────────────────────────────────────────────────

class SkipForwardNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.skipForwardSecs)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getInt(StorageKeys.skipForwardSecs) ??
        AppDefaults.skipForwardSecs;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadSkipForwardSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipForwardSecs, fallback);
    state = fallback;
  }

  Future<void> set(int secs) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipForwardSecs, secs);
    await ref.read(startupStorageServiceProvider).saveSkipForwardSnapshot(secs);
    state = secs;
  }
}

final skipForwardSecsProvider =
    NotifierProvider<SkipForwardNotifier, int>(SkipForwardNotifier.new);

class SkipBackwardNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.skipBackwardSecs)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getInt(StorageKeys.skipBackwardSecs) ??
        AppDefaults.skipBackwardSecs;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadSkipBackwardSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipBackwardSecs, fallback);
    state = fallback;
  }

  Future<void> set(int secs) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipBackwardSecs, secs);
    await ref.read(startupStorageServiceProvider).saveSkipBackwardSnapshot(secs);
    state = secs;
  }
}

final skipBackwardSecsProvider =
    NotifierProvider<SkipBackwardNotifier, int>(SkipBackwardNotifier.new);

// ─── Scan folder ──────────────────────────────────────────────────────────────

class ScanFolderNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.scanFolderPath)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getString(StorageKeys.scanFolderPath);
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadScanFolderPathSnapshot();
    if (fallback == null || fallback.isEmpty || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.scanFolderPath, fallback);
    state = fallback;
  }

  Future<void> set(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.scanFolderPath, path);
    await ref.read(startupStorageServiceProvider).saveScanFolderPathSnapshot(path);
    state = path;
  }
}

final scanFolderPathProvider =
    NotifierProvider<ScanFolderNotifier, String?>(ScanFolderNotifier.new);

// ─── Global playback speed ─────────────────────────────────────────────────

class GlobalPlaybackSpeedNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey('global_playback_speed')) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getDouble('global_playback_speed') ?? AppDefaults.playbackSpeed;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref
        .read(startupStorageServiceProvider)
        .loadGlobalPlaybackSpeedSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_playback_speed', fallback);
    state = fallback;
  }

  Future<void> set(double speed) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_playback_speed', speed);
    await ref
        .read(startupStorageServiceProvider)
        .saveGlobalPlaybackSpeedSnapshot(speed);
    state = speed;
  }
}

final globalPlaybackSpeedProvider =
    NotifierProvider<GlobalPlaybackSpeedNotifier, double>(
        GlobalPlaybackSpeedNotifier.new);

// ─── Global volume ───────────────────────────────────────────────────────────

class GlobalVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey('global_volume')) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getDouble('global_volume') ?? 1.0;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadGlobalVolumeSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_volume', fallback);
    state = fallback;
  }

  Future<void> set(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_volume', normalized);
    await ref
        .read(startupStorageServiceProvider)
        .saveGlobalVolumeSnapshot(normalized);
    state = normalized;
  }
}

final globalVolumeProvider =
    NotifierProvider<GlobalVolumeNotifier, double>(GlobalVolumeNotifier.new);

// ─── Reduced motion ─────────────────────────────────────────────────────────

class ReducedMotionNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.reducedMotion)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getBool(StorageKeys.reducedMotion) ?? false;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadReducedMotionSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.reducedMotion, fallback);
    state = fallback;
  }

  Future<void> set(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.reducedMotion, enabled);
    await ref
        .read(startupStorageServiceProvider)
        .saveReducedMotionSnapshot(enabled);
    state = enabled;
  }
}

final reducedMotionProvider =
    NotifierProvider<ReducedMotionNotifier, bool>(ReducedMotionNotifier.new);

// ─── Audio control preferences ─────────────────────────────────────────────

class TrimSilenceNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.trimSilence)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getBool(StorageKeys.trimSilence) ?? false;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadTrimSilenceSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.trimSilence, fallback);
    state = fallback;
  }

  Future<void> set(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.trimSilence, enabled);
    await ref
        .read(startupStorageServiceProvider)
        .saveTrimSilenceSnapshot(enabled);
    state = enabled;
  }
}

final trimSilenceProvider =
    NotifierProvider<TrimSilenceNotifier, bool>(TrimSilenceNotifier.new);

class PreservePitchNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.preservePitch)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getBool(StorageKeys.preservePitch) ?? true;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref
        .read(startupStorageServiceProvider)
        .loadPreservePitchSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.preservePitch, fallback);
    state = fallback;
  }

  Future<void> set(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.preservePitch, enabled);
    await ref
        .read(startupStorageServiceProvider)
        .savePreservePitchSnapshot(enabled);
    state = enabled;
  }
}

final preservePitchProvider =
    NotifierProvider<PreservePitchNotifier, bool>(PreservePitchNotifier.new);

class PlaybackPitchNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.playbackPitch)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getDouble(StorageKeys.playbackPitch) ?? 1.0;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadPlaybackPitchSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.playbackPitch, fallback);
    state = fallback;
  }

  Future<void> set(double pitch) async {
    final normalized = pitch.clamp(0.5, 2.0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.playbackPitch, normalized);
    await ref
        .read(startupStorageServiceProvider)
        .savePlaybackPitchSnapshot(normalized);
    state = normalized;
  }
}

final playbackPitchProvider =
    NotifierProvider<PlaybackPitchNotifier, double>(PlaybackPitchNotifier.new);

class SmartRewindSecsNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.smartRewindSecs)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getInt(StorageKeys.smartRewindSecs) ??
        AppDefaults.smartRewindSecs;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref
        .read(startupStorageServiceProvider)
        .loadSmartRewindSecsSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.smartRewindSecs, fallback);
    state = fallback;
  }

  Future<void> set(int secs) async {
    final normalized = secs.clamp(0, 30);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.smartRewindSecs, normalized);
    await ref
        .read(startupStorageServiceProvider)
        .saveSmartRewindSecsSnapshot(normalized);
    state = normalized;
  }
}

final smartRewindSecsProvider = NotifierProvider<SmartRewindSecsNotifier, int>(
  SmartRewindSecsNotifier.new,
);

class VolumeBoostNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.volumeBoost)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getDouble(StorageKeys.volumeBoost) ?? AppDefaults.volumeBoost;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadVolumeBoostSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.volumeBoost, fallback);
    state = fallback;
  }

  Future<void> set(double boost) async {
    final normalized = boost.clamp(0.0, 1.0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.volumeBoost, normalized);
    await ref.read(startupStorageServiceProvider).saveVolumeBoostSnapshot(normalized);
    state = normalized;
  }
}

final volumeBoostProvider =
    NotifierProvider<VolumeBoostNotifier, double>(VolumeBoostNotifier.new);

class StereoBalanceNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.stereoBalance)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getDouble(StorageKeys.stereoBalance) ?? AppDefaults.stereoBalance;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref
        .read(startupStorageServiceProvider)
        .loadStereoBalanceSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.stereoBalance, fallback);
    state = fallback;
  }

  Future<void> set(double balance) async {
    final normalized = balance.clamp(-1.0, 1.0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(StorageKeys.stereoBalance, normalized);
    await ref
        .read(startupStorageServiceProvider)
        .saveStereoBalanceSnapshot(normalized);
    state = normalized;
  }
}

final stereoBalanceProvider =
    NotifierProvider<StereoBalanceNotifier, double>(StereoBalanceNotifier.new);

class EqualizerEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.equalizerEnabled)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getBool(StorageKeys.equalizerEnabled) ??
        AppDefaults.equalizerEnabled;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback = await ref
        .read(startupStorageServiceProvider)
        .loadEqualizerEnabledSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.equalizerEnabled, fallback);
    state = fallback;
  }

  Future<void> set(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.equalizerEnabled, enabled);
    await ref
        .read(startupStorageServiceProvider)
        .saveEqualizerEnabledSnapshot(enabled);
    state = enabled;
  }
}

final equalizerEnabledProvider = NotifierProvider<EqualizerEnabledNotifier, bool>(
  EqualizerEnabledNotifier.new,
);

class EqualizerPresetNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (!prefs.containsKey(StorageKeys.equalizerPreset)) {
      unawaited(_hydrateFromDriftIfNeeded());
    }
    return prefs.getInt(StorageKeys.equalizerPreset) ?? AppDefaults.equalizerPreset;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final fallback =
        await ref.read(startupStorageServiceProvider).loadEqualizerPresetSnapshot();
    if (fallback == null || !ref.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.equalizerPreset, fallback);
    state = fallback;
  }

  Future<void> set(int preset) async {
    final normalized = preset.clamp(0, 32);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.equalizerPreset, normalized);
    await ref
        .read(startupStorageServiceProvider)
        .saveEqualizerPresetSnapshot(normalized);
    state = normalized;
  }
}

final equalizerPresetProvider =
    NotifierProvider<EqualizerPresetNotifier, int>(EqualizerPresetNotifier.new);
