import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import 'keyboard_aware_form.dart';
import 'speech_dictation.dart';

Future<void> showProductEditor(
  BuildContext context,
  CommerceStore store, {
  Product? product,
  String? initialBarcode,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return KeyboardAwareDialogFrame(
        child: Dialog(
          insetPadding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _ProductFormDialog(
              store: store,
              product: product,
              initialBarcode: initialBarcode,
            ),
          ),
        ),
      );
    },
  );
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.store,
    this.product,
    this.initialBarcode,
  });

  final CommerceStore store;
  final Product? product;
  final String? initialBarcode;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _costController;
  late final TextEditingController _priceController;
  late final TextEditingController _barcodeController;
  final _categoryFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  final _stockFocusNode = FocusNode();
  final _minStockFocusNode = FocusNode();
  final _costFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _nameDictation = SpeechDictationController();
  final _categoryDictation = SpeechDictationController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _stockController = TextEditingController(
      text: (product?.stockUnits ?? 0).toString(),
    );
    _minStockController = TextEditingController(
      text: (product?.minStockUnits ?? 5).toString(),
    );
    _costController = TextEditingController(
      text: (product?.costPesos ?? 0).toString(),
    );
    _priceController = TextEditingController(
      text: (product?.pricePesos ?? 0).toString(),
    );
    _barcodeController = TextEditingController(
      text: product?.barcode ?? widget.initialBarcode ?? '',
    );
    selectAllTextOnFocus(_categoryFocusNode, _categoryController);
    selectAllTextOnFocus(_barcodeFocusNode, _barcodeController);
    selectAllTextOnFocus(_stockFocusNode, _stockController);
    selectAllTextOnFocus(_minStockFocusNode, _minStockController);
    selectAllTextOnFocus(_costFocusNode, _costController);
    selectAllTextOnFocus(_priceFocusNode, _priceController);
    _nameDictation.initialize();
    _categoryDictation.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _categoryFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _stockFocusNode.dispose();
    _minStockFocusNode.dispose();
    _costFocusNode.dispose();
    _priceFocusNode.dispose();
    _nameDictation.dispose();
    _categoryDictation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 80)
            .clamp(420.0, mediaQuery.size.height * 0.9)
            .toDouble();
    return SizedBox(
      width: double.infinity,
      height: dialogHeight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product == null
                          ? 'Agregar producto'
                          : 'Editar producto',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Nombre',
                                suffixIcon: SpeechDictationActionButton(
                                  controller: _nameDictation,
                                  textController: _nameController,
                                  tooltip: 'Dictar nombre',
                                ),
                              ),
                              validator: _required,
                              onChanged: (_) => setState(() {}),
                            ),
                            SpeechDictationHint(controller: _nameDictation),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _categoryController,
                              focusNode: _categoryFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Categoria (opcional)',
                                suffixIcon: SpeechDictationActionButton(
                                  controller: _categoryDictation,
                                  textController: _categoryController,
                                  tooltip: 'Dictar categoria',
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            SpeechDictationHint(controller: _categoryDictation),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: _barcodeController,
                          focusNode: _barcodeFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Codigo de barras (opcional)',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _stockController,
                          focusNode: _stockFocusNode,
                          decoration: const InputDecoration(labelText: 'Stock'),
                          keyboardType: TextInputType.number,
                          validator: (value) => _intMin(value, 0, 'El stock'),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _minStockController,
                          focusNode: _minStockFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Stock minimo',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              _intMin(value, 0, 'El stock minimo'),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _costController,
                          focusNode: _costFocusNode,
                          decoration: const InputDecoration(labelText: 'Costo'),
                          keyboardType: TextInputType.number,
                          validator: (value) => _intMin(value, 1, 'El costo'),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _priceController,
                          focusNode: _priceFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => _intMin(value, 1, 'El precio'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Vista previa: ${_nameController.text.isEmpty ? 'sin nombre' : _nameController.text} / ${formatMoney(_parseInt(_priceController.text))}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final cancelButton = TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  );
                  final saveButton = FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
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
                      const SizedBox(width: 10),
                      saveButton,
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _intMin(String? value, int min, String label) {
    final parsed = _parseInt(value);
    if (parsed < min) {
      return '$label debe ser ${min == 0 ? 'igual o mayor a 0' : 'mayor a 0'}.';
    }
    return null;
  }

  int _parseInt(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id =
        widget.product?.id ??
        'product-${DateTime.now().microsecondsSinceEpoch}';
    final product = Product(
      id: id,
      name: _nameController.text.trim(),
      stockUnits: _parseInt(_stockController.text),
      minStockUnits: _parseInt(_minStockController.text),
      costPesos: _parseInt(_costController.text),
      pricePesos: _parseInt(_priceController.text),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      barcode: CommerceStore.normalizeBarcode(_barcodeController.text),
    );

    setState(() => _saving = true);
    try {
      await widget.store.addProduct(product);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Producto guardado')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
    }
  }
}
