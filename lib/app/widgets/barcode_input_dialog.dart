import 'package:flutter/material.dart';

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
  final useFullscreen = useFullscreenFormLayout(context);
  final navigator = Navigator.of(context);

  if (useFullscreen) {
    return navigator.push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) {
          return KeyboardAwareFormScaffold(
            title: title,
            child: BpcPanel(
              child: _BarcodeInputForm(
                initialValue: initialValue ?? '',
                helper: helper,
                confirmLabel: confirmLabel,
              ),
            ),
          );
        },
      ),
    );
  }

  return showDialog<String>(
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
          child: _BarcodeInputForm(
            initialValue: initialValue ?? '',
            helper: helper,
            confirmLabel: confirmLabel,
          ),
        ),
      );
    },
  );
}

class _BarcodeInputForm extends StatefulWidget {
  const _BarcodeInputForm({
    required this.initialValue,
    required this.helper,
    required this.confirmLabel,
  });

  final String initialValue;
  final String helper;
  final String confirmLabel;

  @override
  State<_BarcodeInputForm> createState() => _BarcodeInputFormState();
}

class _BarcodeInputFormState extends State<_BarcodeInputForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
      child: Form(
        key: _formKey,
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
                        widget.helper,
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
                focusNode: _focusNode,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Codigo de barras',
                    hintText: 'Ej. 7791234500011 o ABC123',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                  onTapOutside: (_) => _focusNode.unfocus(),
                  validator: (value) {
                    if (CommerceStore.normalizeBarcode(value) == null) {
                      return 'Ingresa un codigo valido.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
              if (compact) ...[
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(widget.confirmLabel),
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
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.search_rounded),
                      label: Text(widget.confirmLabel),
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
    Navigator.of(context).pop(CommerceStore.normalizeBarcode(_controller.text));
  }
}
