import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/speech_dictation.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _productFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _productSearchDictation = SpeechDictationController();
  Product? _selectedProduct;
  String _paymentMethod = 'Efectivo';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _productSearchDictation.initialize();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _productFocusNode.dispose();
    _quantityFocusNode.dispose();
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
          final product = _selectedProduct == null
              ? null
              : store.productById(_selectedProduct!.id) ?? _selectedProduct;
          final quantity = _parseInt(_quantityController.text);
          final total = product == null ? 0 : product.pricePesos * quantity;
          final remaining = product == null
              ? null
              : product.stockUnits - quantity;
          return KeyboardAwarePageBody(
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
                    if (widget.initialProduct != null) ...[
                      const SizedBox(height: 14),
                      BpcPanel(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Producto resuelto. Ajusta cantidad y confirma.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Autocomplete<Product>(
                      initialValue: TextEditingValue(
                        text: widget.initialProduct?.name ?? '',
                      ),
                      optionsBuilder: (value) {
                        final query = value.text.toLowerCase().trim();
                        if (query.isEmpty) {
                          return store.products;
                        }
                        return store.products.where((product) {
                          return product.name.toLowerCase().contains(query) ||
                              (product.barcode ?? '').toLowerCase().contains(
                                query,
                              ) ||
                              (product.category ?? '').toLowerCase().contains(
                                query,
                              );
                        });
                      },
                      displayStringForOption: (product) => product.name,
                      onSelected: (product) {
                        setState(() {
                          _selectedProduct = product;
                        });
                        _quantityFocusNode.requestFocus();
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: controller,
                                  focusNode: _productFocusNode,
                                  autofocus: widget.initialProduct == null,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    labelText: 'Buscar producto',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    suffixIcon: SpeechDictationActionButton(
                                      controller: _productSearchDictation,
                                      textController: controller,
                                      tooltip: 'Dictar busqueda',
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (_selectedProduct != null &&
                                        value.trim() !=
                                            _selectedProduct!.name.trim()) {
                                      setState(() => _selectedProduct = null);
                                    }
                                  },
                                  onFieldSubmitted: (_) {
                                    if (_selectedProduct != null) {
                                      _quantityFocusNode.requestFocus();
                                    } else {
                                      onFieldSubmitted();
                                    }
                                  },
                                  validator: (_) => _selectedProduct == null
                                      ? 'Elegi un producto'
                                      : null,
                                ),
                                SpeechDictationHint(
                                  controller: _productSearchDictation,
                                ),
                              ],
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
                                      _quantityFocusNode.requestFocus();
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
                                focusNode: _quantityFocusNode,
                                autofocus: widget.initialProduct != null,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Cantidad',
                                ),
                                onChanged: (_) => setState(() {}),
                                onFieldSubmitted: (_) => _submitSale(store),
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
                            value: remaining == null
                                ? '-'
                                : remaining.toString(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        final saveButton = FilledButton.icon(
                          onPressed: _saving ? null : () => _submitSale(store),
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
                          label: Text(_saving ? 'Guardando' : 'Guardar venta'),
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

  Future<void> _submitSale(CommerceStore store) async {
    if (_saving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elegi un producto')));
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await store.recordSale(
        productId: _selectedProduct!.id,
        quantityUnits: _parseInt(_quantityController.text),
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
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    const prefix = 'Bad state: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
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
