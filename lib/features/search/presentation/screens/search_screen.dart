import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/listening_analytics_provider.dart';

enum SearchSortMode { relevance, recentPlayed, recentAdded, title, author }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  SearchSortMode _sortMode = SearchSortMode.relevance;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final analytics = ref.watch(listeningAnalyticsProvider).byBook;
    final query = _queryController.text.trim().toLowerCase();

    final results = [...library]
      ..sort((a, b) {
        if (_sortMode == SearchSortMode.recentAdded) {
          return b.importedAt.compareTo(a.importedAt);
        }
        if (_sortMode == SearchSortMode.recentPlayed) {
          final aPlayed = analytics[a.id]?.lastPlayedAt ?? a.lastPlayedAt;
          final bPlayed = analytics[b.id]?.lastPlayedAt ?? b.lastPlayedAt;
          if (aPlayed == null && bPlayed == null) return 0;
          if (aPlayed == null) return 1;
          if (bPlayed == null) return -1;
          return bPlayed.compareTo(aPlayed);
        }
        if (_sortMode == SearchSortMode.title) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        if (_sortMode == SearchSortMode.author) {
          final aAuthor = (a.author?.name ?? '').toLowerCase();
          final bAuthor = (b.author?.name ?? '').toLowerCase();
          return aAuthor.compareTo(bAuthor);
        }

        final aScore = _score(a, query);
        final bScore = _score(b, query);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return b.importedAt.compareTo(a.importedAt);
      });

    final filtered = query.isEmpty
        ? results
        : results.where((book) => _score(book, query) > 0).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Search'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SearchBar(
                  controller: _queryController,
                  onChanged: (_) => setState(() {}),
                  hintText: 'Search books, authors, narrators...',
                  leading: Icon(Icons.search_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  trailing: query.isEmpty
                      ? null
                      : [
                          IconButton(
                            onPressed: () {
                              _queryController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor:
                      WidgetStatePropertyAll(cs.surfaceContainerHighest),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<SearchSortMode>(
                      initialValue: _sortMode,
                      onSelected: (value) => setState(() => _sortMode = value),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: SearchSortMode.relevance,
                          child: Text('Relevance'),
                        ),
                        PopupMenuItem(
                          value: SearchSortMode.recentPlayed,
                          child: Text('Recently played'),
                        ),
                        PopupMenuItem(
                          value: SearchSortMode.recentAdded,
                          child: Text('Recently added'),
                        ),
                        PopupMenuItem(
                          value: SearchSortMode.title,
                          child: Text('Title'),
                        ),
                        PopupMenuItem(
                          value: SearchSortMode.author,
                          child: Text('Author'),
                        ),
                      ],
                      child: Chip(
                        label: Text(
                          switch (_sortMode) {
                            SearchSortMode.relevance => 'Relevance',
                            SearchSortMode.recentPlayed => 'Recently played',
                            SearchSortMode.recentAdded => 'Recently added',
                            SearchSortMode.title => 'Title',
                            SearchSortMode.author => 'Author',
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      query.isEmpty
                          ? 'Start typing to search your library.'
                          : 'No books match your search yet.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (book) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          onTap: () => context.push(AppRoutes.playerPath(book.id)),
                          leading: Icon(
                            book.isFavorite
                                ? Icons.star_rounded
                                : Icons.menu_book_rounded,
                          ),
                          title: Text(book.title),
                          subtitle: Text(
                            [
                              book.author?.name ?? 'Unknown author',
                              '${book.chapterCount} chapters',
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  int _score(Audiobook book, String query) {
    if (query.isEmpty) return 1;

    var score = 0;
    final title = book.title.toLowerCase();
    final author = (book.author?.name ?? '').toLowerCase();
    final narrator = (book.narrator ?? '').toLowerCase();
    final series = (book.series ?? '').toLowerCase();
    final genre = (book.genre ?? '').toLowerCase();

    if (title == query) score += 100;
    if (title.startsWith(query)) score += 70;
    if (title.contains(query)) score += 40;
    if (author.startsWith(query)) score += 30;
    if (author.contains(query)) score += 20;
    if (narrator.contains(query)) score += 12;
    if (series.contains(query)) score += 10;
    if (genre.contains(query)) score += 8;

    return score;
  }
}
