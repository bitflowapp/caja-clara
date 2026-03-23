import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/commerce_store.dart';
import '../utils/text_field_selection.dart';
import 'commerce_components.dart';
import 'input_shortcuts.dart';
import 'keyboard_aware_form.dart';

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

  Widget buildForm(BuildContext context, VoidCallback submit) {
    return InputShortcutScope(
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
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
              EnsureVisibleWhenFocused(
                focusNode: focusNode,
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
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
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final cancelButton = TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  );
                  final submitButton = FilledButton.icon(
                    onPressed: submit,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(confirmLabel),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        submitButton,
                        const SizedBox(height: 10),
                        cancelButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Spacer(),
                      cancelButton,
                      const SizedBox(width: 10),
                      submitButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void submit(BuildContext context) {
    if (!formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(CommerceStore.normalizeBarcode(controller.text));
  }

  final useFullscreen = useFullscreenFormLayout(context);
  final NavigatorState navigator = Navigator.of(context);
  final String? result;
  if (useFullscreen) {
    result = await navigator.push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (pageContext) {
          return KeyboardAwareFormScaffold(
            title: title,
            child: BpcPanel(
              child: buildForm(pageContext, () => submit(pageContext)),
            ),
          );
        },
      ),
    );
  } else {
    result = await showDialog<String>(
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
          content: buildForm(dialogContext, () => submit(dialogContext)),
        );
      },
    );
  }

  controller.dispose();
  focusNode.dispose();
  return result;
}
