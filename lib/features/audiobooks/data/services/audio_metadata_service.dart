import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExtractedAudioMetadata {
  const ExtractedAudioMetadata({
    this.title,
    this.author,
    this.genre,
    this.coverPath,
  });

  final String? title;
  final String? author;
  final String? genre;
  final String? coverPath;

  bool get hasAnyValue =>
      title != null || author != null || genre != null || coverPath != null;
}

class AudioMetadataService {
  Future<ExtractedAudioMetadata?> readFromPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return null;

    // Prefer container formats that commonly carry rich tags for audiobooks.
    final prioritized = [...filePaths]..sort(_sourcePriorityCompare);
    ExtractedAudioMetadata? bestEffort;

    for (final path in prioritized) {
      try {
        final metadata = readMetadata(File(path), getImage: true);
        final title = _firstNonEmpty([metadata.title, metadata.album]);
        final performerNames = metadata.performers
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .join(', ');
        final author = _firstNonEmpty([metadata.artist, performerNames]);
        final genre = metadata.genres.isEmpty ? null : _clean(metadata.genres.first);
        final picture = metadata.pictures.isEmpty ? null : metadata.pictures.first;
        final coverPath = await _storeCoverIfPresent(path, picture?.bytes);

        final extracted = ExtractedAudioMetadata(
          title: title,
          author: author,
          genre: genre,
          coverPath: coverPath,
        );

        bestEffort ??= extracted;

        if (coverPath == null && (title != null || author != null)) {
          final downloadedCover = await _downloadCoverFromOpenLibrary(
            title: title,
            author: author,
            sourcePath: path,
          );
          if (downloadedCover != null) {
            return ExtractedAudioMetadata(
              title: title,
              author: author,
              genre: genre,
              coverPath: downloadedCover,
            );
          }
        }

        if (extracted.hasAnyValue) return extracted;
      } catch (_) {
        // Keep trying other paths if one file cannot be parsed.
      }
    }

    if (bestEffort != null &&
        bestEffort.coverPath == null &&
        (bestEffort.title != null || bestEffort.author != null)) {
      final downloadedCover = await _downloadCoverFromOpenLibrary(
        title: bestEffort.title,
        author: bestEffort.author,
        sourcePath: filePaths.first,
      );
      if (downloadedCover != null) {
        return ExtractedAudioMetadata(
          title: bestEffort.title,
          author: bestEffort.author,
          genre: bestEffort.genre,
          coverPath: downloadedCover,
        );
      }
    }

    return bestEffort;
  }

  Future<String?> _storeCoverIfPresent(
    String sourcePath,
    List<int>? coverBytes,
  ) async {
    if (coverBytes == null || coverBytes.isEmpty) return null;

    try {
      final supportDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(supportDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final extension = 'jpg';
      final safeBase = p
          .basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final fileName = 'cover_${safeBase}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final destination = File(p.join(coversDir.path, fileName));

      await destination.writeAsBytes(coverBytes, flush: true);
      return destination.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _downloadCoverFromOpenLibrary({
    required String? title,
    required String? author,
    required String sourcePath,
  }) async {
    final cleanTitle = _clean(title);
    final cleanAuthor = _clean(author);
    if (cleanTitle == null && cleanAuthor == null) return null;

    try {
      final query = <String, String>{
        'limit': '1',
        'fields': 'cover_i,title,author_name',
      };
      if (cleanTitle != null) query['title'] = cleanTitle;
      if (cleanAuthor != null) query['author'] = cleanAuthor;

      final searchUri = Uri.https('openlibrary.org', '/search.json', query);
      final searchBody = await _httpGetString(searchUri);
      if (searchBody == null || searchBody.isEmpty) return null;

      final map = jsonDecode(searchBody) as Map<String, dynamic>;
      final docs = (map['docs'] as List<dynamic>?) ?? const [];
      if (docs.isEmpty) return null;

      final top = docs.first as Map<String, dynamic>;
      final coverId = top['cover_i'];
      if (coverId is! num) return null;

      final coverUri = Uri.parse(
        'https://covers.openlibrary.org/b/id/${coverId.toInt()}-L.jpg',
      );
      final bytes = await _httpGetBytes(coverUri);
      if (bytes == null || bytes.isEmpty) return null;

      return _storeCoverIfPresent(sourcePath, bytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _httpGetString(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return utf8.decode(await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      ));
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>?> _httpGetBytes(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
    } finally {
      client.close(force: true);
    }
  }

  int _sourcePriorityCompare(String a, String b) {
    final pa = _priorityForExtension(p.extension(a).toLowerCase());
    final pb = _priorityForExtension(p.extension(b).toLowerCase());
    if (pa != pb) return pa.compareTo(pb);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  int _priorityForExtension(String ext) {
    switch (ext) {
      case '.m4b':
        return 0;
      case '.m4a':
        return 1;
      case '.mp3':
        return 2;
      default:
        return 3;
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final cleaned = _clean(value);
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  String? _clean(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
