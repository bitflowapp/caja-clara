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
}) async {
  final controller = TextEditingController(
    text: initialValue == null ? '' : initialValue.toString(),
  );
  final focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();
  selectAllTextOnFocus(focusNode, controller);

  Widget buildForm(BuildContext context, VoidCallback submit) {
    return InputShortcutScope(
      onCancel: () => Navigator.of(context).pop(),
      onSave: submit,
      child: Form(
        key: formKey,
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (helper != null) ...[Text(helper), const SizedBox(height: 12)],
              EnsureVisibleWhenFocused(
                focusNode: focusNode,
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
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
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final cancelButton = TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  );
                  final submitButton = FilledButton(
                    onPressed: submit,
                    child: Text(confirmLabel),
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
    Navigator.of(context).pop(_parseInt(controller.text));
  }

  final useFullscreen = useFullscreenFormLayout(context);
  final NavigatorState navigator = Navigator.of(context);
  final int? result;
  if (useFullscreen) {
    result = await navigator.push<int>(
      MaterialPageRoute<int>(
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
    result = await showDialog<int>(
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

int _parseInt(String? value) {
  final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return -1;
  }
  return int.tryParse(normalized) ?? -1;
}
