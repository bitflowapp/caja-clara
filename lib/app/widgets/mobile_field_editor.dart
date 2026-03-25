import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyboard_aware_form.dart';

class MobileFieldEditorController {
  Future<void> Function()? _open;

  Future<void> open() async {
    final open = _open;
    if (open == null) {
      return;
    }
    await open();
  }

  void _attach(Future<void> Function() open) {
    _open = open;
  }

  void _detach() {
    _open = null;
  }
}

bool useMobileFieldEditor(
  BuildContext context, {
  double breakpoint = kMobileFormBreakpoint,
}) {
  if (MediaQuery.sizeOf(context).width >= breakpoint) {
    return false;
  }

  if (kIsWeb) {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class MobileFieldEditorFormField extends StatefulWidget {
  const MobileFieldEditorFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.editorContext,
    this.hintText,
    this.helperText,
    this.emptyDisplayText,
    this.prefixText,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.displayValueBuilder,
    this.suffixBuilder,
    this.supportingBuilder,
    this.enabled = true,
    this.confirmLabel = 'Confirmar',
    this.editorController,
    this.nextEditorController,
    this.nextFieldLabel,
  });

  final TextEditingController controller;
  final String labelText;
  final String? editorContext;
  final String? hintText;
  final String? helperText;
  final String? emptyDisplayText;
  final String? prefixText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final String Function(String value)? displayValueBuilder;
  final Widget Function(TextEditingController controller)? suffixBuilder;
  final Widget Function()? supportingBuilder;
  final bool enabled;
  final String confirmLabel;
  final MobileFieldEditorController? editorController;
  final MobileFieldEditorController? nextEditorController;
  final String? nextFieldLabel;

  @override
  State<MobileFieldEditorFormField> createState() =>
      _MobileFieldEditorFormFieldState();
}

class _MobileFieldEditorFormFieldState
    extends State<MobileFieldEditorFormField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    widget.editorController?._attach(_openFromController);
  }

  @override
  void didUpdateWidget(covariant MobileFieldEditorFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorController != widget.editorController) {
      oldWidget.editorController?._detach();
      widget.editorController?._attach(_openFromController);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fieldKey.currentState?.didChange(widget.controller.text);
    });
  }

  @override
  void dispose() {
    widget.editorController?._detach();
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _fieldKey.currentState?.didChange(widget.controller.text);
    setState(() {});
  }

  Future<void> _openFromController() async {
    final field = _fieldKey.currentState;
    if (!mounted || field == null || !widget.enabled) {
      return;
    }
    await _openEditor(context, field);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: widget.validator,
      enabled: widget.enabled,
      builder: (field) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final value = widget.controller.text;
        final hasValue = value.trim().isNotEmpty;
        final displayValue = hasValue
            ? (widget.displayValueBuilder?.call(value) ??
                  '${widget.prefixText ?? ''}$value')
            : (widget.emptyDisplayText ??
                  widget.hintText ??
                  'Toca para editar');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.enabled
                    ? () => _openEditor(context, field)
                    : null,
                child: InputDecorator(
                  isFocused: false,
                  isHovering: false,
                  isEmpty: !hasValue,
                  decoration: InputDecoration(
                    labelText: widget.labelText,
                    helperText: field.errorText == null
                        ? widget.helperText
                        : null,
                    errorText: field.errorText,
                    hintText: widget.hintText,
                    suffixIcon: const Icon(Icons.edit_rounded),
                  ),
                  child: Text(
                    displayValue,
                    maxLines: widget.maxLines > 1 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: hasValue
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    FormFieldState<String> field,
  ) async {
    final result = await showMobileFieldEditor(
      context,
      title: widget.labelText,
      contextLabel: widget.editorContext,
      initialValue: widget.controller.text,
      hintText: widget.hintText,
      helperText: widget.helperText,
      prefixText: widget.prefixText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      suffixBuilder: widget.suffixBuilder,
      supportingBuilder: widget.supportingBuilder,
      confirmLabel: widget.confirmLabel,
      nextFieldLabel: widget.nextFieldLabel,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.value != widget.controller.text) {
      widget.controller.value = widget.controller.value.copyWith(
        text: result.value,
        selection: TextSelection.collapsed(offset: result.value.length),
        composing: TextRange.empty,
      );
    }

    field.didChange(widget.controller.text);
    field.validate();
    if (result.openNext && widget.nextEditorController != null) {
      await widget.nextEditorController!.open();
    }
  }
}

class MobileFieldEditorResult {
  const MobileFieldEditorResult({required this.value, this.openNext = false});

  final String value;
  final bool openNext;
}

Future<MobileFieldEditorResult?> showMobileFieldEditor(
  BuildContext context, {
  required String title,
  String? contextLabel,
  required String initialValue,
  String? hintText,
  String? helperText,
  String? prefixText,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int minLines = 1,
  int maxLines = 1,
  TextInputAction? textInputAction,
  String? Function(String?)? validator,
  Widget Function(TextEditingController controller)? suffixBuilder,
  Widget Function()? supportingBuilder,
  String confirmLabel = 'Confirmar',
  String? nextFieldLabel,
}) {
  return showModalBottomSheet<MobileFieldEditorResult>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) {
      return _MobileFieldEditorSheet(
        title: title,
        contextLabel: contextLabel,
        initialValue: initialValue,
        hintText: hintText,
        helperText: helperText,
        prefixText: prefixText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: textInputAction,
        validator: validator,
        suffixBuilder: suffixBuilder,
        supportingBuilder: supportingBuilder,
        confirmLabel: confirmLabel,
        nextFieldLabel: nextFieldLabel,
      );
    },
  );
}

class _MobileFieldEditorSheet extends StatefulWidget {
  const _MobileFieldEditorSheet({
    required this.title,
    required this.initialValue,
    this.contextLabel,
    this.hintText,
    this.helperText,
    this.prefixText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.validator,
    this.suffixBuilder,
    this.supportingBuilder,
    required this.confirmLabel,
    this.nextFieldLabel,
  });

  final String title;
  final String initialValue;
  final String? contextLabel;
  final String? hintText;
  final String? helperText;
  final String? prefixText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget Function(TextEditingController controller)? suffixBuilder;
  final Widget Function()? supportingBuilder;
  final String confirmLabel;
  final String? nextFieldLabel;

  @override
  State<_MobileFieldEditorSheet> createState() =>
      _MobileFieldEditorSheetState();
}

class _MobileFieldEditorSheetState extends State<_MobileFieldEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _hasUnsavedChanges => _controller.text != widget.initialValue;
  bool get _supportsSequentialAdvance {
    if (widget.nextFieldLabel == null || widget.maxLines > 1) {
      return false;
    }
    switch (widget.textInputAction) {
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
        return false;
      default:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final effectiveTextInputAction =
        widget.textInputAction ??
        (_supportsSequentialAdvance
            ? TextInputAction.next
            : widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top -
        24;
    final maxHeight = availableHeight
        .clamp(320.0, mediaQuery.size.height - mediaQuery.padding.top - 12)
        .toDouble();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleCloseRequested();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SafeArea(
          top: true,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: maxHeight,
                ),
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 24,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  if (widget.contextLabel != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.contextLabel!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                  if (_supportsSequentialAdvance) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sigue con ${widget.nextFieldLabel}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _handleCloseRequested,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Cerrar',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    autofocus: true,
                                    keyboardType: widget.keyboardType,
                                    inputFormatters: widget.inputFormatters,
                                    textCapitalization:
                                        widget.textCapitalization,
                                    minLines: widget.minLines,
                                    maxLines: widget.maxLines,
                                    textInputAction: effectiveTextInputAction,
                                    style: theme.textTheme.titleMedium,
                                    decoration: InputDecoration(
                                      labelText: widget.title,
                                      hintText: widget.hintText,
                                      helperText: widget.helperText,
                                      prefixText: widget.prefixText,
                                      alignLabelWithHint: widget.maxLines > 1,
                                      contentPadding: const EdgeInsets.fromLTRB(
                                        16,
                                        18,
                                        16,
                                        18,
                                      ),
                                      suffixIcon: widget.suffixBuilder?.call(
                                        _controller,
                                      ),
                                    ),
                                    onTapOutside: (_) => FocusManager
                                        .instance
                                        .primaryFocus
                                        ?.unfocus(),
                                    onFieldSubmitted: (_) {
                                      if (widget.maxLines > 1) {
                                        return;
                                      }
                                      _confirm(
                                        openNext:
                                            effectiveTextInputAction ==
                                                TextInputAction.next &&
                                            _supportsSequentialAdvance,
                                      );
                                    },
                                    validator: widget.validator,
                                  ),
                                  if (widget.supportingBuilder != null) ...[
                                    const SizedBox(height: 8),
                                    widget.supportingBuilder!.call(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 440;
                            final cancelButton = TextButton(
                              onPressed: _handleCloseRequested,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(96, 52),
                              ),
                              child: const Text('Cancelar'),
                            );
                            final confirmButton = FilledButton(
                              onPressed: _confirm,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(120, 52),
                              ),
                              child: Text(widget.confirmLabel),
                            );
                            final nextButton = !_supportsSequentialAdvance
                                ? null
                                : OutlinedButton.icon(
                                    onPressed: () => _confirm(openNext: true),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(160, 52),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Guardar y seguir'),
                                  );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  confirmButton,
                                  if (nextButton != null) ...[
                                    const SizedBox(height: 10),
                                    nextButton,
                                  ],
                                  const SizedBox(height: 10),
                                  cancelButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                const Spacer(),
                                cancelButton,
                                if (nextButton != null) ...[
                                  const SizedBox(width: 12),
                                  nextButton,
                                ],
                                const SizedBox(width: 12),
                                confirmButton,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCloseRequested() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_PendingEditAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hay cambios sin guardar'),
          content: Text('Todavia no aplicaste los cambios en ${widget.title}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PendingEditAction.keepEditing),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PendingEditAction.discard),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PendingEditAction.save),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    switch (action) {
      case _PendingEditAction.save:
        await _confirm();
        break;
      case _PendingEditAction.discard:
        Navigator.of(context).pop();
        break;
      case _PendingEditAction.keepEditing:
      case null:
        break;
    }
  }

  Future<void> _confirm({bool openNext = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(MobileFieldEditorResult(value: _controller.text, openNext: openNext));
  }
}

enum _PendingEditAction { save, discard, keepEditing }
