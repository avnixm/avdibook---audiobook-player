import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:avdibook/core/constants/app_constants.dart';
import 'package:avdibook/core/widgets/expressive_bounce.dart';
import 'package:avdibook/features/setup/presentation/providers/setup_controller.dart';
import 'package:avdibook/shared/providers/app_state_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _skipOptions = [5, 10, 15, 20, 30, 45, 60];
  static const _smartRewindOptions = [0, 3, 5, 7, 10, 15, 20];
  static const _themeLabels = ['System', 'Light', 'Dark'];

  Future<void> _pickOption<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) label,
    required Future<void> Function(T) onSelect,
  }) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: options.map((opt) {
          final isSelected = opt == current;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(opt),
            child: Row(
              children: [
                Expanded(child: Text(label(opt))),
                if (isSelected)
                  Icon(Icons.check_rounded,
                      size: 18,
                      color: Theme.of(ctx).colorScheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && selected != current) {
      await onSelect(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skipFwd = ref.watch(skipForwardSecsProvider);
    final skipBwd = ref.watch(skipBackwardSecsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final speed = ref.watch(globalPlaybackSpeedProvider);
    final trimSilence = ref.watch(trimSilenceProvider);
    final preservePitch = ref.watch(preservePitchProvider);
    final pitch = ref.watch(playbackPitchProvider);
    final smartRewindSecs = ref.watch(smartRewindSecsProvider);
    final volumeBoost = ref.watch(volumeBoostProvider);
    final stereoBalance = ref.watch(stereoBalanceProvider);
    final reducedMotion = ref.watch(reducedMotionProvider);
    final savedFolder = ref.watch(scanFolderPathProvider);
    final setupState = ref.watch(setupControllerProvider);
    final isBusy = setupState.isBusy;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsSection(
                  title: 'Playback',
                  children: [
                    _SettingsTile(
                      icon: Icons.speed_rounded,
                      label: 'Default Speed',
                      value: '${speed % 1 == 0 ? speed.toInt() : speed}×',
                      onTap: isBusy
                          ? null
                          : () => _pickOption<double>(
                                title: 'Default Playback Speed',
                                options: AppDefaults.speedOptions,
                                current: speed,
                                label: (v) =>
                                    '${v % 1 == 0 ? v.toInt() : v}×',
                                onSelect: (v) => ref
                                    .read(globalPlaybackSpeedProvider.notifier)
                                    .set(v),
                              ),
                    ),
                    _SettingsTile(
                      icon: Icons.fast_forward_rounded,
                      label: 'Skip Forward',
                      value: '${skipFwd}s',
                      onTap: isBusy
                          ? null
                          : () => _pickOption<int>(
                                title: 'Skip Forward Duration',
                                options: _skipOptions,
                                current: skipFwd,
                                label: (v) => '${v}s',
                                onSelect: (v) => ref
                                    .read(skipForwardSecsProvider.notifier)
                                    .set(v),
                              ),
                    ),
                    _SettingsTile(
                      icon: Icons.fast_rewind_rounded,
                      label: 'Skip Backward',
                      value: '${skipBwd}s',
                      onTap: isBusy
                          ? null
                          : () => _pickOption<int>(
                                title: 'Skip Backward Duration',
                                options: _skipOptions,
                                current: skipBwd,
                                label: (v) => '${v}s',
                                onSelect: (v) => ref
                                    .read(skipBackwardSecsProvider.notifier)
                                    .set(v),
                              ),
                    ),
                    _SettingsTile(
                      icon: Icons.replay_10_rounded,
                      label: 'Smart Rewind',
                      value: '${smartRewindSecs}s',
                      subtitle: 'When resuming after a pause',
                      onTap: isBusy
                          ? null
                          : () => _pickOption<int>(
                                title: 'Smart Rewind',
                                options: _smartRewindOptions,
                                current: smartRewindSecs,
                                label: (v) => v == 0 ? 'Off' : '${v}s',
                                onSelect: (v) => ref
                                    .read(smartRewindSecsProvider.notifier)
                                    .set(v),
                              ),
                    ),
                    SwitchListTile.adaptive(
                      value: trimSilence,
                      onChanged: isBusy
                          ? null
                          : (value) => ref
                              .read(trimSilenceProvider.notifier)
                              .set(value),
                      title: const Text('Trim silence'),
                      subtitle: const Text(
                        'Auto-skip silent gaps for faster listening.',
                      ),
                      secondary: const Icon(Icons.graphic_eq_rounded),
                    ),
                    SwitchListTile.adaptive(
                      value: preservePitch,
                      onChanged: isBusy
                          ? null
                          : (value) => ref
                              .read(preservePitchProvider.notifier)
                              .set(value),
                      title: const Text('Preserve pitch'),
                      subtitle: const Text(
                        'Keep voice tone natural at different speeds.',
                      ),
                      secondary: const Icon(Icons.tune_rounded),
                    ),
                    _SettingsTile(
                      icon: Icons.multitrack_audio_rounded,
                      label: 'Voice Pitch',
                      value: '${pitch.toStringAsFixed(1)}×',
                      subtitle: preservePitch
                          ? 'Used while preserve pitch is on'
                          : 'Enable preserve pitch to customize',
                      onTap: isBusy
                          ? null
                          : () => _pickOption<double>(
                                title: 'Voice Pitch',
                                options: AppDefaults.pitchOptions,
                                current: pitch,
                                label: (v) => '${v.toStringAsFixed(1)}×',
                                onSelect: (v) => ref
                                    .read(playbackPitchProvider.notifier)
                                    .set(v),
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Appearance',
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_rounded,
                      label: 'Theme',
                      value: _themeLabels[themeMode.clamp(0, 2)],
                      onTap: isBusy
                          ? null
                          : () => _pickOption<int>(
                                title: 'Theme',
                                options: const [0, 1, 2],
                                current: themeMode,
                                label: (v) => _themeLabels[v],
                                onSelect: (v) => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(v),
                              ),
                    ),
                    SwitchListTile.adaptive(
                      value: reducedMotion,
                      onChanged: isBusy
                          ? null
                          : (value) => ref
                              .read(reducedMotionProvider.notifier)
                              .set(value),
                      title: const Text('Reduced motion'),
                      subtitle: const Text(
                        'Use fewer movement animations across the app.',
                      ),
                      secondary: const Icon(Icons.motion_photos_off_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Audio Effects',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.volume_up_rounded),
                      title: const Text('Volume boost'),
                      subtitle: Text('${(volumeBoost * 100).round()}%'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: volumeBoost,
                        onChanged: isBusy
                            ? null
                            : (value) => ref
                                .read(volumeBoostProvider.notifier)
                                .set(value),
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: '${(volumeBoost * 100).round()}%',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.surround_sound_rounded),
                      title: const Text('Stereo balance'),
                      subtitle: Text(
                        stereoBalance == 0
                            ? 'Centered'
                            : stereoBalance < 0
                                ? 'Left ${(stereoBalance.abs() * 100).round()}%'
                                : 'Right ${(stereoBalance * 100).round()}%',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: stereoBalance,
                        onChanged: isBusy
                            ? null
                            : (value) => ref
                                .read(stereoBalanceProvider.notifier)
                                .set(value),
                        min: -1,
                        max: 1,
                        divisions: 20,
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.equalizer_rounded),
                      title: Text('Equalizer'),
                      subtitle: Text(
                        'Coming next: native DSP presets and per-band controls.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Library',
                  children: [
                    _SettingsTile(
                      icon: Icons.folder_rounded,
                      label: 'Add Folder',
                      subtitle: savedFolder != null
                          ? savedFolder.split('/').last
                          : null,
                      onTap: isBusy
                          ? null
                          : () => ref
                              .read(setupControllerProvider.notifier)
                              .importDirectory(),
                    ),
                    _SettingsTile(
                      icon: Icons.refresh_rounded,
                      label: 'Rescan Library',
                      subtitle: savedFolder == null
                          ? 'No folder selected yet'
                          : null,
                      onTap: isBusy
                          ? null
                          : () async {
                              final controller =
                                  ref.read(setupControllerProvider.notifier);
                              final done =
                                  await controller.rescanLibrary();
                              if (!done && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'No folder saved. Use "Add Folder" first.'),
                                  ),
                                );
                              } else if (done && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Library rescanned.')),
                                );
                              }
                            },
                    ),
                  ],
                ),
                if (setupState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      setupState.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                ],
                if (isBusy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'About',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About AvdiBook',
                      value: '0.1.0',
                      onTap: () => context.push(AppRoutes.about),
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ExpressiveBounce(
      enabled: onTap != null,
      child: ListTile(
        leading:
            Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.7)),
        title: Text(label, style: tt.bodyMedium),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)))
            : null,
        trailing: value != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                  ],
                ],
              )
            : (onTap == null
                ? null
                : Icon(Icons.chevron_right_rounded,
                    size: 18, color: cs.onSurface.withValues(alpha: 0.35))),
        enabled: onTap != null,
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}
