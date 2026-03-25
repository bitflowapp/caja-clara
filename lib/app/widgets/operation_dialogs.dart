import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/text_field_selection.dart';
import 'commerce_components.dart';
import 'input_shortcuts.dart';
import 'keyboard_aware_form.dart';

Future<bool> showDangerConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(false),
        child: AlertDialog(
          insetPadding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}

Future<int?> showAmountEntryDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? helper,
  int? initialValue,
  bool allowZero = false,
}) async {
  final useFullscreen = useFullscreenFormLayout(context);
  final navigator = Navigator.of(context);

  if (useFullscreen) {
    return navigator.push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) {
          return KeyboardAwareFormScaffold(
            title: title,
            child: BpcPanel(
              child: _AmountEntryForm(
                label: label,
                confirmLabel: confirmLabel,
                helper: helper,
                initialValue: initialValue,
                allowZero: allowZero,
              ),
            ),
          );
        },
      ),
    );
  }

  return showDialog<int>(
    context: context,
    useSafeArea: true,
    builder: (dialogContext) {
      return AlertDialog(
        insetPadding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          16 + MediaQuery.viewInsetsOf(dialogContext).bottom,
        ),
        scrollable: true,
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _AmountEntryForm(
            label: label,
            confirmLabel: confirmLabel,
            helper: helper,
            initialValue: initialValue,
            allowZero: allowZero,
          ),
        ),
      );
    },
  );
}

class _AmountEntryForm extends StatefulWidget {
  const _AmountEntryForm({
    required this.label,
    required this.confirmLabel,
    this.helper,
    this.initialValue,
    required this.allowZero,
  });

  final String label;
  final String confirmLabel;
  final String? helper;
  final int? initialValue;
  final bool allowZero;

  @override
  State<_AmountEntryForm> createState() => _AmountEntryFormState();
}

class _AmountEntryFormState extends State<_AmountEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : widget.initialValue.toString(),
    );
    selectAllTextOnFocus(_focusNode, _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return InputShortcutScope(
      onCancel: () => Navigator.of(context).pop(),
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.helper != null) ...[
                Text(widget.helper!),
                const SizedBox(height: 12),
              ],
              EnsureVisibleWhenFocused(
                focusNode: _focusNode,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: widget.label),
                  onTapOutside: (_) => _focusNode.unfocus(),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Completa este campo.';
                    }
                    final parsed = _parseInt(value);
                    if (parsed < 0 || (!widget.allowZero && parsed == 0)) {
                      return widget.allowZero
                          ? 'Ingresa un valor igual o mayor a 0.'
                          : 'Ingresa un valor mayor a 0.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (compact) ...[
                FilledButton(
                  onPressed: _submit,
                  child: Text(widget.confirmLabel),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ] else
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(widget.confirmLabel),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_parseInt(_controller.text));
  }
}

int _parseInt(String? value) {
  final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return -1;
  }
  return int.tryParse(normalized) ?? -1;
}
