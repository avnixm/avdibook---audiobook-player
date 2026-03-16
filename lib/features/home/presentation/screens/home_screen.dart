import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:avdibook/app/theme/app_spacing.dart';
import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/utils/duration_formatter.dart';
import 'package:avdibook/core/widgets/app_scaffold.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/core/widgets/section_header.dart';
import 'package:avdibook/core/widgets/soft_icon_button.dart';
import 'package:avdibook/core/widgets/soft_pill_button.dart';
import 'package:avdibook/features/setup/presentation/providers/setup_controller.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/listening_analytics_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider);
    final analytics = ref.watch(listeningAnalyticsProvider);
    final setupState = ref.watch(setupControllerProvider);
    final isBusy = setupState.isBusy;

    void importFiles() =>
        ref.read(setupControllerProvider.notifier).importFiles();
    void importDirectory() =>
        ref.read(setupControllerProvider.notifier).importDirectory();
    void comingSoon(String label) =>
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — coming soon')),
        );

    return AppScaffold(
      showAppBar: false,
      body: ListView(
        children: [
          Row(
            children: [
              SoftIconButton(
                icon: Icons.menu_rounded,
                onPressed: () => comingSoon('Navigation drawer'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  library.isEmpty ? 'Welcome' : 'Welcome back',
                  style: text.titleMedium,
                ),
              ),
              SoftIconButton(
                icon: Icons.settings_outlined,
                onPressed: () => context.go(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            library.isEmpty
                ? 'Bring your audiobooks into AvdiBook.'
                : 'Find your next listening session.',
            style: text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (library.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 34,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No audiobooks here',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import files or choose a folder to build your library. You can add more books anytime.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SoftPillButton(
                        label: 'Import audiobooks',
                        icon: Icons.download_rounded,
                        onPressed: isBusy ? () {} : importFiles,
                      ),
                      SoftPillButton(
                        label: 'Choose folder',
                        icon: Icons.folder_rounded,
                        onPressed: isBusy ? () {} : importDirectory,
                      ),
                    ],
                  ),
                  if (isBusy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                  if (setupState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      setupState.errorMessage!,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            _ExpressiveBounceIn(
              delayMs: 40,
              child: _ListeningAnalyticsCard(
                totalListening: analytics.totalListeningDuration,
                averageSession: analytics.averageSessionDuration,
                sessions: analytics.totalSessions,
              ),
            ),
            const SizedBox(height: 14),
            _ExpressiveBounceIn(
              delayMs: 120,
              child: _RecentHeroCard(
                title: library.first.title,
                author: library.first.author?.name ?? 'Unknown author',
                chapterCount: library.first.chapterCount,
                coverPath: library.first.coverPath,
                onOpenPlayer:
                    () => context.push(AppRoutes.playerPath(library.first.id)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(
            title: library.isEmpty
                ? 'How AvdiBook will organize your library'
                : 'Imported books',
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: library.isEmpty ? 4 : library.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = library.isEmpty ? null : library[index];

                return ExpressiveBounce(
                  enabled: item != null,
                  child: Material(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: item != null
                          ? () => context.push(AppRoutes.playerPath(item.id))
                          : null,
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.headphones_rounded,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item?.title ?? 'Your books',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item == null
                                  ? 'Imported titles'
                                  : '${item.author?.name ?? 'Unknown author'} • ${item.chapterCount} ch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressiveBounceIn extends StatelessWidget {
  const _ExpressiveBounceIn({
    required this.child,
    this.delayMs = 0,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, value, builtChild) {
        final clamped = value.clamp(0.0, 1.0);
        final translateY = (1 - clamped) * 18;
        final scale = 0.97 + (clamped * 0.03);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: clamped,
              child: builtChild,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _ListeningAnalyticsCard extends StatelessWidget {
  const _ListeningAnalyticsCard({
    required this.totalListening,
    required this.averageSession,
    required this.sessions,
  });

  final Duration totalListening;
  final Duration averageSession;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listening Analytics',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnalyticsStat(
                  label: 'Total time',
                  value: DurationFormatter.formatHuman(totalListening),
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AnalyticsStat(
                  label: 'Avg session',
                  value: DurationFormatter.formatHuman(averageSession),
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AnalyticsStat(
                  label: 'Sessions',
                  value: '$sessions',
                  icon: Icons.repeat_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsStat extends StatelessWidget {
  const _AnalyticsStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHeroCard extends StatelessWidget {
  const _RecentHeroCard({
    required this.title,
    required this.author,
    required this.chapterCount,
    required this.coverPath,
    required this.onOpenPlayer,
  });

  final String title;
  final String author;
  final int chapterCount;
  final String? coverPath;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recently imported',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BookCoverThumb(coverPath: coverPath),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.person_rounded,
                          label: author,
                        ),
                        _InfoChip(
                          icon: Icons.menu_book_rounded,
                          label: '$chapterCount chapter(s)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: onOpenPlayer,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continue listening'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookCoverThumb extends StatelessWidget {
  const _BookCoverThumb({required this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = coverPath != null && File(coverPath!).existsSync();

    return Container(
      width: 116,
      height: 156,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: hasImage
          ? Image.file(File(coverPath!), fit: BoxFit.cover)
          : Icon(
              Icons.auto_stories_rounded,
              size: 42,
              color: scheme.primary,
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
