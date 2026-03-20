import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/commerce_store.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../widgets/barcode_input_dialog.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/operation_dialogs.dart';
import '../widgets/product_form_dialog.dart';
import 'sale_screen.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  late final MobileScannerController _cameraController;
  String? _currentBarcode;
  bool _cameraRunning = false;
  bool _savingStock = false;

  bool get _supportsCamera {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const <BarcodeFormat>[
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.itf14,
      ],
    );
    _cameraRunning = _supportsCamera;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _applyBarcode(String raw) async {
    final normalized = CommerceStore.normalizeBarcode(raw);
    if (normalized == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo leer un codigo valido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_supportsCamera && _cameraRunning) {
      await _cameraController.stop();
      _cameraRunning = false;
    }

    if (!mounted) {
      return;
    }
    setState(() => _currentBarcode = normalized);
  }

  Future<void> _restartCamera() async {
    if (!_supportsCamera) {
      setState(() => _currentBarcode = null);
      return;
    }
    setState(() => _currentBarcode = null);
    await _cameraController.start();
    if (mounted) {
      setState(() => _cameraRunning = true);
    }
  }

  Future<void> _openManualInput() async {
    final barcode = await showBarcodeInputDialog(context);
    if (barcode == null) {
      return;
    }
    await _applyBarcode(barcode);
  }

  Future<void> _openCreateProduct(CommerceStore store) async {
    final barcode = _currentBarcode;
    if (barcode == null) {
      return;
    }
    await showProductEditor(context, store, initialBarcode: barcode);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openSale(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SaleScreen(initialProduct: product),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addStock(CommerceStore store, Product product) async {
    if (_savingStock) {
      return;
    }
    final amount = await showAmountEntryDialog(
      context,
      title: 'Agregar stock',
      label: 'Cantidad a sumar',
      confirmLabel: 'Guardar',
      helper: 'Se registra un ajuste de stock sobre ${product.name}.',
    );
    if (amount == null) {
      return;
    }

    setState(() => _savingStock = true);
    try {
      await store.addStockToProduct(
        productId: product.id,
        quantityUnits: amount,
        note: 'Barcode',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock guardado para ${product.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingStock = false);
      }
    }
  }

  String? _firstReadableBarcode(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = CommerceStore.normalizeBarcode(barcode.rawValue);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    const prefix = 'Bad state: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final foundProduct = _currentBarcode == null
            ? null
            : store.productByBarcode(_currentBarcode!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Escanear producto'),
            actions: [
              TextButton.icon(
                onPressed: _openManualInput,
                icon: const Icon(Icons.keyboard_alt_rounded),
                label: const Text('Ingresar codigo'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Codigo de barras',
                      subtitle: 'Camara, scanner o codigo manual.',
                    ),
                    const SizedBox(height: 14),
                    if (_supportsCamera)
                      BpcPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _CameraStatusBlock(
                                    title: _currentBarcode == null
                                        ? 'Listo para leer'
                                        : 'Codigo leido',
                                    subtitle: _currentBarcode == null
                                        ? 'Apunta al codigo del producto.'
                                        : 'Elige la accion y sigue.',
                                    active: _currentBarcode == null,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _currentBarcode == null
                                      ? _openManualInput
                                      : _restartCamera,
                                  icon: Icon(
                                    _currentBarcode == null
                                        ? Icons.keyboard_alt_rounded
                                        : Icons.restart_alt_rounded,
                                  ),
                                  label: Text(
                                    _currentBarcode == null
                                        ? 'Ingresar codigo'
                                        : 'Leer otro',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: _currentBarcode == null
                                    ? MobileScanner(
                                        controller: _cameraController,
                                        fit: BoxFit.cover,
                                        onDetect: (capture) {
                                          final barcode = _firstReadableBarcode(
                                            capture,
                                          );
                                          if (barcode != null) {
                                            _applyBarcode(barcode);
                                          }
                                        },
                                      )
                                    : Container(
                                        color: BpcColors.greenDeep,
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Codigo detectado',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.72,
                                                        ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _currentBarcode!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      EmptyCard(
                        title: 'Usar codigo o scanner',
                        message:
                            'En Windows lo mas rapido es scanner USB/Bluetooth o ingreso manual.',
                        action: FilledButton.icon(
                          onPressed: _openManualInput,
                          icon: const Icon(Icons.keyboard_alt_rounded),
                          label: const Text('Ingresar codigo'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_currentBarcode == null)
                      const EmptyCard(
                        title: 'Esperando codigo',
                        message: 'Lee o ingresa un codigo para buscarlo.',
                        icon: Icons.qr_code_scanner_rounded,
                      )
                    else if (foundProduct == null)
                      _BarcodeNotFoundCard(
                        barcode: _currentBarcode!,
                        onCreateProduct: () => _openCreateProduct(store),
                        onTryAnother: _supportsCamera
                            ? _restartCamera
                            : _openManualInput,
                      )
                    else
                      _BarcodeProductCard(
                        barcode: _currentBarcode!,
                        product: foundProduct,
                        savingStock: _savingStock,
                        onSale: () => _openSale(foundProduct),
                        onAddStock: () => _addStock(store, foundProduct),
                        onScanAnother: _supportsCamera
                            ? _restartCamera
                            : _openManualInput,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarcodeProductCard extends StatelessWidget {
  const _BarcodeProductCard({
    required this.barcode,
    required this.product,
    required this.savingStock,
    required this.onSale,
    required this.onAddStock,
    required this.onScanAnother,
  });

  final String barcode;
  final Product product;
  final bool savingStock;
  final VoidCallback onSale;
  final VoidCallback onAddStock;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BpcColors.income.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_rounded, color: BpcColors.income),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Producto encontrado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BpcColors.mutedInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: BpcColors.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cod. $barcode',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final width = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _LookupInfo(
                      label: 'Precio',
                      value: formatMoney(product.pricePesos),
                      emphasized: true,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LookupInfo(
                      label: 'Stock actual',
                      value: '${product.stockUnits} u.',
                      emphasized: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final saleButton = FilledButton.icon(
                onPressed: onSale,
                style: compact
                    ? FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      )
                    : null,
                icon: const Icon(Icons.shopping_bag_rounded),
                label: const Text('Registrar venta'),
              );
              final stockButton = OutlinedButton.icon(
                onPressed: savingStock ? null : onAddStock,
                style: compact
                    ? OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      )
                    : null,
                icon: savingStock
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_box_rounded),
                label: Text(savingStock ? 'Guardando' : 'Agregar stock'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    saleButton,
                    const SizedBox(height: 10),
                    stockButton,
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onScanAnother,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Buscar otro'),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  saleButton,
                  stockButton,
                  TextButton.icon(
                    onPressed: onScanAnother,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Buscar otro'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarcodeNotFoundCard extends StatelessWidget {
  const _BarcodeNotFoundCard({
    required this.barcode,
    required this.onCreateProduct,
    required this.onTryAnother,
  });

  final String barcode;
  final VoidCallback onCreateProduct;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BpcColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BpcColors.line),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: BpcColors.mutedInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Codigo leido',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BpcColors.mutedInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No esta en catalogo',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: BpcColors.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Cod. $barcode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BpcColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El codigo se leyo bien. Puedes crear el producto con este dato.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final createButton = FilledButton.icon(
                onPressed: onCreateProduct,
                style: compact
                    ? FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      )
                    : null,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Crear producto'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    createButton,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onTryAnother,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Buscar otro'),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  createButton,
                  TextButton.icon(
                    onPressed: onTryAnother,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Buscar otro'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LookupInfo extends StatelessWidget {
  const _LookupInfo({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Container(
        padding: EdgeInsets.all(emphasized ? 16 : 14),
        decoration: BoxDecoration(
          color: emphasized ? Colors.white : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: emphasized ? Border.all(color: BpcColors.line) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style:
                  (emphasized
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.titleMedium)
                      ?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraStatusBlock extends StatelessWidget {
  const _CameraStatusBlock({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: active ? BpcColors.income : BpcColors.mutedInk,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BpcColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
        ),
      ],
    );
  }
}
