import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import 'app_state_provider.dart';

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.positionMs,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String bookId;
  final int positionMs;
  final DateTime createdAt;
  final String? label;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'positionMs': positionMs,
      'createdAt': createdAt.toIso8601String(),
      'label': label,
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

    parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return parsed;
  }

  Future<void> add({
    required String bookId,
    required Duration position,
    String? label,
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
        label: label,
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

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      StorageKeys.bookmarks,
      state.map((b) => jsonEncode(b.toMap())).toList(),
    );
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

final bookBookmarksProvider = Provider.family<List<Bookmark>, String>((ref, bookId) {
  final all = ref.watch(bookmarksProvider);
  return all.where((b) => b.bookId == bookId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});
