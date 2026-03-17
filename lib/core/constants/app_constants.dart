/// App-wide constants for AvdiBook.
library;

// ─── Routes ──────────────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String setup = '/setup';
  static const String home = '/home';
  static const String library = '/library';
  static const String search = '/search';
  static const String settings = '/settings';

  // Book-scoped routes
  static const String bookDetails = '/library/book/:bookId';
  static const String player = '/player/:bookId';
  static const String chapterList = '/player/:bookId/chapters';
  static const String bookmarks = '/player/:bookId/bookmarks';
  static const String downloads = '/downloads';
  static const String about = '/settings/about';

  static String bookDetailsPath(String bookId) =>
      '/library/book/$bookId';
  static String playerPath(String bookId) => '/player/$bookId';
  static String chapterListPath(String bookId) =>
      '/player/$bookId/chapters';
  static String bookmarksPath(String bookId) =>
      '/player/$bookId/bookmarks';
}

// ─── Storage keys ────────────────────────────────────────────────────────────

abstract class StorageKeys {
  static const String isOnboarded = 'is_onboarded';
  static const String hasLibrary = 'has_library';
  static const String lastBookId = 'last_book_id';
  static const String lastPosition = 'last_position';
  static const String playbackSpeed = 'playback_speed_';
  static const String sleepTimer = 'sleep_timer_mins';
  static const String themeMode = 'theme_mode';
  static const String reducedMotion = 'reduced_motion';
  static const String skipForwardSecs = 'skip_forward_secs';
  static const String skipBackwardSecs = 'skip_backward_secs';
  static const String scanFolderPath = 'scan_folder_path';
  static const String listeningAnalytics = 'listening_analytics_v1';
  static const String bookmarks = 'bookmarks_v1';
  static const String trimSilence = 'trim_silence';
  static const String preservePitch = 'preserve_pitch';
  static const String playbackPitch = 'playback_pitch';
  static const String smartRewindSecs = 'smart_rewind_secs';
  static const String playbackHistory = 'playback_history_v1';
  static const String volumeBoost = 'volume_boost';
  static const String stereoBalance = 'stereo_balance';
  static const String equalizerEnabled = 'equalizer_enabled';
  static const String equalizerPreset = 'equalizer_preset';
}

// ─── App defaults ─────────────────────────────────────────────────────────────

abstract class AppDefaults {
  static const int skipForwardSecs = 30;
  static const int skipBackwardSecs = 10;
  static const double playbackSpeed = 1.0;
  static const int sleepTimerMins = 30;
  static const int smartRewindSecs = 7;
  static const double volumeBoost = 0.0;
  static const double stereoBalance = 0.0;
  static const bool equalizerEnabled = false;
  static const int equalizerPreset = 0;
  static const double minCoverSize = 56.0;
  static const double cardBorderRadius = 20.0;
  static const double sheetBorderRadius = 28.0;

  /// Supported audio extensions for import
  static const List<String> audioExtensions = [
    'mp3',
    'm4b',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'flac',
    'opus',
  ];

  /// Primary audiobook container formats
  static const List<String> audiobookExtensions = ['m4b', 'mp3', 'm4a'];

  static const List<double> speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  static const List<double> pitchOptions = [
    0.8,
    0.9,
    1.0,
    1.1,
    1.2,
  ];

  static const List<int> sleepTimerOptions = [5, 10, 15, 20, 30, 45, 60, 90];
}

// ─── Animation durations ─────────────────────────────────────────────────────

abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration hero = Duration(milliseconds: 380);
  static const Duration splash = Duration(milliseconds: 800);
}
