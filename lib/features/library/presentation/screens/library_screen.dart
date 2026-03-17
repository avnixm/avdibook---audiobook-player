import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/shared/providers/character_notes_provider.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/listening_analytics_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';

enum LibraryViewFilter {
  all,
  continueListening,
  recentPlayed,
  favorites,
  downloaded,
}

enum LibrarySortMode {
  recentAdded,
  recentPlayed,
  title,
  author,
  progress,
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  BookStatus? _statusFilter;
  LibraryViewFilter _viewFilter = LibraryViewFilter.all;
  LibrarySortMode _sortMode = LibrarySortMode.recentAdded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final analytics = ref.watch(listeningAnalyticsProvider);
    final charactersByBook = ref.watch(characterNotesProvider);
    final analyticsByBook = analytics.byBook;

    final sorted = [...library];

    final statusCounts = {
      BookStatus.newBook: 0,
      BookStatus.started: 0,
      BookStatus.finished: 0,
    };
    for (final book in sorted) {
      final listened = analyticsByBook[book.id]?.totalDuration ?? Duration.zero;
      final resolved = _resolveStatus(book, listened);
      statusCounts[resolved] = (statusCounts[resolved] ?? 0) + 1;
    }

    final filtered = sorted.where((book) {
      if (_statusFilter == null) return true;
      final listened = analyticsByBook[book.id]?.totalDuration ?? Duration.zero;
      return _resolveStatus(book, listened) == _statusFilter;
    }).where((book) {
      final listened = analyticsByBook[book.id]?.totalDuration ?? Duration.zero;
      switch (_viewFilter) {
        case LibraryViewFilter.all:
          return true;
        case LibraryViewFilter.continueListening:
          return (book.progress > 0 && book.progress < 0.98) ||
              (listened > Duration.zero && book.progress < 0.98);
        case LibraryViewFilter.recentPlayed:
          return analyticsByBook[book.id]?.lastPlayedAt != null ||
              book.lastPlayedAt != null;
        case LibraryViewFilter.favorites:
          return book.isFavorite;
        case LibraryViewFilter.downloaded:
          return book.sourcePaths.isNotEmpty;
      }
    }).toList()
      ..sort((a, b) {
        switch (_sortMode) {
          case LibrarySortMode.recentAdded:
            return b.importedAt.compareTo(a.importedAt);
          case LibrarySortMode.recentPlayed:
            final aPlayed = analyticsByBook[a.id]?.lastPlayedAt ?? a.lastPlayedAt;
            final bPlayed = analyticsByBook[b.id]?.lastPlayedAt ?? b.lastPlayedAt;
            if (aPlayed == null && bPlayed == null) return 0;
            if (aPlayed == null) return 1;
            if (bPlayed == null) return -1;
            return bPlayed.compareTo(aPlayed);
          case LibrarySortMode.title:
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          case LibrarySortMode.author:
            final aAuthor = (a.author?.name ?? '').toLowerCase();
            final bAuthor = (b.author?.name ?? '').toLowerCase();
            return aAuthor.compareTo(bAuthor);
          case LibrarySortMode.progress:
            return b.progress.compareTo(a.progress);
        }
      });

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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusCounterChip(
                          icon: Icons.library_books_rounded,
                          label: 'All',
                          count: sorted.length,
                          active: _viewFilter == LibraryViewFilter.all,
                          onTap: () => setState(() => _viewFilter = LibraryViewFilter.all),
                        ),
                        _StatusCounterChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Continue',
                          count: sorted
                              .where((book) => book.progress > 0 && book.progress < 0.98)
                              .length,
                          active: _viewFilter == LibraryViewFilter.continueListening,
                          onTap: () => setState(() =>
                              _viewFilter = LibraryViewFilter.continueListening),
                        ),
                        _StatusCounterChip(
                          icon: Icons.history_rounded,
                          label: 'Recent',
                          count: sorted
                              .where((book) =>
                                  analyticsByBook[book.id]?.lastPlayedAt != null ||
                                  book.lastPlayedAt != null)
                              .length,
                          active: _viewFilter == LibraryViewFilter.recentPlayed,
                          onTap: () => setState(() =>
                              _viewFilter = LibraryViewFilter.recentPlayed),
                        ),
                        _StatusCounterChip(
                          icon: Icons.star_rounded,
                          label: 'Favorites',
                          count: sorted.where((book) => book.isFavorite).length,
                          active: _viewFilter == LibraryViewFilter.favorites,
                          onTap: () =>
                              setState(() => _viewFilter = LibraryViewFilter.favorites),
                        ),
                        _StatusCounterChip(
                          icon: Icons.download_done_rounded,
                          label: 'Downloaded',
                          count: sorted.where((book) => book.sourcePaths.isNotEmpty).length,
                          active: _viewFilter == LibraryViewFilter.downloaded,
                          onTap: () =>
                              setState(() => _viewFilter = LibraryViewFilter.downloaded),
                        ),
                        _StatusCounterChip(
                          icon: Icons.fiber_new_rounded,
                          label: 'New',
                          count: statusCounts[BookStatus.newBook] ?? 0,
                          active: _statusFilter == BookStatus.newBook,
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == BookStatus.newBook
                                ? null
                                : BookStatus.newBook;
                          }),
                        ),
                        _StatusCounterChip(
                          icon: Icons.auto_stories_rounded,
                          label: 'Started',
                          count: statusCounts[BookStatus.started] ?? 0,
                          active: _statusFilter == BookStatus.started,
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == BookStatus.started
                                ? null
                                : BookStatus.started;
                          }),
                        ),
                        _StatusCounterChip(
                          icon: Icons.task_alt_rounded,
                          label: 'Finished',
                          count: statusCounts[BookStatus.finished] ?? 0,
                          active: _statusFilter == BookStatus.finished,
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == BookStatus.finished
                                ? null
                                : BookStatus.finished;
                          }),
                        ),
                      ],
                    ),
                    if (_statusFilter != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(() => _statusFilter = null),
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Clear filter'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Sort by',
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<LibrarySortMode>(
                          initialValue: _sortMode,
                          onSelected: (value) => setState(() => _sortMode = value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: LibrarySortMode.recentAdded,
                              child: Text('Recently added'),
                            ),
                            PopupMenuItem(
                              value: LibrarySortMode.recentPlayed,
                              child: Text('Recently played'),
                            ),
                            PopupMenuItem(
                              value: LibrarySortMode.title,
                              child: Text('Title'),
                            ),
                            PopupMenuItem(
                              value: LibrarySortMode.author,
                              child: Text('Author'),
                            ),
                            PopupMenuItem(
                              value: LibrarySortMode.progress,
                              child: Text('Progress'),
                            ),
                          ],
                          child: Chip(
                            label: Text(
                              switch (_sortMode) {
                                LibrarySortMode.recentAdded => 'Recently added',
                                LibrarySortMode.recentPlayed => 'Recently played',
                                LibrarySortMode.title => 'Title',
                                LibrarySortMode.author => 'Author',
                                LibrarySortMode.progress => 'Progress',
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (sorted.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'No books in this category yet.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemBuilder: (context, index) {
                        final book = filtered[index];
                        final stats = analytics.byBook[book.id];
                        final listened = stats?.totalDuration ?? Duration.zero;
                        return _LibraryBookTile(
                          book: book,
                          listened: listened,
                          status: _resolveStatus(book, listened),
                          characterCount:
                              charactersByBook[book.id]?.length ?? 0,
                          onOpen: () =>
                              context.push(AppRoutes.playerPath(book.id)),
                          onManageCharacters: () =>
                              _showCharactersSheet(context, ref, book),
                            onToggleFavorite: () =>
                              _toggleFavorite(context, ref, book),
                          onRemove: () => _removeBook(context, ref, book),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemCount: filtered.length,
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCharactersSheet(
    BuildContext context,
    WidgetRef ref,
    Audiobook book,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, modalRef, _) {
            final items = modalRef.watch(bookCharactersProvider(book.id));
            final tt = Theme.of(context).textTheme;
            final cs = Theme.of(context).colorScheme;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Characters',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showCharacterEditor(
                          context: ctx,
                          ref: modalRef,
                          bookId: book.id,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track who is who in "${book.title}".',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        'No characters yet. Add the first one.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Material(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              title: Text(item.name),
                              subtitle: Text(
                                [if (item.role != null) item.role!, if (item.note != null) item.note!]
                                    .join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showCharacterEditor(
                                      context: ctx,
                                      ref: modalRef,
                                      bookId: book.id,
                                      existing: item,
                                    );
                                  }
                                  if (value == 'delete') {
                                    modalRef
                                        .read(characterNotesProvider.notifier)
                                        .remove(bookId: book.id, id: item.id);
                                  }
                                },
                                itemBuilder: (_) => const [
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
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCharacterEditor({
    required BuildContext context,
    required WidgetRef ref,
    required String bookId,
    BookCharacter? existing,
  }) async {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final roleCtl = TextEditingController(text: existing?.role ?? '');
    final noteCtl = TextEditingController(text: existing?.note ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? 'Add character' : 'Edit character'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleCtl,
                  decoration: const InputDecoration(
                    labelText: 'Role (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
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
      final name = nameCtl.text.trim();
      if (name.isNotEmpty) {
        final notifier = ref.read(characterNotesProvider.notifier);
        if (existing == null) {
          await notifier.add(
            bookId: bookId,
            name: name,
            role: roleCtl.text,
            note: noteCtl.text,
          );
        } else {
          await notifier.update(
            bookId: bookId,
            id: existing.id,
            name: name,
            role: roleCtl.text,
            note: noteCtl.text,
          );
        }
      }
    }

    nameCtl.dispose();
    roleCtl.dispose();
    noteCtl.dispose();
  }

  BookStatus _resolveStatus(Audiobook book, Duration listened) {
    if (book.status != BookStatus.newBook) return book.status;
    if (book.progress >= 0.98) return BookStatus.finished;
    if (book.progress > 0.01 || listened > Duration.zero) {
      return BookStatus.started;
    }
    return BookStatus.newBook;
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

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    Audiobook book,
  ) async {
    final existing = ref.read(libraryProvider);
    final index = existing.indexWhere((b) => b.id == book.id);
    if (index < 0) return;

    final next = [...existing];
    next[index] = next[index].copyWith(isFavorite: !next[index].isFavorite);

    ref.read(libraryProvider.notifier).setLibrary(next);
    await ref.read(startupStorageServiceProvider).setLibraryItems(next);
  }
}

class _LibraryBookTile extends StatelessWidget {
  const _LibraryBookTile({
    required this.book,
    required this.listened,
    required this.status,
    required this.characterCount,
    required this.onOpen,
    required this.onManageCharacters,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final Audiobook book;
  final Duration listened;
  final BookStatus status;
  final int characterCount;
  final VoidCallback onOpen;
  final VoidCallback onManageCharacters;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progressPercent = (book.progress.clamp(0.0, 1.0) * 100).round();

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
                          _StatusBadge(status: status),
                          _MetaPill(
                            icon: Icons.menu_book_rounded,
                            label: '${book.chapterCount} chapters',
                          ),
                          if (progressPercent > 0)
                            _MetaPill(
                              icon: Icons.timelapse_rounded,
                              label: '$progressPercent% complete',
                            ),
                          _MetaPill(
                            icon: Icons.graphic_eq_rounded,
                            label:
                                'Listened ${DurationFormatter.formatHuman(listened)}',
                          ),
                          if (characterCount > 0)
                            _MetaPill(
                              icon: Icons.groups_rounded,
                              label: '$characterCount characters',
                            ),
                          if (book.isFavorite)
                            _MetaPill(
                              icon: Icons.star_rounded,
                              label: 'Favorite',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'open') onOpen();
                    if (value == 'characters') onManageCharacters();
                    if (value == 'favorite') onToggleFavorite();
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Text('Open player'),
                    ),
                    PopupMenuItem(
                      value: 'characters',
                      child: Text('Manage characters'),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(book.isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites'),
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

class _StatusCounterChip extends StatelessWidget {
  const _StatusCounterChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ExpressiveBounce(
      child: ChoiceChip(
        selected: active,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, size: 16),
        label: Text('$label ($count)'),
        selectedColor: cs.secondaryContainer,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (icon, bg, fg) = switch (status) {
      BookStatus.newBook => (
          Icons.fiber_new_rounded,
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
        ),
      BookStatus.started => (
          Icons.auto_stories_rounded,
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      BookStatus.finished => (
          Icons.task_alt_rounded,
          cs.secondaryContainer,
          cs.onSecondaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
