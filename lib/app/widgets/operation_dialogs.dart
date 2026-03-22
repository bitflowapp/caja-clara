import 'package:flutter/material.dart';

import '../utils/text_field_selection.dart';

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
      return AlertDialog(
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
      return AlertDialog(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (helper != null) ...[Text(helper), const SizedBox(height: 12)],
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: label),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(context).pop(_parseInt(controller.text));
            },
            child: Text(confirmLabel),
          ),
        ],
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
