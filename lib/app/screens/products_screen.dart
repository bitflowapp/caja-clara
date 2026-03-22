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
  });

  final Future<void> Function() onApplyStarterTemplate;
  final bool applyingStarterTemplate;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _onlyLowStock = false;

  @override
  void dispose() {
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
        final filteredEmpty = products.isEmpty && !emptyCatalog;
        return InputShortcutScope(
          onCancel: () {
            if (_searchController.text.isNotEmpty) {
              setState(() => _searchController.clear());
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
                      OutlinedButton.icon(
                        onPressed: widget.applyingStarterTemplate
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
                              onChanged: (_) => setState(() {}),
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
                  const SizedBox(height: 16),
                  if (products.isEmpty)
                    EmptyCard(
                      title: emptyCatalog
                          ? 'Todavia no cargaste productos'
                          : 'Sin resultados',
                      message: emptyCatalog
                          ? 'Puedes empezar con la plantilla kiosco o crear tus productos a mano. Todo queda editable y se guarda localmente.'
                          : 'No hay productos con ese filtro. Ajusta la busqueda o carga uno nuevo.',
                      action: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          if (emptyCatalog)
                            FilledButton(
                              onPressed: widget.applyingStarterTemplate
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
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _onlyLowStock = false;
                              }),
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

  List<Product> _filteredProducts(List<Product> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products
        .where((product) {
          final matchesQuery =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.category ?? '').toLowerCase().contains(query) ||
              (product.barcode ?? '').toLowerCase().contains(query);
          final matchesLowStock = !_onlyLowStock || product.isLowStock;
          return matchesQuery && matchesLowStock;
        })
        .toList(growable: false);
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
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
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProductTileAction { edit, delete }

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
