import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/barcode_scanner_input.dart';
import '../services/commerce_store.dart';
import '../services/product_catalog_service.dart';
import '../services/visual_signature_service.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../utils/payment_methods.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/operation_dialogs.dart';
import '../widgets/product_form_dialog.dart';
import 'expense_screen.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _searchController = TextEditingController();
  final _scannerController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scannerFocusNode = FocusNode();
  final List<_CartLine> _cart = <_CartLine>[];

  String _paymentMethod = defaultSalePaymentMethod;
  bool _didSeedDefaults = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshDraft);
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
    final initialProduct = widget.initialProduct;
    if (initialProduct != null) {
      _addProduct(initialProduct, showFeedback: false);
    }
    _didSeedDefaults = true;
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshDraft)
      ..dispose();
    _scannerController.dispose();
    _searchFocusNode.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            tooltip: 'Registrar gasto',
            onPressed: _saving ? null : _openExpense,
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          IconButton(
            tooltip: 'Cierre del dia',
            onPressed: _saving ? null : () => _showDailySummary(store),
            icon: const Icon(Icons.summarize_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final catalog = ProductCatalogService(store);
          return KeyboardAwarePageBody(
            child: InputShortcutScope(
              onSave: _cart.isEmpty || _saving ? null : () => _checkout(store),
              onCancel: _saving ? null : () => Navigator.of(context).maybePop(),
              onFocusSearch: () => _searchFocusNode.requestFocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final catalogPane = _CatalogPane(
                    catalog: catalog,
                    searchController: _searchController,
                    scannerController: _scannerController,
                    searchFocusNode: _searchFocusNode,
                    scannerFocusNode: _scannerFocusNode,
                    onBarcodeSubmitted: (value) =>
                        _handleBarcodeSubmitted(store, value),
                    onAddProduct: _addProduct,
                    onCreateProduct: () => _createProductAndAsk(store),
                    onPhotoLookup: () => _handlePhotoLookup(store),
                    onExpense: _openExpense,
                    onDailySummary: () => _showDailySummary(store),
                  );
                  final cartPane = _CartPane(
                    cart: _cart,
                    paymentMethod: _paymentMethod,
                    saving: _saving,
                    onIncrease: _increaseQuantity,
                    onDecrease: _decreaseQuantity,
                    onRemove: _removeLine,
                    onPaymentChanged: (value) =>
                        setState(() => _paymentMethod = value),
                    onCheckout: _cart.isEmpty || _saving
                        ? null
                        : () => _checkout(store),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: catalogPane),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: cartPane),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      catalogPane,
                      const SizedBox(height: 18),
                      cartPane,
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _addProduct(Product product, {bool showFeedback = true}) {
    final currentIndex = _cart.indexWhere(
      (line) => line.product.id == product.id,
    );
    if (currentIndex == -1) {
      setState(() {
        _cart.add(_CartLine(product: product));
      });
    } else {
      _increaseQuantity(_cart[currentIndex]);
    }
    _scannerController.clear();
    if (showFeedback) {
      _showMessage('${product.name} agregado al carrito.');
    }
  }

  void _increaseQuantity(_CartLine line) {
    setState(() {
      line.quantity += 1;
    });
  }

  void _decreaseQuantity(_CartLine line) {
    setState(() {
      if (line.quantity <= 1) {
        _cart.remove(line);
      } else {
        line.quantity -= 1;
      }
    });
  }

  void _removeLine(_CartLine line) {
    setState(() {
      _cart.remove(line);
    });
  }

  Future<void> _handleBarcodeSubmitted(
    CommerceStore store,
    String rawInput,
  ) async {
    final barcode = BarcodeScannerInput.parseSubmitted(rawInput);
    _scannerController.clear();
    if (barcode == null) {
      _showMessage('Escanea o escribe un codigo valido.');
      return;
    }

    final product = ProductCatalogService(store).findByBarcode(barcode);
    if (product != null) {
      _addProduct(product);
      return;
    }

    final result = await _openProductEditor(store, barcode: barcode);
    if (result == null || !mounted) {
      return;
    }
    await _askAddCreatedProductToCart(result.product);
  }

  Future<ProductEditorResult?> _openProductEditor(
    CommerceStore store, {
    String? barcode,
    String? imagePath,
    String? visualSignature,
  }) {
    return showProductEditor(
      context,
      store,
      initialBarcode: barcode,
      seed: ProductEditorSeed(
        stockUnits: 10,
        minStockUnits: 0,
        barcode: barcode,
        imagePath: imagePath,
        visualSignature: visualSignature,
      ),
    );
  }

  Future<void> _createProductAndAsk(CommerceStore store) async {
    final result = await _openProductEditor(store);
    if (result == null || !mounted) {
      return;
    }
    await _askAddCreatedProductToCart(result.product);
  }

  Future<void> _handlePhotoLookup(CommerceStore store) async {
    try {
      const imageTypeGroup = XTypeGroup(
        label: 'Imagen',
        extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[imageTypeGroup],
      );
      if (file == null) {
        return;
      }

      final signature = VisualSignatureService.generate(
        await file.readAsBytes(),
      );
      if (signature.isEmpty) {
        _showMessage('No pudimos leer esa imagen.');
        return;
      }

      final match = ProductCatalogService(store).bestVisualMatch(signature);
      if (match != null && mounted) {
        await _confirmVisualMatch(match);
        return;
      }

      if (!mounted) {
        return;
      }
      final result = await _openProductEditor(
        store,
        imagePath: file.path.isEmpty ? file.name : file.path,
        visualSignature: signature,
      );
      if (result == null || !mounted) {
        _showMessage('No hubo coincidencia segura.');
        return;
      }
      await _askAddCreatedProductToCart(result.product);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(userFacingErrorMessage(error));
    }
  }

  Future<void> _confirmVisualMatch(VisualProductMatch match) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Producto sugerido'),
          content: Text(
            'Parece ${match.product.name}. Revisa antes de agregarlo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      _addProduct(match.product);
    }
  }

  Future<void> _askAddCreatedProductToCart(Product product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Producto guardado'),
          content: Text('Agregar ${product.name} al carrito ahora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      _addProduct(product);
    }
  }

  Future<void> _openExpense() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ExpenseScreen()),
    );
    if (!mounted || result == null) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _showDailySummary(CommerceStore store) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final totalSales = store.todaySalesPesos;
        final totalExpenses = store.todayExpensesPesos;
        final net = totalSales - totalExpenses;
        final expectedCash = store.todayExpectedCashPesos;
        return AlertDialog(
          title: const Text('Cierre del dia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DailySummaryRow(label: 'Ventas', value: formatMoney(totalSales)),
              _DailySummaryRow(
                label: 'Gastos',
                value: formatMoney(totalExpenses),
              ),
              const Divider(),
              _DailySummaryRow(label: 'Neto', value: formatMoney(net)),
              _DailySummaryRow(
                label: 'Cantidad de ventas',
                value: store.todaySalesCount.toString(),
              ),
              _DailySummaryRow(
                label: 'Caja del dia',
                value: expectedCash == null ? '-' : formatMoney(expectedCash),
              ),
              if (expectedCash == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Para cerrar caja, primero registrá una apertura desde la pestaña Resumen.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: store.hasCashOpeningToday
                  ? () async {
                      Navigator.of(context).pop();
                      await _registerCashClosing(store);
                    }
                  : null,
              child: const Text('Cerrar caja'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerCashClosing(CommerceStore store) async {
    if (_saving) {
      return;
    }

    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashClosingToday ? 'Actualizar cierre' : 'Cierre de caja',
      label: 'Caja contada',
      confirmLabel: store.hasCashClosingToday ? 'Actualizar' : 'Guardar',
      helper: 'Ingresa el monto contado al cierre.',
      initialValue: store.todayClosingCashPesos,
    );
    if (amount == null || !mounted) {
      return;
    }

    var overwrite = false;
    if (store.hasCashClosingToday) {
      overwrite = await showDangerConfirmationDialog(
        context,
        title: 'Reemplazar cierre',
        message: 'Ya existe un cierre registrado hoy. Se reemplazara.',
        confirmLabel: 'Reemplazar',
      );
      if (!overwrite || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await store.registerCashClosing(
        closingBalancePesos: amount,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Cierre de caja registrado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'No se pudo registrar el cierre: ${userFacingErrorMessage(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _checkout(CommerceStore store) async {
    if (_cart.isEmpty || _saving) {
      return;
    }

    for (final line in _cart) {
      final message = store.saleReadinessMessage(
        line.product.id,
        quantityUnits: line.quantity,
      );
      if (message != null) {
        _showMessage('${line.product.name}: $message');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final total = _cart.fold<int>(0, (sum, line) => sum + line.total);
      for (final line in List<_CartLine>.of(_cart)) {
        await store.recordSale(
          productId: line.product.id,
          quantityUnits: line.quantity,
          paymentMethod: _paymentMethod,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _cart.clear();
        _saving = false;
      });
      _searchController.clear();
      _showMessage('Venta registrada: ${formatMoney(total)}');
      _scannerFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showMessage(userFacingErrorMessage(error));
    }
  }

  void _refreshDraft() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.catalog,
    required this.searchController,
    required this.scannerController,
    required this.searchFocusNode,
    required this.scannerFocusNode,
    required this.onBarcodeSubmitted,
    required this.onAddProduct,
    required this.onCreateProduct,
    required this.onPhotoLookup,
    required this.onExpense,
    required this.onDailySummary,
  });

  final ProductCatalogService catalog;
  final TextEditingController searchController;
  final TextEditingController scannerController;
  final FocusNode searchFocusNode;
  final FocusNode scannerFocusNode;
  final ValueChanged<String> onBarcodeSubmitted;
  final ValueChanged<Product> onAddProduct;
  final VoidCallback onCreateProduct;
  final VoidCallback onPhotoLookup;
  final VoidCallback onExpense;
  final VoidCallback onDailySummary;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text;
    final results = catalog.searchByName(query);
    final favorites = catalog.getFavorites();
    final frequent = catalog.getFrequentProducts();
    final quickProducts = <Product>[
      ...favorites,
      for (final product in frequent)
        if (!favorites.any((favorite) => favorite.id == product.id)) product,
    ].take(12).toList(growable: false);

    return BpcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Venta de mostrador',
            subtitle: 'Escanea, busca o toca un producto. Menos pasos.',
            trailing: IconButton(
              tooltip: 'Buscar por foto',
              onPressed: onPhotoLookup,
              icon: const Icon(Icons.photo_camera_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: scannerController,
            focusNode: scannerFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Escaner USB o codigo',
              hintText: 'Escanea y Enter',
              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
            ),
            onSubmitted: onBarcodeSubmitted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Buscar producto',
              hintText: 'Nombre del producto',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (query.trim().isNotEmpty)
            _ProductResults(products: results, onAddProduct: onAddProduct)
          else
            _QuickProducts(products: quickProducts, onAddProduct: onAddProduct),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Nuevo producto'),
              ),
              OutlinedButton.icon(
                onPressed: onPhotoLookup,
                icon: const Icon(Icons.image_search_rounded),
                label: const Text('Buscar por foto'),
              ),
              OutlinedButton.icon(
                onPressed: onExpense,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Gasto'),
              ),
              OutlinedButton.icon(
                onPressed: onDailySummary,
                icon: const Icon(Icons.summarize_rounded),
                label: const Text('Cierre'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductResults extends StatelessWidget {
  const _ProductResults({required this.products, required this.onAddProduct});

  final List<Product> products;
  final ValueChanged<Product> onAddProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const EmptyCard(
        title: 'Sin resultados',
        message: 'Si no existe, crealo una vez y queda listo.',
        icon: Icons.search_off_rounded,
        framed: false,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: products.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = products[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(product.name),
            subtitle: Text(_productSubtitle(product)),
            trailing: FilledButton(
              onPressed: () => onAddProduct(product),
              child: const Text('Agregar'),
            ),
          );
        },
      ),
    );
  }
}

class _QuickProducts extends StatelessWidget {
  const _QuickProducts({required this.products, required this.onAddProduct});

  final List<Product> products;
  final ValueChanged<Product> onAddProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const EmptyCard(
        title: 'Sin favoritos aun',
        message:
            'Marca productos como favoritos o vende algunos para verlos aca.',
        icon: Icons.star_border_rounded,
        framed: false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favoritos y frecuentes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final product in products)
              ActionChip(
                avatar: Icon(
                  product.isFavorite
                      ? Icons.star_rounded
                      : Icons.local_fire_department_rounded,
                  size: 18,
                ),
                label: Text(
                  '${product.name}  ${formatMoney(product.pricePesos)}',
                ),
                onPressed: () => onAddProduct(product),
              ),
          ],
        ),
      ],
    );
  }
}

class _CartPane extends StatelessWidget {
  const _CartPane({
    required this.cart,
    required this.paymentMethod,
    required this.saving,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onPaymentChanged,
    required this.onCheckout,
  });

  final List<_CartLine> cart;
  final String paymentMethod;
  final bool saving;
  final ValueChanged<_CartLine> onIncrease;
  final ValueChanged<_CartLine> onDecrease;
  final ValueChanged<_CartLine> onRemove;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final total = cart.fold<int>(0, (sum, line) => sum + line.total);
    return BpcPanel(
      color: BpcColors.surfaceStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Carrito',
            subtitle: cart.isEmpty
                ? 'Agrega productos para cobrar.'
                : '${cart.length} productos',
          ),
          const SizedBox(height: 16),
          if (cart.isEmpty)
            const EmptyCard(
              title: 'Carrito vacio',
              message: 'Escanea o busca un producto para empezar.',
              icon: Icons.shopping_cart_outlined,
              framed: false,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cart.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = cart[index];
                return _CartLineTile(
                  line: line,
                  onIncrease: () => onIncrease(line),
                  onDecrease: () => onDecrease(line),
                  onRemove: () => onRemove(line),
                );
              },
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Medio de pago'),
            items: [
              for (final option in salePaymentMethodOptions(
                selectedValue: paymentMethod,
              ))
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      onPaymentChanged(value);
                    }
                  },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BpcColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  formatMoney(total),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: BpcColors.income,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCheckout,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(saving ? 'Cobrando...' : 'Registrar venta'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final _CartLine line;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMoney(line.product.pricePesos)} c/u',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BpcColors.subtleInk),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restar',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text(
            line.quantity.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            tooltip: 'Sumar',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatMoney(line.total),
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _DailySummaryRow extends StatelessWidget {
  const _DailySummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CartLine {
  _CartLine({required this.product}) : quantity = 1;

  final Product product;
  int quantity;

  int get total => product.pricePesos * quantity;
}

String _productSubtitle(Product product) {
  final parts = <String>[
    formatMoney(product.pricePesos),
    'Stock ${product.stockUnits}',
    if ((product.category ?? '').trim().isNotEmpty) product.category!.trim(),
    if ((product.barcode ?? '').trim().isNotEmpty) 'Cod. ${product.barcode}',
  ];
  return parts.join(' / ');
}
