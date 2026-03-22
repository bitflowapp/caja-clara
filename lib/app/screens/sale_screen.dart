import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/speech_dictation.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productSearchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _productFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _paymentFocusNode = FocusNode();
  final _productSearchDictation = SpeechDictationController();
  Product? _selectedProduct;
  String _paymentMethod = 'Efectivo';
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _productSearchController.text = widget.initialProduct?.name ?? '';
    _productSearchController.addListener(_handleProductSearchChanged);
    _productFocusNode.addListener(_handleProductFocusChanged);
    selectAllTextOnFocus(_quantityFocusNode, _quantityController);
    _productSearchDictation.initialize();
  }

  @override
  void dispose() {
    _productSearchController
      ..removeListener(_handleProductSearchChanged)
      ..dispose();
    _quantityController.dispose();
    _productFocusNode.removeListener(_handleProductFocusChanged);
    _productFocusNode.dispose();
    _quantityFocusNode.dispose();
    _paymentFocusNode.dispose();
    _productSearchDictation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (!store.hasProducts) {
            return KeyboardAwarePageBody(
              child: BpcPanel(
                child: EmptyCard(
                  title: 'Primero carga tus productos',
                  message:
                      'Para vender sin vueltas, empieza con la plantilla kiosco o agrega tu primer producto manualmente.',
                  icon: Icons.inventory_2_rounded,
                  action: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () => _loadStarterTemplate(store),
                        child: const Text('Cargar plantilla kiosco'),
                      ),
                      TextButton(
                        onPressed: () => showProductEditor(context, store),
                        child: const Text('Agregar producto'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final product = _selectedProduct == null
              ? null
              : store.productById(_selectedProduct!.id);
          if (_selectedProduct != null && product == null) {
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
          final filteredProducts = _filteredProducts(store);
          final productFieldError = _productFieldErrorText(filteredProducts);
          final productFieldHelper = _productFieldHelperText(
            filteredProducts,
            productFieldError,
          );
          final saleWarning = product == null
              ? null
              : store.saleReadinessMessage(product.id, quantityUnits: quantity);
          final total = product == null ? 0 : product.pricePesos * quantity;
          final remaining = product == null
              ? null
              : product.stockUnits - quantity;
          final canSaveSale =
              !_saving &&
              product != null &&
              saleWarning == null &&
              quantity > 0;
          return KeyboardAwarePageBody(
            child: InputShortcutScope(
              onSave: _saving ? null : () => _submitSale(store),
              onCancel: _saving ? null : () => Navigator.of(context).maybePop(),
              onFocusSearch: () => focusAndSelectAll(
                _productFocusNode,
                _productSearchController,
              ),
              child: BpcPanel(
                child: FocusTraversalGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar venta',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Elegi producto, cantidad y medio de pago. Guardar es directo.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _productSearchController,
                          focusNode: _productFocusNode,
                          autofocus: widget.initialProduct == null,
                          textInputAction: TextInputAction.search,
                          onTapOutside: (_) => _productFocusNode.unfocus(),
                          onFieldSubmitted: (_) {
                            if (_selectedProduct != null) {
                              _quantityFocusNode.requestFocus();
                              return;
                            }
                            if (_autoValidateMode ==
                                AutovalidateMode.disabled) {
                              setState(() {
                                _autoValidateMode =
                                    AutovalidateMode.onUserInteraction;
                              });
                            }
                            _showBlockedFeedback(
                              productFieldError ?? 'Debes seleccionar un producto.',
                            );
                          },
                          decoration: InputDecoration(
                            labelText: 'Buscar producto',
                            hintText: 'Escribe y toca un resultado',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: SpeechDictationActionButton(
                              controller: _productSearchDictation,
                              textController: _productSearchController,
                              tooltip: 'Dictar busqueda',
                            ),
                            errorText: productFieldError,
                            helperText: productFieldHelper,
                          ),
                        ),
                        SpeechDictationHint(
                          controller: _productSearchDictation,
                        ),
                        if (_shouldShowProductResults(filteredProducts)) ...[
                          const SizedBox(height: 14),
                          _ProductSearchResults(
                            products: filteredProducts,
                            hasActiveQuery: _normalizedProductQuery.isNotEmpty,
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
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 600;
                            final fieldWidth = wide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: TextFormField(
                                    controller: _quantityController,
                                    focusNode: _quantityFocusNode,
                                    autofocus: widget.initialProduct != null,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                    ),
                                    onTapOutside: (_) =>
                                        _quantityFocusNode.unfocus(),
                                    onChanged: (_) => setState(() {}),
                                    onFieldSubmitted: (_) =>
                                        _paymentFocusNode.requestFocus(),
                                    validator: (value) {
                                      if (product == null) {
                                        final parsed = _parseInt(value);
                                        return parsed <= 0
                                            ? 'Ingresa una cantidad'
                                            : null;
                                      }
                                      return store.saleReadinessMessage(
                                        product.id,
                                        quantityUnits: _parseInt(value),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String>(
                                    focusNode: _paymentFocusNode,
                                    initialValue: _paymentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Medio de pago',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Efectivo',
                                        child: Text('Efectivo'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Debito',
                                        child: Text('Debito'),
                                      ),
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
                                    onTap: () =>
                                        _paymentFocusNode.requestFocus(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        BpcPanel(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              _SummaryRow(
                                label: 'Producto',
                                value: product?.name ?? 'Sin seleccionar',
                              ),
                              _SummaryRow(
                                label: 'Cantidad',
                                value: quantity.toString(),
                              ),
                              _SummaryRow(
                                label: 'Total',
                                value: formatMoney(total),
                              ),
                              _SummaryRow(
                                label: 'Stock restante',
                                value: remaining == null
                                    ? '-'
                                    : remaining.toString(),
                              ),
                              if (saleWarning != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  saleWarning,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 520;
                            final saveButton = FilledButton.icon(
                              onPressed: canSaveSale
                                  ? () => _submitSale(store)
                                  : null,
                              style: compact
                                  ? FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                    )
                                  : null,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _saving ? 'Guardando' : 'Guardar venta',
                              ),
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  saveButton,
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    child: const Text('Cancelar'),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                const Spacer(),
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 12),
                                saveButton,
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
          );
        },
      ),
    );
  }

  Future<void> _loadStarterTemplate(CommerceStore store) async {
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
                ? 'La plantilla kiosco ya estaba cargada.'
                : 'Plantilla kiosco cargada. Ya puedes buscar y vender.',
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

    return store.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query) ||
          (product.category ?? '').toLowerCase().contains(query);
    }).toList(growable: false);
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

    final query = _normalizedProductQuery;
    if (query.isEmpty) {
      return _autoValidateMode == AutovalidateMode.onUserInteraction
          ? 'Debes seleccionar un producto.'
          : null;
    }

    if (filteredProducts.isEmpty) {
      return 'No se encontraron productos.';
    }

    return 'Debes seleccionar un producto.';
  }

  String? _productFieldHelperText(
    List<Product> filteredProducts,
    String? errorText,
  ) {
    if (errorText != null) {
      return null;
    }
    if (_selectedProduct != null) {
      return 'Producto seleccionado. Puedes seguir con la venta o buscar otro.';
    }
    if (_normalizedProductQuery.isEmpty) {
      return 'Escribe, dicta o toca un producto para seleccionarlo.';
    }
    if (filteredProducts.isNotEmpty) {
      return 'Toca un resultado para confirmar el producto.';
    }
    return null;
  }

  void _selectProduct(Product product) {
    _productSearchController.value = TextEditingValue(
      text: product.name,
      selection: TextSelection.collapsed(offset: product.name.length),
    );
    setState(() => _selectedProduct = product);
    _productFocusNode.unfocus();
    _quantityFocusNode.requestFocus();
  }

  void _clearSelectedProduct() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
    });
    _productFocusNode.requestFocus();
  }

  void _showBlockedFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submitSale(CommerceStore store) async {
    if (_saving) {
      return;
    }
    final resolvedProduct = _selectedProduct == null
        ? null
        : store.productById(_selectedProduct!.id);
    final quantity = _parseInt(_quantityController.text);
    final validationMessage = resolvedProduct == null
        ? 'Debes seleccionar un producto.'
        : store.saleReadinessMessage(
            resolvedProduct.id,
            quantityUnits: quantity,
          );

    if (resolvedProduct == null || validationMessage != null) {
      if (_autoValidateMode == AutovalidateMode.disabled) {
        setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
      }
      _formKey.currentState!.validate();
      _showBlockedFeedback(
        validationMessage ?? 'Revisa los datos de la venta.',
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await store.recordSale(
        productId: resolvedProduct.id,
        quantityUnits: quantity,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Venta guardada. Caja y stock al dia.')),
      );
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
                  'Producto seleccionado',
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
          TextButton(
            onPressed: onChangeProduct,
            child: const Text('Cambiar'),
          ),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
                        if ((product.barcode ?? '').isNotEmpty) product.barcode!,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
