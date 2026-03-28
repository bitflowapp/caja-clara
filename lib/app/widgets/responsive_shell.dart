import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../screens/expense_screen.dart';
import '../screens/home_screen.dart';
import '../screens/products_screen.dart';
import '../screens/barcode_scan_screen.dart';
import '../screens/sale_screen.dart';
import '../screens/summary_screen.dart';
import '../models/movement.dart';
import '../models/product.dart';
import '../services/commerce_store.dart';
import '../services/backup_service.dart';
import '../services/build_info.dart';
import '../services/excel_export_service.dart';
import '../services/license_service.dart';
import '../theme/bpc_colors.dart';
import '../utils/user_facing_errors.dart';
import 'caja_clara_brand.dart';
import 'commerce_components.dart';
import 'commerce_scope.dart';
import 'license_dialogs.dart';
import 'license_scope.dart';
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
  static const Duration _recoverableSaveBannerDuration = Duration(seconds: 8);

  CommerceTab _tab = CommerceTab.home;
  bool _exportingExcel = false;
  bool _applyingStarterTemplate = false;
  bool _loadingDemoData = false;
  bool _exportingBackup = false;
  bool _restoringBackup = false;
  bool _retryingSave = false;
  bool _undoingMovement = false;
  bool _savingCashEvent = false;
  String? _trackedSaveIssueMessage;
  bool _recoverableSaveBannerDismissed = false;
  Timer? _recoverableSaveBannerTimer;
  bool _recoverableSaveBannerTimerQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final saveIssueMessage = _saveIssueMessageFor(
      CommerceScope.of(context).lastError,
    );
    if (saveIssueMessage != _trackedSaveIssueMessage) {
      _trackedSaveIssueMessage = saveIssueMessage;
      _cancelRecoverableSaveBannerTimer();
      _recoverableSaveBannerDismissed = false;
    }
  }

  @override
  void dispose() {
    _cancelRecoverableSaveBannerTimer();
    super.dispose();
  }

  Future<void> _openSale() async {
    if (!await _ensureFeatureAccess(LockedFeature.sales) || !mounted) {
      return;
    }
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const SaleScreen()),
    );
    if (!mounted || message == null) {
      return;
    }
    _showMovementSavedFeedback(message);
  }

  Future<void> _openSaleForProduct(Product product) async {
    if (!await _ensureFeatureAccess(LockedFeature.sales) || !mounted) {
      return;
    }
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SaleScreen(initialProduct: product),
      ),
    );
    if (!mounted || message == null) {
      return;
    }
    _showMovementSavedFeedback(message);
  }

  Future<void> _openExpense() async {
    if (!await _ensureFeatureAccess(LockedFeature.expenses) || !mounted) {
      return;
    }
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ExpenseScreen()),
    );
    if (!mounted || message == null) {
      return;
    }
    _showMovementSavedFeedback(message);
  }

  void _openBarcodeScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BarcodeScanScreen()));
  }

  void _openProducts() {
    setState(() => _tab = CommerceTab.products);
  }

  Future<void> _openQuickHelp() async {
    await showQuickHelpDialog(context);
  }

  Future<bool> _ensureFeatureAccess(LockedFeature feature) {
    return ensureLicenseAccess(context, feature);
  }

  Future<void> _openLicenseManagement() {
    return showLicenseManagementDialog(context);
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
              ? '"${result.product.name}" ya quedo en el catalogo.'
              : 'Usaras "${result.product.name}", que ya estaba en el catalogo.',
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

  bool _isRecoverableSaveIssue(String? lastError) {
    return lastError == 'No se pudo guardar el cambio.';
  }

  String? _saveIssueTitleFor(String? lastError) {
    if (lastError == null) {
      return null;
    }
    return _isRecoverableSaveIssue(lastError)
        ? 'Guardado pendiente'
        : 'Revisa el guardado';
  }

  String? _saveIssueMessageFor(String? lastError) {
    if (lastError == null) {
      return null;
    }
    return _isRecoverableSaveIssue(lastError)
        ? 'El ultimo cambio no pudo guardarse. Puedes reintentarlo desde aqui.'
        : lastError;
  }

  void _cancelRecoverableSaveBannerTimer() {
    _recoverableSaveBannerTimer?.cancel();
    _recoverableSaveBannerTimer = null;
    _recoverableSaveBannerTimerQueued = false;
  }

  void _dismissRecoverableSaveBanner() {
    _cancelRecoverableSaveBannerTimer();
    if (!mounted) {
      return;
    }
    setState(() => _recoverableSaveBannerDismissed = true);
  }

  void _syncRecoverableSaveBanner({
    required bool wide,
    required bool hasIssue,
    required bool isRecoverable,
  }) {
    final shouldAutoDismiss = wide && hasIssue && isRecoverable;
    if (!shouldAutoDismiss) {
      _cancelRecoverableSaveBannerTimer();
      return;
    }
    if (_recoverableSaveBannerDismissed ||
        _recoverableSaveBannerTimer != null ||
        _recoverableSaveBannerTimerQueued) {
      return;
    }

    _recoverableSaveBannerTimerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverableSaveBannerTimerQueued = false;
      if (!mounted ||
          _recoverableSaveBannerDismissed ||
          _recoverableSaveBannerTimer != null) {
        return;
      }
      _recoverableSaveBannerTimer = Timer(_recoverableSaveBannerDuration, () {
        if (!mounted) {
          return;
        }
        setState(() => _recoverableSaveBannerDismissed = true);
        _recoverableSaveBannerTimer = null;
      });
    });
  }

  Future<void> _applyStarterTemplate() async {
    if (_applyingStarterTemplate) {
      return;
    }
    if (!await _ensureFeatureAccess(LockedFeature.templates) || !mounted) {
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

  Future<void> _loadDemoData() async {
    if (_loadingDemoData) {
      return;
    }
    if (!await _ensureFeatureAccess(LockedFeature.demoData) || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _loadingDemoData = true);
    try {
      await store.loadDemoData();
      if (!mounted) {
        return;
      }

      setState(() => _tab = CommerceTab.home);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Ejemplo cargado. Ya puedes recorrer ventas, productos y caja.',
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
          content: Text(userFacingErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingDemoData = false);
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
            content: Text('Respaldo guardado en ${result.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.downloaded) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Descarga del respaldo iniciada'),
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
            'No se pudo guardar el respaldo: ${userFacingErrorMessage(error)}',
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
    if (!await _ensureFeatureAccess(LockedFeature.restore) || !mounted) {
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
        title: 'Restaurar respaldo',
        message:
            'Se reemplazara el estado actual por el contenido de ${importData.fileName}. Esta accion no se puede revertir.',
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
          content: Text('Respaldo restaurado desde ${importData.fileName}'),
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
            'No se pudo restaurar el respaldo: ${userFacingErrorMessage(error)}',
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
    if (!await _ensureFeatureAccess(LockedFeature.cash) || !mounted) {
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
        title: 'Deshacer ultimo movimiento',
        message:
            'Se va a deshacer "${movement.title}". Si fue una venta, tambien se repone el stock.',
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
          content: Text('Ultimo movimiento deshecho'),
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
    if (!await _ensureFeatureAccess(LockedFeature.cash) || !mounted) {
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
      helper:
          'Ingresa el efectivo inicial del dia. Puedes usar 0 si abres sin efectivo.',
      initialValue: store.todayOpeningCashPesos,
      allowZero: true,
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
            'Ya existe una apertura registrada hoy. Se reemplazara la apertura y se limpiara el cierre del dia.',
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
    if (!await _ensureFeatureAccess(LockedFeature.cash) || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashClosingToday ? 'Actualizar cierre' : 'Cierre de caja',
      label: 'Caja contada',
      confirmLabel: store.hasCashClosingToday ? 'Actualizar' : 'Guardar',
      helper:
          'Ingresa el monto contado al cierre. Puedes usar 0 si la caja queda vacia.',
      initialValue: store.todayClosingCashPesos,
      allowZero: true,
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
            'Ya existe un cierre registrado hoy. Se reemplazara por el nuevo valor.',
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
    final license = LicenseScope.of(context);
    final pages = <CommerceTab, Widget>{
      CommerceTab.home: HomeScreen(
        onNewSale: _openSale,
        onNewExpense: _openExpense,
        onScanProduct: _openBarcodeScan,
        onOpenProducts: _openProducts,
        onExportExcel: _exportExcel,
        onApplyStarterTemplate: _applyStarterTemplate,
        onLoadDemoData: _loadDemoData,
        onCreateProductFromFreeSale: _createProductFromFreeSale,
        onCreateProductFromSuggestion: _createProductFromSuggestion,
        onDismissFreeSaleSuggestion: _dismissFreeSaleSuggestion,
        exportingExcel: _exportingExcel,
        applyingStarterTemplate: _applyingStarterTemplate,
        loadingDemoData: _loadingDemoData,
      ),
      CommerceTab.products: ProductsScreen(
        onApplyStarterTemplate: _applyStarterTemplate,
        applyingStarterTemplate: _applyingStarterTemplate,
        onLoadDemoData: _loadDemoData,
        loadingDemoData: _loadingDemoData,
        onSellProduct: _openSaleForProduct,
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
        final hasSaveIssue = store.lastError != null;
        final isRecoverableSaveIssue = _isRecoverableSaveIssue(store.lastError);
        final saveIssueTitle = _saveIssueTitleFor(store.lastError);
        final saveIssueMessage = _saveIssueMessageFor(store.lastError);
        final canCollapseSaveBanner = wide && isRecoverableSaveIssue;
        _syncRecoverableSaveBanner(
          wide: wide,
          hasIssue: saveIssueMessage != null,
          isRecoverable: isRecoverableSaveIssue,
        );
        final showSaveIssueBanner =
            saveIssueMessage != null &&
            (!canCollapseSaveBanner || !_recoverableSaveBannerDismissed);
        final saveStatusLabel = hasSaveIssue
            ? isRecoverableSaveIssue
                  ? 'Pendiente de guardado'
                  : 'Revisa el guardado'
            : store.isSaving
            ? 'Guardando'
            : 'Todo guardado';
        final saveStatusColor = hasSaveIssue
            ? BpcColors.expenseSoft
            : store.isSaving
            ? BpcColors.sandMuted
            : BpcColors.income;
        final saveStatusIcon = hasSaveIssue
            ? Icons.sync_problem_rounded
            : store.isSaving
            ? Icons.sync_rounded
            : Icons.check_circle_outline_rounded;

        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    child: SizedBox(
                      width: 230,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(6, 6, 6, 14),
                            child: _RailBrand(),
                          ),
                          Expanded(
                            child: NavigationRail(
                              selectedIndex: _tab.index,
                              onDestinationSelected: (index) {
                                setState(
                                  () => _tab = CommerceTab.values[index],
                                );
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
                                  icon: _ProductsIconBadge(
                                    count: lowStockCount,
                                  ),
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
                            padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                            child: _RailSystemFooter(
                              saveStatusLabel: saveStatusLabel,
                              saveStatusColor: saveStatusColor,
                              saveStatusIcon: saveStatusIcon,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.fromLTRB(18, 20, 0, 20),
                    color: BpcColors.line,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 18, 16),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: _ShellUtilityActions(
                              showLicenseAction: license.shouldShowLicenseUi,
                              licenseActionLabel: license.isActivated
                                  ? 'Licencia'
                                  : 'Activar Caja Clara',
                              onLicenseAction: _openLicenseManagement,
                              onHelp: _openQuickHelp,
                            ),
                          ),
                          if (showSaveIssueBanner) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                child: _SaveErrorBanner(
                                  title: saveIssueTitle!,
                                  message: saveIssueMessage,
                                  retrying: _retryingSave || store.isSaving,
                                  onRetry: _retrySave,
                                  onDismiss: canCollapseSaveBanner
                                      ? _dismissRecoverableSaveBanner
                                      : null,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          if (license.shouldShowLicenseUi &&
                              license.status != LicenseStatus.active) ...[
                            _LicenseStatusBanner(
                              licenseService: license,
                              onManage: _openLicenseManagement,
                            ),
                            SizedBox(
                              height:
                                  license.status == LicenseStatus.trialActive
                                  ? 6
                                  : 10,
                            ),
                          ],
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ShellUtilityActions(
                      showLicenseAction: license.shouldShowLicenseUi,
                      licenseActionLabel: license.isActivated
                          ? 'Licencia'
                          : 'Activar Caja Clara',
                      onLicenseAction: _openLicenseManagement,
                      onHelp: _openQuickHelp,
                    ),
                  ),
                  if (showSaveIssueBanner) ...[
                    const SizedBox(height: 10),
                    _SaveErrorBanner(
                      title: saveIssueTitle!,
                      message: saveIssueMessage,
                      retrying: _retryingSave || store.isSaving,
                      onRetry: _retrySave,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  if (license.shouldShowLicenseUi &&
                      license.status != LicenseStatus.active) ...[
                    _LicenseStatusBanner(
                      licenseService: license,
                      onManage: _openLicenseManagement,
                    ),
                    SizedBox(
                      height: license.status == LicenseStatus.trialActive
                          ? 6
                          : 10,
                    ),
                  ],
                  const _BuildInfoStrip(),
                  const SizedBox(height: 8),
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

class _ShellUtilityActions extends StatelessWidget {
  const _ShellUtilityActions({
    required this.showLicenseAction,
    required this.licenseActionLabel,
    required this.onLicenseAction,
    required this.onHelp,
  });

  final bool showLicenseAction;
  final String licenseActionLabel;
  final Future<void> Function() onLicenseAction;
  final Future<void> Function() onHelp;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (showLicenseAction)
          TextButton.icon(
            onPressed: () => onLicenseAction(),
            icon: const Icon(Icons.verified_user_rounded),
            label: Text(licenseActionLabel),
          ),
        TextButton.icon(
          onPressed: () => onHelp(),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('Ayuda'),
        ),
      ],
    );
  }
}

class _RailSystemFooter extends StatelessWidget {
  const _RailSystemFooter({
    required this.saveStatusLabel,
    required this.saveStatusColor,
    required this.saveStatusIcon,
  });

  final String saveStatusLabel;
  final Color saveStatusColor;
  final IconData saveStatusIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = BuildInfo.footerText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.34)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(saveStatusIcon, size: 14, color: saveStatusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  saveStatusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _BuildInfoStrip(
            dense: true,
            leadingIcon: false,
            text: text,
            copySnackLabel: 'Datos de soporte copiados',
          ),
        ],
      ),
    );
  }
}

class _LicenseStatusBanner extends StatelessWidget {
  const _LicenseStatusBanner({
    required this.licenseService,
    required this.onManage,
  });

  final LicenseService licenseService;
  final Future<void> Function() onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expired = licenseService.isTrialExpired;
    final accent = expired ? scheme.error : scheme.primary;
    final chipLabel = expired
        ? 'Solo lectura'
        : '${licenseService.trialDaysRemaining} ${licenseService.trialDaysRemaining == 1 ? 'dia' : 'dias'} restantes';

    if (!expired) {
      final summary =
          'Puedes activar cuando quieras. Tus datos siguen guardados en esta PC.';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final manageButton = TextButton.icon(
              onPressed: () => onManage(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.key_rounded, size: 18),
              label: const Text('Ver activacion'),
            );
            final body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      licenseService.statusHeadline,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chipLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [body, const SizedBox(height: 4), manageButton],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: body),
                const SizedBox(width: 12),
                manageButton,
              ],
            );
          },
        ),
      );
    }

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: expired
          ? scheme.errorContainer.withValues(alpha: 0.54)
          : scheme.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final manageButton = FilledButton.icon(
            onPressed: () => onManage(),
            style: compact
                ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))
                : null,
            icon: const Icon(Icons.key_rounded),
            label: Text(expired ? 'Activar Caja Clara' : 'Ver activacion'),
          );
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    licenseService.statusHeadline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chipLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                licenseService.statusDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                licenseService.positioningMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [body, const SizedBox(height: 14), manageButton],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: body),
              const SizedBox(width: 16),
              manageButton,
            ],
          );
        },
      ),
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
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.07),
                  BpcColors.surface,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const CajaClaraSmallMark(size: 36),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caja Clara',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: BpcColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Caja, ventas, stock y codigos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BpcColors.subtleInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Listo para mostrador',
          style: theme.textTheme.labelMedium?.copyWith(
            color: BpcColors.mutedInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({
    required this.title,
    required this.message,
    required this.retrying,
    required this.onRetry,
    this.onDismiss,
  });

  final String title;
  final String message;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelColor = Color.alphaBlend(
      BpcColors.sandSoft.withValues(alpha: 0.44),
      BpcColors.surface,
    );
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: panelColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final action = OutlinedButton.icon(
            onPressed: retrying ? null : onRetry,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: BpcColors.ink,
              backgroundColor: Colors.white.withValues(alpha: 0.42),
              side: BorderSide(
                color: BpcColors.lineStrong.withValues(alpha: 0.8),
              ),
            ),
            icon: retrying
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(retrying ? 'Reintentando' : 'Reintentar'),
          );

          final messageBlock = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: BpcColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BpcColors.mutedInk,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          );

          final leading = DecoratedBox(
            decoration: BoxDecoration(
              color: BpcColors.sand.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.sync_problem_rounded,
                color: BpcColors.expense,
                size: 16,
              ),
            ),
          );

          final dismissButton = onDismiss == null
              ? null
              : IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  splashRadius: 18,
                  tooltip: 'Ocultar aviso',
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(child: messageBlock),
                    if (dismissButton != null) dismissButton,
                  ],
                ),
                const SizedBox(height: 10),
                action,
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(child: messageBlock),
              const SizedBox(width: 12),
              action,
              if (dismissButton != null) ...[
                const SizedBox(width: 2),
                dismissButton,
              ],
            ],
          );
        },
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
  const _BuildInfoStrip({
    this.dense = false,
    this.leadingIcon = true,
    this.text,
    this.copySnackLabel = 'Datos de soporte copiados',
  });

  final bool dense;
  final bool leadingIcon;
  final String? text;
  final String copySnackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final footerText = text ?? BuildInfo.footerText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: footerText));
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$copySnackLabel: $footerText'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(dense ? 22 : 0, dense ? 2 : 10, 0, 2),
          decoration: BoxDecoration(
            border: dense
                ? null
                : Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
          ),
          child: Row(
            children: [
              if (leadingIcon) ...[
                Icon(
                  Icons.fingerprint_rounded,
                  size: dense ? 14 : 16,
                  color: scheme.outline,
                ),
                SizedBox(width: dense ? 6 : 8),
              ],
              Expanded(
                child: Text(
                  footerText,
                  maxLines: dense ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline.withValues(alpha: dense ? 0.88 : 1),
                    fontWeight: dense ? FontWeight.w600 : FontWeight.w700,
                    height: dense ? 1.15 : null,
                  ),
                ),
              ),
              SizedBox(width: dense ? 6 : 8),
              Icon(
                Icons.copy_rounded,
                size: dense ? 13 : 16,
                color: scheme.outline.withValues(alpha: dense ? 0.72 : 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
