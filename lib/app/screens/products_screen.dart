import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../utils/text_field_selection.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/operation_dialogs.dart';
import '../widgets/product_form_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.onApplyStarterTemplate,
    required this.applyingStarterTemplate,
    required this.onLoadDemoData,
    required this.loadingDemoData,
  });

  final Future<void> Function() onApplyStarterTemplate;
  final bool applyingStarterTemplate;
  final Future<void> Function() onLoadDemoData;
  final bool loadingDemoData;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _debouncedQuery = '';
  bool _onlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final products = _filteredProducts(store.products);
        final emptyCatalog = store.products.isEmpty;
        final canLoadDemoData = store.isEmptyState;
        final filteredEmpty = products.isEmpty && !emptyCatalog;
        return InputShortcutScope(
          onCancel: () {
            if (_searchController.text.isNotEmpty || _onlyLowStock) {
              _clearFilters();
            }
            _searchFocusNode.unfocus();
          },
          onFocusSearch: () =>
              focusAndSelectAll(_searchFocusNode, _searchController),
          child: FocusTraversalGroup(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Productos',
                    subtitle:
                        'Carga, busca y corrige productos sin perder de vista stock y precio',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (emptyCatalog && canLoadDemoData)
                        FilledButton.icon(
                          onPressed: widget.loadingDemoData
                              ? null
                              : () => widget.onLoadDemoData(),
                          icon: widget.loadingDemoData
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_circle_rounded),
                          label: Text(
                            widget.loadingDemoData
                                ? 'Cargando demo'
                                : 'Demo comercial',
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed:
                            widget.applyingStarterTemplate ||
                                widget.loadingDemoData
                            ? null
                            : () => widget.onApplyStarterTemplate(),
                        icon: widget.applyingStarterTemplate
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.storefront_rounded),
                        label: const Text('Plantilla kiosco'),
                      ),
                      FilledButton.icon(
                        onPressed: () => showProductEditor(context, store),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar producto'),
                      ),
                    ],
                  ),
                  if (!emptyCatalog) ...[
                    const SizedBox(height: 14),
                    _CatalogMetricsStrip(store: store),
                  ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 700;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: wide
                                ? constraints.maxWidth - 180
                                : constraints.maxWidth,
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              onTapOutside: (_) => _searchFocusNode.unfocus(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded),
                                labelText: 'Buscar producto',
                                hintText:
                                    'Nombre, categoria o codigo de barras',
                              ),
                            ),
                          ),
                          FilterChip(
                            selected: _onlyLowStock,
                            label: const Text('Solo bajo stock'),
                            onSelected: (value) {
                              setState(() => _onlyLowStock = value);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 10),
                    _ActiveFilterCard(
                      message: _activeFilterLabel,
                      onClear: _clearFilters,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (products.isEmpty)
                    EmptyCard(
                      title: emptyCatalog
                          ? 'Todavia no cargaste productos'
                          : 'Sin resultados',
                      message: emptyCatalog
                          ? canLoadDemoData
                                ? 'Puedes empezar con la plantilla kiosco o crear tus productos a mano. Todo queda editable y se guarda localmente.'
                                : 'Ya hay movimientos guardados, asi que conviene sumar catalogo real con una plantilla kiosco o alta manual sin pisar ese historial.'
                          : 'No hay productos con ese filtro. Ajusta la busqueda o carga uno nuevo.',
                      action: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          if (emptyCatalog && canLoadDemoData)
                            FilledButton(
                              onPressed: widget.loadingDemoData
                                  ? null
                                  : () => widget.onLoadDemoData(),
                              child: Text(
                                widget.loadingDemoData
                                    ? 'Cargando demo...'
                                    : 'Cargar demo comercial',
                              ),
                            ),
                          if (emptyCatalog)
                            OutlinedButton(
                              onPressed:
                                  widget.applyingStarterTemplate ||
                                      widget.loadingDemoData
                                  ? null
                                  : () => widget.onApplyStarterTemplate(),
                              child: Text(
                                widget.applyingStarterTemplate
                                    ? 'Cargando plantilla...'
                                    : 'Cargar plantilla kiosco',
                              ),
                            ),
                          if (filteredEmpty)
                            FilledButton(
                              onPressed: _clearFilters,
                              child: const Text('Limpiar filtros'),
                            ),
                          TextButton(
                            onPressed: () => showProductEditor(context, store),
                            child: const Text('Agregar producto'),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final product in products)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProductTile(
                              product: product,
                              onTap: () => showProductEditor(
                                context,
                                store,
                                product: product,
                              ),
                              onAdjustStock: () => _addStock(store, product),
                              onDelete: () => _deleteProduct(store, product),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _hasActiveFilters => _searchQuery.trim().isNotEmpty || _onlyLowStock;

  String get _activeFilterLabel {
    final parts = <String>[];
    if (_searchQuery.trim().isNotEmpty) {
      parts.add('busqueda: "${_searchQuery.trim()}"');
    }
    if (_onlyLowStock) {
      parts.add('solo bajo stock');
    }
    return 'Filtro activo: ${parts.join(' + ')}';
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text;
    if (_searchQuery != query) {
      setState(() => _searchQuery = query);
    }
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      if (_debouncedQuery != query) {
        setState(() => _debouncedQuery = query);
      }
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.clear();
    _searchController.addListener(_handleSearchChanged);
    setState(() {
      _searchQuery = '';
      _debouncedQuery = '';
      _onlyLowStock = false;
    });
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _debouncedQuery.trim().toLowerCase();
    return products
        .where((product) {
          final matchesQuery =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.category ?? '').toLowerCase().contains(query) ||
              CommerceStore.barcodeMatchesQuery(product.barcode, query);
          final matchesLowStock = !_onlyLowStock || product.isLowStock;
          return matchesQuery && matchesLowStock;
        })
        .toList(growable: false);
  }

  Future<void> _addStock(CommerceStore store, Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: 'Ajustar stock',
      label: 'Cantidad a sumar',
      confirmLabel: 'Guardar',
      helper: 'Se registra un ajuste de stock sobre ${product.name}.',
    );
    if (amount == null || !mounted) {
      return;
    }

    try {
      await store.addStockToProduct(
        productId: product.id,
        quantityUnits: amount,
        note: 'Productos',
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Stock actualizado para ${product.name}.'),
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

  Future<void> _deleteProduct(CommerceStore store, Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDangerConfirmationDialog(
      context,
      title: 'Eliminar producto',
      message:
          'Se va a eliminar "${product.name}". Si ya tiene movimientos, la app lo bloqueara para cuidar tu historial.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await store.removeProduct(product.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('${product.name} se elimino del catalogo'),
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
}

class _CatalogMetricsStrip extends StatelessWidget {
  const _CatalogMetricsStrip({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.all(14),
      color: Colors.white.withValues(alpha: 0.78),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 880
              ? 4
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          final gaps = columns > 1 ? 10.0 * (columns - 1) : 0.0;
          final itemWidth = (constraints.maxWidth - gaps) / columns;
          final cards = <Widget>[
            MetricCard(
              label: 'Productos cargados',
              value: '${store.products.length}',
              helper: '${store.totalStockUnits} unidades en stock',
              tight: true,
            ),
            MetricCard(
              label: 'Listos para vender',
              value: '${store.sellableProductsCount}',
              helper: 'Con precio y stock positivo',
              tight: true,
            ),
            MetricCard(
              label: 'Cobertura barcode',
              value:
                  '${store.productsWithBarcodeCount}/${store.products.length}',
              helper: 'Productos listos para scanner',
              tight: true,
            ),
            MetricCard(
              label: 'Stock valorizado',
              value: formatMoney(store.estimatedInventoryCostPesos),
              helper: '${store.lowStockCount} alertas de reposicion',
              tight: true,
            ),
          ];

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map((card) => SizedBox(width: itemWidth, child: card))
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onAdjustStock,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: BpcPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category?.isNotEmpty == true
                              ? product.category!
                              : 'Sin categoria',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.outline),
                        ),
                        if (product.barcode != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Cod. ${product.barcode}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.outline,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<_ProductTileAction>(
                    tooltip: 'Acciones',
                    onSelected: (value) {
                      if (value == _ProductTileAction.edit) {
                        onTap();
                        return;
                      }
                      onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ProductTileAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _ProductTileAction.delete,
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  StockBadge(product: product),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 420;
                  final cells = <Widget>[
                    _InfoChip(
                      label: 'Stock',
                      value: product.stockUnits.toString(),
                    ),
                    _InfoChip(
                      label: 'Minimo',
                      value: product.minStockUnits.toString(),
                    ),
                    _InfoChip(
                      label: 'Costo',
                      value: formatMoney(product.costPesos),
                    ),
                    _InfoChip(
                      label: 'Precio',
                      value: formatMoney(product.pricePesos),
                    ),
                  ];

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: cells
                        .map(
                          (cell) => SizedBox(
                            width: wide
                                ? (constraints.maxWidth - 10) / 2
                                : constraints.maxWidth,
                            child: cell,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAdjustStock,
                    icon: const Icon(Icons.add_box_rounded),
                    label: const Text('Ajustar stock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProductTileAction { edit, delete }

class _ActiveFilterCard extends StatelessWidget {
  const _ActiveFilterCard({required this.message, required this.onClear});

  final String message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onClear, child: const Text('Limpiar')),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
