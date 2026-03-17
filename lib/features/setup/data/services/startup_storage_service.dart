import 'dart:convert';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_author.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_chapter.dart';
import 'package:avdibook/features/setup/data/local/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupStorageService {
  StartupStorageService(this._prefs, this._database);

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _setupCompleteKey = 'setup_complete';
  static const _libraryItemsKey = 'library_items_v2';
  static const _driftMigratedKey = 'drift_migrated_v1';

  static const _kvBookmarksKey = 'legacy_bookmarks_v1';
  static const _kvListeningAnalyticsKey = 'legacy_listening_analytics_v1';
  static const _kvCharacterNotesKey = 'legacy_character_notes_v1';
  static const _kvAppSettingsSnapshotKey = 'legacy_app_settings_snapshot_v1';
  static const _kvThemeModeKey = 'setting_theme_mode';
  static const _kvSkipForwardKey = 'setting_skip_forward_secs';
  static const _kvSkipBackwardKey = 'setting_skip_backward_secs';
  static const _kvScanFolderPathKey = 'setting_scan_folder_path';
  static const _kvGlobalSpeedKey = 'setting_global_playback_speed';
  static const _kvGlobalVolumeKey = 'setting_global_volume';
  static const _kvReducedMotionKey = 'setting_reduced_motion';
  static const _kvTrimSilenceKey = 'setting_trim_silence';
  static const _kvPreservePitchKey = 'setting_preserve_pitch';
  static const _kvPlaybackPitchKey = 'setting_playback_pitch';
  static const _kvSmartRewindSecsKey = 'setting_smart_rewind_secs';
  static const _kvPlaybackHistoryKey = 'legacy_playback_history_v1';
  static const _kvVolumeBoostKey = 'setting_volume_boost';
  static const _kvStereoBalanceKey = 'setting_stereo_balance';

  final SharedPreferences _prefs;
  final AppDatabase _database;

  Future<void> ensureDriftMigration() async {
    final migrated = _prefs.getBool(_driftMigratedKey) ?? false;
    if (migrated) return;

    final rawLibrary = _prefs.getStringList(_libraryItemsKey) ?? <String>[];
    final books = rawLibrary
        .map(_decodeBookOrNull)
        .whereType<Audiobook>()
        .toList();
    await _writeLibraryToDrift(books);

    final bookmarks = _prefs.getStringList(StorageKeys.bookmarks);
    if (bookmarks != null) {
      await _database.putKeyValue(
        key: _kvBookmarksKey,
        value: jsonEncode(bookmarks),
      );
    }

    final analytics = _prefs.getString(StorageKeys.listeningAnalytics);
    if (analytics != null) {
      await _database.putKeyValue(
        key: _kvListeningAnalyticsKey,
        value: analytics,
      );
    }

    final characterNotes = _prefs.getString('book_characters_v1');
    if (characterNotes != null) {
      await _database.putKeyValue(
        key: _kvCharacterNotesKey,
        value: characterNotes,
      );
    }

    final appSettingsSnapshot = {
      StorageKeys.themeMode: _prefs.getInt(StorageKeys.themeMode),
      StorageKeys.skipForwardSecs: _prefs.getInt(StorageKeys.skipForwardSecs),
      StorageKeys.skipBackwardSecs: _prefs.getInt(StorageKeys.skipBackwardSecs),
      'global_playback_speed': _prefs.getDouble('global_playback_speed'),
      'global_volume': _prefs.getDouble('global_volume'),
      StorageKeys.scanFolderPath: _prefs.getString(StorageKeys.scanFolderPath),
      _onboardingCompleteKey: _prefs.getBool(_onboardingCompleteKey),
      _setupCompleteKey: _prefs.getBool(_setupCompleteKey),
      StorageKeys.trimSilence: _prefs.getBool(StorageKeys.trimSilence),
      StorageKeys.preservePitch: _prefs.getBool(StorageKeys.preservePitch),
      StorageKeys.playbackPitch: _prefs.getDouble(StorageKeys.playbackPitch),
      StorageKeys.smartRewindSecs: _prefs.getInt(StorageKeys.smartRewindSecs),
      StorageKeys.volumeBoost: _prefs.getDouble(StorageKeys.volumeBoost),
      StorageKeys.stereoBalance: _prefs.getDouble(StorageKeys.stereoBalance),
    };

    await _database.putKeyValue(
      key: _kvAppSettingsSnapshotKey,
      value: jsonEncode(appSettingsSnapshot),
    );

    final themeMode = _prefs.getInt(StorageKeys.themeMode);
    if (themeMode != null) {
      await saveThemeModeSnapshot(themeMode);
    }

    final skipForward = _prefs.getInt(StorageKeys.skipForwardSecs);
    if (skipForward != null) {
      await saveSkipForwardSnapshot(skipForward);
    }

    final skipBackward = _prefs.getInt(StorageKeys.skipBackwardSecs);
    if (skipBackward != null) {
      await saveSkipBackwardSnapshot(skipBackward);
    }

    final scanFolderPath = _prefs.getString(StorageKeys.scanFolderPath);
    if (scanFolderPath != null && scanFolderPath.isNotEmpty) {
      await saveScanFolderPathSnapshot(scanFolderPath);
    }

    final globalSpeed = _prefs.getDouble('global_playback_speed');
    if (globalSpeed != null) {
      await saveGlobalPlaybackSpeedSnapshot(globalSpeed);
    }

    final globalVolume = _prefs.getDouble('global_volume');
    if (globalVolume != null) {
      await saveGlobalVolumeSnapshot(globalVolume);
    }

    final reducedMotion = _prefs.getBool(StorageKeys.reducedMotion);
    if (reducedMotion != null) {
      await saveReducedMotionSnapshot(reducedMotion);
    }

    final trimSilence = _prefs.getBool(StorageKeys.trimSilence);
    if (trimSilence != null) {
      await saveTrimSilenceSnapshot(trimSilence);
    }

    final preservePitch = _prefs.getBool(StorageKeys.preservePitch);
    if (preservePitch != null) {
      await savePreservePitchSnapshot(preservePitch);
    }

    final playbackPitch = _prefs.getDouble(StorageKeys.playbackPitch);
    if (playbackPitch != null) {
      await savePlaybackPitchSnapshot(playbackPitch);
    }

    final smartRewindSecs = _prefs.getInt(StorageKeys.smartRewindSecs);
    if (smartRewindSecs != null) {
      await saveSmartRewindSecsSnapshot(smartRewindSecs);
    }

    final playbackHistory = _prefs.getString(StorageKeys.playbackHistory);
    if (playbackHistory != null) {
      await savePlaybackHistorySnapshot(playbackHistory);
    }

    final volumeBoost = _prefs.getDouble(StorageKeys.volumeBoost);
    if (volumeBoost != null) {
      await saveVolumeBoostSnapshot(volumeBoost);
    }

    final stereoBalance = _prefs.getDouble(StorageKeys.stereoBalance);
    if (stereoBalance != null) {
      await saveStereoBalanceSnapshot(stereoBalance);
    }

    await _prefs.setBool(_driftMigratedKey, true);
  }

  Future<void> saveBookmarksSnapshot(List<String> bookmarks) {
    return _database.putKeyValue(
      key: _kvBookmarksKey,
      value: jsonEncode(bookmarks),
    );
  }

  Future<List<String>?> loadBookmarksSnapshot() async {
    final raw = await _database.getKeyValue(_kvBookmarksKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveListeningAnalyticsSnapshot(String jsonPayload) {
    return _database.putKeyValue(
      key: _kvListeningAnalyticsKey,
      value: jsonPayload,
    );
  }

  Future<String?> loadListeningAnalyticsSnapshot() {
    return _database.getKeyValue(_kvListeningAnalyticsKey);
  }

  Future<void> saveCharacterNotesSnapshot(String jsonPayload) {
    return _database.putKeyValue(
      key: _kvCharacterNotesKey,
      value: jsonPayload,
    );
  }

  Future<String?> loadCharacterNotesSnapshot() {
    return _database.getKeyValue(_kvCharacterNotesKey);
  }

  Future<void> saveThemeModeSnapshot(int mode) {
    return _database.putKeyValue(
      key: _kvThemeModeKey,
      value: mode.toString(),
    );
  }

  Future<int?> loadThemeModeSnapshot() async {
    final raw = await _database.getKeyValue(_kvThemeModeKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveSkipForwardSnapshot(int secs) {
    return _database.putKeyValue(
      key: _kvSkipForwardKey,
      value: secs.toString(),
    );
  }

  Future<int?> loadSkipForwardSnapshot() async {
    final raw = await _database.getKeyValue(_kvSkipForwardKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveSkipBackwardSnapshot(int secs) {
    return _database.putKeyValue(
      key: _kvSkipBackwardKey,
      value: secs.toString(),
    );
  }

  Future<int?> loadSkipBackwardSnapshot() async {
    final raw = await _database.getKeyValue(_kvSkipBackwardKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveScanFolderPathSnapshot(String path) {
    return _database.putKeyValue(
      key: _kvScanFolderPathKey,
      value: path,
    );
  }

  Future<String?> loadScanFolderPathSnapshot() {
    return _database.getKeyValue(_kvScanFolderPathKey);
  }

  Future<void> saveGlobalPlaybackSpeedSnapshot(double speed) {
    return _database.putKeyValue(
      key: _kvGlobalSpeedKey,
      value: speed.toString(),
    );
  }

  Future<double?> loadGlobalPlaybackSpeedSnapshot() async {
    final raw = await _database.getKeyValue(_kvGlobalSpeedKey);
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> saveGlobalVolumeSnapshot(double volume) {
    return _database.putKeyValue(
      key: _kvGlobalVolumeKey,
      value: volume.toString(),
    );
  }

  Future<double?> loadGlobalVolumeSnapshot() async {
    final raw = await _database.getKeyValue(_kvGlobalVolumeKey);
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> saveReducedMotionSnapshot(bool enabled) {
    return _database.putKeyValue(
      key: _kvReducedMotionKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool?> loadReducedMotionSnapshot() async {
    final raw = await _database.getKeyValue(_kvReducedMotionKey);
    if (raw == null) return null;
    if (raw == '1') return true;
    if (raw == '0') return false;
    return null;
  }

  Future<void> saveTrimSilenceSnapshot(bool enabled) {
    return _database.putKeyValue(
      key: _kvTrimSilenceKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool?> loadTrimSilenceSnapshot() async {
    final raw = await _database.getKeyValue(_kvTrimSilenceKey);
    if (raw == null) return null;
    if (raw == '1') return true;
    if (raw == '0') return false;
    return null;
  }

  Future<void> savePreservePitchSnapshot(bool enabled) {
    return _database.putKeyValue(
      key: _kvPreservePitchKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool?> loadPreservePitchSnapshot() async {
    final raw = await _database.getKeyValue(_kvPreservePitchKey);
    if (raw == null) return null;
    if (raw == '1') return true;
    if (raw == '0') return false;
    return null;
  }

  Future<void> savePlaybackPitchSnapshot(double pitch) {
    return _database.putKeyValue(
      key: _kvPlaybackPitchKey,
      value: pitch.toString(),
    );
  }

  Future<double?> loadPlaybackPitchSnapshot() async {
    final raw = await _database.getKeyValue(_kvPlaybackPitchKey);
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> saveSmartRewindSecsSnapshot(int secs) {
    return _database.putKeyValue(
      key: _kvSmartRewindSecsKey,
      value: secs.toString(),
    );
  }

  Future<int?> loadSmartRewindSecsSnapshot() async {
    final raw = await _database.getKeyValue(_kvSmartRewindSecsKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> savePlaybackHistorySnapshot(String jsonPayload) {
    return _database.putKeyValue(
      key: _kvPlaybackHistoryKey,
      value: jsonPayload,
    );
  }

  Future<String?> loadPlaybackHistorySnapshot() {
    return _database.getKeyValue(_kvPlaybackHistoryKey);
  }

  Future<void> saveVolumeBoostSnapshot(double boost) {
    return _database.putKeyValue(
      key: _kvVolumeBoostKey,
      value: boost.toString(),
    );
  }

  Future<double?> loadVolumeBoostSnapshot() async {
    final raw = await _database.getKeyValue(_kvVolumeBoostKey);
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> saveStereoBalanceSnapshot(double balance) {
    return _database.putKeyValue(
      key: _kvStereoBalanceKey,
      value: balance.toString(),
    );
  }

  Future<double?> loadStereoBalanceSnapshot() async {
    final raw = await _database.getKeyValue(_kvStereoBalanceKey);
    return raw == null ? null : double.tryParse(raw);
  }

  Future<bool> getOnboardingComplete() async {
    return _prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingCompleteKey, value);
  }

  Future<bool> getSetupComplete() async {
    return _prefs.getBool(_setupCompleteKey) ?? false;
  }

  Future<void> setSetupComplete(bool value) async {
    await _prefs.setBool(_setupCompleteKey, value);
  }

  Future<List<Audiobook>> getLibraryItems() async {
    final rawFromDb = await _database.getLibraryPayloads();
    if (rawFromDb.isNotEmpty) {
      return rawFromDb
          .map(_decodeBookOrNull)
          .whereType<Audiobook>()
          .toList();
    }

    final rawFromPrefs = _prefs.getStringList(_libraryItemsKey) ?? <String>[];
    return rawFromPrefs
        .map(_decodeBookOrNull)
        .whereType<Audiobook>()
        .toList();
  }

  Future<void> setLibraryItems(List<Audiobook> items) async {
    // Dual-write during migration phase keeps rollback easy.
    await _prefs.setStringList(
      _libraryItemsKey,
      items.map(_encodeBook).toList(),
    );
    await _writeLibraryToDrift(items);
  }

  Future<void> _writeLibraryToDrift(List<Audiobook> items) {
    final payloads = items
        .map((book) => (id: book.id, payload: _encodeBook(book)))
        .toList();
    return _database.replaceLibraryPayloads(payloads);
  }

  String _encodeBook(Audiobook book) {
    return jsonEncode({
      'id': book.id,
      'title': book.title,
      'author': book.author?.name,
      'narrator': book.narrator,
      'description': book.description,
      'coverPath': book.coverPath,
      'series': book.series,
      'genre': book.genre,
      'sourcePaths': book.sourcePaths,
      'primaryFormat': book.primaryFormat,
      'importedAt': book.importedAt.toIso8601String(),
      'progress': book.progress,
      'resumePosition': book.resumePosition?.inMilliseconds,
      'lastPlayedAt': book.lastPlayedAt?.toIso8601String(),
      'status': book.status.name,
      'completedAt': book.completedAt?.toIso8601String(),
      'preferredSpeed': book.preferredSpeed,
      'isFavorite': book.isFavorite,
      'chapters': book.chapters
          .map(
            (chapter) => {
              'id': chapter.id,
              'title': chapter.title,
              'filePath': chapter.filePath,
              'index': chapter.index,
              'startOffset': chapter.startOffset?.inMilliseconds,
              'duration': chapter.duration?.inMilliseconds,
            },
          )
          .toList(),
    });
  }

  Audiobook? _decodeBookOrNull(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final rawChapters = (map['chapters'] as List<dynamic>? ?? <dynamic>[]);

      return Audiobook(
        id: map['id'] as String,
        title: map['title'] as String,
        author: map['author'] == null
            ? null
            : AudiobookAuthor(name: map['author'] as String),
        narrator: map['narrator'] as String?,
        description: map['description'] as String?,
        coverPath: map['coverPath'] as String?,
        series: map['series'] as String?,
        genre: map['genre'] as String?,
        sourcePaths: List<String>.from(map['sourcePaths'] as List<dynamic>),
        primaryFormat: map['primaryFormat'] as String,
        importedAt: DateTime.parse(map['importedAt'] as String),
        progress: (map['progress'] as num?)?.toDouble() ?? 0,
        resumePosition: map['resumePosition'] == null
            ? null
            : Duration(milliseconds: map['resumePosition'] as int),
        lastPlayedAt: map['lastPlayedAt'] == null
            ? null
            : DateTime.parse(map['lastPlayedAt'] as String),
        status: _decodeStatus(map['status'] as String?),
        completedAt: map['completedAt'] == null
            ? null
            : DateTime.parse(map['completedAt'] as String),
        preferredSpeed: (map['preferredSpeed'] as num?)?.toDouble(),
        isFavorite: map['isFavorite'] as bool? ?? false,
        chapters: rawChapters.map((chapterMap) {
          final c = chapterMap as Map<String, dynamic>;
          return AudiobookChapter(
            id: c['id'] as String,
            title: c['title'] as String,
            filePath: c['filePath'] as String,
            index: c['index'] as int,
            startOffset: c['startOffset'] == null
                ? null
                : Duration(milliseconds: c['startOffset'] as int),
            duration: c['duration'] == null
                ? null
                : Duration(milliseconds: c['duration'] as int),
          );
        }).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  BookStatus _decodeStatus(String? rawStatus) {
    if (rawStatus == null) return BookStatus.newBook;
    return BookStatus.values.firstWhere(
      (status) => status.name == rawStatus,
      orElse: () => BookStatus.newBook,
    );
  }
}
