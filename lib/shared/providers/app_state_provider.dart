import 'package:avdibook/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences instance provider ─────────────────────────────────────

/// Overridden in [ProviderScope] with a real [SharedPreferences] instance.
/// See [main()] for the override setup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope. '
    'Call SharedPreferences.getInstance() in main() and pass it as an override.',
  );
});

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
    return prefs.getInt(StorageKeys.themeMode) ?? 0;
  }

  Future<void> setMode(int mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.themeMode, mode);
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
    return prefs.getInt(StorageKeys.skipForwardSecs) ??
        AppDefaults.skipForwardSecs;
  }

  Future<void> set(int secs) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipForwardSecs, secs);
    state = secs;
  }
}

final skipForwardSecsProvider =
    NotifierProvider<SkipForwardNotifier, int>(SkipForwardNotifier.new);

class SkipBackwardNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(StorageKeys.skipBackwardSecs) ??
        AppDefaults.skipBackwardSecs;
  }

  Future<void> set(int secs) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(StorageKeys.skipBackwardSecs, secs);
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
    return prefs.getString(StorageKeys.scanFolderPath);
  }

  Future<void> set(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.scanFolderPath, path);
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
    return prefs.getDouble('global_playback_speed') ?? AppDefaults.playbackSpeed;
  }

  Future<void> set(double speed) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_playback_speed', speed);
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
    return prefs.getDouble('global_volume') ?? 1.0;
  }

  Future<void> set(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('global_volume', normalized);
    state = normalized;
  }
}

final globalVolumeProvider =
    NotifierProvider<GlobalVolumeNotifier, double>(GlobalVolumeNotifier.new);
