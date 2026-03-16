import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';
import 'package:avdibook/shared/providers/bookmarks_provider.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookBookmarksProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (bookmarks.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => ref
                  .read(bookmarksProvider.notifier)
                  .clearForBook(bookId),
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
                      Icons.bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      item.label ?? 'Bookmark ${index + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DurationFormatter.format(position),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      onPressed: () =>
                          ref.read(bookmarksProvider.notifier).remove(item.id),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
