import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/mobile_field_editor.dart';

/// Pantalla Nueva venta — flujo único de venta rápida (venta libre).
///
/// Se cargan descripción, cantidad y precio a mano. Al guardar, la caja del
/// día se actualiza sola. No depende del catálogo de productos.
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  /// Producto opcional para precargar descripción y precio (uso del escáner).
  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _unitPriceFocusNode = FocusNode();
  final _paymentFocusNode = FocusNode();
  final _descriptionEditorController = MobileFieldEditorController();
  final _quantityEditorController = MobileFieldEditorController();
  final _unitPriceEditorController = MobileFieldEditorController();

  String _paymentMethod = 'Efectivo';
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _didSeedDefaults = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProduct;
    if (initial != null) {
      _descriptionController.text = initial.name;
      if (initial.pricePesos > 0) {
        _unitPriceController.text = initial.pricePesos.toString();
      }
    } else if (InputShortcutScope.demoAutofillEnabled) {
      _descriptionController.text = 'Café frío';
      _quantityController.text = '2';
      _unitPriceController.text = '1800';
    }
    _descriptionController.addListener(_handleDraftChanged);
    _quantityController.addListener(_handleDraftChanged);
    _unitPriceController.addListener(_handleDraftChanged);
    selectAllTextOnFocus(_quantityFocusNode, _quantityController);
    selectAllTextOnFocus(_unitPriceFocusNode, _unitPriceController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedDefaults) {
      return;
    }
    final store = CommerceScope.of(context);
    _paymentMethod = store.lastSalePaymentMethod ?? 'Efectivo';
    _didSeedDefaults = true;
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    _quantityController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    _unitPriceController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    _descriptionFocusNode.dispose();
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();
    _paymentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    final useMobileEditor = useMobileFieldEditor(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final quantity = _parseInt(_quantityController.text);
          final description = _descriptionController.text.trim();
          final unitPrice = _parseInt(_unitPriceController.text);
          final total = unitPrice * quantity;
          final saleWarning = store.freeSaleReadinessMessage(
            description: description,
            quantityUnits: quantity,
            unitPricePesos: unitPrice,
          );
          final canSaveSale = !_saving && saleWarning == null;

          return KeyboardAwarePageBody(
            child: InputShortcutScope(
              onSave: _saving ? null : () => _submitSale(store),
              onCancel: _saving ? null : () => Navigator.of(context).maybePop(),
              onFocusSearch: () => _moveFocusTo(
                _descriptionFocusNode,
                controller: _descriptionController,
              ),
              onDemoAutofill: _fillPremiumDemoSale,
              child: BpcPanel(
                child: FocusTraversalGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venta rápida',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cargá una venta rápida. Al guardar, la caja del día se actualiza sola.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: BpcColors.subtleInk),
                        ),
                        const SizedBox(height: 18),
                        _buildDescriptionField(useMobileEditor),
                        const SizedBox(height: 14),
                        _buildFieldsRow(useMobileEditor),
                        const SizedBox(height: 16),
                        _SaleSummary(
                          description: description,
                          quantity: quantity,
                          unitPrice: unitPrice,
                          total: total,
                          warning: saleWarning,
                        ),
                        const SizedBox(height: 18),
                        _buildActions(context, store, canSaveSale),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionField(bool useMobileEditor) {
    if (useMobileEditor) {
      return MobileFieldEditorFormField(
        controller: _descriptionController,
        editorController: _descriptionEditorController,
        nextEditorController: _quantityEditorController,
        nextFieldLabel: 'Cantidad',
        labelText: 'Producto o detalle',
        editorContext: 'Nueva venta',
        hintText: 'Ej. Alfajor, gaseosa, servicio',
        emptyDisplayText: 'Tocá para cargar el detalle',
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        validator: _validateDescription,
      );
    }
    return EnsureVisibleWhenFocused(
      focusNode: _descriptionFocusNode,
      child: TextFormField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        autofocus: true,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.sentences,
        onTapOutside: (_) => _descriptionFocusNode.unfocus(),
        onFieldSubmitted: (_) =>
            _moveFocusTo(_quantityFocusNode, controller: _quantityController),
        decoration: const InputDecoration(
          labelText: 'Producto o detalle',
          hintText: 'Ej. Alfajor, gaseosa, servicio',
          prefixIcon: Icon(Icons.sell_rounded),
        ),
        validator: _validateDescription,
      ),
    );
  }

  Widget _buildFieldsRow(bool useMobileEditor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        const spacing = 12.0;
        final fieldWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: fieldWidth,
              child: _buildQuantityField(useMobileEditor),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildPriceField(useMobileEditor),
            ),
            SizedBox(width: fieldWidth, child: _buildPaymentField()),
          ],
        );
      },
    );
  }

  Widget _buildQuantityField(bool useMobileEditor) {
    if (useMobileEditor) {
      return MobileFieldEditorFormField(
        controller: _quantityController,
        editorController: _quantityEditorController,
        nextEditorController: _unitPriceEditorController,
        nextFieldLabel: 'Precio',
        labelText: 'Cantidad',
        editorContext: 'Nueva venta',
        emptyDisplayText: 'Tocá para cargar la cantidad',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (value) =>
            _parseInt(value) <= 0 ? 'Ingresá una cantidad' : null,
      );
    }
    return EnsureVisibleWhenFocused(
      focusNode: _quantityFocusNode,
      child: TextFormField(
        controller: _quantityController,
        focusNode: _quantityFocusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Cantidad'),
        onTapOutside: (_) => _quantityFocusNode.unfocus(),
        onFieldSubmitted: (_) => _moveFocusTo(
          _unitPriceFocusNode,
          controller: _unitPriceController,
        ),
        validator: (value) =>
            _parseInt(value) <= 0 ? 'Ingresá una cantidad' : null,
      ),
    );
  }

  Widget _buildPriceField(bool useMobileEditor) {
    if (useMobileEditor) {
      return MobileFieldEditorFormField(
        controller: _unitPriceController,
        editorController: _unitPriceEditorController,
        labelText: 'Precio',
        editorContext: 'Nueva venta',
        emptyDisplayText: 'Tocá para cargar el precio',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        prefixText: '\$ ',
        displayValueBuilder: (value) {
          final parsed = _parseInt(value);
          return parsed <= 0 ? 'Tocá para cargar el precio' : formatMoney(parsed);
        },
        validator: (value) =>
            _parseInt(value) <= 0 ? 'Ingresá un precio' : null,
      );
    }
    return EnsureVisibleWhenFocused(
      focusNode: _unitPriceFocusNode,
      child: TextFormField(
        controller: _unitPriceController,
        focusNode: _unitPriceFocusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Precio',
          prefixText: '\$ ',
        ),
        onTapOutside: (_) => _unitPriceFocusNode.unfocus(),
        onFieldSubmitted: (_) => _moveFocusTo(_paymentFocusNode),
        validator: (value) =>
            _parseInt(value) <= 0 ? 'Ingresá un precio' : null,
      ),
    );
  }

  Widget _buildPaymentField() {
    return EnsureVisibleWhenFocused(
      focusNode: _paymentFocusNode,
      child: DropdownButtonFormField<String>(
        focusNode: _paymentFocusNode,
        initialValue: _paymentMethod,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Medio de pago'),
        items: const [
          DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
          DropdownMenuItem(value: 'Débito', child: Text('Débito')),
          DropdownMenuItem(
            value: 'Transferencia',
            child: Text('Transferencia'),
          ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() => _paymentMethod = value);
        },
        onTap: () {
          _dismissKeyboard();
          _paymentFocusNode.requestFocus();
        },
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    CommerceStore store,
    bool canSaveSale,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final saveButton = FilledButton.icon(
          onPressed: canSaveSale ? () => _submitSale(store) : null,
          style: compact
              ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))
              : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(_saving ? 'Guardando...' : 'Registrar venta'),
        );

        final cancelButton = TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              saveButton,
              const SizedBox(height: 10),
              cancelButton,
            ],
          );
        }
        return Row(
          children: [
            const Spacer(),
            cancelButton,
            const SizedBox(width: 12),
            saveButton,
          ],
        );
      },
    );
  }

  String? _validateDescription(String? value) {
    return (value ?? '').trim().isEmpty ? 'Escribí qué estás vendiendo.' : null;
  }

  int _parseInt(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }

  void _handleDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _moveFocusTo(FocusNode focusNode, {TextEditingController? controller}) {
    _dismissKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (controller != null) {
        focusAndSelectAll(focusNode, controller);
        return;
      }
      focusNode.requestFocus();
    });
  }

  void _showBlockedFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _fillPremiumDemoSale() {
    setState(() {
      _descriptionController.text = 'Café frío';
      _quantityController.text = '2';
      _unitPriceController.text = '1800';
      _paymentMethod = 'Efectivo';
      _autoValidateMode = AutovalidateMode.disabled;
    });
    _dismissKeyboard();
  }

  Future<void> _submitSale(CommerceStore store) async {
    if (_saving) {
      return;
    }
    final quantity = _parseInt(_quantityController.text);
    final unitPrice = _parseInt(_unitPriceController.text);
    final validationMessage = store.freeSaleReadinessMessage(
      description: _descriptionController.text,
      quantityUnits: quantity,
      unitPricePesos: unitPrice,
    );

    if (validationMessage != null) {
      if (_autoValidateMode == AutovalidateMode.disabled) {
        setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
      }
      _formKey.currentState!.validate();
      _showBlockedFeedback(validationMessage);
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await store.recordFreeSale(
        description: _descriptionController.text,
        quantityUnits: quantity,
        unitPricePesos: unitPrice,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      navigator.pop('Venta registrada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(error))),
      );
    }
  }
}

/// Resumen claro de la venta en curso.
class _SaleSummary extends StatelessWidget {
  const _SaleSummary({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.warning,
  });

  final String description;
  final int quantity;
  final int unitPrice;
  final int total;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BpcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Producto o detalle',
            value: description.isEmpty ? 'Sin cargar' : description,
          ),
          _SummaryRow(label: 'Cantidad', value: quantity.toString()),
          _SummaryRow(
            label: 'Precio',
            value: unitPrice <= 0 ? '-' : formatMoney(unitPrice),
          ),
          const Divider(height: 20, color: BpcColors.line),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatMoney(total),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: BpcColors.income,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: BpcColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BpcColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BpcColors.subtleInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
