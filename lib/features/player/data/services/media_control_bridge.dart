import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/shared/providers/library_provider.dart';

class MediaControlBridge {
  MediaControlBridge(this.ref);

  final Ref ref;
  static const String rootId = 'root';

  final Map<String, List<MediaItem>> _children = <String, List<MediaItem>>{};
  final Map<String, MediaItem> _itemsById = <String, MediaItem>{};

  Future<void> Function(String mediaId)? _onPlayFromMediaId;

  Future<void> initialize({
    Future<void> Function(String mediaId)? onPlayFromMediaId,
  }) async {
    _onPlayFromMediaId = onPlayFromMediaId;

    _rebuildCatalog(ref.read(libraryProvider));
    ref.listen<List<Audiobook>>(libraryProvider, (_, next) {
      _rebuildCatalog(next);
    });
  }

  List<MediaItem> getChildren(String parentId) {
    return _children[parentId] ?? const <MediaItem>[];
  }

  MediaItem? getMediaItem(String mediaId) {
    return _itemsById[mediaId];
  }

  Future<void> playFromMediaId(String mediaId) async {
    await _onPlayFromMediaId?.call(mediaId);
  }

  bool isChapterItem(String mediaId) => mediaId.startsWith('chapter:');

  ({String bookId, int chapterIndex})? parseChapterMediaId(String mediaId) {
    if (!isChapterItem(mediaId)) return null;
    final parts = mediaId.split(':');
    if (parts.length != 3) return null;
    final chapterIndex = int.tryParse(parts[2]);
    if (chapterIndex == null) return null;
    return (bookId: parts[1], chapterIndex: chapterIndex);
  }

  String bookMediaId(String bookId) => 'book:$bookId';
  String chapterMediaId(String bookId, int chapterIndex) =>
      'chapter:$bookId:$chapterIndex';

  void _rebuildCatalog(List<Audiobook> library) {
    _children.clear();
    _itemsById.clear();

    final books = <MediaItem>[];
    for (final book in library) {
      final bookId = bookMediaId(book.id);
      final bookItem = MediaItem(
        id: bookId,
        title: book.title,
        artist: book.author?.name,
        album: book.series,
        artUri: book.coverPath == null ? null : Uri.file(book.coverPath!),
        playable: book.chapters.isEmpty,
        extras: {
          'bookId': book.id,
          'kind': 'book',
        },
      );
      books.add(bookItem);
      _itemsById[bookId] = bookItem;

      final chapterItems = <MediaItem>[];
      if (book.chapters.isNotEmpty) {
        final sorted = [...book.chapters]..sort((a, b) => a.index.compareTo(b.index));
        for (var i = 0; i < sorted.length; i++) {
          final chapter = sorted[i];
          final chapterId = chapterMediaId(book.id, i);
          final chapterItem = MediaItem(
            id: chapterId,
            title: chapter.title,
            artist: book.author?.name,
            album: book.title,
            artUri: book.coverPath == null ? null : Uri.file(book.coverPath!),
            playable: true,
            extras: {
              'bookId': book.id,
              'chapterIndex': i,
              'kind': 'chapter',
            },
          );
          chapterItems.add(chapterItem);
          _itemsById[chapterId] = chapterItem;
        }
      }
      _children[bookId] = chapterItems;
    }

    _children[rootId] = books;
  }

  Future<void> dispose() async {
    _children.clear();
    _itemsById.clear();
    _onPlayFromMediaId = null;
  }
}
