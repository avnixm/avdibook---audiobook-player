# AvdiBook

Premium Material 3 expressive audiobook player built with Flutter.

AvdiBook is focused on local-library audiobook listening with a polished, expressive UI and practical listening tools: chapter navigation, bookmarks, clips, sleep timer, listening analytics, character notes, and per-book progress.

## Table Of Contents

1. [Highlights](#highlights)
2. [Core Features](#core-features)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Architecture Notes](#architecture-notes)
6. [Getting Started](#getting-started)
7. [Run, Build, Install](#run-build-install)
8. [Data And Persistence](#data-and-persistence)
9. [Navigation](#navigation)
10. [Design System](#design-system)
11. [Troubleshooting](#troubleshooting)
12. [Development Notes](#development-notes)
13. [Roadmap Ideas](#roadmap-ideas)

## Highlights

- Material 3 expressive UI across Home, Library, Search, Settings, and Player.
- Local audiobook import from files and folders.
- Smart playback controls: skip intervals, speed, sleep timer, end-of-chapter timer.
- Rich book context: chapter list, bookmarks, clips, character notes.
- Listening analytics and status tracking.
- Riverpod + GoRouter app foundation.
- Drift-backed persistence with migration support from legacy key-value storage.

## Core Features

### Library Management

- Import audiobooks from files or directories.
- Folder import semantics:
	- Top-level audio files under selected root can become one-file books.
	- Each top-level subfolder becomes one book with chapters from nested files.
- Favorite books.
- Filter and sort controls (view/status/sort).
- Remove books from library.

### Playback

- Play/pause, seek, and chapter-aware playback.
- Configurable skip forward/backward durations.
- Smart rewind on resume.
- Adjustable speed and pitch handling options.
- Sleep timer with:
	- Time-based timer (minutes).
	- End-of-current-chapter mode.
	- Optional shake-to-resume behavior.

### Book Context

- Chapter list navigation.
- Bookmarks with labels/notes.
- Quick clip creation (saved as bookmark clips).
- Character notes per book (add/edit/delete).

### Discovery And Personalization

- Search by title/author/narrator/series/genre.
- Sort by relevance/recent/title/author.
- Home dashboard:
	- Continue listening
	- Listening analytics
	- Playback history
	- Library status overview

## Tech Stack

- Flutter (Dart)
- State management: `flutter_riverpod`
- Routing: `go_router`
- Audio: `just_audio`
- Background/audio service packages present in dependencies:
	- `audio_service`
	- `audio_session`
	- `just_audio_background`
- Storage:
	- Drift (`drift`, `drift_flutter`)
	- SharedPreferences (`shared_preferences`)
- File and metadata:
	- `file_picker`, `permission_handler`, `path_provider`, `path`
	- `audio_metadata_reader`, `mime`
- UI utilities:
	- `dynamic_color`, `google_fonts`, `palette_generator`
- Sensors: `sensors_plus`

## Project Structure

Top-level folders of interest:

```text
lib/
	app/
		app.dart
		router/
		theme/
	core/
		constants/
		utils/
		widgets/
	features/
		audiobooks/
		bookmarks/
		downloads/
		home/
		library/
		onboarding/
		player/
		search/
		settings/
		setup/
		splash/
	shared/
		models/
		providers/
```

Supporting files:

- `pubspec.yaml` - dependencies/assets/fonts
- `analysis_options.yaml` - lint/analyzer config
- `build_debug.sh` - debug build + install + launch script
- `build_install_flutter_device.sh` - target device install script

## Architecture Notes

Current architecture is feature-organized and provider-driven.

- UI and state logic are heavily coordinated in presentation/provider layers.
- Player state is maintained via Riverpod notifier/provider patterns.
- Audio player stream listeners feed position/duration/playback updates.
- App uses shell-based navigation for primary tabs.

Persistence strategy:

- Drift database foundation includes:
	- `library_books`
	- `key_value_entries`
- Migration bootstrap can hydrate from legacy SharedPreferences entries.
- Several providers use dual-write patterns to keep compatibility while transitioning to Drift-backed snapshots.

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `>=3.10.0 <4.0.0`
- Android SDK and platform tools
- Java JDK (project scripts currently reference JDK 21)
- A physical Android device or emulator

### Install Dependencies

```bash
flutter pub get
```

### Run In Debug

```bash
flutter run
```

## Run, Build, Install

### Standard Flutter Commands

```bash
flutter analyze
flutter test
flutter build apk --debug
```

### Repo Scripts

`build_debug.sh`:

- Runs `pub get`
- Builds debug APK
- Detects first connected Android device via `adb`
- Installs APK in place (`adb install -r`)
- Launches app

Run:

```bash
./build_debug.sh
```

`build_install_flutter_device.sh`:

- Detects Flutter Android device (or accepts device id arg)
- Builds latest debug APK
- Installs in place
- Launches app

Run:

```bash
./build_install_flutter_device.sh
# or
./build_install_flutter_device.sh <device_id>
```

## Data And Persistence

Persistent data includes:

- Library items and metadata
- Favorites
- Playback progress
- Bookmarks/clips
- Character notes
- User settings:
	- theme mode
	- skip forward/backward durations
	- global speed/volume
	- selected scan folder path

Practical note:

- Some settings and feature stores use SharedPreferences compatibility paths while Drift migration/backfill is in place.

## Navigation

Primary shell tabs:

- `/home`
- `/library`
- `/search`
- `/settings`

Other key routes:

- Player: `/player/:bookId`
- Chapter list: `/player/:bookId/chapters`
- Bookmarks: `/player/:bookId/bookmarks`
- About: `/settings/about`

Back handling:

- Shell tracks tab navigation history.
- Back first pops nested routes when available.
- If no nested route exists, back navigates to previous tab/history.

## Design System

The app uses Material 3 expressive components and motion patterns.

Current design direction includes:

- Tonal surfaces/cards
- Chip and compact action systems for filtering and controls
- Expressive transitions/reveals
- Strong visual hierarchy in playback and discovery screens

Design reference used in this repository workflow:

- Material Components Android docs: `https://github.com/material-components/material-components-android/tree/master/docs`

## Troubleshooting

### `flutter` command not found

- Ensure Flutter is installed and on `PATH`, or run via absolute binary path.

### Android build issues (`JAVA_HOME`)

- Set a valid JDK and ensure Gradle can access it.

### App installs but does not launch

- Verify package id and connected device:

```bash
adb devices
adb shell monkey -p com.avdibook.app -c android.intent.category.LAUNCHER 1
```

### Analyzer warnings

- Lints are configured in `analysis_options.yaml`.
- Run targeted analysis while iterating:

```bash
flutter analyze lib/features/player/presentation/screens/now_playing_screen.dart
```

## Development Notes

### Lint Configuration

The project uses `flutter_lints` with custom rule preferences, including:

- `prefer_single_quotes`
- `always_use_package_imports`
- `avoid_print`
- `prefer_const_constructors`

See `analysis_options.yaml` for full configuration.

### Testing

- Widget test scaffold exists under `test/`.
- Expand with feature-level tests as architecture evolves.

## Roadmap Ideas

- Full background playback and media controls wiring.
- Offline download management enhancements.
- Advanced library metadata editing.
- Better onboarding and import diagnostics.
- Expanded automated test coverage (providers, player flows, routing/back behavior).

---

If you are contributing, open a PR with a clear scope and include before/after notes for UI changes and route/state behavior changes.
