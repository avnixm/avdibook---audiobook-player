import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avdibook/app/theme/app_colors.dart';
import 'package:avdibook/app/theme/app_spacing.dart';
import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/features/player/presentation/providers/cover_palette_provider.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';
import 'package:avdibook/features/player/presentation/providers/sleep_timer_provider.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_author.dart';
import 'package:avdibook/features/setup/presentation/providers/setup_controller.dart';
import 'package:avdibook/shared/providers/bookmarks_provider.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _startShakeListener();
    final library = ref.read(libraryProvider);
    final matching = library.where((b) => b.id == widget.bookId);
    if (matching.isNotEmpty) {
      final book = matching.first;
      ref.read(playerProvider.notifier).load(book);
      unawaited(_backfillMetadataIfNeeded(book));
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _startShakeListener() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      if (magnitude < 21) return;
      if (now.difference(_lastShakeAt) < const Duration(milliseconds: 1300)) {
        return;
      }
      _lastShakeAt = now;

      final timerState = ref.read(sleepTimerProvider);
      if (!timerState.resumeArmed) return;

      ref.read(sleepTimerProvider.notifier).resumeFromShake();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback resumed after shake.')),
      );
    });
  }

  Future<void> _showSleepTimerSheet(SleepTimerState timerState) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Sleep timer'),
              subtitle: Text('Pause automatically after a delay.'),
            ),
            for (final mins in AppDefaults.sleepTimerOptions)
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text('$mins minutes'),
                onTap: () => Navigator.of(ctx).pop(mins),
              ),
            ListTile(
              leading: Icon(
                timerState.endOfChapterArmed
                    ? Icons.bookmark_added_rounded
                    : Icons.bookmark_add_outlined,
              ),
              title: const Text('End of current chapter'),
              onTap: () => Navigator.of(ctx).pop(-2),
            ),
            if (timerState.remaining != null || timerState.resumeArmed)
              ListTile(
                leading: const Icon(Icons.timer_off_rounded),
                title: const Text('Turn off timer'),
                onTap: () => Navigator.of(ctx).pop(0),
              ),
          ],
        );
      },
    );

    if (selected == null) return;
    final notifier = ref.read(sleepTimerProvider.notifier);
    if (selected == -2) {
      notifier.toggleEndOfChapter();
      return;
    }
    if (selected <= 0) {
      notifier.cancel();
      return;
    }
    notifier.start(Duration(minutes: selected));
  }

  String _sleepTimerLabel(SleepTimerState timerState) {
    if (timerState.resumeArmed) return 'Shake';
    if (timerState.endOfChapterArmed) return 'EoC';
    final remaining = timerState.remaining;
    if (remaining == null) return 'Sleep';

    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    return '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _backfillMetadataIfNeeded(Audiobook book) async {
    final missingAuthor =
        book.author == null || book.author!.name.trim().isEmpty;
    var missingCover = book.coverPath == null;
    if (!missingCover && book.coverPath != null) {
      missingCover = !await File(book.coverPath!).exists();
    }
    if (!missingAuthor && !missingCover) return;

    final extracted = await ref
        .read(audioMetadataServiceProvider)
        .readFromPaths(book.sourcePaths);
    if (extracted == null || !extracted.hasAnyValue) return;

    final updated = book.copyWith(
      title: extracted.title ?? book.title,
      author: extracted.author == null
          ? book.author
          : AudiobookAuthor(name: extracted.author!),
      coverPath: extracted.coverPath ?? book.coverPath,
      genre: extracted.genre ?? book.genre,
    );
    if (updated == book) return;

    final library = ref.read(libraryProvider);
    final index = library.indexWhere((b) => b.id == widget.bookId);
    if (index < 0) return;

    final merged = [...library];
    merged[index] = updated;
    ref.read(libraryProvider.notifier).setLibrary(merged);
    await ref.read(startupStorageServiceProvider).setLibraryItems(merged);
  }

  Future<void> _showVolumeSheet(double currentVolume) async {
    var temp = currentVolume;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        temp == 0
                            ? Icons.volume_off_rounded
                            : temp < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Slider(
                          value: temp,
                          onChanged: (v) {
                            setLocal(() => temp = v);
                            ref.read(playerProvider.notifier).setVolume(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(temp * 100).round()}%'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddBookmarkSheet({
    required String bookId,
    required Duration position,
  }) async {
    final titleCtl = TextEditingController(
      text: 'At ${DurationFormatter.format(position)}',
    );
    final noteCtl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'Bookmark title'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await ref
          .read(bookmarksProvider.notifier)
          .add(
            bookId: bookId,
            position: position,
            label: titleCtl.text,
            note: noteCtl.text,
          );
      if (!mounted) return;
      context.push(AppRoutes.bookmarksPath(bookId));
    }

    titleCtl.dispose();
    noteCtl.dispose();
  }

  Future<void> _addQuickClip({
    required String bookId,
    required Duration position,
    required Duration chapterDuration,
  }) async {
    final start = position - const Duration(seconds: 15);
    final boundedStart = start < Duration.zero ? Duration.zero : start;
    final end = position + const Duration(seconds: 15);
    final boundedEnd = chapterDuration > Duration.zero && end > chapterDuration
        ? chapterDuration
        : end;

    await ref
        .read(bookmarksProvider.notifier)
        .addClip(
          bookId: bookId,
          start: boundedStart,
          end: boundedEnd,
          label:
              'Clip ${DurationFormatter.format(boundedStart)} - ${DurationFormatter.format(boundedEnd)}',
        );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Clip saved to bookmarks.')));
  }

  Future<void> _toggleFavoriteForBook(Audiobook book) async {
    final library = ref.read(libraryProvider);
    final index = library.indexWhere((b) => b.id == book.id);
    if (index < 0) return;

    final next = [...library];
    next[index] = next[index].copyWith(isFavorite: !next[index].isFavorite);

    ref.read(libraryProvider.notifier).setLibrary(next);
    await ref.read(startupStorageServiceProvider).setLibraryItems(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final playerState = ref.watch(playerProvider);
    final paletteAsync = ref.watch(coverPaletteProvider(widget.bookId));
    final paletteColor = paletteAsync.value;
    final sleepTimer = ref.watch(sleepTimerProvider);

    ref.listen<int>(playerProvider.select((s) => s.currentChapterIndex), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) return;
      final timerState = ref.read(sleepTimerProvider);
      if (!timerState.endOfChapterArmed) return;

      ref.read(playerProvider.notifier).pause();
      ref.read(sleepTimerProvider.notifier).clearEndOfChapter();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paused at chapter end.')));
    });

    final matching = library.where((b) => b.id == widget.bookId);
    final book = matching.isEmpty ? null : matching.first;
    final useCompanionPane =
        MediaQuery.sizeOf(context).width >= AppSpacing.mediumMaxWidth;
    final bookmarks = book == null
        ? const <Bookmark>[]
        : ref.watch(bookBookmarksProvider(book.id));

    final title = book?.title ?? 'Now Playing';
    final author = book?.author?.name ?? 'Unknown author';
    final targetAccentColor = paletteColor ?? scheme.primary;
    final accentColor = Color.lerp(
          scheme.primary,
          targetAccentColor,
          paletteAsync.isLoading ? 0.45 : 1,
        ) ??
        targetAccentColor;
    final onAccent = accentColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    final positionLabel = DurationFormatter.format(playerState.position);
    final totalLabel = DurationFormatter.format(playerState.duration);

    final mainPlayerContent = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundedIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        scheme: scheme,
                        semanticsLabel: 'Close player',
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Now Playing',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _RoundedIconButton(
                        icon: Icons.volume_up_rounded,
                        scheme: scheme,
                        semanticsLabel: 'Volume controls',
                        onTap: () => _showVolumeSheet(playerState.volume),
                      ),
                      const SizedBox(width: 8),
                      _RoundedIconButton(
                        icon: Icons.playlist_play_rounded,
                        scheme: scheme,
                        semanticsLabel: 'Open chapter list',
                        onTap: book != null
                            ? () => context.push(
                                AppRoutes.chapterListPath(book.id),
                              )
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _CoverArea(
                              coverPath: book?.coverPath,
                              accentColor: accentColor,
                              scheme: scheme,
                              chapterLabel: '',
                              textTheme: text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 40,
                          height: 160,
                          child: _CoverFallback(
                            accentColor: accentColor,
                            scheme: scheme,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(
                                color: AppColors.subtle(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RoundedIconButton(
                        icon: Icons.playlist_add_check_rounded,
                        scheme: scheme,
                        semanticsLabel: 'Add bookmark',
                        onTap: book == null
                            ? null
                            : () => _showAddBookmarkSheet(
                                bookId: book.id,
                                position: playerState.position,
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor,
                      thumbColor: accentColor,
                      inactiveTrackColor: scheme.outlineVariant.withValues(
                        alpha: 0.45,
                      ),
                      overlayColor: accentColor.withValues(alpha: 0.08),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                    ),
                    child: Slider(
                      value: playerState.progress,
                      onChanged: (v) =>
                          ref.read(playerProvider.notifier).seekTo(v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          positionLabel,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.subtle(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          totalLabel,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.subtle(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SideTransportButton(
                        icon: Icons.skip_previous_rounded,
                        scheme: scheme,
                        accentColor: accentColor,
                        semanticsLabel: 'Previous chapter',
                        onTap: () =>
                            ref.read(playerProvider.notifier).previousChapter(),
                      ),
                      const SizedBox(width: 16),
                      _PlayPauseButton(
                        isPlaying: playerState.isPlaying,
                        isLoading: playerState.isLoading,
                        accentColor: accentColor,
                        onAccent: onAccent,
                        semanticsLabel: playerState.isPlaying
                            ? 'Pause'
                            : 'Play',
                        onTap: () =>
                            ref.read(playerProvider.notifier).togglePlay(),
                      ),
                      const SizedBox(width: 16),
                      _SideTransportButton(
                        icon: Icons.skip_next_rounded,
                        scheme: scheme,
                        accentColor: accentColor,
                        semanticsLabel: 'Next chapter',
                        onTap: () =>
                            ref.read(playerProvider.notifier).nextChapter(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniActionButton(
                            icon: Icons.shuffle_rounded,
                            active: playerState.shuffleEnabled,
                            scheme: scheme,
                            accentColor: accentColor,
                            onTap: () => ref
                                .read(playerProvider.notifier)
                                .toggleShuffle(),
                          ),
                        ),
                        Expanded(
                          child: _MiniActionButton(
                            icon: switch (playerState.loopMode) {
                              LoopMode.off => Icons.sync_alt_rounded,
                              LoopMode.all => Icons.repeat_rounded,
                              LoopMode.one => Icons.repeat_one_rounded,
                            },
                            active: playerState.loopMode != LoopMode.off,
                            scheme: scheme,
                            accentColor: accentColor,
                            onTap: () => ref
                                .read(playerProvider.notifier)
                                .cycleLoopMode(),
                          ),
                        ),
                        Expanded(
                          child: _MiniActionButton(
                            icon: book?.isFavorite == true
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            active: book?.isFavorite == true,
                            scheme: scheme,
                            accentColor: accentColor,
                            onTap: book == null
                                ? null
                                : () => _toggleFavoriteForBook(book),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showSleepTimerSheet(sleepTimer),
                        icon: Icon(
                          sleepTimer.resumeArmed
                              ? Icons.vibration_rounded
                              : Icons.bedtime_rounded,
                        ),
                        label: Text(_sleepTimerLabel(sleepTimer)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final selected = await showDialog<double>(
                            context: context,
                            builder: (ctx) => SimpleDialog(
                              title: const Text('Playback Speed'),
                              children: AppDefaults.speedOptions.map((v) {
                                final isSelected = v == playerState.speed;
                                return SimpleDialogOption(
                                  onPressed: () => Navigator.of(ctx).pop(v),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${v % 1 == 0 ? v.toInt() : v}×',
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Theme.of(
                                            ctx,
                                          ).colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                          if (selected != null) {
                            ref
                                .read(playerProvider.notifier)
                                .setSpeed(selected);
                          }
                        },
                        icon: const Icon(Icons.speed_rounded),
                        label: Text(
                          '${playerState.speed % 1 == 0 ? playerState.speed.toInt() : playerState.speed}×',
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: book == null
                            ? null
                            : () => _addQuickClip(
                                bookId: book.id,
                                position: playerState.position,
                                chapterDuration: playerState.duration,
                              ),
                        icon: const Icon(Icons.content_cut_rounded),
                        label: const Text('Clip'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      body: useCompanionPane && book != null
          ? Row(
              children: [
                Expanded(flex: 7, child: mainPlayerContent),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _PlayerCompanionPane(
                    book: book,
                    currentChapterIndex: playerState.currentChapterIndex,
                    bookmarks: bookmarks,
                    onChapterTap: (index) {
                      ref
                          .read(playerProvider.notifier)
                          .seekToChapterIndex(index);
                    },
                    onBookmarkTap: (bookmark) {
                      ref
                          .read(playerProvider.notifier)
                          .seekToPosition(
                            Duration(milliseconds: bookmark.positionMs),
                          );
                    },
                    onOpenChaptersRoute: () =>
                        context.push(AppRoutes.chapterListPath(book.id)),
                    onOpenBookmarksRoute: () =>
                        context.push(AppRoutes.bookmarksPath(book.id)),
                  ),
                ),
              ],
            )
          : mainPlayerContent,
    );
  }
}

class _PlayerCompanionPane extends StatelessWidget {
  const _PlayerCompanionPane({
    required this.book,
    required this.currentChapterIndex,
    required this.bookmarks,
    required this.onChapterTap,
    required this.onBookmarkTap,
    required this.onOpenChaptersRoute,
    required this.onOpenBookmarksRoute,
  });

  final Audiobook book;
  final int currentChapterIndex;
  final List<Bookmark> bookmarks;
  final ValueChanged<int> onChapterTap;
  final ValueChanged<Bookmark> onBookmarkTap;
  final VoidCallback onOpenChaptersRoute;
  final VoidCallback onOpenBookmarksRoute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chapters = [...book.chapters]
      ..sort((a, b) => a.index.compareTo(b.index));
    final topBookmarks = bookmarks.take(10).toList();

    return SafeArea(
      left: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 20, 24),
        child: Card(
          color: cs.surfaceContainerLow,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 10),
                TabBar(
                  tabs: [
                    Tab(text: 'Chapters (${chapters.length})'),
                    Tab(text: 'Bookmarks (${bookmarks.length})'),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(10),
                              itemCount: chapters.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final chapter = chapters[index];
                                final isActive =
                                    chapter.index == currentChapterIndex;
                                return Material(
                                  color: isActive
                                      ? cs.secondaryContainer
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    dense: true,
                                    onTap: () => onChapterTap(chapter.index),
                                    leading: Icon(
                                      isActive
                                          ? Icons.play_circle_rounded
                                          : Icons.menu_book_rounded,
                                    ),
                                    title: Text(
                                      chapter.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Chapter ${chapter.index + 1}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: OutlinedButton.icon(
                              onPressed: onOpenChaptersRoute,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open full chapter list'),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Expanded(
                            child: topBookmarks.isEmpty
                                ? Center(
                                    child: Text(
                                      'No bookmarks yet',
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(10),
                                    itemCount: topBookmarks.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final bookmark = topBookmarks[index];
                                      final ms = bookmark.positionMs;
                                      return Material(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ListTile(
                                          dense: true,
                                          onTap: () => onBookmarkTap(bookmark),
                                          leading: Icon(
                                            bookmark.isClip
                                                ? Icons.content_cut_rounded
                                                : Icons.bookmark_rounded,
                                          ),
                                          title: Text(
                                            bookmark.label ??
                                                'At ${DurationFormatter.format(Duration(milliseconds: ms))}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            DurationFormatter.format(
                                              Duration(milliseconds: ms),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: OutlinedButton.icon(
                              onPressed: onOpenBookmarksRoute,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open full bookmarks'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cover area ────────────────────────────────────────────────────────────────

class _CoverArea extends StatelessWidget {
  const _CoverArea({
    required this.coverPath,
    required this.accentColor,
    required this.scheme,
    required this.chapterLabel,
    required this.textTheme,
  });

  final String? coverPath;
  final Color accentColor;
  final ColorScheme scheme;
  final String chapterLabel;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final imagePath = coverPath;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image or gradient placeholder
        if (imagePath != null)
          Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _CoverFallback(accentColor: accentColor, scheme: scheme),
          )
        else
          _CoverFallback(accentColor: accentColor, scheme: scheme),

        if (chapterLabel.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 52, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  chapterLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.accentColor, required this.scheme});

  final Color accentColor;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(accentColor, Colors.black, 0.2)!,
            Color.lerp(accentColor, scheme.secondaryContainer, 0.55)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.headphones_rounded,
        size: 80,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }
}

// ── Rounded icon button (header) ──────────────────────────────────────────────

class _RoundedIconButton extends StatelessWidget {
  const _RoundedIconButton({
    required this.icon,
    required this.scheme,
    this.semanticsLabel,
    this.onTap,
  });

  final IconData icon;
  final ColorScheme scheme;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = scheme.onSurfaceVariant;
    final background = scheme.surfaceContainerHighest;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ExpressiveBounce(
        enabled: onTap != null,
        child: IconButton.filledTonal(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

// ── Side transport button (replay / forward) ───────────────────────────────────

class _SideTransportButton extends StatelessWidget {
  const _SideTransportButton({
    required this.icon,
    required this.scheme,
    required this.accentColor,
    required this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  final ColorScheme scheme;
  final Color accentColor;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = scheme.onSurfaceVariant;
    final background = Color.lerp(
          scheme.surfaceContainerHighest,
          accentColor,
          0.12,
        ) ??
        scheme.surfaceContainerHighest;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ExpressiveBounce(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, size: 20, color: foreground)],
          ),
        ),
        ),
      ),
    );
  }
}

// ── Play / pause main button ──────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.accentColor,
    required this.onAccent,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accentColor;
  final Color onAccent;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ExpressiveBounce(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: accentColor),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, animatedColor, child) {
            final effective = animatedColor ?? accentColor;
            return FloatingActionButton.large(
              onPressed: onTap,
              backgroundColor: effective,
              foregroundColor: onAccent,
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(onAccent),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey<bool>(isPlaying),
                        size: 34,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

// ── Mini action button ────────────────────────────────────────────────────────

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.active,
    required this.scheme,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final ColorScheme scheme;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: IconButton.filledTonal(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? accentColor.withValues(alpha: 0.16)
              : scheme.surfaceContainer,
          foregroundColor: active ? accentColor : scheme.onSurfaceVariant,
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
