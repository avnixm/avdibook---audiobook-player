import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/shared/providers/preferences_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';


class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.positionMs,
    required this.createdAt,
    this.label,
    this.note,
    this.clipStartMs,
    this.clipEndMs,
  });

  final String id;
  final String bookId;
  final int positionMs;
  final DateTime createdAt;
  final String? label;
  final String? note;
  final int? clipStartMs;
  final int? clipEndMs;

  bool get isClip =>
      clipStartMs != null && clipEndMs != null && clipEndMs! > clipStartMs!;

  Bookmark copyWith({
    String? label,
    String? note,
    bool clearLabel = false,
    bool clearNote = false,
    int? clipStartMs,
    int? clipEndMs,
    bool clearClipRange = false,
  }) {
    return Bookmark(
      id: id,
      bookId: bookId,
      positionMs: positionMs,
      createdAt: createdAt,
      label: clearLabel ? null : (label ?? this.label),
      note: clearNote ? null : (note ?? this.note),
      clipStartMs: clearClipRange ? null : (clipStartMs ?? this.clipStartMs),
      clipEndMs: clearClipRange ? null : (clipEndMs ?? this.clipEndMs),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'positionMs': positionMs,
      'createdAt': createdAt.toIso8601String(),
      'label': label,
      'note': note,
      'clipStartMs': clipStartMs,
      'clipEndMs': clipEndMs,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      positionMs: map['positionMs'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      label: map['label'] as String?,
      note: map['note'] as String?,
      clipStartMs: map['clipStartMs'] as int?,
      clipEndMs: map['clipEndMs'] as int?,
    );
  }
}

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  final Uuid _uuid = const Uuid();

  @override
  List<Bookmark> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getStringList(StorageKeys.bookmarks) ?? const <String>[];

    final parsed = <Bookmark>[];
    for (final item in raw) {
      try {
        parsed.add(Bookmark.fromMap(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {
        // Skip malformed bookmark payloads.
      }
    }

    unawaited(_hydrateFromDriftIfNeeded(raw));

    parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return parsed;
  }

  Future<void> _hydrateFromDriftIfNeeded(List<String> existingRaw) async {
    if (existingRaw.isNotEmpty) return;

    final storage = ref.read(startupStorageServiceProvider);
    final fallback = await storage.loadBookmarksSnapshot();
    if (fallback == null || fallback.isEmpty || !ref.mounted) {
      return;
    }

    final parsed = <Bookmark>[];
    for (final item in fallback) {
      try {
        parsed.add(Bookmark.fromMap(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {
        // Skip malformed bookmark payloads.
      }
    }

    parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = parsed;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(StorageKeys.bookmarks, fallback);
  }

  Future<void> add({
    required String bookId,
    required Duration position,
    String? label,
    String? note,
  }) async {
    final ms = position.inMilliseconds;
    final duplicate = state.where((b) => b.bookId == bookId).any(
          (b) => (b.positionMs - ms).abs() <= 1500,
        );
    if (duplicate) return;

    final next = [
      Bookmark(
        id: _uuid.v4(),
        bookId: bookId,
        positionMs: ms,
        createdAt: DateTime.now(),
        label: _normalize(label),
        note: _normalize(note),
      ),
      ...state,
    ];

    state = next;
    await _persist();
  }

  Future<void> addClip({
    required String bookId,
    required Duration start,
    required Duration end,
    String? label,
    String? note,
  }) async {
    final startMs = start.inMilliseconds;
    final endMs = end.inMilliseconds;
    if (endMs <= startMs) return;

    final duplicate = state.where((b) => b.bookId == bookId && b.isClip).any(
          (b) =>
              ((b.clipStartMs ?? 0) - startMs).abs() <= 1500 &&
              ((b.clipEndMs ?? 0) - endMs).abs() <= 1500,
        );
    if (duplicate) return;

    final next = [
      Bookmark(
        id: _uuid.v4(),
        bookId: bookId,
        positionMs: startMs,
        createdAt: DateTime.now(),
        label: _normalize(label),
        note: _normalize(note),
        clipStartMs: startMs,
        clipEndMs: endMs,
      ),
      ...state,
    ];

    state = next;
    await _persist();
  }

  Future<void> remove(String bookmarkId) async {
    state = state.where((b) => b.id != bookmarkId).toList();
    await _persist();
  }

  Future<void> clearForBook(String bookId) async {
    state = state.where((b) => b.bookId != bookId).toList();
    await _persist();
  }

  Future<void> update({
    required String bookmarkId,
    String? label,
    String? note,
  }) async {
    final index = state.indexWhere((b) => b.id == bookmarkId);
    if (index < 0) return;

    final next = [...state];
    next[index] = next[index].copyWith(
      label: _normalize(label),
      note: _normalize(note),
      clearLabel: _normalize(label) == null,
      clearNote: _normalize(note) == null,
    );

    state = next;
    await _persist();
  }

  String? _normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final encoded = state.map((b) => jsonEncode(b.toMap())).toList();

    await prefs.setStringList(
      StorageKeys.bookmarks,
      encoded,
    );

    await ref.read(startupStorageServiceProvider).saveBookmarksSnapshot(encoded);
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

final bookBookmarksProvider = Provider.family<List<Bookmark>, String>((ref, bookId) {
  final all = ref.watch(bookmarksProvider);
  return all.where((b) => b.bookId == bookId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});
