import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/formatters.dart';
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
      final scheme = Theme.of(context).colorScheme;
      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(false),
        child: BpcDialogFrame(
          maxWidth: 520,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BpcDialogHeader(
                icon: Icons.warning_amber_rounded,
                title: title,
                subtitle: 'Si confirmas, se aplica ahora.',
                badgeLabel: 'Confirmacion',
                badgeColor: scheme.error,
                onClose: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 18),
              BpcPanel(
                color: scheme.errorContainer.withValues(alpha: 0.38),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B2216),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final cancelButton = TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  );
                  final confirmButton = FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        confirmButton,
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
                      confirmButton,
                    ],
                  );
                },
              ),
            ],
          ),
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
      return BpcDialogFrame(
        maxWidth: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BpcDialogHeader(
              icon: Icons.point_of_sale_rounded,
              title: title,
              subtitle: 'Escribe el monto y guarda.',
              badgeLabel: 'Movimiento de caja',
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
            const SizedBox(height: 18),
            _AmountEntryForm(
              label: label,
              confirmLabel: confirmLabel,
              helper: helper,
              initialValue: initialValue,
              allowZero: allowZero,
            ),
          ],
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
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final parsedValue = _parseInt(_controller.text);
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
              BpcPanel(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(parsedValue < 0 ? 0 : parsedValue),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (widget.helper != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.helper!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              EnsureVisibleWhenFocused(
                focusNode: _focusNode,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    prefixText: '\$ ',
                    helperText: 'Solo numeros en pesos.',
                  ),
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

  void _handleChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }
}

int _parseInt(String? value) {
  final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return -1;
  }
  return int.tryParse(normalized) ?? -1;
}
