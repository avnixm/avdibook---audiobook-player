import 'dart:async';
import 'dart:convert';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/shared/providers/preferences_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.id,
    required this.bookId,
    required this.positionMs,
    required this.playedAt,
    required this.event,
  });

  final String id;
  final String bookId;
  final int positionMs;
  final DateTime playedAt;
  final String event;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'positionMs': positionMs,
      'playedAt': playedAt.toIso8601String(),
      'event': event,
    };
  }

  factory PlaybackHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PlaybackHistoryEntry(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      positionMs: map['positionMs'] as int? ?? 0,
      playedAt: DateTime.tryParse(map['playedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      event: map['event'] as String? ?? 'play',
    );
  }
}

class PlaybackHistoryNotifier extends Notifier<List<PlaybackHistoryEntry>> {
  final Uuid _uuid = const Uuid();

  @override
  List<PlaybackHistoryEntry> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.playbackHistory);
    if (raw == null || raw.isEmpty) {
      unawaited(_hydrateFromDriftIfNeeded());
      return const [];
    }

    final parsed = _decode(raw);
    parsed.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return parsed;
  }

  Future<void> _hydrateFromDriftIfNeeded() async {
    final snapshot =
        await ref.read(startupStorageServiceProvider).loadPlaybackHistorySnapshot();
    if (snapshot == null || snapshot.isEmpty || !ref.mounted) {
      return;
    }

    final parsed = _decode(snapshot);
    parsed.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    state = parsed;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.playbackHistory, snapshot);
  }

  Future<void> addEvent({
    required String bookId,
    required Duration position,
    required String event,
  }) async {
    final now = DateTime.now();
    final ms = position.inMilliseconds;

    final recentDuplicate = state.any(
      (entry) =>
          entry.bookId == bookId &&
          entry.event == event &&
          (entry.positionMs - ms).abs() <= 1200 &&
          now.difference(entry.playedAt) < const Duration(seconds: 20),
    );
    if (recentDuplicate) return;

    final next = [
      PlaybackHistoryEntry(
        id: _uuid.v4(),
        bookId: bookId,
        positionMs: ms,
        playedAt: now,
        event: event,
      ),
      ...state,
    ];

    state = next.take(150).toList();
    await _persist();
  }

  List<PlaybackHistoryEntry> _decode(String raw) {
    try {
      final payload = jsonDecode(raw) as List<dynamic>;
      return payload
          .whereType<Map<String, dynamic>>()
          .map(PlaybackHistoryEntry.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final encoded = jsonEncode(state.map((e) => e.toMap()).toList());
    await prefs.setString(StorageKeys.playbackHistory, encoded);
    await ref.read(startupStorageServiceProvider).savePlaybackHistorySnapshot(encoded);
  }
}

final playbackHistoryProvider = NotifierProvider<PlaybackHistoryNotifier,
    List<PlaybackHistoryEntry>>(PlaybackHistoryNotifier.new);

final bookPlaybackHistoryProvider =
    Provider.family<List<PlaybackHistoryEntry>, String>((ref, bookId) {
  final all = ref.watch(playbackHistoryProvider);
  return all.where((e) => e.bookId == bookId).toList()
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
});
