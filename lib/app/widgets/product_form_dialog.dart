import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import 'commerce_components.dart';
import 'input_shortcuts.dart';
import 'keyboard_aware_form.dart';
import 'speech_dictation.dart';

class ProductEditorSeed {
  const ProductEditorSeed({
    this.name,
    this.pricePesos,
    this.stockUnits,
    this.minStockUnits,
    this.category,
    this.barcode,
  });

  final String? name;
  final int? pricePesos;
  final int? stockUnits;
  final int? minStockUnits;
  final String? category;
  final String? barcode;
}

enum ProductEditorResultKind { created, usedExisting }

class ProductEditorResult {
  const ProductEditorResult({required this.kind, required this.product});

  final ProductEditorResultKind kind;
  final Product product;
}

Future<ProductEditorResult?> showProductEditor(
  BuildContext context,
  CommerceStore store, {
  Product? product,
  String? initialBarcode,
  ProductEditorSeed? seed,
}) async {
  if (useFullscreenFormLayout(context)) {
    return Navigator.of(context).push<ProductEditorResult>(
      MaterialPageRoute<ProductEditorResult>(
        fullscreenDialog: true,
        builder: (pageContext) {
          return _ProductFormPage(
            store: store,
            product: product,
            initialBarcode: initialBarcode,
            seed: seed,
          );
        },
      ),
    );
  }

  return showDialog<ProductEditorResult>(
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
              seed: seed,
              fullscreen: false,
            ),
          ),
        ),
      );
    },
  );
}

class _ProductFormPage extends StatelessWidget {
  const _ProductFormPage({
    required this.store,
    this.product,
    this.initialBarcode,
    this.seed,
  });

  final CommerceStore store;
  final Product? product;
  final String? initialBarcode;
  final ProductEditorSeed? seed;

  @override
  Widget build(BuildContext context) {
    final title = product == null ? 'Agregar producto' : 'Editar producto';
    return KeyboardAwareFormScaffold(
      title: title,
      child: BpcPanel(
        child: _ProductFormDialog(
          store: store,
          product: product,
          initialBarcode: initialBarcode,
          seed: seed,
          fullscreen: true,
        ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.store,
    this.product,
    this.initialBarcode,
    this.seed,
    required this.fullscreen,
  });

  final CommerceStore store;
  final Product? product;
  final String? initialBarcode;
  final ProductEditorSeed? seed;
  final bool fullscreen;

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
  final _nameFocusNode = FocusNode();
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
    final seed = widget.seed;
    _nameController = TextEditingController(
      text: product?.name ?? seed?.name ?? '',
    );
    _categoryController = TextEditingController(
      text: product?.category ?? seed?.category ?? '',
    );
    _stockController = TextEditingController(
      text: (product?.stockUnits ?? seed?.stockUnits ?? 0).toString(),
    );
    _minStockController = TextEditingController(
      text: (product?.minStockUnits ?? seed?.minStockUnits ?? 5).toString(),
    );
    _costController = TextEditingController(
      text: (product?.costPesos ?? 0).toString(),
    );
    _priceController = TextEditingController(
      text: (product?.pricePesos ?? seed?.pricePesos ?? 0).toString(),
    );
    _barcodeController = TextEditingController(
      text: product?.barcode ?? seed?.barcode ?? widget.initialBarcode ?? '',
    );
    selectAllTextOnFocus(_nameFocusNode, _nameController);
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
    _nameFocusNode.dispose();
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
    if (widget.fullscreen) {
      return _buildFullscreenContent(context);
    }
    return _buildDialogContent(context);
  }

  String get _title =>
      widget.product == null ? 'Agregar producto' : 'Editar producto';

  Widget _buildDialogContent(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 80)
            .clamp(420.0, mediaQuery.size.height * 0.9)
            .toDouble();
    return SizedBox(
      width: double.infinity,
      height: dialogHeight,
      child: InputShortcutScope(
        onSave: _saving ? null : _save,
        onCancel: _saving ? null : () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FocusTraversalGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogHeader(context),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _buildFields(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildPreview(context),
                  const SizedBox(height: 16),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenContent(BuildContext context) {
    return InputShortcutScope(
      onSave: _saving ? null : _save,
      onCancel: _saving ? null : () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Completa lo basico y guarda. Si todavia no definiste costo o precio, puedes dejarlo en 0 y ajustarlo despues.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 18),
              _buildFields(context),
              const SizedBox(height: 18),
              _buildPreview(context),
              const SizedBox(height: 16),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Completa lo basico y guarda. Si todavia no definiste costo o precio, puedes dejarlo en 0 y ajustarlo despues.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildFields(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EnsureVisibleWhenFocused(
                focusNode: _nameFocusNode,
                child: TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    suffixIcon: SpeechDictationActionButton(
                      controller: _nameDictation,
                      textController: _nameController,
                      tooltip: 'Dictar nombre',
                    ),
                  ),
                  onTapOutside: (_) => _nameFocusNode.unfocus(),
                  onFieldSubmitted: (_) => _moveFocusTo(
                    _categoryFocusNode,
                    controller: _categoryController,
                  ),
                  validator: _required,
                  onChanged: (_) => setState(() {}),
                ),
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
              EnsureVisibleWhenFocused(
                focusNode: _categoryFocusNode,
                child: TextFormField(
                  controller: _categoryController,
                  focusNode: _categoryFocusNode,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Categoria (opcional)',
                    suffixIcon: SpeechDictationActionButton(
                      controller: _categoryDictation,
                      textController: _categoryController,
                      tooltip: 'Dictar categoria',
                    ),
                  ),
                  onTapOutside: (_) => _categoryFocusNode.unfocus(),
                  onFieldSubmitted: (_) => _moveFocusTo(
                    _barcodeFocusNode,
                    controller: _barcodeController,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SpeechDictationHint(controller: _categoryDictation),
            ],
          ),
        ),
        SizedBox(
          width: 220,
          child: EnsureVisibleWhenFocused(
            focusNode: _barcodeFocusNode,
            child: TextFormField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Codigo de barras (opcional)',
              ),
              onTapOutside: (_) => _barcodeFocusNode.unfocus(),
              onFieldSubmitted: (_) =>
                  _moveFocusTo(_stockFocusNode, controller: _stockController),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: EnsureVisibleWhenFocused(
            focusNode: _stockFocusNode,
            child: TextFormField(
              controller: _stockController,
              focusNode: _stockFocusNode,
              decoration: const InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => _stockFocusNode.unfocus(),
              onFieldSubmitted: (_) => _moveFocusTo(
                _minStockFocusNode,
                controller: _minStockController,
              ),
              validator: (value) => _intMin(value, 0, 'El stock'),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: EnsureVisibleWhenFocused(
            focusNode: _minStockFocusNode,
            child: TextFormField(
              controller: _minStockController,
              focusNode: _minStockFocusNode,
              decoration: const InputDecoration(labelText: 'Stock minimo'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => _minStockFocusNode.unfocus(),
              onFieldSubmitted: (_) =>
                  _moveFocusTo(_costFocusNode, controller: _costController),
              validator: (value) => _intMin(value, 0, 'El stock minimo'),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: EnsureVisibleWhenFocused(
            focusNode: _costFocusNode,
            child: TextFormField(
              controller: _costController,
              focusNode: _costFocusNode,
              decoration: const InputDecoration(labelText: 'Costo'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => _costFocusNode.unfocus(),
              onFieldSubmitted: (_) =>
                  _moveFocusTo(_priceFocusNode, controller: _priceController),
              validator: (value) => _intMin(value, 0, 'El costo'),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: EnsureVisibleWhenFocused(
            focusNode: _priceFocusNode,
            child: TextFormField(
              controller: _priceController,
              focusNode: _priceFocusNode,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => _priceFocusNode.unfocus(),
              onFieldSubmitted: (_) {
                _dismissKeyboard();
                _save();
              },
              validator: (value) => _intMin(value, 0, 'El precio'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Text(
      'Vista previa: ${_nameController.text.isEmpty ? 'sin nombre' : _nameController.text} / ${formatMoney(_parseInt(_priceController.text))}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final cancelButton = TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
            children: [saveButton, const SizedBox(height: 10), cancelButton],
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
    _dismissKeyboard();
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

    if (widget.product == null) {
      final existing = widget.store.productByNormalizedName(product.name);
      if (existing != null) {
        final resolution = await _showDuplicateNameDialog(existing);
        if (!mounted) {
          return;
        }
        if (resolution == _DuplicateProductResolution.cancel) {
          return;
        }
        if (resolution == _DuplicateProductResolution.useExisting) {
          Navigator.of(context).pop(
            ProductEditorResult(
              kind: ProductEditorResultKind.usedExisting,
              product: existing,
            ),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      await widget.store.addProduct(product);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        ProductEditorResult(
          kind: ProductEditorResultKind.created,
          product: product,
        ),
      );
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

  Future<_DuplicateProductResolution?> _showDuplicateNameDialog(
    Product existing,
  ) {
    return showDialog<_DuplicateProductResolution>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ya existe un producto con ese nombre'),
          content: Text(
            'Se encontro "${existing.name}" en el catalogo. Puedes usar ese producto, cancelar o crear otro igual si de verdad lo necesitas.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_DuplicateProductResolution.cancel),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_DuplicateProductResolution.useExisting),
              child: const Text('Usar existente'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_DuplicateProductResolution.createDuplicate),
              child: const Text('Crear igual'),
            ),
          ],
        );
      },
    );
  }
}

enum _DuplicateProductResolution { cancel, useExisting, createDuplicate }
