import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/shared/providers/app_bootstrap_provider.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/listening_analytics_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final analytics = ref.watch(listeningAnalyticsProvider);

    final sorted = [...library]
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Library'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
          ),
          if (sorted.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      size: 56,
                      color: cs.onSurface.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No books yet',
                      style: tt.titleLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Import from Home to build your audiobook library.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemBuilder: (context, index) {
                  final book = sorted[index];
                  final stats = analytics.byBook[book.id];
                  return _LibraryBookTile(
                    book: book,
                    listened: stats?.totalDuration ?? Duration.zero,
                    onOpen: () => context.push(AppRoutes.playerPath(book.id)),
                    onRemove: () => _removeBook(context, ref, book),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: sorted.length,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _removeBook(
    BuildContext context,
    WidgetRef ref,
    Audiobook book,
  ) async {
    final existing = ref.read(libraryProvider);
    final next = existing.where((b) => b.id != book.id).toList();

    ref.read(libraryProvider.notifier).setLibrary(next);
    await ref.read(startupStorageServiceProvider).setLibraryItems(next);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${book.title}" from library.')),
      );
    }
  }
}

class _LibraryBookTile extends StatelessWidget {
  const _LibraryBookTile({
    required this.book,
    required this.listened,
    required this.onOpen,
    required this.onRemove,
  });

  final Audiobook book;
  final Duration listened;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: ExpressiveBounce(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _BookCover(coverPath: book.coverPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author?.name ?? 'Unknown author',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            icon: Icons.menu_book_rounded,
                            label: '${book.chapterCount} chapters',
                          ),
                          _MetaPill(
                            icon: Icons.graphic_eq_rounded,
                            label:
                                'Listened ${DurationFormatter.formatHuman(listened)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'open') onOpen();
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'open',
                      child: Text('Open player'),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from library'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = coverPath != null && File(coverPath!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 70,
        height: 96,
        child: hasImage
            ? Image.file(File(coverPath!), fit: BoxFit.cover)
            : Container(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: cs.primary,
                  size: 26,
                ),
              ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
