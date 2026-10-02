import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/plan_type.dart';

/// Plan-period selector: 7 / 30 / 60 / 90 / Custom (PRD §4.7).
class PlanSelector extends StatelessWidget {
  const PlanSelector({
    super.key,
    required this.period,
    required this.customDays,
    required this.onSelected,
    this.enabled = true,
  });

  /// The currently selected period.
  final PlanType period;

  /// Number of days used when [period] is [PlanType.custom].
  final int customDays;

  /// Called with the chosen period (and, for custom, the entered day count).
  final void Function(PlanType period, int? customDays) onSelected;

  /// Whether interaction is allowed.
  final bool enabled;

  /// The selectable presets.
  static const List<PlanType> presets = <PlanType>[
    PlanType.day7,
    PlanType.day30,
    PlanType.day60,
    PlanType.day90,
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final PlanType type in presets)
          ChoiceChip(
            label: Text('${type.days} ${AppStrings.daysWord}'),
            selected: period == type,
            onSelected: enabled ? (_) => onSelected(type, null) : null,
            labelStyle: theme.textTheme.bodyMedium,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        ChoiceChip(
          label: Text(
            period == PlanType.custom
                ? '${AppStrings.studyPlanCustom} · $customDays ${AppStrings.daysWord}'
                : AppStrings.studyPlanCustom,
          ),
          selected: period == PlanType.custom,
          onSelected: enabled ? (_) => _pickCustom(context) : null,
          labelStyle: theme.textTheme.bodyMedium,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ],
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final int? days = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _CustomDaysDialog(initial: customDays),
    );
    if (days != null) {
      onSelected(PlanType.custom, days);
    }
  }
}

/// A small dialog asking for a custom plan length.
class _CustomDaysDialog extends StatefulWidget {
  const _CustomDaysDialog({required this.initial});

  final int initial;

  @override
  State<_CustomDaysDialog> createState() => _CustomDaysDialogState();
}

class _CustomDaysDialogState extends State<_CustomDaysDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(parsed.clamp(1, 365).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.studyPlanCustomDaysTitle),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: AppStrings.studyPlanCustomDaysHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(AppStrings.confirm),
        ),
      ],
    );
  }
}
