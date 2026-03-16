import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

class SleepTimerState {
  const SleepTimerState({
    this.remaining,
    this.resumeArmed = false,
  });

  final Duration? remaining;
  final bool resumeArmed;

  bool get isActive => remaining != null && !resumeArmed;

  SleepTimerState copyWith({
    Duration? remaining,
    bool? resumeArmed,
    bool clearRemaining = false,
  }) {
    return SleepTimerState(
      remaining: clearRemaining ? null : (remaining ?? this.remaining),
      resumeArmed: resumeArmed ?? this.resumeArmed,
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

  Future<void> _expire() async {
    _ticker?.cancel();
    state = const SleepTimerState(
      remaining: Duration.zero,
      resumeArmed: true,
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
