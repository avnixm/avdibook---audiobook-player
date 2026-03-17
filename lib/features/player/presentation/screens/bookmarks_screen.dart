import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';
import 'package:avdibook/shared/providers/bookmarks_provider.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  Future<void> _exportBookmarks(List<Bookmark> bookmarks) async {
    final buffer = StringBuffer();
    buffer.writeln('AvdiBook Bookmarks');
    buffer.writeln('Book ID: ${widget.bookId}');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    for (var i = 0; i < bookmarks.length; i++) {
      final item = bookmarks[i];
      final ts = DurationFormatter.format(Duration(milliseconds: item.positionMs));
      final title = item.label ?? (item.isClip ? 'Clip ${i + 1}' : 'Bookmark ${i + 1}');
      buffer.writeln('${i + 1}. $title');
      if (item.isClip) {
        final clipStart = Duration(milliseconds: item.clipStartMs!);
        final clipEnd = Duration(milliseconds: item.clipEndMs!);
        buffer.writeln(
          '   Clip: ${DurationFormatter.format(clipStart)} - ${DurationFormatter.format(clipEnd)}',
        );
      } else {
        buffer.writeln('   Time: $ts');
      }
      if (item.note != null && item.note!.trim().isNotEmpty) {
        buffer.writeln('   Note: ${item.note!.trim()}');
      }
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmarks copied to clipboard.')),
    );
  }

  Future<void> _showEditDialog(Bookmark bookmark) async {
    final titleCtl = TextEditingController(text: bookmark.label ?? '');
    final noteCtl = TextEditingController(text: bookmark.note ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Bookmark'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Bookmark title',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Optional note',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      await ref.read(bookmarksProvider.notifier).update(
            bookmarkId: bookmark.id,
            label: titleCtl.text,
            note: noteCtl.text,
          );
    }

    titleCtl.dispose();
    noteCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookBookmarksProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (bookmarks.isNotEmpty)
            IconButton(
              tooltip: 'Export',
              onPressed: () => _exportBookmarks(bookmarks),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          if (bookmarks.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => ref
                  .read(bookmarksProvider.notifier)
                  .clearForBook(widget.bookId),
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: bookmarks.isEmpty
          ? Center(
              child: Text(
                'No bookmarks yet.\nAdd one from Now Playing.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = bookmarks[index];
                final position = Duration(milliseconds: item.positionMs);
                final clipRange = item.isClip
                  ? '${DurationFormatter.format(Duration(milliseconds: item.clipStartMs!))} - ${DurationFormatter.format(Duration(milliseconds: item.clipEndMs!))}'
                  : null;

                return Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    onTap: () async {
                      await ref
                          .read(playerProvider.notifier)
                          .seekToPosition(position);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    leading: Icon(
                      item.isClip
                          ? Icons.content_cut_rounded
                          : Icons.bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      item.label ?? (item.isClip ? 'Clip ${index + 1}' : 'Bookmark ${index + 1}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.note == null || item.note!.isEmpty
                          ? (clipRange ?? DurationFormatter.format(position))
                          : '${clipRange ?? DurationFormatter.format(position)}\n${item.note}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(item);
                        }
                        if (value == 'delete') {
                          ref
                              .read(bookmarksProvider.notifier)
                              .remove(item.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
