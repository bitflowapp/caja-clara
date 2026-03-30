import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../services/license_service.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../utils/text_field_selection.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/license_dialogs.dart';
import '../widgets/operation_dialogs.dart';
import '../widgets/product_form_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.onApplyStarterTemplate,
    required this.applyingStarterTemplate,
    required this.onLoadDemoData,
    required this.loadingDemoData,
    required this.onChooseEmptyCatalogStart,
    this.onSellProduct,
  });

  final Future<void> Function() onApplyStarterTemplate;
  final bool applyingStarterTemplate;
  final Future<void> Function() onLoadDemoData;
  final bool loadingDemoData;
  final Future<void> Function() onChooseEmptyCatalogStart;
  final Future<void> Function(Product product)? onSellProduct;

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
  bool _onlyMissingBarcode = false;
  bool _onlyNeedsAttention = false;

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
        final showInitialSetupChoice = store.shouldPromptInitialCatalogSetup;
        final canLoadDemoData = store.isEmptyState && showInitialSetupChoice;
        final filteredEmpty = products.isEmpty && !emptyCatalog;
        final withoutBarcodeCount = store.productsWithoutBarcodeCount;
        final needsAttentionCount = store.productsNeedingCatalogReviewCount;

        return InputShortcutScope(
          onCancel: () {
            if (_hasActiveFilters) {
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
                  _CatalogOverviewCard(
                    store: store,
                    applyingStarterTemplate: widget.applyingStarterTemplate,
                    loadingDemoData: widget.loadingDemoData,
                    canLoadDemoData: canLoadDemoData,
                    showInitialSetupChoice: showInitialSetupChoice,
                    onApplyStarterTemplate: widget.onApplyStarterTemplate,
                    onLoadDemoData: widget.onLoadDemoData,
                    onChooseEmptyCatalogStart: widget.onChooseEmptyCatalogStart,
                    onAddProduct: () => showProductEditor(context, store),
                    withoutBarcodeCount: withoutBarcodeCount,
                    needsAttentionCount: needsAttentionCount,
                  ),
                  const SizedBox(height: 14),
                  _CatalogToolbarCard(
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    searchQuery: _searchQuery,
                    visibleCount: products.length,
                    totalCount: store.products.length,
                    onlyLowStock: _onlyLowStock,
                    onlyMissingBarcode: _onlyMissingBarcode,
                    onlyNeedsAttention: _onlyNeedsAttention,
                    lowStockCount: store.lowStockCount,
                    withoutBarcodeCount: withoutBarcodeCount,
                    needsAttentionCount: needsAttentionCount,
                    onToggleLowStock: (value) {
                      setState(() => _onlyLowStock = value);
                    },
                    onToggleMissingBarcode: (value) {
                      setState(() => _onlyMissingBarcode = value);
                    },
                    onToggleNeedsAttention: (value) {
                      setState(() => _onlyNeedsAttention = value);
                    },
                    onClearFilters: _clearFilters,
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
                          ? showInitialSetupChoice
                                ? 'Elige como quieres empezar'
                                : 'Todavia no cargaste productos'
                          : 'Sin resultados para ese filtro',
                      message: emptyCatalog
                          ? showInitialSetupChoice
                                ? 'Nada se carga solo. Puedes arrancar vacio o probar un ejemplo corto.'
                                : store.hasMovements
                                ? 'Ya hay movimientos guardados, asi que conviene sumar catalogo real sin tocar ese historial.'
                                : 'Agrega tu primer producto y deja el resto para despues. Si quieres, tambien puedes cargar una base simple.'
                          : 'No hay productos que coincidan con la busqueda actual. Ajusta filtros o agrega un producto nuevo.',
                      action: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          if (emptyCatalog && showInitialSetupChoice)
                            FilledButton(
                              onPressed: () =>
                                  widget.onChooseEmptyCatalogStart(),
                              child: const Text('Empezar vacio'),
                            ),
                          if (emptyCatalog && canLoadDemoData)
                            OutlinedButton(
                              onPressed: widget.loadingDemoData
                                  ? null
                                  : () => widget.onLoadDemoData(),
                              child: Text(
                                widget.loadingDemoData
                                    ? 'Cargando ejemplo...'
                                    : 'Cargar ejemplo para probar',
                              ),
                            ),
                          if (emptyCatalog && !showInitialSetupChoice)
                            FilledButton(
                              onPressed: () =>
                                  showProductEditor(context, store),
                              child: const Text('Agregar producto'),
                            ),
                          if (emptyCatalog &&
                              !showInitialSetupChoice &&
                              !store.hasMovements)
                            OutlinedButton(
                              onPressed:
                                  widget.applyingStarterTemplate ||
                                      widget.loadingDemoData
                                  ? null
                                  : () => widget.onApplyStarterTemplate(),
                              child: Text(
                                widget.applyingStarterTemplate
                                    ? 'Cargando base...'
                                    : 'Cargar base simple',
                              ),
                            ),
                          if (filteredEmpty)
                            FilledButton(
                              onPressed: _clearFilters,
                              child: const Text('Limpiar filtros'),
                            ),
                          if (!emptyCatalog || filteredEmpty)
                            TextButton(
                              onPressed: () =>
                                  showProductEditor(context, store),
                              child: const Text('Agregar producto'),
                            ),
                        ],
                      ),
                    )
                  else
                    _ProductCollection(
                      products: products,
                      onEdit: (product) =>
                          showProductEditor(context, store, product: product),
                      onAdjustStock: (product) => _addStock(store, product),
                      onDelete: (product) => _deleteProduct(store, product),
                      onSell: widget.onSellProduct,
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

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _onlyLowStock ||
      _onlyMissingBarcode ||
      _onlyNeedsAttention;

  String get _activeFilterLabel {
    final parts = <String>[];
    if (_searchQuery.trim().isNotEmpty) {
      parts.add('busqueda: "${_searchQuery.trim()}"');
    }
    if (_onlyLowStock) {
      parts.add('bajo stock');
    }
    if (_onlyMissingBarcode) {
      parts.add('sin codigo');
    }
    if (_onlyNeedsAttention) {
      parts.add('pendientes');
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
      _onlyMissingBarcode = false;
      _onlyNeedsAttention = false;
    });
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _debouncedQuery.trim().toLowerCase();
    final filtered = products
        .where((product) {
          final matchesQuery =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.category ?? '').toLowerCase().contains(query) ||
              CommerceStore.barcodeMatchesQuery(product.barcode, query);
          final matchesLowStock = !_onlyLowStock || product.isLowStock;
          final matchesMissingBarcode =
              !_onlyMissingBarcode || !product.hasBarcode;
          final matchesAttention =
              !_onlyNeedsAttention || product.needsCatalogAttention;
          return matchesQuery &&
              matchesLowStock &&
              matchesMissingBarcode &&
              matchesAttention;
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      final leftRank = _productSortRank(left);
      final rightRank = _productSortRank(right);
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return filtered;
  }

  Future<void> _addStock(CommerceStore store, Product product) async {
    if (!await ensureLicenseAccess(context, LockedFeature.stock) || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: 'Ajustar stock',
      label: 'Cantidad a sumar',
      confirmLabel: 'Guardar',
      helper:
          'Se suma stock sobre ${product.name} sin tocar el resto del catalogo.',
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
          content: Text('Stock guardado para ${product.name}.'),
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
    if (!await ensureLicenseAccess(context, LockedFeature.catalog) ||
        !mounted) {
      return;
    }
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

int _productSortRank(Product product) {
  if (!product.hasPrice) {
    return 0;
  }
  if (product.isLowStock) {
    return 1;
  }
  if (!product.hasBarcode) {
    return 2;
  }
  return 3;
}

class _CatalogOverviewCard extends StatelessWidget {
  const _CatalogOverviewCard({
    required this.store,
    required this.applyingStarterTemplate,
    required this.loadingDemoData,
    required this.canLoadDemoData,
    required this.showInitialSetupChoice,
    required this.onApplyStarterTemplate,
    required this.onLoadDemoData,
    required this.onChooseEmptyCatalogStart,
    required this.onAddProduct,
    required this.withoutBarcodeCount,
    required this.needsAttentionCount,
  });

  final CommerceStore store;
  final bool applyingStarterTemplate;
  final bool loadingDemoData;
  final bool canLoadDemoData;
  final bool showInitialSetupChoice;
  final Future<void> Function() onApplyStarterTemplate;
  final Future<void> Function() onLoadDemoData;
  final Future<void> Function() onChooseEmptyCatalogStart;
  final VoidCallback onAddProduct;
  final int withoutBarcodeCount;
  final int needsAttentionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (showInitialSetupChoice) {
      return BpcPanel(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        color: Colors.white.withValues(alpha: 0.86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Como quieres empezar?',
              subtitle:
                  'Nada se carga sin preguntarte. Puedes arrancar vacio o probar un ejemplo corto.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onChooseEmptyCatalogStart,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Empezar vacio'),
                ),
                if (canLoadDemoData)
                  OutlinedButton.icon(
                    onPressed: loadingDemoData ? null : onLoadDemoData,
                    icon: loadingDemoData
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_rounded),
                    label: Text(
                      loadingDemoData
                          ? 'Cargando ejemplo'
                          : 'Cargar ejemplo para probar',
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    final metrics = [
      _OverviewMetricData(
        label: 'Catalogo',
        value: '${store.products.length}',
        helper: 'productos cargados',
        accent: BpcColors.greenDark,
      ),
      _OverviewMetricData(
        label: 'Listos para vender',
        value: '${store.sellableProductsCount}',
        helper: 'con stock y precio',
        accent: BpcColors.income,
      ),
      _OverviewMetricData(
        label: 'Sin codigo',
        value: '$withoutBarcodeCount',
        helper: 'pendientes para lector',
        accent: BpcColors.sandMuted,
      ),
      _OverviewMetricData(
        label: 'Para revisar',
        value: '$needsAttentionCount',
        helper: 'sin precio o sin codigo',
        accent: scheme.error,
      ),
    ];

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      color: Colors.white.withValues(alpha: 0.86),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Catalogo',
                subtitle:
                    'Control rapido de productos, precios y stock sin dar vueltas.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map((metric) => _CatalogSummaryPill(metric: metric))
                    .toList(growable: false),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar producto'),
              ),
              if (!store.hasMovements)
                OutlinedButton.icon(
                  onPressed: applyingStarterTemplate || loadingDemoData
                      ? null
                      : () => onApplyStarterTemplate(),
                  icon: applyingStarterTemplate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.storefront_rounded),
                  label: Text(
                    applyingStarterTemplate
                        ? 'Cargando base'
                        : 'Cargar base simple',
                  ),
                ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Align(alignment: Alignment.topRight, child: actions),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CatalogToolbarCard extends StatelessWidget {
  const _CatalogToolbarCard({
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.visibleCount,
    required this.totalCount,
    required this.onlyLowStock,
    required this.onlyMissingBarcode,
    required this.onlyNeedsAttention,
    required this.lowStockCount,
    required this.withoutBarcodeCount,
    required this.needsAttentionCount,
    required this.onToggleLowStock,
    required this.onToggleMissingBarcode,
    required this.onToggleNeedsAttention,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final int visibleCount;
  final int totalCount;
  final bool onlyLowStock;
  final bool onlyMissingBarcode;
  final bool onlyNeedsAttention;
  final int lowStockCount;
  final int withoutBarcodeCount;
  final int needsAttentionCount;
  final ValueChanged<bool> onToggleLowStock;
  final ValueChanged<bool> onToggleMissingBarcode;
  final ValueChanged<bool> onToggleNeedsAttention;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: Colors.white.withValues(alpha: 0.82),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final resultsChip = _ToolbarCountChip(
            label: visibleCount == totalCount
                ? '$visibleCount productos'
                : '$visibleCount de $totalCount visibles',
          );

          final field = TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => searchFocusNode.unfocus(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: 'Buscar producto',
              hintText: 'Nombre, categoria o codigo',
              suffixIcon: searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar busqueda',
                      onPressed: onClearFilters,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );

          final filters = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterChip(
                selected: onlyLowStock,
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text('Bajo stock ($lowStockCount)'),
                onSelected: onToggleLowStock,
              ),
              FilterChip(
                selected: onlyMissingBarcode,
                avatar: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: Text('Sin codigo ($withoutBarcodeCount)'),
                onSelected: onToggleMissingBarcode,
              ),
              FilterChip(
                selected: onlyNeedsAttention,
                avatar: const Icon(Icons.rule_folder_rounded, size: 18),
                label: Text('Pendientes ($needsAttentionCount)'),
                onSelected: onToggleNeedsAttention,
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Buscar y filtrar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    resultsChip,
                  ],
                ),
                const SizedBox(height: 12),
                field,
                const SizedBox(height: 12),
                filters,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Buscar y filtrar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: BpcColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  resultsChip,
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: field),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Align(alignment: Alignment.topLeft, child: filters),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCollection extends StatelessWidget {
  const _ProductCollection({
    required this.products,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
    this.onSell,
  });

  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onAdjustStock;
  final ValueChanged<Product> onDelete;
  final Future<void> Function(Product product)? onSell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1500
            ? 3
            : constraints.maxWidth >= 1040
            ? 2
            : 1;
        final spacing = 14.0;
        final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
        final itemWidth = (constraints.maxWidth - totalGap) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: products
              .map(
                (product) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : itemWidth,
                  child: _ProductTile(
                    product: product,
                    onTap: () => onEdit(product),
                    onAdjustStock: () => onAdjustStock(product),
                    onDelete: () => onDelete(product),
                    onSell: onSell == null ? null : () => onSell!(product),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onAdjustStock,
    required this.onDelete,
    this.onSell,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;
  final VoidCallback? onSell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasBarcode = product.hasBarcode;
    final missingPrice = !product.hasPrice;
    final canSell = onSell != null && product.isSellable;
    final accent = missingPrice
        ? scheme.error
        : product.isLowStock
        ? BpcColors.sandMuted
        : BpcColors.greenSoft;
    final borderColor = accent.withValues(alpha: 0.28);
    final subtitle = product.category?.trim().isNotEmpty == true
        ? product.category!.trim()
        : 'Sin categoria';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: BpcColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final detailSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProductStateBadge(
                        label: product.isLowStock
                            ? 'Stock bajo'
                            : 'Stock al dia',
                        color: product.isLowStock
                            ? scheme.error
                            : BpcColors.income,
                        icon: product.isLowStock
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      if (!hasBarcode)
                        const _ProductStateBadge(
                          label: 'Sin codigo',
                          color: BpcColors.sandMuted,
                          icon: Icons.qr_code_2_rounded,
                        ),
                      if (missingPrice)
                        _ProductStateBadge(
                          label: 'Sin precio',
                          color: scheme.error,
                          icon: Icons.sell_outlined,
                        ),
                      if (canSell)
                        const _ProductStateBadge(
                          label: 'Todo listo para vender',
                          color: BpcColors.greenSoft,
                          icon: Icons.shopping_bag_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ProductInfoPanel(
                        label: 'Stock',
                        value: '${product.stockUnits}',
                        helper: product.isLowStock
                            ? 'debajo del minimo'
                            : 'unidades disponibles',
                        icon: Icons.inventory_2_outlined,
                        accent: product.isLowStock
                            ? scheme.error
                            : BpcColors.greenSoft,
                      ),
                      _ProductInfoPanel(
                        label: 'Minimo',
                        value: '${product.minStockUnits}',
                        helper: 'alerta de reposicion',
                        icon: Icons.vertical_align_bottom_rounded,
                        accent: BpcColors.sandMuted,
                      ),
                      _ProductInfoPanel(
                        label: 'Costo',
                        value: formatMoney(product.costPesos),
                        helper: 'base estimada',
                        icon: Icons.payments_outlined,
                        accent: BpcColors.mutedInk,
                      ),
                      _ProductInfoPanel(
                        label: 'Codigo',
                        value: hasBarcode ? product.barcode! : 'Sin codigo',
                        helper: hasBarcode
                            ? 'listo para lector'
                            : 'puedes cargarlo despues',
                        icon: Icons.qr_code_rounded,
                        accent: hasBarcode
                            ? BpcColors.greenSoft
                            : BpcColors.sandMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: canSell ? onSell : null,
                        icon: const Icon(Icons.shopping_bag_rounded),
                        label: const Text('Vender'),
                      ),
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
              );
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: BpcColors.ink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: BpcColors.subtleInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasBarcode
                                  ? 'Codigo ${product.barcode}'
                                  : 'Producto sin codigo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hasBarcode
                                    ? BpcColors.greenSoft
                                    : BpcColors.sandMuted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProductPricePanel(
                    pricePesos: product.pricePesos,
                    costPesos: product.costPesos,
                    missingPrice: missingPrice,
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summary,
                    const SizedBox(height: 16),
                    detailSection,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: summary),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: detailSection),
                ],
              );
            },
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
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w800,
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

class _OverviewMetricData {
  const _OverviewMetricData({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  final String label;
  final String value;
  final String helper;
  final Color accent;
}

class _CatalogSummaryPill extends StatelessWidget {
  const _CatalogSummaryPill({required this.metric});

  final _OverviewMetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: metric.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: metric.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: metric.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarCountChip extends StatelessWidget {
  const _ToolbarCountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BpcColors.line),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: BpcColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProductPricePanel extends StatelessWidget {
  const _ProductPricePanel({
    required this.pricePesos,
    required this.costPesos,
    required this.missingPrice,
  });

  final int pricePesos;
  final int costPesos;
  final bool missingPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: missingPrice
            ? scheme.errorContainer.withValues(alpha: 0.48)
            : BpcColors.greenDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            missingPrice ? 'Precio pendiente' : 'Precio de venta',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: missingPrice
                  ? scheme.error
                  : Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            missingPrice ? 'Definir precio' : formatMoney(pricePesos),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: missingPrice ? BpcColors.ink : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Costo ${formatMoney(costPesos)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: missingPrice
                  ? BpcColors.subtleInk
                  : Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductInfoPanel extends StatelessWidget {
  const _ProductInfoPanel({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductStateBadge extends StatelessWidget {
  const _ProductStateBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
