import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avdibook/features/player/presentation/providers/player_provider.dart';


class SleepTimerState {
  const SleepTimerState({
    this.remaining,
    this.resumeArmed = false,
    this.endOfChapterArmed = false,
  });

  final Duration? remaining;
  final bool resumeArmed;
  final bool endOfChapterArmed;

  bool get isActive => remaining != null && !resumeArmed;

  SleepTimerState copyWith({
    Duration? remaining,
    bool? resumeArmed,
    bool? endOfChapterArmed,
    bool clearRemaining = false,
  }) {
    return SleepTimerState(
      remaining: clearRemaining ? null : (remaining ?? this.remaining),
      resumeArmed: resumeArmed ?? this.resumeArmed,
      endOfChapterArmed: endOfChapterArmed ?? this.endOfChapterArmed,
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _ticker;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const SleepTimerState();
  }

  void start(Duration duration) {
    if (duration <= Duration.zero) {
      cancel();
      return;
    }

    _ticker?.cancel();
    state = SleepTimerState(remaining: duration);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remaining;
      if (remaining == null) {
        _ticker?.cancel();
        return;
      }

      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _expire();
        return;
      }

      state = state.copyWith(remaining: next);
    });
  }

  void cancel() {
    _ticker?.cancel();
    state = const SleepTimerState();
  }

  void toggleEndOfChapter() {
    final next = !state.endOfChapterArmed;
    state = state.copyWith(endOfChapterArmed: next);
  }

  void clearEndOfChapter() {
    if (!state.endOfChapterArmed) return;
    state = state.copyWith(endOfChapterArmed: false);
  }

  Future<void> _expire() async {
    _ticker?.cancel();
    state = const SleepTimerState(
      remaining: Duration.zero,
      resumeArmed: true,
      endOfChapterArmed: false,
    );
    ref.read(playerProvider.notifier).pause();
  }

  void resumeFromShake() {
    if (!state.resumeArmed) return;
    ref.read(playerProvider.notifier).play();
    cancel();
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(
  SleepTimerNotifier.new,
);
