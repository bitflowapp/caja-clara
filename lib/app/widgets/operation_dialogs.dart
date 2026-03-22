import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/text_field_selection.dart';
import 'input_shortcuts.dart';

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
}) async {
  final controller = TextEditingController(
    text: initialValue == null ? '' : initialValue.toString(),
  );
  final focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();
  selectAllTextOnFocus(focusNode, controller);

  final result = await showDialog<int>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      void submit() {
        if (!formKey.currentState!.validate()) {
          return;
        }
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop(_parseInt(controller.text));
      }

      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(),
        onSave: submit,
        child: AlertDialog(
          insetPadding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          scrollable: true,
          title: Text(title),
          content: Form(
            key: formKey,
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (helper != null) ...[
                    Text(helper),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(labelText: label),
                    onTapOutside: (_) => focusNode.unfocus(),
                    onFieldSubmitted: (_) => submit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Completa este campo.';
                      }
                      final parsed = _parseInt(value);
                      if (parsed <= 0) {
                        return 'Ingresa un valor mayor a 0.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(onPressed: submit, child: Text(confirmLabel)),
          ],
        ),
      );
    },
  );

  controller.dispose();
  focusNode.dispose();
  return result;
}

int _parseInt(String? value) {
  final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return -1;
  }
  return int.tryParse(normalized) ?? -1;
}
