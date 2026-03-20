import 'package:flutter/material.dart';

Future<bool> showDangerConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
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
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
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
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(labelText: label),
                validator: (value) {
                  final parsed = _parseInt(value);
                  if (parsed < 0) {
                    return 'Ingresa un valor valido.';
                  }
                  if (value == null || value.trim().isEmpty) {
                    return 'Completa este campo.';
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
  return result;
}

int _parseInt(String? value) {
  final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return -1;
  }
  return int.tryParse(normalized) ?? -1;
}
