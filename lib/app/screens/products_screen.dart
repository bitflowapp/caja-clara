import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/product_form_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _onlyLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final products = _filteredProducts(store.products);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Productos',
                subtitle:
                    'Stock actual, costo, precio, barcode y alertas de reposicion',
                trailing: FilledButton.icon(
                  onPressed: () => showProductEditor(context, store),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
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
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            labelText: 'Buscar producto',
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
                  title: 'Sin resultados',
                  message: 'Proba con otro texto o agrega un producto nuevo.',
                  action: FilledButton(
                    onPressed: () => showProductEditor(context, store),
                    child: const Text('Agregar producto'),
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
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((product) {
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.category ?? '').toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query);
      final matchesLowStock = !_onlyLowStock || product.isLowStock;
      return matchesQuery && matchesLowStock;
    }).toList(growable: false);
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.outline,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
