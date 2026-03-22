import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/commerce_store.dart';
import '../utils/text_field_selection.dart';
import 'input_shortcuts.dart';

Future<String?> showBarcodeInputDialog(
  BuildContext context, {
  String? initialValue,
  String title = 'Ingresar codigo',
  String helper = 'Escanea o pega el codigo. Enter busca al instante.',
  String confirmLabel = 'Buscar producto',
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();
  selectAllTextOnFocus(focusNode, controller);

  final result = await showDialog<String>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      void submit() {
        if (!formKey.currentState!.validate()) {
          return;
        }
        FocusScope.of(context).unfocus();
        Navigator.of(
          context,
        ).pop(CommerceStore.normalizeBarcode(controller.text));
      }

      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(),
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
                    focusNode: focusNode,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Codigo de barras',
                      hintText: 'Ej. 7791234500011',
                      prefixIcon: Icon(Icons.qr_code_2_rounded),
                    ),
                    onTapOutside: (_) => focusNode.unfocus(),
                    validator: (value) {
                      if (CommerceStore.normalizeBarcode(value) == null) {
                        return 'Ingresa un codigo valido.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => submit(),
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
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.search_rounded),
              label: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );

  controller.dispose();
  focusNode.dispose();
  return result;
}
