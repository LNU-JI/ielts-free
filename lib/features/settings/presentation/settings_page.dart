import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/utils/date_utils.dart';
import 'package:ielts_free/features/settings/application/settings_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Settings (desktop shell route `/settings`).
///
/// V0.1 keeps this screen minimal: study goal, appearance, data actions and the
/// About / privacy / license entries (PRD §4.2 / §6.2).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSettingsState> async =
        ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (AppSettingsState state) => _SettingsBody(state: state),
      ),
    );
  }
}

/// The scrollable settings content.
class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.state});

  final AppSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController controller =
        ref.read(settingsControllerProvider.notifier);

    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.settingsSaveFailed)),
          );
        }
      }
    }

    return ContentContainer(
      maxWidth: 720,
      child: ListView(
        children: <Widget>[
          _Section(
            title: AppStrings.settingsSectionGoal,
            children: <Widget>[
              _ChipRow(
                label: AppStrings.settingsTargetBand,
                values: SettingsController.targetBandPresets,
                isSelected: (double v) => state.targetBand == v,
                labelOf: (double v) => v.toStringAsFixed(1),
                onSelected: (double v) =>
                    guard(() => controller.setTargetBand(v)),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: AppStrings.settingsExamDate,
                value: state.examDate ?? AppStrings.notSet,
                onTap: () => _pickExamDate(context, controller),
                trailing: state.examDate == null
                    ? null
                    : IconButton(
                        tooltip: AppStrings.settingsExamDateClear,
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            guard(() => controller.setExamDate(null)),
                      ),
              ),
              const Divider(height: AppSpacing.xl),
              _ChipRow(
                label: AppStrings.settingsDailyStudyTime,
                values: SettingsController.dailyMinutePresets,
                isSelected: (int v) => state.dailyStudyMinutes == v,
                labelOf: (int v) => '$v ${AppStrings.minutesWord}',
                onSelected: (int v) =>
                    guard(() => controller.setDailyStudyMinutes(v)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: AppStrings.settingsSectionAppearance,
            children: <Widget>[
              _ChipRow(
                label: AppStrings.settingsDarkMode,
                values: const <ThemeMode>[
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ],
                isSelected: (ThemeMode v) => state.themeMode == v,
                labelOf: _themeModeLabel,
                onSelected: (ThemeMode v) =>
                    guard(() => controller.setThemeMode(v)),
              ),
              const Divider(height: AppSpacing.xl),
              _ChipRow(
                label: AppStrings.settingsFontSize,
                values: SettingsController.fontScalePresets,
                isSelected: (double v) => (state.fontScale - v).abs() < 0.001,
                labelOf: _fontScaleLabel,
                onSelected: (double v) =>
                    guard(() => controller.setFontScale(v)),
              ),
              const Divider(height: AppSpacing.xl),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.settingsSound),
                value: state.soundEnabled,
                onChanged: (bool v) =>
                    guard(() => controller.setSoundEnabled(v)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: AppStrings.settingsSectionData,
            children: <Widget>[
              _Row(
                label: AppStrings.settingsExportData,
                value: AppStrings.settingsExportDataSubtitle,
                onTap: () => _export(context, controller),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: AppStrings.settingsDeleteData,
                value: AppStrings.settingsDeleteDataSubtitle,
                destructive: true,
                onTap: () => _delete(context, controller),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: AppStrings.settingsSectionAbout,
            children: <Widget>[
              _Row(
                label: AppStrings.aboutTitle,
                value: AppStrings.settingsAboutSubtitle,
                onTap: () => context.go(AppRoutes.about),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: AppStrings.settingsPrivacy,
                onTap: () => _showText(
                  context,
                  AppStrings.settingsPrivacy,
                  AppStrings.privacySummary,
                ),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: AppStrings.settingsLicense,
                onTap: () => _showText(
                  context,
                  AppStrings.settingsLicense,
                  AppStrings.licenseSummary,
                ),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: AppStrings.settingsOpenSource,
                onTap: () => _showText(
                  context,
                  AppStrings.settingsOpenSource,
                  AppStrings.openSourceSummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              '${AppStrings.appName} · v${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.caption.copyWith(
                    color: context.palette.muted,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // --- interactions -------------------------------------------------------

  Future<void> _pickExamDate(
    BuildContext context,
    SettingsController controller,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      await controller.setExamDate(AppDateUtils.localDateString(picked));
    }
  }

  Future<void> _export(BuildContext context, SettingsController controller) async {
    try {
      final String path = await controller.exportData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.settingsExportSuccess}$path')),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.settingsExportFailed)),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, SettingsController controller) async {
    final bool first = await _confirm(
      context,
      AppStrings.settingsDeleteConfirmTitle,
      AppStrings.settingsDeleteConfirmMessage,
    );
    if (!first || !context.mounted) {
      return;
    }
    final bool second = await _confirm(
      context,
      AppStrings.settingsDeleteConfirmTitle,
      AppStrings.settingsDeleteConfirmStep2,
    );
    if (!second || !context.mounted) {
      return;
    }
    try {
      await controller.deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.settingsDeleteSuccess)),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.settingsDeleteFailed)),
        );
      }
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.settingsDeleteAction),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showText(
    BuildContext context,
    String title,
    String body,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  // --- labels -------------------------------------------------------------

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return AppStrings.settingsThemeSystem;
      case ThemeMode.light:
        return AppStrings.settingsThemeLight;
      case ThemeMode.dark:
        return AppStrings.settingsThemeDark;
    }
  }

  String _fontScaleLabel(double scale) {
    if (scale < 0.95) {
      return AppStrings.settingsFontSmall;
    }
    if (scale < 1.1) {
      return AppStrings.settingsFontDefault;
    }
    if (scale < 1.25) {
      return AppStrings.settingsFontLarge;
    }
    return AppStrings.settingsFontXLarge;
  }
}

/// A titled card grouping related rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// A labelled row with a value and an optional trailing widget.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color labelColor =
        destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(color: labelColor),
                  ),
                  if (value != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.palette.muted,
              ),
          ],
        ),
      ),
    );
  }
}

/// A labelled set of single-select chips.
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.isSelected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final bool Function(T value) isSelected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final T value in values)
              ChoiceChip(
                label: Text(labelOf(value)),
                selected: isSelected(value),
                onSelected: (_) => onSelected(value),
                labelStyle: theme.textTheme.bodySmall,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
