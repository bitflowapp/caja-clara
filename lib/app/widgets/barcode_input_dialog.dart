import 'package:flutter/material.dart';

import '../services/commerce_store.dart';

Future<String?> showBarcodeInputDialog(
  BuildContext context, {
  String? initialValue,
  String title = 'Ingresar codigo',
  String helper = 'Usa el scanner como teclado. Enter confirma.',
  String confirmLabel = 'Buscar producto',
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.keyboard_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        helper,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Codigo de barras',
                  hintText: 'Ej. 7791234500011',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
                validator: (value) {
                  if (CommerceStore.normalizeBarcode(value) == null) {
                    return 'Ingresa un codigo valido.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(CommerceStore.normalizeBarcode(controller.text));
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
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(
                context,
              ).pop(CommerceStore.normalizeBarcode(controller.text));
            },
            icon: const Icon(Icons.search_rounded),
            label: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}
