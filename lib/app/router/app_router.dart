import 'dart:io';

import 'package:collection/collection.dart';
import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/features/home/presentation/screens/home_screen.dart';
import 'package:avdibook/features/library/presentation/screens/library_screen.dart';
import 'package:avdibook/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';
import 'package:avdibook/features/player/presentation/screens/bookmarks_screen.dart';
import 'package:avdibook/features/player/presentation/screens/chapter_list_screen.dart';
import 'package:avdibook/features/search/presentation/screens/search_screen.dart';
import 'package:avdibook/features/settings/presentation/screens/settings_screen.dart';
import 'package:avdibook/features/settings/presentation/screens/about_screen.dart';
import 'package:avdibook/features/setup/presentation/screens/setup_screen.dart';
import 'package:avdibook/features/splash/presentation/screens/splash_screen.dart';
import 'package:avdibook/features/player/presentation/screens/now_playing_screen.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/library_provider.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // Redirect logic handled by splash screen via ProviderScope
      return null;
    },
    routes: [
      // Splash / bootstrap
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Setup / import flow
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupScreen(),
      ),

      GoRoute(
        path: AppRoutes.player,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: NowPlayingScreen(bookId: bookId),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (context, animation, secondary, child) {
              final curve = CurvedAnimation(
                parent: animation,
                curve: Curves.linearToEaseOut,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(begin: 0.75, end: 1).animate(curve),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.92),
                    end: Offset.zero,
                  ).animate(curve),
                  child: child,
                ),
              );
            },
          );
        },
      ),

      GoRoute(
        path: AppRoutes.chapterList,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return ChapterListScreen(bookId: bookId);
        },
      ),

      GoRoute(
        path: AppRoutes.bookmarks,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return BookmarksScreen(bookId: bookId);
        },
      ),

      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),

      // Main shell — shows bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            _MainShell(child: child, currentPath: state.uri.path),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

// ─── Main shell with bottom navigation ──────────────────────────────────────

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerRoute = currentPath.startsWith('/player/');

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          _MiniNowPlayingBar(hidden: isPlayerRoute),
        ],
      ),
      bottomNavigationBar: _AvdiBottomNav(currentPath: currentPath),
    );
  }
}

class _AvdiBottomNav extends StatelessWidget {
  const _AvdiBottomNav({required this.currentPath});

  final String currentPath;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
    (
      icon: Icons.library_books_rounded,
      label: 'Library',
      route: AppRoutes.library,
    ),
    (
      icon: Icons.search_rounded,
      label: 'Search',
      route: AppRoutes.search,
    ),
    (
      icon: Icons.settings_rounded,
      label: 'Settings',
      route: AppRoutes.settings,
    ),
  ];

  int _currentIndex() {
    for (var i = 0; i < _tabs.length; i++) {
      if (currentPath.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex();
    return NavigationBar(
      selectedIndex: current,
      onDestinationSelected: (i) => context.go(_tabs[i].route),
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
      ],
    );
  }
}

class _MiniNowPlayingBar extends ConsumerWidget {
  const _MiniNowPlayingBar({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);
    final bookId = playerState.bookId;

    final book = bookId == null
      ? null
      : library.firstWhereOrNull((b) => b.id == bookId);
    final canShow = !hidden && book != null;

    final Widget content;
    if (!canShow) {
      content = const SizedBox(
        key: ValueKey('mini_now_playing_hidden'),
      );
    } else {
      final currentBook = book!;
      content = Padding(
        key: const ValueKey('mini_now_playing_visible'),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          child: ExpressiveBounce(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push(AppRoutes.playerPath(currentBook.id)),
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    _MiniCover(coverPath: currentBook.coverPath),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentBook.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentBook.author?.name ?? 'Unknown author',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: playerState.progress,
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.read(playerProvider.notifier).togglePlay(),
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: content,
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final imagePath = coverPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 50,
        height: 50,
        child: imagePath != null
            ? Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _MiniCoverFallback(),
              )
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.headphones_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
      ),
    );
  }
}

class _MiniCoverFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.headphones_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}
