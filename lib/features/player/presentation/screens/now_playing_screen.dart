import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avdibook/app/theme/app_colors.dart';
import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/features/player/presentation/providers/cover_palette_provider.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';
import 'package:avdibook/features/player/presentation/providers/sleep_timer_provider.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_author.dart';
import 'package:avdibook/features/setup/presentation/providers/setup_controller.dart';
import 'package:avdibook/shared/providers/app_state_provider.dart';
import 'package:avdibook/shared/providers/app_bootstrap_provider.dart';
import 'package:avdibook/shared/providers/bookmarks_provider.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = ref.read(libraryProvider);
      final matching = library.where((b) => b.id == widget.bookId);
      if (matching.isNotEmpty) {
        final book = matching.first;
        ref.read(playerProvider.notifier).load(book);
        _backfillMetadataIfNeeded(book);
      }
    });
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
    if (selected <= 0) {
      notifier.cancel();
      return;
    }
    notifier.start(Duration(minutes: selected));
  }

  String _sleepTimerLabel(SleepTimerState timerState) {
    if (timerState.resumeArmed) return 'Shake';
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
                decoration: const InputDecoration(
                  labelText: 'Bookmark title',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
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
      await ref.read(bookmarksProvider.notifier).add(
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final playerState = ref.watch(playerProvider);
    final paletteAsync = ref.watch(coverPaletteProvider(widget.bookId));
    final paletteColor = paletteAsync.value;
    final skipFwd = ref.watch(skipForwardSecsProvider);
    final skipBwd = ref.watch(skipBackwardSecsProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    final matching = library.where((b) => b.id == widget.bookId);
    final book = matching.isEmpty ? null : matching.first;

    final title = book?.title ?? 'Now Playing';
    final author = book?.author?.name ?? 'Unknown author';
    final chapterLabel = book == null
        ? 'No chapters imported'
        : '${book.chapterCount} chapter(s) • ${book.primaryFormat.toUpperCase()}';

    final accentColor = paletteColor ?? scheme.primary;
    final onAccent =
        accentColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    final remaining =
        playerState.duration - playerState.position;
    final positionLabel = DurationFormatter.format(playerState.position);
    final remainingLabel =
        '-${DurationFormatter.format(remaining > Duration.zero ? remaining : Duration.zero)}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  _RoundedIconButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    scheme: scheme,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Now Playing',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _RoundedIconButton(
                    icon: Icons.volume_up_rounded,
                    scheme: scheme,
                    onTap: () => _showVolumeSheet(playerState.volume),
                  ),
                  const SizedBox(width: 8),
                  _RoundedIconButton(
                    icon: Icons.playlist_play_rounded,
                    scheme: scheme,
                    onTap: book != null
                        ? () =>
                            context.push(AppRoutes.chapterListPath(book.id))
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Cover art ─────────────────────────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: _CoverArea(
                    coverPath: book?.coverPath,
                    accentColor: accentColor,
                    scheme: scheme,
                    chapterLabel: chapterLabel,
                    textTheme: text,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Book info ─────────────────────────────────────────────────
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
                          style: text.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
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
                  const SizedBox(width: 12),
                  _RoundedIconButton(
                    icon: Icons.playlist_add_check_rounded,
                    scheme: scheme,
                    onTap: book == null
                        ? null
                        : () => _showAddBookmarkSheet(
                              bookId: book.id,
                              position: playerState.position,
                            ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Progress slider ───────────────────────────────────────────
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accentColor,
                  thumbColor: accentColor,
                  inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                  overlayColor: accentColor.withValues(alpha: 0.1),
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.subtle(context)),
                    ),
                    const Spacer(),
                    Text(
                      remainingLabel,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.subtle(context)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Transport controls (M3 Expressive size contrast) ──────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SideTransportButton(
                    icon: Icons.replay_rounded,
                    label: '${skipBwd}s',
                    scheme: scheme,
                    onTap: () =>
                        ref.read(playerProvider.notifier).skipBackward(skipBwd),
                  ),
                  const SizedBox(width: 16),
                  _PlayPauseButton(
                    isPlaying: playerState.isPlaying,
                    isLoading: playerState.isLoading,
                    accentColor: accentColor,
                    onAccent: onAccent,
                    onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                  ),
                  const SizedBox(width: 16),
                  _SideTransportButton(
                    icon: Icons.forward_rounded,
                    label: '${skipFwd}s',
                    scheme: scheme,
                    onTap: () =>
                        ref.read(playerProvider.notifier).skipForward(skipFwd),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Mini actions ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniActionButton(
                        icon: Icons.history_rounded,
                        label: 'Undo',
                        active: playerState.previousPosition != null,
                        scheme: scheme,
                        accentColor: accentColor,
                        onTap: playerState.previousPosition == null
                            ? null
                            : () => ref
                                .read(playerProvider.notifier)
                                .undoLastJump(),
                      ),
                    ),
                    Expanded(
                      child: _MiniActionButton(
                        icon: Icons.shuffle_rounded,
                        active: playerState.shuffleEnabled,
                        scheme: scheme,
                        accentColor: accentColor,
                        onTap: () =>
                            ref.read(playerProvider.notifier).toggleShuffle(),
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
                        onTap: () =>
                            ref.read(playerProvider.notifier).cycleLoopMode(),
                      ),
                    ),
                    Expanded(
                      child: _MiniActionButton(
                        icon: Icons.speed_rounded,
                        label:
                            '${playerState.speed % 1 == 0 ? playerState.speed.toInt() : playerState.speed}×',
                        active: playerState.speed != 1.0,
                        scheme: scheme,
                        accentColor: accentColor,
                        onTap: () async {
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
                                            '${v % 1 == 0 ? v.toInt() : v}×'),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_rounded,
                                            size: 18,
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .primary),
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
                      ),
                    ),
                    Expanded(
                      child: _MiniActionButton(
                        icon: sleepTimer.resumeArmed
                            ? Icons.vibration_rounded
                            : Icons.bedtime_rounded,
                        label: _sleepTimerLabel(sleepTimer),
                        active: sleepTimer.remaining != null ||
                            sleepTimer.resumeArmed,
                        scheme: scheme,
                        accentColor: accentColor,
                        onTap: () => _showSleepTimerSheet(sleepTimer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            errorBuilder: (_, __, ___) => _CoverFallback(
              accentColor: accentColor,
              scheme: scheme,
            ),
          )
        else
          _CoverFallback(
            accentColor: accentColor,
            scheme: scheme,
          ),

        // Bottom scrim + chapter label
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
  const _CoverFallback({
    required this.accentColor,
    required this.scheme,
  });

  final Color accentColor;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    this.onTap,
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: ExpressiveBounce(
        enabled: onTap != null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: scheme.onSurface, size: 22),
          ),
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
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: ExpressiveBounce(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: scheme.onSurface),
                if (label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
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
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accentColor;
  final Color onAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: accentColor.withValues(alpha: 0.45),
      child: ExpressiveBounce(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(onAccent),
                      ),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: onAccent,
                    size: 34,
                  ),
          ),
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
    this.label,
  });

  final IconData icon;
  final bool active;
  final ColorScheme scheme;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bg =
        active ? accentColor.withValues(alpha: 0.15) : Colors.transparent;
    final fg = active ? accentColor : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: ExpressiveBounce(
        enabled: onTap != null,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: label != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: fg, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        label!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  )
                : Icon(icon, color: fg, size: 20),
          ),
        ),
      ),
    );
  }
}
