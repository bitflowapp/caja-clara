import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/barcode_lookup_service.dart';
import '../services/commerce_store.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/barcode_input_dialog.dart';
import '../widgets/commerce_components.dart';
import '../widgets/barcode_lookup_scope.dart';
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
  bool _cameraStarting = false;
  bool _savingStock = false;
  String? _cameraIssue;
  bool _lookupInProgress = false;
  int _lookupRequestId = 0;
  BarcodeLookupResult? _lookupResult;

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
    if (_supportsCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _startCamera();
      });
    }
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

    _lookupRequestId += 1;
    final store = CommerceScope.of(context);
    final lookupService = BarcodeLookupScope.of(context);

    if (_supportsCamera && _cameraRunning) {
      await _cameraController.stop();
    }
    final localProduct = store.productByBarcode(normalized);

    if (!mounted) {
      return;
    }
    setState(() {
      _currentBarcode = normalized;
      _cameraRunning = false;
      _cameraStarting = false;
      _cameraIssue = null;
      _lookupInProgress = false;
      _lookupResult = null;
    });

    if (localProduct != null) {
      return;
    }

    final lookupId = _lookupRequestId;
    setState(() => _lookupInProgress = true);

    final lookupResult = await lookupService.lookup(normalized);
    if (!mounted ||
        lookupId != _lookupRequestId ||
        _currentBarcode != normalized) {
      return;
    }

    setState(() {
      _lookupInProgress = false;
      _lookupResult = lookupResult;
    });
  }

  Future<void> _startCamera({bool clearSelection = false}) async {
    if (clearSelection) {
      _lookupRequestId += 1;
    }
    if (!_supportsCamera) {
      setState(() {
        if (clearSelection) {
          _currentBarcode = null;
          _lookupInProgress = false;
          _lookupResult = null;
        }
      });
      return;
    }
    setState(() {
      if (clearSelection) {
        _currentBarcode = null;
        _lookupInProgress = false;
        _lookupResult = null;
      }
      _cameraStarting = true;
      _cameraRunning = false;
      _cameraIssue = null;
    });
    try {
      await _cameraController.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraRunning = true;
        _cameraStarting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraRunning = false;
        _cameraStarting = false;
        _cameraIssue = userFacingErrorMessage(error);
      });
    }
  }

  Future<void> _restartCamera() async {
    await _startCamera(clearSelection: true);
  }

  Future<void> _openManualInput() async {
    final barcode = await showBarcodeInputDialog(context);
    if (barcode == null) {
      return;
    }
    await _applyBarcode(barcode);
  }

  Future<void> _openCreateProduct(CommerceStore store) async {
    await _openProductEditor(store);
  }

  Future<void> _openProductEditor(
    CommerceStore store, {
    Product? product,
    ProductEditorSeed? seed,
  }) async {
    final barcode = _currentBarcode;
    if (product == null && barcode == null) {
      return;
    }
    _lookupRequestId += 1;
    final result = await showProductEditor(
      context,
      store,
      product: product,
      initialBarcode: barcode,
      seed: seed,
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      _currentBarcode = result.product.barcode ?? _currentBarcode;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.kind == ProductEditorResultKind.usedExisting
                ? 'Usaras "${result.product.name}", que ya estaba en el catalogo.'
                : product != null
                ? 'Producto actualizado.'
                : 'Producto guardado. Ese codigo ya queda listo para futuras busquedas.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _openAssistedCreateProduct(CommerceStore store) async {
    final match = _lookupResult?.match;
    final barcode = _currentBarcode;
    if (match == null || barcode == null) {
      return;
    }
    await _openProductEditor(
      store,
      seed: ProductEditorSeed(
        name: match.seededName,
        category: match.suggestedCategory,
        barcode: barcode,
        lookupSourceLabel: match.sourceLabel,
        suggestedBrand: match.brand,
        lookupMessage:
            'Revisa los datos sugeridos antes de guardar. Si algo no coincide, ajustalo manualmente.',
      ),
    );
  }

  Future<void> _openEditProduct(CommerceStore store, Product product) async {
    await _openProductEditor(store, product: product);
  }

  Future<void> _openSale(Product product) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SaleScreen(initialProduct: product),
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
    setState(() {});
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
          content: Text(userFacingErrorMessage(error)),
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

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final foundProduct = _currentBarcode == null
            ? null
            : store.productByBarcode(_currentBarcode!);
        final externalMatch = _lookupResult?.match;
        final saleWarning = foundProduct == null
            ? null
            : store.saleReadinessMessage(foundProduct.id, quantityUnits: 1);

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
                      subtitle:
                          'Busca un producto por camara, scanner o ingreso manual.',
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
                                    title: _cameraStatusTitle,
                                    subtitle: _cameraStatusSubtitle,
                                    active:
                                        _currentBarcode == null &&
                                        _cameraRunning &&
                                        _cameraIssue == null,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _currentBarcode == null &&
                                          !_cameraStarting
                                      ? _openManualInput
                                      : _restartCamera,
                                  icon: Icon(
                                    _currentBarcode == null && !_cameraStarting
                                        ? Icons.keyboard_alt_rounded
                                        : Icons.restart_alt_rounded,
                                  ),
                                  label: Text(
                                    _currentBarcode == null && !_cameraStarting
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
                                    ? _buildCameraViewport(context)
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
                            'En Windows suele ser mas rapido usar scanner USB/Bluetooth o escribir el codigo.',
                        action: FilledButton.icon(
                          onPressed: _openManualInput,
                          icon: const Icon(Icons.keyboard_alt_rounded),
                          label: const Text('Ingresar codigo'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_currentBarcode == null)
                      EmptyCard(
                        title: _cameraIssue != null
                            ? 'Camara no disponible'
                            : 'Esperando codigo',
                        message: _cameraIssue != null
                            ? 'Puedes reintentar la camara o seguir con ingreso manual sin frenar la venta.'
                            : 'Lee o escribe un codigo para encontrar el producto al instante.',
                        icon: _cameraIssue != null
                            ? Icons.warning_amber_rounded
                            : Icons.qr_code_scanner_rounded,
                        action: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _openManualInput,
                              icon: const Icon(Icons.keyboard_alt_rounded),
                              label: const Text('Ingresar codigo'),
                            ),
                            if (_supportsCamera)
                              TextButton.icon(
                                onPressed: _cameraStarting
                                    ? null
                                    : _restartCamera,
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: Text(
                                  _cameraIssue != null
                                      ? 'Reintentar camara'
                                      : 'Reiniciar lector',
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (_lookupInProgress)
                      _BarcodeLookupLoadingCard(
                        barcode: _currentBarcode!,
                        onCreateProduct: () => _openCreateProduct(store),
                        onTryAnother: _supportsCamera
                            ? _restartCamera
                            : _openManualInput,
                      )
                    else if (foundProduct == null)
                      externalMatch != null
                          ? _BarcodeExternalMatchCard(
                              barcode: _currentBarcode!,
                              match: externalMatch,
                              onCreateProduct: () =>
                                  _openAssistedCreateProduct(store),
                              onCreateManual: () => _openCreateProduct(store),
                              onTryAnother: _supportsCamera
                                  ? _restartCamera
                                  : _openManualInput,
                            )
                          : _BarcodeNotFoundCard(
                              barcode: _currentBarcode!,
                              title:
                                  _lookupResult?.status ==
                                      BarcodeLookupStatus.disabled
                                  ? 'Lookup externo desactivado'
                                  : _lookupResult?.status ==
                                        BarcodeLookupStatus.failed
                                  ? 'No pudimos completar la busqueda externa'
                                  : 'No esta en catalogo',
                              message:
                                  _lookupResult?.message ??
                                  'El codigo se leyo bien. Puedes dar de alta el producto con este codigo cargado.',
                              createButtonLabel: 'Crear producto',
                              onCreateProduct: () => _openCreateProduct(store),
                              onTryAnother: _supportsCamera
                                  ? _restartCamera
                                  : _openManualInput,
                            )
                    else
                      _BarcodeProductCard(
                        barcode: _currentBarcode!,
                        product: foundProduct,
                        saleWarning: saleWarning,
                        savingStock: _savingStock,
                        onSale: () => _openSale(foundProduct),
                        onAddStock: () => _addStock(store, foundProduct),
                        onEdit: () => _openEditProduct(store, foundProduct),
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

  String get _cameraStatusTitle {
    if (_currentBarcode != null) {
      return 'Codigo leido';
    }
    if (_cameraStarting) {
      return 'Preparando camara';
    }
    if (_cameraIssue != null) {
      return _cameraIssue!.toLowerCase().contains('permiso')
          ? 'Sin permiso de camara'
          : 'Camara con problemas';
    }
    if (_cameraRunning) {
      return 'Listo para leer';
    }
    return 'Camara pausada';
  }

  String get _cameraStatusSubtitle {
    if (_currentBarcode != null) {
      return 'Elige la accion y sigue.';
    }
    if (_cameraStarting) {
      return 'Estamos iniciando la camara para leer el codigo.';
    }
    if (_cameraIssue != null) {
      return _cameraIssue!;
    }
    if (_cameraRunning) {
      return 'Apunta al codigo del producto o usa ingreso manual.';
    }
    return 'Puedes seguir con ingreso manual si la camara no responde.';
  }

  Widget _buildCameraViewport(BuildContext context) {
    if (_cameraStarting) {
      return _CameraPlaceholderState(
        icon: Icons.videocam_rounded,
        title: 'Cargando camara',
        message: 'Dando acceso al lector para empezar a escanear.',
      );
    }
    if (_cameraIssue != null) {
      return _CameraPlaceholderState(
        icon: _cameraIssue!.toLowerCase().contains('permiso')
            ? Icons.no_photography_rounded
            : Icons.videocam_off_rounded,
        title: _cameraIssue!.toLowerCase().contains('permiso')
            ? 'Permiso denegado'
            : 'No se pudo iniciar la camara',
        message: _cameraIssue!,
      );
    }
    if (!_cameraRunning) {
      return const _CameraPlaceholderState(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Listo para reintentar',
        message: 'Toca "Leer otro" o usa ingreso manual para seguir.',
      );
    }
    return MobileScanner(
      controller: _cameraController,
      fit: BoxFit.cover,
      onDetect: (capture) {
        final barcode = _firstReadableBarcode(capture);
        if (barcode != null) {
          _applyBarcode(barcode);
        }
      },
    );
  }
}

class _BarcodeProductCard extends StatelessWidget {
  const _BarcodeProductCard({
    required this.barcode,
    required this.product,
    required this.saleWarning,
    required this.savingStock,
    required this.onSale,
    required this.onAddStock,
    required this.onEdit,
    required this.onScanAnother,
  });

  final String barcode;
  final Product product;
  final String? saleWarning;
  final bool savingStock;
  final VoidCallback onSale;
  final VoidCallback onAddStock;
  final VoidCallback onEdit;
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
                      'Ya existe en catalogo',
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
          const SizedBox(height: 6),
          Text(
            'Puedes venderlo, ajustar stock o editar la ficha sin crear duplicados.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
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
          if (saleWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              saleWarning!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final saleButton = FilledButton.icon(
                onPressed: saleWarning == null ? onSale : null,
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
              final editButton = TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar ficha'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    saleButton,
                    const SizedBox(height: 10),
                    stockButton,
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        editButton,
                        TextButton.icon(
                          onPressed: onScanAnother,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Buscar otro'),
                        ),
                      ],
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
                  editButton,
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

class _BarcodeLookupLoadingCard extends StatelessWidget {
  const _BarcodeLookupLoadingCard({
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
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
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
                      'Buscando datos para acelerar el alta',
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
          const SizedBox(height: 10),
          Text(
            'Primero revisamos tu catalogo local. Como no estaba, ahora consultamos un catalogo externo para no pedirte que cargues todo a mano.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Cargar manual igual'),
              ),
              TextButton.icon(
                onPressed: onTryAnother,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Buscar otro'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarcodeExternalMatchCard extends StatelessWidget {
  const _BarcodeExternalMatchCard({
    required this.barcode,
    required this.match,
    required this.onCreateProduct,
    required this.onCreateManual,
    required this.onTryAnother,
  });

  final String barcode;
  final BarcodeLookupMatch match;
  final VoidCallback onCreateProduct;
  final VoidCallback onCreateManual;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BpcColors.income.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: BpcColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos encontrados afuera',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BpcColors.mutedInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.seededName,
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
            'Fuente: ${match.sourceLabel}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LookupInfo(label: 'Codigo', value: barcode, emphasized: true),
              if ((match.brand ?? '').trim().isNotEmpty)
                _LookupInfo(
                  label: 'Marca',
                  value: match.brand!,
                  emphasized: true,
                ),
              if ((match.suggestedCategory ?? '').trim().isNotEmpty)
                _LookupInfo(
                  label: 'Categoria sugerida',
                  value: match.suggestedCategory!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Revísalos antes de guardar. Si algo no coincide, puedes corregirlo o pasar a alta manual sin perder el codigo.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final assistedButton = FilledButton.icon(
                onPressed: onCreateProduct,
                style: compact
                    ? FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      )
                    : null,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Crear con datos sugeridos'),
              );
              final manualButton = OutlinedButton.icon(
                onPressed: onCreateManual,
                style: compact
                    ? OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      )
                    : null,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Cargar manualmente'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    assistedButton,
                    const SizedBox(height: 10),
                    manualButton,
                    const SizedBox(height: 4),
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
                  assistedButton,
                  manualButton,
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

class _BarcodeNotFoundCard extends StatelessWidget {
  const _BarcodeNotFoundCard({
    required this.barcode,
    required this.title,
    required this.message,
    this.createButtonLabel = 'Crear producto',
    required this.onCreateProduct,
    required this.onTryAnother,
  });

  final String barcode;
  final String title;
  final String message;
  final String createButtonLabel;
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
                      title,
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
            message,
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
                label: Text(createButtonLabel),
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

class _CameraPlaceholderState extends StatelessWidget {
  const _CameraPlaceholderState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BpcColors.greenDeep,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
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
