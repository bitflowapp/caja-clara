import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  Product? _selectedProduct;
  String _paymentMethod = 'Efectivo';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _quantityController.dispose();
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
          final product = _selectedProduct == null
              ? null
              : store.productById(_selectedProduct!.id) ?? _selectedProduct;
          final quantity = _parseInt(_quantityController.text);
          final total = product == null ? 0 : product.pricePesos * quantity;
          final remaining = product == null ? null : product.stockUnits - quantity;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: BpcPanel(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar venta',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Selecciona un producto, cantidad y medio de pago.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Autocomplete<Product>(
                          optionsBuilder: (value) {
                            final query = value.text.toLowerCase().trim();
                            if (query.isEmpty) {
                              return store.products;
                            }
                            return store.products.where((product) {
                              return product.name.toLowerCase().contains(query) ||
                                  (product.barcode ?? '')
                                      .toLowerCase()
                                      .contains(query) ||
                                  (product.category ?? '')
                                      .toLowerCase()
                                      .contains(query);
                            });
                          },
                          displayStringForOption: (product) => product.name,
                          onSelected: (product) {
                            setState(() {
                              _selectedProduct = product;
                            });
                          },
                          fieldViewBuilder: (
                            context,
                            controller,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Buscar producto',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              validator: (_) => _selectedProduct == null
                                  ? 'Elegi un producto'
                                  : null,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final optionList = options.toList();
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(18),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 280),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(8),
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      final option = optionList[index];
                                      return ListTile(
                                        title: Text(option.name),
                                        subtitle: Text(
                                          '${option.category ?? 'Sin categoria'} / ${formatMoney(option.pricePesos)}${option.barcode == null ? '' : ' / ${option.barcode}'}',
                                        ),
                                        trailing: Text('${option.stockUnits} u.'),
                                        onTap: () {
                                          onSelected(option);
                                          setState(() => _selectedProduct = option);
                                        },
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 4),
                                    itemCount: optionList.length,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      final parsed = _parseInt(value);
                                      if (parsed <= 0) {
                                        return 'Ingresa una cantidad';
                                      }
                                      if (product != null &&
                                          parsed > product.stockUnits) {
                                        return 'No hay stock suficiente';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String>(
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
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        BpcPanel(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                                value: remaining == null ? '-' : remaining.toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed:
                                  _saving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      if (_selectedProduct == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Elegi un producto'),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _saving = true);
                                      try {
                                        await store.recordSale(
                                          productId: _selectedProduct!.id,
                                          quantityUnits: _parseInt(
                                            _quantityController.text,
                                          ),
                                          paymentMethod: _paymentMethod,
                                        );
                                        if (!context.mounted) {
                                          return;
                                        }
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Venta guardada'),
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        setState(() => _saving = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                          ),
                                        );
                                      }
                                    },
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(_saving ? 'Guardando' : 'Guardar venta'),
                            ),
                          ],
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

  int _parseInt(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
