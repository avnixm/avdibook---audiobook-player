import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook.dart';
import 'package:avdibook/features/player/data/services/media_control_bridge.dart';
import 'package:avdibook/features/player/data/services/audio_fx_service.dart';
import 'package:avdibook/shared/providers/app_state_provider.dart';
import 'package:avdibook/shared/providers/library_provider.dart';
import 'package:avdibook/shared/providers/listening_analytics_provider.dart';
import 'package:avdibook/shared/providers/playback_history_provider.dart';
import 'package:avdibook/shared/providers/storage_providers.dart';


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
    this.trimSilence = false,
    this.preservePitch = true,
    this.pitch = 1.0,
    this.previousPosition,
    this.chapterRemaining = Duration.zero,
    this.bookRemaining = Duration.zero,
    this.chapterProgress = 0.0,
    this.bookProgress = 0.0,
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
  final bool trimSilence;
  final bool preservePitch;
  final double pitch;
  final Duration? previousPosition;
  final Duration chapterRemaining;
  final Duration bookRemaining;
  final double chapterProgress;
  final double bookProgress;
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
    bool? trimSilence,
    bool? preservePitch,
    double? pitch,
    Duration? previousPosition,
    bool clearPreviousPosition = false,
    Duration? chapterRemaining,
    Duration? bookRemaining,
    double? chapterProgress,
    double? bookProgress,
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
      trimSilence: trimSilence ?? this.trimSilence,
      preservePitch: preservePitch ?? this.preservePitch,
      pitch: pitch ?? this.pitch,
      previousPosition: clearPreviousPosition
          ? null
          : (previousPosition ?? this.previousPosition),
      chapterRemaining: chapterRemaining ?? this.chapterRemaining,
      bookRemaining: bookRemaining ?? this.bookRemaining,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      bookProgress: bookProgress ?? this.bookProgress,
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
  DateTime? _lastPausedAt;
  MediaControlBridge? _mediaBridge;
  AudioFxService? _audioFx;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  @override
  PlayerState build() {
    final initialSpeed = ref.read(globalPlaybackSpeedProvider);
    final initialVolume = ref.read(globalVolumeProvider);
    final initialVolumeBoost = ref.read(volumeBoostProvider);
    final initialTrimSilence = ref.read(trimSilenceProvider);
    final initialPreservePitch = ref.read(preservePitchProvider);
    final initialPitch = ref.read(playbackPitchProvider);

    _player = AudioPlayer();
    _mediaBridge = MediaControlBridge(ref);
    _audioFx = AudioFxService();
    unawaited(
      _mediaBridge?.initialize(
        onPlayFromMediaId: _playFromBridgeMediaId,
      ),
    );
    unawaited(_configureAudioSession());
    unawaited(_player.setSpeed(initialSpeed));
    unawaited(_player.setVolume(_effectiveVolume(initialVolume, initialVolumeBoost)));
    unawaited(_player.setSkipSilenceEnabled(initialTrimSilence));
    unawaited(_player.setPitch(initialPreservePitch ? initialPitch : initialSpeed));

    ref.listen<bool>(trimSilenceProvider, (_, next) {
      unawaited(_player.setSkipSilenceEnabled(next));
      state = state.copyWith(trimSilence: next);
    });

    ref.listen<bool>(preservePitchProvider, (_, next) {
      final targetPitch = next ? ref.read(playbackPitchProvider) : state.speed;
      unawaited(_player.setPitch(targetPitch));
      state = state.copyWith(preservePitch: next, pitch: targetPitch);
    });

    ref.listen<double>(playbackPitchProvider, (_, next) {
      final preservePitch = ref.read(preservePitchProvider);
      if (!preservePitch) return;
      unawaited(_player.setPitch(next));
      state = state.copyWith(pitch: next);
    });

    ref.listen<double>(volumeBoostProvider, (_, __) {
      final baseVolume = ref.read(globalVolumeProvider);
      final boost = ref.read(volumeBoostProvider);
      unawaited(_player.setVolume(_effectiveVolume(baseVolume, boost)));
      unawaited(_audioFx?.setLoudnessBoost(boost));
      state = state.copyWith(volume: _effectiveVolume(baseVolume, boost));
    });

    ref.listen<bool>(equalizerEnabledProvider, (_, next) {
      unawaited(_audioFx?.setEqualizerEnabled(next));
    });

    ref.listen<int>(equalizerPresetProvider, (_, next) {
      unawaited(_audioFx?.setEqualizerPreset(next));
    });

    ref.listen<double>(stereoBalanceProvider, (_, next) {
      unawaited(_audioFx?.setStereoBalance(next));
    });

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      _refreshDerivedProgress();
      _trackListeningProgress(pos);
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
        _refreshDerivedProgress();
      }
    });

    _player.playerStateStream.listen((ps) {
      state = state.copyWith(isPlaying: ps.playing);
      if (_wasPlaying && !ps.playing) {
        _lastPausedAt = DateTime.now();
        unawaited(_flushListeningDeltaAndPersistProgress());
      }
      _wasPlaying = ps.playing;
    });

    _player.currentIndexStream.listen((i) {
      if (i != null) {
        state = state.copyWith(currentChapterIndex: i);
        _refreshDerivedProgress();
      }
    });

    _player.volumeStream.listen((v) {
      state = state.copyWith(volume: v.clamp(0.0, 1.0));
    });

    _player.androidAudioSessionIdStream.listen((sessionId) {
      unawaited(_audioFx?.setAudioSessionId(sessionId));
    });

    ref.onDispose(() {
      unawaited(_flushListeningDeltaAndPersistProgress());
      unawaited(_mediaBridge?.dispose());
      unawaited(_audioFx?.setAudioSessionId(null));
      unawaited(_interruptionSub?.cancel());
      unawaited(_becomingNoisySub?.cancel());
      _player.dispose();
    });

    return PlayerState(
      speed: initialSpeed,
      volume: initialVolume,
      trimSilence: initialTrimSilence,
      preservePitch: initialPreservePitch,
      pitch: initialPitch,
    );
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
          source = AudioSource.uri(
            Uri.file(book.sourcePaths.first),
            tag: _mediaItem(book, book.sourcePaths.first, 0),
          );
        } else {
          source = ConcatenatingAudioSource(
            children: [
              for (var i = 0; i < book.sourcePaths.length; i++)
                AudioSource.uri(
                  Uri.file(book.sourcePaths[i]),
                  tag: _mediaItem(book, book.sourcePaths[i], i),
                ),
            ],
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
          source = AudioSource.uri(
            Uri.file(uniquePaths.first),
            tag: _mediaItem(book, uniquePaths.first, 0),
          );
        } else {
          source = ConcatenatingAudioSource(
            children: [
              for (var i = 0; i < uniquePaths.length; i++)
                AudioSource.uri(
                  Uri.file(uniquePaths[i]),
                  tag: _mediaItem(book, uniquePaths[i], i),
                ),
            ],
          );
        }
      }

      await _player.setAudioSource(source);
      final resolvedSpeed = book.preferredSpeed ?? state.speed;
      await _player.setSpeed(resolvedSpeed);
      if (!ref.read(preservePitchProvider)) {
        await _player.setPitch(resolvedSpeed);
      }
      await _player.setVolume(state.volume);
      final resumeFrom = book.resumePosition;
      if (resumeFrom != null && resumeFrom > Duration.zero) {
        final duration = _player.duration;
        final clamped = duration == null || resumeFrom <= duration
            ? resumeFrom
            : duration;
        await _player.seek(clamped);
      }
      state = state.copyWith(
        isLoading: false,
        speed: resolvedSpeed,
        pitch: ref.read(preservePitchProvider)
        ? ref.read(playbackPitchProvider)
        : resolvedSpeed,
      );
      _refreshDerivedProgress();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load audiobook. Check that the files still exist.',
      );
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_player.playing) {
          _player.pause();
        }
      } else {
        if (event.type == AudioInterruptionType.pause) {
          _player.play();
        }
      }
    });

    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }

  MediaItem _mediaItem(Audiobook book, String filePath, int index) {
    return MediaItem(
      id: '${book.id}::$index::$filePath',
      album: book.series,
      title: book.title,
      artist: book.author?.name,
      artUri: book.coverPath == null ? null : Uri.file(book.coverPath!),
      displayTitle: book.title,
      displaySubtitle: book.author?.name,
      extras: {
        'bookId': book.id,
        'chapterIndex': index,
      },
    );
  }

  void _refreshDerivedProgress() {
    final chapterDuration = state.duration;
    final chapterPosition = state.position;
    final safeChapterRemaining =
        chapterDuration > chapterPosition ? chapterDuration - chapterPosition : Duration.zero;
    final safeChapterProgress = chapterDuration.inMilliseconds <= 0
        ? 0.0
        : (chapterPosition.inMilliseconds / chapterDuration.inMilliseconds)
            .clamp(0.0, 1.0);

    final sequence = _player.sequence;
    Duration bookRemaining = safeChapterRemaining;
    double bookProgress = safeChapterProgress;

    if (sequence.isNotEmpty) {
      var allDurationsKnown = true;
      var totalMs = 0;
      for (final source in sequence) {
        final duration = source.duration;
        if (duration == null) {
          allDurationsKnown = false;
          break;
        }
        totalMs += duration.inMilliseconds;
      }

      if (allDurationsKnown && totalMs > 0) {
        final currentIndex = state.currentChapterIndex.clamp(0, sequence.length - 1);
        var elapsedMs = chapterPosition.inMilliseconds;

        for (var i = 0; i < currentIndex; i++) {
          elapsedMs += sequence[i].duration!.inMilliseconds;
        }

        final remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
        bookRemaining = Duration(milliseconds: remainingMs);
        bookProgress = (elapsedMs / totalMs).clamp(0.0, 1.0);
      }
    }

    state = state.copyWith(
      chapterRemaining: safeChapterRemaining,
      bookRemaining: bookRemaining,
      chapterProgress: safeChapterProgress,
      bookProgress: bookProgress,
    );
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

    final pausedAt = _lastPausedAt;
    if (pausedAt != null) {
      final elapsed = DateTime.now().difference(pausedAt);
      final smartRewindSecs = ref.read(smartRewindSecsProvider);
      if (elapsed >= const Duration(minutes: 1) && smartRewindSecs > 0) {
        final rewindBy = Duration(seconds: smartRewindSecs);
        final rewindTarget = state.position - rewindBy;
        unawaited(_player.seek(rewindTarget < Duration.zero ? Duration.zero : rewindTarget));
      }
    }

    if (bookId != null && !_player.playing) {
      unawaited(ref.read(listeningAnalyticsProvider.notifier).startSession(bookId));
      unawaited(
        ref.read(playbackHistoryProvider.notifier).addEvent(
              bookId: bookId,
              position: state.position,
              event: 'resume',
            ),
      );
    }
    _player.play();
  }

  void pause() {
    final bookId = state.bookId;
    if (bookId != null && _player.playing) {
      unawaited(
        ref.read(playbackHistoryProvider.notifier).addEvent(
              bookId: bookId,
              position: state.position,
              event: 'pause',
            ),
      );
    }
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
    final preservePitch = ref.read(preservePitchProvider);
    if (!preservePitch) {
      await _player.setPitch(speed);
    }
    state = state.copyWith(speed: speed, pitch: preservePitch ? state.pitch : speed);
    await ref.read(globalPlaybackSpeedProvider.notifier).set(speed);

    final bookId = state.bookId;
    if (bookId == null) return;

    final library = ref.read(libraryProvider);
    final index = library.indexWhere((book) => book.id == bookId);
    if (index < 0) return;

    final currentBook = library[index];
    if (currentBook.preferredSpeed == speed) return;

    final updatedBook = currentBook.copyWith(preferredSpeed: speed);
    final nextLibrary = [...library];
    nextLibrary[index] = updatedBook;

    ref.read(libraryProvider.notifier).setLibrary(nextLibrary);
    await ref.read(startupStorageServiceProvider).setLibraryItems(nextLibrary);
  }

  Future<void> setVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    final boosted = _effectiveVolume(normalized, ref.read(volumeBoostProvider));
    await _player.setVolume(boosted);
    state = state.copyWith(volume: boosted);
    await ref.read(globalVolumeProvider.notifier).set(normalized);
  }

  double _effectiveVolume(double baseVolume, double boost) {
    // Best effort "volume boost" within player constraints.
    return (baseVolume * (1.0 + boost)).clamp(0.0, 1.6);
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

  Future<void> _playFromBridgeMediaId(String mediaId) async {
    final bridge = _mediaBridge;
    if (bridge == null) return;

    final chapterTarget = bridge.parseChapterMediaId(mediaId);
    if (chapterTarget != null) {
      final library = ref.read(libraryProvider);
      Audiobook? book;
      for (final item in library) {
        if (item.id == chapterTarget.bookId) {
          book = item;
          break;
        }
      }
      if (book == null) return;

      if (state.bookId != book.id) {
        await load(book);
      }

      final chapterCount = book.chapters.length;
      if (chapterCount > 0) {
        final index = chapterTarget.chapterIndex.clamp(0, chapterCount - 1);
        await seekToChapterIndex(index);
      }
      play();
      return;
    }

    if (mediaId.startsWith('book:')) {
      final bookId = mediaId.substring('book:'.length);
      final library = ref.read(libraryProvider);
      Audiobook? book;
      for (final item in library) {
        if (item.id == bookId) {
          book = item;
          break;
        }
      }
      if (book == null) return;

      if (state.bookId != book.id) {
        await load(book);
      }
      play();
    }
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
