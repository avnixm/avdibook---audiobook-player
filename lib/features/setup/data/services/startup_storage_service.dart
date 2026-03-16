import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../audiobooks/domain/models/audiobook.dart';
import '../../../audiobooks/domain/models/audiobook_author.dart';
import '../../../audiobooks/domain/models/audiobook_chapter.dart';

class StartupStorageService {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _setupCompleteKey = 'setup_complete';
  static const _libraryItemsKey = 'library_items_v2';

  Future<bool> getOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, value);
  }

  Future<bool> getSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  Future<void> setSetupComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, value);
  }

  Future<List<Audiobook>> getLibraryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_libraryItemsKey) ?? <String>[];
    return raw.map(_decodeBook).toList();
  }

  Future<void> setLibraryItems(List<Audiobook> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _libraryItemsKey,
      items.map(_encodeBook).toList(),
    );
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

  Audiobook _decodeBook(String raw) {
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
  }

  BookStatus _decodeStatus(String? rawStatus) {
    if (rawStatus == null) return BookStatus.newBook;
    return BookStatus.values.firstWhere(
      (status) => status.name == rawStatus,
      orElse: () => BookStatus.newBook,
    );
  }
}
