import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../services/license_service.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../utils/payment_methods.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/license_dialogs.dart';
import '../widgets/mobile_field_editor.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/sale_receipt_card.dart';
import '../widgets/speech_dictation.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

enum SaleEntryMode { catalog, quick }

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productSearchController = TextEditingController();
  final _manualDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _manualUnitPriceController = TextEditingController();
  final _productFocusNode = FocusNode();
  final _manualDescriptionFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _manualUnitPriceFocusNode = FocusNode();
  final _manualDescriptionEditorController = MobileFieldEditorController();
  final _quantityEditorController = MobileFieldEditorController();
  final _manualUnitPriceEditorController = MobileFieldEditorController();
  final _productSearchDictation = SpeechDictationController();
  Product? _selectedProduct;
  SaleEntryMode _saleMode = SaleEntryMode.catalog;
  String _paymentMethod = 'Efectivo';
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _didSeedDefaults = false;
  bool _showReceiptPreview = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _productSearchController.text = widget.initialProduct?.name ?? '';
    _productSearchController.addListener(_handleProductSearchChanged);
    _manualDescriptionController.addListener(_handleSaleDraftChanged);
    _manualUnitPriceController.addListener(_handleSaleDraftChanged);
    _quantityController.addListener(_handleSaleDraftChanged);
    _productFocusNode.addListener(_handleProductFocusChanged);
    selectAllTextOnFocus(_quantityFocusNode, _quantityController);
    selectAllTextOnFocus(_manualUnitPriceFocusNode, _manualUnitPriceController);
    _productSearchDictation.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedDefaults) {
      return;
    }
    final store = CommerceScope.of(context);
    _paymentMethod = resolveSalePaymentMethodSelection(
      store.lastSalePaymentMethod,
    );
    _didSeedDefaults = true;
  }

  @override
  void dispose() {
    _productSearchController
      ..removeListener(_handleProductSearchChanged)
      ..dispose();
    _manualDescriptionController
      ..removeListener(_handleSaleDraftChanged)
      ..dispose();
    _quantityController
      ..removeListener(_handleSaleDraftChanged)
      ..dispose();
    _manualUnitPriceController
      ..removeListener(_handleSaleDraftChanged)
      ..dispose();
    _productFocusNode.removeListener(_handleProductFocusChanged);
    _productFocusNode.dispose();
    _manualDescriptionFocusNode.dispose();
    _quantityFocusNode.dispose();
    _manualUnitPriceFocusNode.dispose();
    _productSearchDictation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    final useMobileSensitiveFieldEditor = useMobileFieldEditor(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final product =
              _saleMode == SaleEntryMode.catalog && _selectedProduct != null
              ? store.productById(_selectedProduct!.id)
              : null;
          if (_saleMode == SaleEntryMode.catalog &&
              _selectedProduct != null &&
              product == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              final selected = _selectedProduct;
              if (selected == null || store.productById(selected.id) != null) {
                return;
              }
              setState(() => _selectedProduct = null);
            });
          }
          final quantity = _parseInt(_quantityController.text);
          final manualDescription = _manualDescriptionController.text.trim();
          final manualUnitPrice = _parseInt(_manualUnitPriceController.text);
          final exactQuickMatch = _saleMode == SaleEntryMode.quick
              ? _exactQuickMatchProduct(store)
              : null;
          final exactCatalogMatch = _saleMode == SaleEntryMode.catalog
              ? _exactCatalogMatchProduct(store)
              : null;
          final filteredProducts = _filteredProducts(store);
          final productFieldError = _saleMode == SaleEntryMode.catalog
              ? _productFieldErrorText(filteredProducts)
              : null;
          final productFieldHelper = _saleMode == SaleEntryMode.catalog
              ? _productFieldHelperText(filteredProducts, productFieldError)
              : null;
          final saleWarning = _saleMode == SaleEntryMode.catalog
              ? (product == null
                    ? null
                    : store.saleReadinessMessage(
                        product.id,
                        quantityUnits: quantity,
                      ))
              : store.freeSaleReadinessMessage(
                  description: manualDescription,
                  quantityUnits: quantity,
                  unitPricePesos: manualUnitPrice,
                );
          final total = _saleMode == SaleEntryMode.catalog
              ? (product == null ? 0 : product.pricePesos * quantity)
              : manualUnitPrice * quantity;
          final remaining =
              _saleMode == SaleEntryMode.catalog && product != null
              ? product.stockUnits - quantity
              : null;
          final canSaveSale =
              !_saving &&
              (_saleMode == SaleEntryMode.catalog
                  ? product != null && saleWarning == null && quantity > 0
                  : saleWarning == null && quantity > 0);
          final receiptPreview = _buildReceiptData(
            product: product,
            quantity: quantity,
            manualUnitPrice: manualUnitPrice,
            total: total,
            remaining: remaining,
          );
          final paymentMethodOptions = salePaymentMethodOptions(
            selectedValue: _paymentMethod,
          );
          final hasCustomPaymentMethod = !supportedSalePaymentMethods.contains(
            _paymentMethod,
          );
          final flowStatus = _buildSaleFlowStatus(
            product: product,
            quantity: quantity,
            manualDescription: manualDescription,
            manualUnitPrice: manualUnitPrice,
            total: total,
            saleWarning: saleWarning,
          );
          return KeyboardAwarePageBody(
            child: InputShortcutScope(
              onSave: _saving ? null : () => _submitSale(store),
              onCancel: _saving ? null : () => Navigator.of(context).maybePop(),
              onFocusSearch: () {
                if (_saleMode == SaleEntryMode.quick) {
                  _moveFocusTo(
                    _manualDescriptionFocusNode,
                    controller: _manualDescriptionController,
                  );
                  return;
                }
                _moveFocusTo(
                  _productFocusNode,
                  controller: _productSearchController,
                );
              },
              child: BpcPanel(
                child: FocusTraversalGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva venta',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. Elige el producto. 2. Marca el cobro. 3. Confirma.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 18),
                        _SaleModeSelector(
                          currentMode: _saleMode,
                          onChanged: _saving ? null : _handleSaleModeChanged,
                        ),
                        const SizedBox(height: 18),
                        _SaleStepSection(
                          step: '1',
                          title: _saleMode == SaleEntryMode.catalog
                              ? 'Elige el producto'
                              : 'Describe la venta',
                          subtitle: _saleMode == SaleEntryMode.catalog
                              ? 'Busca y toca el producto antes de cobrar.'
                              : 'Escribe que vendiste. Si ya existe, usa el producto cargado.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_saleMode == SaleEntryMode.catalog) ...[
                                if (!store.hasProducts) ...[
                                  EmptyCard(
                                    title: 'Todavia no hay productos cargados',
                                    message:
                                        'Cobra ahora con venta libre o agrega tu primer producto.',
                                    icon: Icons.inventory_2_rounded,
                                    action: Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _handleSaleModeChanged(
                                                SaleEntryMode.quick,
                                              ),
                                          icon: const Icon(
                                            Icons.flash_on_rounded,
                                          ),
                                          label: const Text('Usar venta libre'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              showProductEditor(context, store),
                                          icon: const Icon(
                                            Icons.add_box_rounded,
                                          ),
                                          label: const Text('Agregar producto'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _loadStarterTemplate(store),
                                          child: const Text(
                                            'Cargar base simple',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                EnsureVisibleWhenFocused(
                                  focusNode: _productFocusNode,
                                  child: TextFormField(
                                    controller: _productSearchController,
                                    focusNode: _productFocusNode,
                                    autofocus: widget.initialProduct == null,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.search,
                                    onTapOutside: (_) =>
                                        _productFocusNode.unfocus(),
                                    onFieldSubmitted: (_) {
                                      if (_selectedProduct != null) {
                                        _moveFocusTo(
                                          _quantityFocusNode,
                                          controller: _quantityController,
                                        );
                                        return;
                                      }
                                      if (exactCatalogMatch != null) {
                                        _commitProductSelection(
                                          exactCatalogMatch,
                                        );
                                        return;
                                      }
                                      if (_autoValidateMode ==
                                          AutovalidateMode.disabled) {
                                        setState(() {
                                          _autoValidateMode = AutovalidateMode
                                              .onUserInteraction;
                                        });
                                      }
                                      _formKey.currentState!.validate();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Buscar producto',
                                      hintText: 'Nombre, categoria o codigo',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
                                      suffixIcon: SpeechDictationActionButton(
                                        controller: _productSearchDictation,
                                        textController:
                                            _productSearchController,
                                        tooltip: 'Dictar producto',
                                      ),
                                      errorText: productFieldError,
                                      helperText: productFieldHelper,
                                    ),
                                  ),
                                ),
                                SpeechDictationHint(
                                  controller: _productSearchDictation,
                                ),
                                if (_shouldShowProductResults(
                                  filteredProducts,
                                )) ...[
                                  const SizedBox(height: 14),
                                  _ProductSearchResults(
                                    products: filteredProducts,
                                    hasActiveQuery:
                                        _normalizedProductQuery.isNotEmpty,
                                    onSelect: _selectProduct,
                                  ),
                                ],
                                if (product != null) ...[
                                  const SizedBox(height: 14),
                                  _SelectedProductCard(
                                    product: product,
                                    onChangeProduct: _clearSelectedProduct,
                                  ),
                                ],
                              ] else ...[
                                if (useMobileSensitiveFieldEditor)
                                  MobileFieldEditorFormField(
                                    controller: _manualDescriptionController,
                                    editorController:
                                        _manualDescriptionEditorController,
                                    nextEditorController:
                                        _quantityEditorController,
                                    nextFieldLabel: 'Cantidad',
                                    labelText: 'Descripcion',
                                    editorContext: 'Venta libre',
                                    hintText: 'Ej. Agua mineral 500 ml',
                                    helperText:
                                        'Usalo si todavia no cargaste el producto en el catalogo.',
                                    emptyDisplayText:
                                        'Toca para cargar la descripcion',
                                    keyboardType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    validator: (value) {
                                      if (_saleMode != SaleEntryMode.quick) {
                                        return null;
                                      }
                                      return (value ?? '').trim().isEmpty
                                          ? 'Escribe una descripcion.'
                                          : null;
                                    },
                                  )
                                else
                                  EnsureVisibleWhenFocused(
                                    focusNode: _manualDescriptionFocusNode,
                                    child: TextFormField(
                                      controller: _manualDescriptionController,
                                      focusNode: _manualDescriptionFocusNode,
                                      autofocus: widget.initialProduct == null,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      onTapOutside: (_) =>
                                          _manualDescriptionFocusNode.unfocus(),
                                      onFieldSubmitted: (_) => _moveFocusTo(
                                        _quantityFocusNode,
                                        controller: _quantityController,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Descripcion',
                                        hintText: 'Ej. Agua mineral 500 ml',
                                        helperText:
                                            'Usalo si todavia no cargaste el producto en el catalogo.',
                                      ),
                                      validator: (value) {
                                        if (_saleMode != SaleEntryMode.quick) {
                                          return null;
                                        }
                                        return (value ?? '').trim().isEmpty
                                            ? 'Escribe una descripcion.'
                                            : null;
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  'La venta libre suma en caja y reportes, pero no descuenta stock hasta pasarla al catalogo.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                if (exactQuickMatch != null) ...[
                                  _ExactProductSuggestionCard(
                                    product: exactQuickMatch,
                                    onUseProduct: () =>
                                        _useExistingProductFromQuickSale(
                                          exactQuickMatch,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                OutlinedButton.icon(
                                  onPressed:
                                      manualDescription.isEmpty || _saving
                                      ? null
                                      : () {
                                          if (exactQuickMatch != null) {
                                            _useExistingProductFromQuickSale(
                                              exactQuickMatch,
                                            );
                                            return;
                                          }
                                          _createProductFromFreeSale(store);
                                        },
                                  icon: const Icon(Icons.add_box_rounded),
                                  label: Text(
                                    exactQuickMatch == null
                                        ? 'Pasar al catalogo'
                                        : 'Usar el producto cargado',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final quickColumns =
                                      _saleMode == SaleEntryMode.quick
                                      ? (constraints.maxWidth >= 840 ? 2 : 1)
                                      : 1;
                                  final gaps = quickColumns > 1
                                      ? 12.0 * (quickColumns - 1)
                                      : 0.0;
                                  final fieldWidth =
                                      (constraints.maxWidth - gaps) /
                                      quickColumns;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: fieldWidth,
                                        child: useMobileSensitiveFieldEditor
                                            ? MobileFieldEditorFormField(
                                                controller: _quantityController,
                                                editorController:
                                                    _quantityEditorController,
                                                nextEditorController:
                                                    _saleMode ==
                                                        SaleEntryMode.quick
                                                    ? _manualUnitPriceEditorController
                                                    : null,
                                                nextFieldLabel:
                                                    _saleMode ==
                                                        SaleEntryMode.quick
                                                    ? 'Precio unitario'
                                                    : null,
                                                labelText: 'Cantidad',
                                                editorContext:
                                                    _saleMode ==
                                                        SaleEntryMode.quick
                                                    ? 'Venta libre'
                                                    : 'Nueva venta',
                                                emptyDisplayText:
                                                    'Toca para cargar la cantidad',
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                validator: (value) {
                                                  final parsed = _parseInt(
                                                    value,
                                                  );
                                                  if (_saleMode ==
                                                      SaleEntryMode.quick) {
                                                    return parsed <= 0
                                                        ? 'Ingresa una cantidad'
                                                        : null;
                                                  }
                                                  if (product == null) {
                                                    return parsed <= 0
                                                        ? 'Ingresa una cantidad'
                                                        : null;
                                                  }
                                                  return store
                                                      .saleReadinessMessage(
                                                        product.id,
                                                        quantityUnits: parsed,
                                                      );
                                                },
                                              )
                                            : EnsureVisibleWhenFocused(
                                                focusNode: _quantityFocusNode,
                                                child: TextFormField(
                                                  controller:
                                                      _quantityController,
                                                  focusNode: _quantityFocusNode,
                                                  autofocus:
                                                      widget.initialProduct !=
                                                          null &&
                                                      _saleMode ==
                                                          SaleEntryMode.catalog,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Cantidad',
                                                    helperText:
                                                        'Cuantas unidades cobras ahora.',
                                                  ),
                                                  onTapOutside: (_) =>
                                                      _quantityFocusNode
                                                          .unfocus(),
                                                  onFieldSubmitted: (_) {
                                                    if (_saleMode ==
                                                        SaleEntryMode.quick) {
                                                      _moveFocusTo(
                                                        _manualUnitPriceFocusNode,
                                                        controller:
                                                            _manualUnitPriceController,
                                                      );
                                                      return;
                                                    }
                                                    _dismissKeyboard();
                                                  },
                                                  validator: (value) {
                                                    final parsed = _parseInt(
                                                      value,
                                                    );
                                                    if (_saleMode ==
                                                        SaleEntryMode.quick) {
                                                      return parsed <= 0
                                                          ? 'Ingresa una cantidad'
                                                          : null;
                                                    }
                                                    if (product == null) {
                                                      return parsed <= 0
                                                          ? 'Ingresa una cantidad'
                                                          : null;
                                                    }
                                                    return store
                                                        .saleReadinessMessage(
                                                          product.id,
                                                          quantityUnits: parsed,
                                                        );
                                                  },
                                                ),
                                              ),
                                      ),
                                      if (_saleMode == SaleEntryMode.quick)
                                        SizedBox(
                                          width: fieldWidth,
                                          child: useMobileSensitiveFieldEditor
                                              ? MobileFieldEditorFormField(
                                                  controller:
                                                      _manualUnitPriceController,
                                                  editorController:
                                                      _manualUnitPriceEditorController,
                                                  labelText: 'Precio unitario',
                                                  editorContext: 'Venta libre',
                                                  emptyDisplayText:
                                                      'Toca para cargar el precio',
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  prefixText: '\$ ',
                                                  displayValueBuilder: (value) {
                                                    final parsed = _parseInt(
                                                      value,
                                                    );
                                                    return parsed <= 0
                                                        ? 'Toca para cargar el precio'
                                                        : formatMoney(parsed);
                                                  },
                                                  validator: (value) {
                                                    if (_saleMode !=
                                                        SaleEntryMode.quick) {
                                                      return null;
                                                    }
                                                    final parsed = _parseInt(
                                                      value,
                                                    );
                                                    return parsed <= 0
                                                        ? 'Ingresa un precio'
                                                        : null;
                                                  },
                                                )
                                              : EnsureVisibleWhenFocused(
                                                  focusNode:
                                                      _manualUnitPriceFocusNode,
                                                  child: TextFormField(
                                                    controller:
                                                        _manualUnitPriceController,
                                                    focusNode:
                                                        _manualUnitPriceFocusNode,
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Precio unitario',
                                                          prefixText: '\$ ',
                                                          helperText:
                                                              'Precio por unidad que aparece en el cobro.',
                                                        ),
                                                    onTapOutside: (_) =>
                                                        _manualUnitPriceFocusNode
                                                            .unfocus(),
                                                    onFieldSubmitted: (_) =>
                                                        _dismissKeyboard(),
                                                    validator: (value) {
                                                      if (_saleMode !=
                                                          SaleEntryMode.quick) {
                                                        return null;
                                                      }
                                                      final parsed = _parseInt(
                                                        value,
                                                      );
                                                      return parsed <= 0
                                                          ? 'Ingresa un precio'
                                                          : null;
                                                    },
                                                  ),
                                                ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SaleStepSection(
                          step: '2',
                          title: 'Marca el cobro',
                          subtitle:
                              'Elige el medio de pago para que caja y comprobante queden claros.',
                          child: _PaymentMethodSelectorCard(
                            options: paymentMethodOptions,
                            selectedValue: _paymentMethod,
                            hasCustomSelection: hasCustomPaymentMethod,
                            onSelect: (value) {
                              _dismissKeyboard();
                              setState(() => _paymentMethod = value);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SaleStepSection(
                          step: '3',
                          title: 'Confirma y cobra',
                          subtitle:
                              'Revisa el total y registra la venta cuando este lista.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SaleCheckoutOverviewCard(
                                status: flowStatus,
                                receipt: receiptPreview,
                                canSaveSale: canSaveSale,
                                saving: _saving,
                                onSubmit: canSaveSale
                                    ? () => _submitSale(store)
                                    : null,
                                onCancel: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showReceiptPreview = !_showReceiptPreview;
                                  });
                                },
                                icon: Icon(
                                  _showReceiptPreview
                                      ? Icons.expand_less_rounded
                                      : Icons.receipt_long_rounded,
                                ),
                                label: Text(
                                  _showReceiptPreview
                                      ? 'Ocultar detalle del comprobante'
                                      : 'Ver detalle del comprobante',
                                ),
                              ),
                              if (_showReceiptPreview) ...[
                                const SizedBox(height: 8),
                                SaleReceiptCard(receipt: receiptPreview),
                              ],
                            ],
                          ),
                        ),
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

  _SaleFlowStatus _buildSaleFlowStatus({
    required Product? product,
    required int quantity,
    required String manualDescription,
    required int manualUnitPrice,
    required int total,
    required String? saleWarning,
  }) {
    if (_saleMode == SaleEntryMode.catalog && product == null) {
      return const _SaleFlowStatus(
        title: 'Falta elegir el producto',
        message: 'Busca y confirma un producto para seguir con la venta.',
        icon: Icons.inventory_2_rounded,
        isReady: false,
      );
    }
    if (_saleMode == SaleEntryMode.quick && manualDescription.isEmpty) {
      return const _SaleFlowStatus(
        title: 'Falta la descripcion',
        message: 'Escribe que estas cobrando para que quede claro en caja.',
        icon: Icons.edit_note_rounded,
        isReady: false,
      );
    }
    if (quantity <= 0) {
      return const _SaleFlowStatus(
        title: 'Falta la cantidad',
        message: 'Ingresa cuantas unidades vas a cobrar.',
        icon: Icons.pin_rounded,
        isReady: false,
      );
    }
    if (_saleMode == SaleEntryMode.quick && manualUnitPrice <= 0) {
      return const _SaleFlowStatus(
        title: 'Falta el precio',
        message: 'Carga el precio unitario antes de registrar la venta.',
        icon: Icons.sell_rounded,
        isReady: false,
      );
    }
    if (saleWarning != null) {
      return _SaleFlowStatus(
        title: 'Revisa antes de cobrar',
        message: saleWarning,
        icon: Icons.warning_amber_rounded,
        isReady: false,
      );
    }
    return _SaleFlowStatus(
      title: 'Todo listo para vender',
      message:
          'Cobras ${formatMoney(total)} con ${displayPaymentMethodLabel(_paymentMethod)} y la caja se actualiza al momento.',
      icon: Icons.check_circle_rounded,
      isReady: true,
    );
  }

  Future<void> _loadStarterTemplate(CommerceStore store) async {
    if (!await ensureLicenseAccess(context, LockedFeature.templates) ||
        !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await store.applyArgentinianKioskTemplate();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.fullySkipped
                ? 'La base simple ya estaba cargada.'
                : 'Base simple cargada. Ya puedes buscar y vender.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(userFacingErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _parseInt(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }

  String get _normalizedProductQuery => _productSearchController.text.trim();

  void _handleSaleDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleSaleModeChanged(SaleEntryMode mode) {
    if (_saleMode == mode) {
      return;
    }
    _dismissKeyboard();
    setState(() {
      _saleMode = mode;
      _autoValidateMode = AutovalidateMode.disabled;
    });

    if (mode == SaleEntryMode.catalog) {
      _moveFocusTo(_productFocusNode, controller: _productSearchController);
      return;
    }

    _moveFocusTo(
      _manualDescriptionFocusNode,
      controller: _manualDescriptionController,
    );
  }

  void _handleProductSearchChanged() {
    if (!mounted) {
      return;
    }

    final selectedProduct = _selectedProduct;
    if (selectedProduct != null &&
        !_matchesSelectedProductName(
          _productSearchController.text,
          selectedProduct,
        )) {
      setState(() => _selectedProduct = null);
      return;
    }

    setState(() {});
  }

  void _handleProductFocusChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  bool _matchesSelectedProductName(String value, Product product) {
    return value.trim().toLowerCase() == product.name.trim().toLowerCase();
  }

  List<Product> _filteredProducts(CommerceStore store) {
    final query = _normalizedProductQuery.toLowerCase();
    if (query.isEmpty) {
      return store.products.take(8).toList(growable: false);
    }

    return store.products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              CommerceStore.barcodeMatchesQuery(product.barcode, query) ||
              (product.category ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  bool _shouldShowProductResults(List<Product> filteredProducts) {
    if (_selectedProduct != null) {
      return false;
    }
    if (_productFocusNode.hasFocus) {
      return true;
    }
    return _normalizedProductQuery.isNotEmpty;
  }

  String? _productFieldErrorText(List<Product> filteredProducts) {
    if (_selectedProduct != null) {
      return null;
    }

    if (_autoValidateMode != AutovalidateMode.onUserInteraction) {
      return null;
    }

    final query = _normalizedProductQuery;
    if (query.isEmpty) {
      return 'Debes seleccionar un producto.';
    }

    if (filteredProducts.isNotEmpty) {
      return 'Debes seleccionar un producto.';
    }

    return null;
  }

  String? _productFieldHelperText(
    List<Product> filteredProducts,
    String? errorText,
  ) {
    if (errorText != null) {
      return null;
    }
    if (_selectedProduct != null) {
      return 'Producto listo. Sigue con la venta o cambialo.';
    }
    if (_normalizedProductQuery.isEmpty) {
      return 'Escribe, dicta o toca un producto para seleccionarlo.';
    }
    if (filteredProducts.isNotEmpty) {
      return 'Toca un resultado para confirmar el producto.';
    }
    return null;
  }

  Product? _exactCatalogMatchProduct(CommerceStore store) {
    final rawQuery = _productSearchController.text.trim();
    if (rawQuery.isEmpty) {
      return null;
    }
    return store.productByBarcode(rawQuery) ??
        store.productByNormalizedName(rawQuery);
  }

  void _commitProductSelection(
    Product product, {
    bool switchToCatalogMode = false,
  }) {
    _productSearchController.value = TextEditingValue(
      text: product.name,
      selection: TextSelection.collapsed(offset: product.name.length),
    );
    setState(() {
      if (switchToCatalogMode) {
        _saleMode = SaleEntryMode.catalog;
        _autoValidateMode = AutovalidateMode.disabled;
      }
      _selectedProduct = product;
    });
    _moveFocusTo(_quantityFocusNode, controller: _quantityController);
  }

  void _selectProduct(Product product) {
    _commitProductSelection(product);
  }

  void _clearSelectedProduct() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
    });
    _productFocusNode.requestFocus();
  }

  Product? _exactQuickMatchProduct(CommerceStore store) {
    final rawQuery = _manualDescriptionController.text.trim();
    if (rawQuery.isEmpty) {
      return null;
    }
    return store.productByBarcode(rawQuery) ??
        store.productByNormalizedName(rawQuery);
  }

  void _useExistingProductFromQuickSale(Product product) {
    _commitProductSelection(product, switchToCatalogMode: true);
  }

  void _showBlockedFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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

  ProductEditorSeed _buildProductSeedFromFreeSale() {
    return ProductEditorSeed(
      name: _manualDescriptionController.text.trim(),
      pricePesos: _parseInt(_manualUnitPriceController.text),
      stockUnits: 0,
      minStockUnits: 0,
    );
  }

  Future<void> _createProductFromFreeSale(CommerceStore store) async {
    final seed = _buildProductSeedFromFreeSale();
    if ((seed.name ?? '').trim().isEmpty) {
      _showBlockedFeedback(
        'Escribe una descripcion antes de crear el producto.',
      );
      return;
    }

    final exactMatch = _exactQuickMatchProduct(store);
    if (exactMatch != null) {
      _useExistingProductFromQuickSale(exactMatch);
      return;
    }

    final result = await showProductEditor(context, store, seed: seed);
    if (!mounted || result == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    _commitProductSelection(result.product, switchToCatalogMode: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.kind == ProductEditorResultKind.created
              ? '"${result.product.name}" ya quedo en el catalogo y seleccionado en la venta.'
              : '"${result.product.name}" ya estaba en el catalogo y quedo seleccionado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitSale(CommerceStore store) async {
    if (_saving) {
      return;
    }
    final quantity = _parseInt(_quantityController.text);
    final resolvedProduct =
        _saleMode == SaleEntryMode.catalog && _selectedProduct != null
        ? store.productById(_selectedProduct!.id)
        : null;
    final validationMessage = _saleMode == SaleEntryMode.catalog
        ? (resolvedProduct == null
              ? 'Debes seleccionar un producto.'
              : store.saleReadinessMessage(
                  resolvedProduct.id,
                  quantityUnits: quantity,
                ))
        : store.freeSaleReadinessMessage(
            description: _manualDescriptionController.text,
            quantityUnits: quantity,
            unitPricePesos: _parseInt(_manualUnitPriceController.text),
          );

    if ((_saleMode == SaleEntryMode.catalog && resolvedProduct == null) ||
        validationMessage != null) {
      if (_autoValidateMode == AutovalidateMode.disabled) {
        setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
      }
      _formKey.currentState!.validate();
      if (_saleMode == SaleEntryMode.quick) {
        _showBlockedFeedback(
          validationMessage ?? 'Revisa los datos de la venta.',
        );
      }
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = _saleMode == SaleEntryMode.catalog
        ? 'Venta registrada. Comprobante listo.'
        : 'Venta libre registrada. Comprobante listo.';

    try {
      if (_saleMode == SaleEntryMode.catalog) {
        await store.recordSale(
          productId: resolvedProduct!.id,
          quantityUnits: quantity,
          paymentMethod: _paymentMethod,
        );
      } else {
        await store.recordFreeSale(
          description: _manualDescriptionController.text,
          quantityUnits: quantity,
          unitPricePesos: _parseInt(_manualUnitPriceController.text),
          paymentMethod: _paymentMethod,
        );
      }
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      final receipt = _buildSavedReceiptData(store, resolvedProduct, quantity);
      await showSaleReceiptDialog(context, receipt: receipt);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.hideCurrentSnackBar();
      if (error is LicenseRestrictionException) {
        await showLicenseManagementDialog(
          context,
          lockedFeature: LockedFeature.sales,
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(error))),
      );
    }
  }

  SaleReceiptData _buildReceiptData({
    required Product? product,
    required int quantity,
    required int manualUnitPrice,
    required int total,
    required int? remaining,
  }) {
    final itemLabel = _saleMode == SaleEntryMode.catalog
        ? product?.name ?? 'Sin seleccionar'
        : _manualDescriptionController.text.trim().isEmpty
        ? 'Sin descripcion'
        : _manualDescriptionController.text.trim();
    final quantityValue = quantity <= 0 ? 0 : quantity;
    final unitPrice = _saleMode == SaleEntryMode.catalog
        ? product?.pricePesos
        : (manualUnitPrice <= 0 ? null : manualUnitPrice);
    final categoryLabel = _saleMode == SaleEntryMode.catalog
        ? product?.category
        : 'Venta libre';

    return SaleReceiptData(
      issuedAt: DateTime.now(),
      itemLabel: itemLabel,
      quantityUnits: quantityValue,
      totalPesos: total,
      paymentMethodLabel: displayPaymentMethodLabel(_paymentMethod),
      saleKindLabel: _saleMode == SaleEntryMode.catalog
          ? 'Venta de producto'
          : 'Venta libre',
      unitPricePesos: unitPrice,
      stockAfterUnits: _saleMode == SaleEntryMode.catalog ? remaining : null,
      categoryLabel: categoryLabel,
    );
  }

  SaleReceiptData _buildSavedReceiptData(
    CommerceStore store,
    Product? resolvedProduct,
    int quantity,
  ) {
    final savedMovement = store.lastMovement;
    final savedProduct = resolvedProduct == null
        ? null
        : store.productById(resolvedProduct.id);
    final itemLabel = _saleMode == SaleEntryMode.catalog
        ? savedProduct?.name ?? resolvedProduct?.name ?? 'Producto'
        : _manualDescriptionController.text.trim();
    final unitPrice = _saleMode == SaleEntryMode.catalog
        ? savedProduct?.pricePesos ?? resolvedProduct?.pricePesos
        : _parseInt(_manualUnitPriceController.text);

    return SaleReceiptData(
      issuedAt: savedMovement?.createdAt ?? DateTime.now(),
      itemLabel: itemLabel,
      quantityUnits: quantity,
      totalPesos: savedMovement?.amountPesos ?? 0,
      paymentMethodLabel: displayPaymentMethodLabel(_paymentMethod),
      saleKindLabel: _saleMode == SaleEntryMode.catalog
          ? 'Venta de producto'
          : 'Venta libre',
      unitPricePesos: unitPrice == null || unitPrice <= 0 ? null : unitPrice,
      stockAfterUnits: _saleMode == SaleEntryMode.catalog
          ? savedProduct?.stockUnits
          : null,
      categoryLabel: _saleMode == SaleEntryMode.catalog
          ? savedProduct?.category ?? resolvedProduct?.category
          : 'Venta libre',
      referenceLabel: _buildReceiptReference(savedMovement?.id),
    );
  }

  String? _buildReceiptReference(String? movementId) {
    final normalized = (movementId ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final tail = normalized.length <= 8
        ? normalized.toUpperCase()
        : normalized.substring(normalized.length - 8).toUpperCase();
    return 'CC-$tail';
  }
}

class _SaleFlowStatus {
  const _SaleFlowStatus({
    required this.title,
    required this.message,
    required this.icon,
    required this.isReady,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool isReady;
}

class _SaleStepSection extends StatelessWidget {
  const _SaleStepSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: BpcColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  step,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BpcColors.subtleInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PaymentMethodSelectorCard extends StatelessWidget {
  const _PaymentMethodSelectorCard({
    required this.options,
    required this.selectedValue,
    required this.hasCustomSelection,
    required this.onSelect,
  });

  final List<String> options;
  final String selectedValue;
  final bool hasCustomSelection;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasCustomSelection
              ? 'Quedo el ultimo cobro usado. Cambialo si hace falta.'
              : 'Marca el cobro.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              ChoiceChip(
                key: _paymentMethodKey(option),
                selected: option == selectedValue,
                showCheckmark: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paymentMethodIcon(option),
                      size: 16,
                      color: option == selectedValue
                          ? scheme.primary
                          : BpcColors.mutedInk,
                    ),
                    const SizedBox(width: 6),
                    Text(option),
                  ],
                ),
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: option == selectedValue
                      ? scheme.primary
                      : BpcColors.ink,
                  fontWeight: FontWeight.w800,
                ),
                backgroundColor: scheme.surface,
                selectedColor: scheme.primary.withValues(alpha: 0.12),
                side: BorderSide(
                  color: option == selectedValue
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                onSelected: (_) => onSelect(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _SaleCheckoutOverviewCard extends StatelessWidget {
  const _SaleCheckoutOverviewCard({
    required this.status,
    required this.receipt,
    required this.canSaveSale,
    required this.saving,
    required this.onSubmit,
    required this.onCancel,
  });

  final _SaleFlowStatus status;
  final SaleReceiptData receipt;
  final bool canSaveSale;
  final bool saving;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = status.isReady ? scheme.primary : scheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BpcPanel(
          color: status.isReady
              ? scheme.primary.withValues(alpha: 0.06)
              : scheme.errorContainer.withValues(alpha: 0.22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(status.icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: status.isReady ? BpcColors.ink : accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: BpcColors.subtleInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CheckoutMetaChip(
                    icon: Icons.receipt_long_rounded,
                    label: receipt.saleKindLabel,
                  ),
                  _CheckoutMetaChip(
                    icon: Icons.pin_rounded,
                    label: '${receipt.quantityUnits} u.',
                  ),
                  _CheckoutMetaChip(
                    icon: _paymentMethodIcon(receipt.paymentMethodLabel),
                    label: receipt.paymentMethodLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BpcColors.greenDeep,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: BpcColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total a cobrar',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney(receipt.totalPesos),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Detalle: ${receipt.itemLabel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Medio de pago: ${receipt.paymentMethodLabel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.white,
                  foregroundColor: BpcColors.greenDeep,
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale_rounded),
                label: Text(saving ? 'Guardando' : 'Registrar venta'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status.isReady
                          ? 'Caja y comprobante quedan al dia en el momento.'
                          : 'Completa lo que falta y despues registra la venta.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onCancel != null) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutMetaChip extends StatelessWidget {
  const _CheckoutMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Key _paymentMethodKey(String method) {
  final normalized = method
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return Key('payment-method-$normalized');
}

IconData _paymentMethodIcon(String method) {
  return switch (displayPaymentMethodLabel(method)) {
    'Efectivo' => Icons.payments_rounded,
    'Transferencia' => Icons.account_balance_rounded,
    'Mercado Pago' => Icons.qr_code_2_rounded,
    'Debito' => Icons.credit_score_rounded,
    'Credito' => Icons.credit_card_rounded,
    'Cuenta corriente' => Icons.menu_book_rounded,
    _ => Icons.wallet_rounded,
  };
}

class _SaleModeSelector extends StatelessWidget {
  const _SaleModeSelector({required this.currentMode, required this.onChanged});

  final SaleEntryMode currentMode;
  final ValueChanged<SaleEntryMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige como cargarla',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SaleModeChip(
              tapKey: const Key('sale-mode-catalog'),
              label: 'Producto cargado',
              icon: Icons.inventory_2_rounded,
              selected: currentMode == SaleEntryMode.catalog,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(SaleEntryMode.catalog),
            ),
            _SaleModeChip(
              tapKey: const Key('sale-mode-quick'),
              label: 'Venta libre',
              icon: Icons.flash_on_rounded,
              selected: currentMode == SaleEntryMode.quick,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(SaleEntryMode.quick),
            ),
          ],
        ),
      ],
    );
  }
}

class _SaleModeChip extends StatelessWidget {
  const _SaleModeChip({
    this.tapKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key? tapKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 168, maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExactProductSuggestionCard extends StatelessWidget {
  const _ExactProductSuggestionCard({
    required this.product,
    required this.onUseProduct,
  });

  final Product product;
  final VoidCallback onUseProduct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BpcPanel(
      color: scheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.inventory_2_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ya esta en el catalogo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SelectedProductMeta(
                      icon: Icons.sell_rounded,
                      label: formatMoney(product.pricePesos),
                    ),
                    _SelectedProductMeta(
                      icon: Icons.inventory_2_rounded,
                      label: 'Stock ${product.stockUnits}',
                    ),
                    if ((product.barcode ?? '').isNotEmpty)
                      _SelectedProductMeta(
                        icon: Icons.qr_code_rounded,
                        label: product.barcode!,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Conviene usar este producto para no duplicar catalogo ni stock.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onUseProduct,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Usar este producto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProductCard extends StatelessWidget {
  const _SelectedProductCard({
    required this.product,
    required this.onChangeProduct,
  });

  final Product product;
  final VoidCallback onChangeProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BpcPanel(
      color: scheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Producto listo',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SelectedProductMeta(
                      icon: Icons.sell_rounded,
                      label: formatMoney(product.pricePesos),
                    ),
                    _SelectedProductMeta(
                      icon: Icons.inventory_2_rounded,
                      label: 'Stock ${product.stockUnits}',
                    ),
                    if ((product.barcode ?? '').isNotEmpty)
                      _SelectedProductMeta(
                        icon: Icons.qr_code_rounded,
                        label: product.barcode!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onChangeProduct, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}

class _SelectedProductMeta extends StatelessWidget {
  const _SelectedProductMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProductSearchResults extends StatelessWidget {
  const _ProductSearchResults({
    required this.products,
    required this.hasActiveQuery,
    required this.onSelect,
  });

  final List<Product> products;
  final bool hasActiveQuery;
  final ValueChanged<Product> onSelect;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return BpcPanel(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              'No se encontraron productos',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveQuery
                  ? 'Prueba con otro nombre, categoria o codigo.'
                  : 'Todavia no hay productos para elegir.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return BpcPanel(
      padding: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemCount: products.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.44),
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductSearchResultTile(
              product: product,
              onTap: () => onSelect(product),
            );
          },
        ),
      ),
    );
  }
}

class _ProductSearchResultTile extends StatelessWidget {
  const _ProductSearchResultTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        product.category ?? 'Sin categoria',
                        formatMoney(product.pricePesos),
                        if ((product.barcode ?? '').isNotEmpty)
                          product.barcode!,
                      ].join(' / '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${product.stockUnits} u.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
