import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../screens/expense_screen.dart';
import '../screens/home_screen.dart';
import '../screens/products_screen.dart';
import '../screens/sale_screen.dart';
import '../screens/summary_screen.dart';
import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../services/backup_service.dart';
import '../services/build_info.dart';
import '../services/excel_export_service.dart';
import '../theme/bpc_colors.dart';
import '../utils/user_facing_errors.dart';
import 'caja_clara_brand.dart';
import 'commerce_components.dart';
import 'commerce_scope.dart';
import 'operation_dialogs.dart';
import 'product_form_dialog.dart';
import 'quick_help_dialog.dart';

enum CommerceTab { home, products, summary }

class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({super.key});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  CommerceTab _tab = CommerceTab.home;
  bool _exportingExcel = false;
  bool _applyingStarterTemplate = false;
  bool _loadingCommercialDemo = false;
  bool _cleaningCommercialDemo = false;
  bool _resettingCommercialDemo = false;
  bool _resettingAllData = false;
  bool _exportingBackup = false;
  bool _restoringBackup = false;
  bool _retryingSave = false;
  bool _undoingMovement = false;
  bool _savingCashEvent = false;

  Future<void> _openSale() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const SaleScreen()),
    );
    if (!mounted || message == null) {
      return;
    }
    _showMovementSavedFeedback(message);
  }

  Future<void> _openExpense() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ExpenseScreen()),
    );
    if (!mounted || message == null) {
      return;
    }
    _showMovementSavedFeedback(message);
  }

  void _openProducts() {
    setState(() => _tab = CommerceTab.products);
  }

  void _openCash() {
    setState(() => _tab = CommerceTab.summary);
  }

  Future<void> _openQuickHelp() async {
    await showQuickHelpDialog(context);
  }

  void _showMovementSavedFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: _ActionSnackContent(
          message: message,
          actions: [
            _ActionSnackButton(
              label: 'Deshacer',
              onPressed: () {
                messenger.hideCurrentSnackBar();
                _undoLastMovement(skipConfirmation: true);
              },
            ),
            _ActionSnackButton(
              label: 'Ver caja',
              onPressed: () {
                messenger.hideCurrentSnackBar();
                if (!mounted) {
                  return;
                }
                setState(() => _tab = CommerceTab.summary);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProductFromSeed(
    CommerceStore store,
    ProductEditorSeed seed,
  ) async {
    final result = await showProductEditor(context, store, seed: seed);
    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.kind == ProductEditorResultKind.created
              ? '"${result.product.name}" ya se sumó al catálogo.'
              : 'Vas a usar "${result.product.name}" que ya existía en el catálogo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createProductFromFreeSale(Movement movement) async {
    if (!movement.isFreeSale) {
      return;
    }

    final store = CommerceScope.of(context);
    final seed = ProductEditorSeed(
      name: movement.subtitle ?? movement.title,
      pricePesos: movement.quantityUnits == null || movement.quantityUnits == 0
          ? movement.amountPesos
          : movement.amountPesos ~/ movement.quantityUnits!,
      stockUnits: 0,
      minStockUnits: 0,
    );
    await _createProductFromSeed(store, seed);
  }

  Future<void> _createProductFromSuggestion(
    FreeSaleSuggestion suggestion,
  ) async {
    final store = CommerceScope.of(context);
    await _createProductFromSeed(
      store,
      ProductEditorSeed(
        name: suggestion.displayDescription,
        pricePesos: suggestion.latestUnitPricePesos,
        stockUnits: 0,
        minStockUnits: 0,
      ),
    );
  }

  Future<void> _dismissFreeSaleSuggestion(FreeSaleSuggestion suggestion) async {
    final store = CommerceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.dismissFreeSaleSuggestion(suggestion.normalizedDescription);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sugerencia ocultada por ahora.'),
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

  Future<void> _retrySave() async {
    if (_retryingSave) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    setState(() => _retryingSave = true);
    try {
      await store.retrySave();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Guardado recuperado. Todo vuelve a estar en orden.'),
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
    } finally {
      if (mounted) {
        setState(() => _retryingSave = false);
      }
    }
  }

  Future<void> _loadCommercialDemo() async {
    if (_loadingCommercialDemo) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    if (!store.canLoadCommercialDemo) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Los datos de demo solo se cargan cuando la app está vacía.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loadingCommercialDemo = true);
    try {
      final result = await store.loadCommercialDemo();
      if (!mounted) {
        return;
      }
      if (!result.applied) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Los datos de demo no se cargaron.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Listo. Ahora probá registrar una venta.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar la demo: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingCommercialDemo = false);
      }
    }
  }

  Future<void> _resetCommercialDemo() async {
    if (_resettingCommercialDemo) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar demo'),
        content: const Text(
          'Se reemplazan los datos actuales por un ejemplo neutro listo para mostrar. Esta acción no usa datos personales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reiniciar demo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    setState(() => _resettingCommercialDemo = true);
    try {
      final result = await store.resetCommercialDemo();
      if (!mounted) {
        return;
      }
      setState(() => _tab = CommerceTab.home);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Demo lista: ${result.productCount} productos y ${result.movementCount} movimientos.',
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
          content: Text(
            'No se pudo reiniciar la demo: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resettingCommercialDemo = false);
      }
    }
  }

  Future<void> _cleanCommercialDemoData() async {
    if (_cleaningCommercialDemo) {
      return;
    }

    final confirmed = await showDangerConfirmationDialog(
      context,
      title: 'Limpiar datos de demo',
      message:
          'Se eliminarán los datos de ejemplo cargados para probar Caja Clara. Tus datos reales no deberían verse afectados.',
      confirmLabel: 'Limpiar demo',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    setState(() => _cleaningCommercialDemo = true);
    try {
      final result = await store.cleanCommercialDemoData();
      if (!mounted) {
        return;
      }
      setState(() => _tab = CommerceTab.home);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.applied
                ? 'Datos de demo limpiados: ${result.productCount} productos y ${result.movementCount} movimientos.'
                : 'No había datos de demo identificables para limpiar.',
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
          content: Text(
            'No se pudo limpiar la demo: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cleaningCommercialDemo = false);
      }
    }
  }

  Future<void> _resetAllData() async {
    if (_resettingAllData) {
      return;
    }

    final confirmed = await _showTypedResetConfirmation();
    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    setState(() => _resettingAllData = true);
    try {
      await store.resetAllData();
      if (!mounted) {
        return;
      }
      setState(() => _tab = CommerceTab.home);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Caja Clara quedó lista para empezar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo restablecer Caja Clara: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resettingAllData = false);
      }
    }
  }

  Future<bool> _showTypedResetConfirmation() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        var canReset = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Restablecer Caja Clara'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esto eliminará productos, ventas, gastos y movimientos guardados en este dispositivo.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Escribí RESTABLECER',
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      setDialogState(() => canReset = value == 'RESTABLECER');
                    },
                    onSubmitted: (_) {
                      if (canReset) {
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: canReset
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Restablecer'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result ?? false;
  }

  Future<void> _applyStarterTemplate() async {
    if (_applyingStarterTemplate) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _applyingStarterTemplate = true);
    try {
      final result = await store.applyArgentinianKioskTemplate();
      if (!mounted) {
        return;
      }

      setState(() => _tab = CommerceTab.products);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.fullySkipped
                ? 'La plantilla kiosco ya estaba cargada.'
                : result.skippedCount == 0
                ? 'Plantilla kiosco cargada: ${result.addedCount} productos nuevos.'
                : 'Plantilla kiosco cargada: ${result.addedCount} nuevos y ${result.skippedCount} repetidos salteados.',
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
          content: Text(
            'No se pudo cargar la plantilla: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _applyingStarterTemplate = false);
      }
    }
  }

  Future<void> _exportExcel() async {
    if (_exportingExcel) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _exportingExcel = true);
    try {
      final result = await ExcelExportService().export(store);
      if (!mounted) {
        return;
      }

      if (result.saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Excel guardado en ${result.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.downloaded) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Descarga de Excel iniciada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo exportar Excel: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }

  Future<void> _exportBackup() async {
    if (_exportingBackup) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _exportingBackup = true);
    try {
      final result = await BackupService().exportBackup(store);
      if (!mounted) {
        return;
      }
      if (result.saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Backup guardado en ${result.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.downloaded) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Descarga de backup iniciada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo exportar el backup: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingBackup = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_restoringBackup) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final backupService = BackupService();

    setState(() => _restoringBackup = true);
    try {
      final importData = await backupService.pickBackupToImport();
      if (importData == null || !mounted) {
        return;
      }

      final confirmed = await showDangerConfirmationDialog(
        context,
        title: 'Restaurar backup',
        message:
            'Se reemplazará el estado actual por el contenido de ${importData.fileName}. Esta acción no se puede revertir.',
        confirmLabel: 'Restaurar',
      );
      if (!confirmed || !mounted) {
        return;
      }

      await store.restoreSnapshot(importData.snapshot);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup restaurado desde ${importData.fileName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo restaurar el backup: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoringBackup = false);
      }
    }
  }

  Future<void> _undoLastMovement({bool skipConfirmation = false}) async {
    if (_undoingMovement) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final movement = store.lastMovement;
    if (movement == null) {
      return;
    }

    if (!skipConfirmation) {
      final confirmed = await showDangerConfirmationDialog(
        context,
        title: 'Deshacer último movimiento',
        message:
            'Se va a deshacer "${movement.title}". Si fue una venta, también se repone el stock.',
        confirmLabel: 'Deshacer',
      );
      if (!confirmed) {
        return;
      }
    }

    setState(() => _undoingMovement = true);
    try {
      await store.undoLastMovement();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Último movimiento deshecho'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo deshacer: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _undoingMovement = false);
      }
    }
  }

  Future<void> _registerCashOpening() async {
    if (_savingCashEvent) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashOpeningToday
          ? 'Actualizar apertura'
          : 'Apertura de caja',
      label: 'Caja inicial',
      confirmLabel: store.hasCashOpeningToday ? 'Actualizar' : 'Guardar',
      helper: 'Ingresá el efectivo inicial del día.',
      initialValue: store.todayOpeningCashPesos,
    );
    if (amount == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    var overwrite = false;
    if (store.hasCashOpeningToday) {
      overwrite = await showDangerConfirmationDialog(
        context,
        title: 'Reemplazar apertura',
        message:
            'Ya existe una apertura registrada hoy. Se reemplazará la apertura y se limpiará el cierre del día.',
        confirmLabel: 'Reemplazar',
      );
      if (!overwrite) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    setState(() => _savingCashEvent = true);
    try {
      await store.registerCashOpening(
        openingBalancePesos: amount,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      _showMovementSavedFeedback('Apertura de caja registrada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar la apertura: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingCashEvent = false);
      }
    }
  }

  Future<void> _registerCashClosing() async {
    if (_savingCashEvent) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashClosingToday ? 'Actualizar cierre' : 'Cierre de caja',
      label: 'Caja contada',
      confirmLabel: store.hasCashClosingToday ? 'Actualizar' : 'Guardar',
      helper: 'Ingresá el monto contado al cierre.',
      initialValue: store.todayClosingCashPesos,
    );
    if (amount == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    var overwrite = false;
    if (store.hasCashClosingToday) {
      overwrite = await showDangerConfirmationDialog(
        context,
        title: 'Reemplazar cierre',
        message:
            'Ya existe un cierre registrado hoy. Se reemplazará por el nuevo valor.',
        confirmLabel: 'Reemplazar',
      );
      if (!overwrite) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    setState(() => _savingCashEvent = true);
    try {
      await store.registerCashClosing(
        closingBalancePesos: amount,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      _showMovementSavedFeedback('Cierre de caja registrado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar el cierre: ${userFacingErrorMessage(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingCashEvent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    final pages = <CommerceTab, Widget>{
      CommerceTab.home: HomeScreen(
        onNewSale: _openSale,
        onNewExpense: _openExpense,
        onOpenProducts: _openProducts,
        onOpenCash: _openCash,
        onOpenCashRegister: _registerCashOpening,
        onExportExcel: _exportExcel,
        exportingExcel: _exportingExcel,
        onApplyStarterTemplate: _applyStarterTemplate,
        onLoadCommercialDemo: _loadCommercialDemo,
        onCleanCommercialDemo: _cleanCommercialDemoData,
        onResetCommercialDemo: _resetCommercialDemo,
        onResetAllData: _resetAllData,
        onCreateProductFromFreeSale: _createProductFromFreeSale,
        onCreateProductFromSuggestion: _createProductFromSuggestion,
        onDismissFreeSaleSuggestion: _dismissFreeSaleSuggestion,
        applyingStarterTemplate: _applyingStarterTemplate,
        loadingCommercialDemo: _loadingCommercialDemo,
        cleaningCommercialDemo: _cleaningCommercialDemo,
        resettingCommercialDemo: _resettingCommercialDemo,
        resettingAllData: _resettingAllData,
      ),
      CommerceTab.products: ProductsScreen(
        onApplyStarterTemplate: _applyStarterTemplate,
        applyingStarterTemplate: _applyingStarterTemplate,
      ),
      CommerceTab.summary: SummaryScreen(
        onExportExcel: _exportExcel,
        exportingExcel: _exportingExcel,
        onExportBackup: _exportBackup,
        exportingBackup: _exportingBackup,
        onRestoreBackup: _restoreBackup,
        restoringBackup: _restoringBackup,
        onUndoLastMovement: _undoLastMovement,
        undoingMovement: _undoingMovement,
        onRegisterCashOpening: _registerCashOpening,
        onRegisterCashClosing: _registerCashClosing,
        savingCashEvent: _savingCashEvent,
        onCreateProductFromFreeSale: _createProductFromFreeSale,
        onCreateProductFromSuggestion: _createProductFromSuggestion,
        onDismissFreeSaleSuggestion: _dismissFreeSaleSuggestion,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final page = pages[_tab]!;
        final lowStockCount = store.lowStockCount;

        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 238,
                    margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    decoration: BoxDecoration(
                      color: BpcColors.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: BpcColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: BpcColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(2, 4, 2, 6),
                            child: _RailBrand(),
                          ),
                        ),
                        Expanded(
                          child: NavigationRail(
                            selectedIndex: _tab.index,
                            onDestinationSelected: (index) {
                              setState(() => _tab = CommerceTab.values[index]);
                            },
                            labelType: NavigationRailLabelType.all,
                            leading: const SizedBox(height: 2),
                            groupAlignment: -0.88,
                            backgroundColor: Colors.transparent,
                            destinations: [
                              const NavigationRailDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home_rounded),
                                label: Text('Inicio'),
                              ),
                              NavigationRailDestination(
                                icon: _ProductsIconBadge(count: lowStockCount),
                                selectedIcon: _ProductsIconBadge(
                                  count: lowStockCount,
                                  selected: true,
                                ),
                                label: const Text('Productos'),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                selectedIcon: Icon(
                                  Icons.account_balance_wallet_rounded,
                                ),
                                label: Text('Caja'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          child: _SaveStatusChip(store: store),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: _BuildInfoStrip(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                      child: Column(
                        children: [
                          if (store.lastError != null) ...[
                            _SaveErrorBanner(
                              message: store.lastError!,
                              retrying: _retryingSave || store.isSaving,
                              onRetry: _retrySave,
                            ),
                            const SizedBox(height: 10),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _openQuickHelp,
                              icon: const Icon(Icons.help_outline_rounded),
                              label: const Text('Ayuda'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(child: page),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  if (store.lastError != null) ...[
                    _SaveErrorBanner(
                      message: store.lastError!,
                      retrying: _retryingSave || store.isSaving,
                      onRetry: _retrySave,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _openQuickHelp,
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('Ayuda'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: page),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) {
              setState(() => _tab = CommerceTab.values[index]);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: _ProductsIconBadge(count: lowStockCount),
                selectedIcon: _ProductsIconBadge(
                  count: lowStockCount,
                  selected: true,
                ),
                label: 'Productos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Caja',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductsIconBadge extends StatelessWidget {
  const _ProductsIconBadge({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? Icons.inventory_2_rounded
        : Icons.inventory_2_outlined;
    if (count <= 0) return Icon(icon);

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -8,
          top: -6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BpcColors.expense,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.surface, width: 1.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '$count',
                style: TextStyle(
                  color: scheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: BpcColors.accentStrong,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: BpcColors.accentStrong.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const CajaClaraSymbol(size: 29),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caja Clara',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: BpcColors.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Luna Systems',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BpcColors.accentStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Ventas, gastos y caja en un solo lugar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: BpcColors.mutedInk,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Indicador discreto de guardado: refleja el estado real del store.
class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    if (store.lastError != null) {
      color = BpcColors.expense;
      label = 'Guardado con problema';
      icon = Icons.error_outline_rounded;
    } else if (store.isSaving) {
      color = BpcColors.warning;
      label = 'Guardando...';
      icon = Icons.sync_rounded;
    } else {
      color = BpcColors.accentStrong;
      label = 'Todo guardado';
      icon = Icons.cloud_done_rounded;
    }

    final saved = store.lastError == null && !store.isSaving;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: saved ? BpcColors.surface : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: saved ? BpcColors.line : color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: saved ? BpcColors.mutedInk : color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: scheme.errorContainer.withValues(alpha: 0.72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BpcColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: retrying ? null : onRetry,
            child: Text(retrying ? 'Reintentando' : 'Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _ActionSnackButton {
  const _ActionSnackButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _ActionSnackContent extends StatelessWidget {
  const _ActionSnackContent({required this.message, required this.actions});

  final String message;
  final List<_ActionSnackButton> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final action in actions)
                TextButton(
                  onPressed: action.onPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(action.label),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BuildInfoStrip extends StatelessWidget {
  const _BuildInfoStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = BuildInfo.footerText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Build copiado: $text'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.fingerprint_rounded, size: 16, color: scheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 16, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
