import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../features/audiobooks/domain/models/audiobook.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../../shared/providers/app_state_provider.dart';
import '../../../../shared/providers/library_provider.dart';
import '../../../../shared/providers/listening_analytics_provider.dart';

class PlayerState {
  const PlayerState({
    this.bookId,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentChapterIndex = 0,
    this.speed = 1.0,
    this.shuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.volume = 1.0,
    this.previousPosition,
    this.error,
  });

  final String? bookId;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final int currentChapterIndex;
  final double speed;
  final bool shuffleEnabled;
  final LoopMode loopMode;
  final double volume;
  final Duration? previousPosition;
  final String? error;

  bool get isLoaded => bookId != null && !isLoading;

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    String? bookId,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    int? currentChapterIndex,
    double? speed,
    bool? shuffleEnabled,
    LoopMode? loopMode,
    double? volume,
    Duration? previousPosition,
    bool clearPreviousPosition = false,
    String? error,
    bool clearError = false,
  }) {
    return PlayerState(
      bookId: bookId ?? this.bookId,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      speed: speed ?? this.speed,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      volume: volume ?? this.volume,
      previousPosition: clearPreviousPosition
          ? null
          : (previousPosition ?? this.previousPosition),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  late final AudioPlayer _player;
  Duration? _lastTrackedPosition;
  Duration _pendingListenDelta = Duration.zero;
  String? _trackedBookId;
  bool _wasPlaying = false;
  DateTime _lastProgressPersistAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  PlayerState build() {
    final initialSpeed = ref.read(globalPlaybackSpeedProvider);
    final initialVolume = ref.read(globalVolumeProvider);

    _player = AudioPlayer();
    unawaited(_player.setSpeed(initialSpeed));
    unawaited(_player.setVolume(initialVolume));

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      _trackListeningProgress(pos);
    });

    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    _player.playerStateStream.listen((ps) {
      state = state.copyWith(isPlaying: ps.playing);
      if (_wasPlaying && !ps.playing) {
        unawaited(_flushListeningDeltaAndPersistProgress());
      }
      _wasPlaying = ps.playing;
    });

    _player.currentIndexStream.listen((i) {
      if (i != null) state = state.copyWith(currentChapterIndex: i);
    });

    _player.volumeStream.listen((v) {
      state = state.copyWith(volume: v.clamp(0.0, 1.0));
    });

    ref.onDispose(() {
      unawaited(_flushListeningDeltaAndPersistProgress());
      _player.dispose();
    });

    return PlayerState(speed: initialSpeed, volume: initialVolume);
  }

  Future<void> load(Audiobook book) async {
    if (state.bookId == book.id && state.isLoaded) return;
    await _flushListeningDeltaAndPersistProgress();
    _trackedBookId = book.id;
    _lastTrackedPosition = Duration.zero;
    state = state.copyWith(isLoading: true, bookId: book.id, clearError: true);
    try {
      await _player.stop();
      final AudioSource source;
      if (book.chapters.isEmpty) {
        // Fallback: load source paths directly
        if (book.sourcePaths.length == 1) {
          source = AudioSource.uri(Uri.file(book.sourcePaths.first));
        } else {
          source = ConcatenatingAudioSource(
            children: book.sourcePaths
                .map((p) => AudioSource.uri(Uri.file(p)))
                .toList(),
          );
        }
      } else {
        // Load each unique file; for single-file books (m4b), just one source
        final uniquePaths = book.chapters
            .map((c) => c.filePath)
            .toSet()
            .toList()
          ..sort();

        if (uniquePaths.length == 1) {
          source = AudioSource.uri(Uri.file(uniquePaths.first));
        } else {
          source = ConcatenatingAudioSource(
            children: uniquePaths
                .map((p) => AudioSource.uri(Uri.file(p)))
                .toList(),
          );
        }
      }

      await _player.setAudioSource(source);
      await _player.setSpeed(state.speed);
      await _player.setVolume(state.volume);
      final resumeFrom = book.resumePosition;
      if (resumeFrom != null && resumeFrom > Duration.zero) {
        final duration = _player.duration;
        final clamped = duration == null || resumeFrom <= duration
            ? resumeFrom
            : duration;
        await _player.seek(clamped);
      }
      state = state.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load audiobook. Check that the files still exist.',
      );
    }
  }

  void togglePlay() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    final bookId = state.bookId;
    if (bookId != null && !_player.playing) {
      unawaited(ref.read(listeningAnalyticsProvider.notifier).startSession(bookId));
    }
    _player.play();
  }

  void pause() {
    _player.pause();
  }

  Future<void> seekTo(double fraction) async {
    _rememberUndoPoint();
    final ms = (state.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await _player.seek(Duration(milliseconds: ms));
  }

  Future<void> skipForward(int seconds) async {
    _rememberUndoPoint();
    final target = state.position + Duration(seconds: seconds);
    await _player.seek(
      target > state.duration ? state.duration : target,
    );
  }

  Future<void> skipBackward(int seconds) async {
    _rememberUndoPoint();
    final target = state.position - Duration(seconds: seconds);
    await _player.seek(
      target < Duration.zero ? Duration.zero : target,
    );
  }

  Future<void> nextChapter() async {
    _rememberUndoPoint();
    await _player.seekToNext();
  }

  Future<void> previousChapter() async {
    _rememberUndoPoint();
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
    await ref.read(globalPlaybackSpeedProvider.notifier).set(speed);
  }

  Future<void> setVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    await _player.setVolume(normalized);
    state = state.copyWith(volume: normalized);
    await ref.read(globalVolumeProvider.notifier).set(normalized);
  }

  Future<void> toggleShuffle() async {
    final next = !state.shuffleEnabled;
    await _player.setShuffleModeEnabled(next);
    state = state.copyWith(shuffleEnabled: next);
  }

  Future<void> cycleLoopMode() async {
    final next = switch (state.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
    state = state.copyWith(loopMode: next);
  }

  Future<void> seekToChapterIndex(int chapterIndex) async {
    if (chapterIndex < 0) return;
    _rememberUndoPoint();
    await _player.seek(Duration.zero, index: chapterIndex);
  }

  Future<void> seekToPosition(Duration position) async {
    _rememberUndoPoint();
    await _player.seek(position < Duration.zero ? Duration.zero : position);
  }

  Future<void> undoLastJump() async {
    final previous = state.previousPosition;
    if (previous == null) return;
    await _player.seek(previous);
    state = state.copyWith(clearPreviousPosition: true);
  }

  void _rememberUndoPoint() {
    state = state.copyWith(previousPosition: state.position);
  }

  void _trackListeningProgress(Duration currentPosition) {
    final bookId = state.bookId;
    if (bookId == null || !_player.playing) {
      _lastTrackedPosition = currentPosition;
      return;
    }

    if (_trackedBookId != bookId) {
      unawaited(_flushListeningDelta());
      _trackedBookId = bookId;
      _lastTrackedPosition = currentPosition;
      return;
    }

    if (_lastTrackedPosition == null) {
      _lastTrackedPosition = currentPosition;
      return;
    }

    final delta = currentPosition - _lastTrackedPosition!;
    _lastTrackedPosition = currentPosition;

    // Ignore seeks and jitter; only count natural forward playback.
    if (delta <= Duration.zero || delta > const Duration(seconds: 30)) {
      return;
    }

    _pendingListenDelta += delta;
    if (_pendingListenDelta >= const Duration(seconds: 12)) {
      unawaited(_flushListeningDelta());
      final now = DateTime.now();
      if (now.difference(_lastProgressPersistAt) >=
          const Duration(seconds: 20)) {
        _lastProgressPersistAt = now;
        unawaited(_persistBookProgress());
      }
    }
  }

  Future<void> _flushListeningDeltaAndPersistProgress() async {
    await _flushListeningDelta();
    await _persistBookProgress();
  }

  Future<void> _flushListeningDelta() async {
    final bookId = _trackedBookId;
    if (bookId == null || _pendingListenDelta <= Duration.zero) return;

    final delta = _pendingListenDelta;
    _pendingListenDelta = Duration.zero;

    await ref
        .read(listeningAnalyticsProvider.notifier)
        .recordListening(bookId: bookId, delta: delta);
  }

  Future<void> _persistBookProgress() async {
    final bookId = state.bookId;
    if (bookId == null) return;

    final library = ref.read(libraryProvider);
    final index = library.indexWhere((book) => book.id == bookId);
    if (index < 0) return;

    final currentBook = library[index];
    final totalMs = state.duration.inMilliseconds;
    final positionMs = state.position.inMilliseconds;

    double progress = currentBook.progress;
    if (totalMs > 0) {
      progress = (positionMs / totalMs).clamp(0.0, 1.0);
    }

    final status = BookStatus.fromProgress(progress);
    final now = DateTime.now();
    final updatedBook = currentBook.copyWith(
      progress: progress,
      resumePosition: state.position,
      lastPlayedAt: now,
      status: status,
      completedAt: status == BookStatus.finished
          ? (currentBook.completedAt ?? now)
          : null,
      clearCompletedAt: status != BookStatus.finished,
    );

    if (updatedBook == currentBook) return;

    final nextLibrary = [...library];
    nextLibrary[index] = updatedBook;
    ref.read(libraryProvider.notifier).setLibrary(nextLibrary);
    await ref.read(startupStorageServiceProvider).setLibraryItems(nextLibrary);
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
