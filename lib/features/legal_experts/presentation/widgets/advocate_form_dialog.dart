import 'package:flutter/material.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// A bounded editor for one backend record. It closes only after confirmation
/// from the repository; a failed save keeps entered values available for retry.
class AdvocateFormField {
  const AdvocateFormField(this.name, this.label,
      {this.initial = '',
      this.required = false,
      this.maxLength = 200,
      this.lines = 1,
      this.keyboard,
      this.options,
      this.validate});
  final String name;
  final String label;
  final String initial;
  final bool required;
  final int maxLength;
  final int lines;
  final TextInputType? keyboard;
  final Map<String, String>? options;
  final bool Function(String value)? validate;
}

class AdvocateFormDialog extends StatefulWidget {
  const AdvocateFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.notice,
    this.submitLabel,
  });
  final String title;
  final List<AdvocateFormField> fields;
  final Future<Failure?> Function(Map<String, String> values) onSave;
  final String? notice;
  final String? submitLabel;

  static Future<bool> show(BuildContext context,
          {required String title,
          required List<AdvocateFormField> fields,
          required Future<Failure?> Function(Map<String, String>) onSave,
          String? notice,
          String? submitLabel}) async =>
      await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AdvocateFormDialog(
              title: title,
              fields: fields,
              onSave: onSave,
              notice: notice,
              submitLabel: submitLabel)) ??
      false;

  @override
  State<AdvocateFormDialog> createState() => _AdvocateFormDialogState();
}

class _AdvocateFormDialogState extends State<AdvocateFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.name: TextEditingController(text: field.initial),
  };
  bool _saving = false;
  Failure? _failure;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _form.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    Failure? failure;
    try {
      failure = await widget.onSave({
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      });
    } catch (_) {
      failure = const ServerFailure(message: '');
    }
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failure = _failure;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: AppLayout.formWidth,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.notice case final String notice) ...[
                    Text(notice),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  for (final field in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: field.options != null
                          ? DropdownButtonFormField<String>(
                              key: ValueKey('advocate_field_${field.name}'),
                              initialValue:
                                  field.options?.containsKey(field.initial) ==
                                          true
                                      ? field.initial
                                      : null,
                              isExpanded: true,
                              decoration:
                                  InputDecoration(labelText: field.label),
                              items: [
                                for (final option
                                    in (field.options ?? <String, String>{})
                                        .entries)
                                  DropdownMenuItem(
                                    value: option.key,
                                    child: Text(option.value,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) => _controllers[field.name]?.text =
                                      value ?? '',
                              validator: (value) => field.required &&
                                      (value == null || value.isEmpty)
                                  ? l.advocateRequired
                                  : null,
                            )
                          : TextFormField(
                              key: ValueKey('advocate_field_${field.name}'),
                              controller: _controllers[field.name],
                              enabled: !_saving,
                              maxLength: field.maxLength,
                              minLines: field.lines,
                              maxLines: field.lines,
                              keyboardType: field.keyboard,
                              decoration:
                                  InputDecoration(labelText: field.label),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (field.required && text.isEmpty) {
                                  return l.advocateRequired;
                                }
                                if (field.validate?.call(text) == false) {
                                  return l.advocateInvalid;
                                }
                                return null;
                              },
                            ),
                    ),
                  if (failure != null)
                    Text(failureMessageFor(l, failure.code),
                        key: const ValueKey('advocate_save_error'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: Text(l.profileCancel)),
          FilledButton(
            key: const ValueKey('advocate_save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: AppIconSize.sm,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.submitLabel ?? l.profileSave),
          ),
        ],
      ),
    );
  }
}
