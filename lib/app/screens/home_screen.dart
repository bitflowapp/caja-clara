import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../services/starter_templates.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/input_shortcuts.dart';
import '../widgets/product_form_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onOpenProducts,
    required this.onOpenCash,
    required this.onOpenCashRegister,
    required this.onCloseCashRegister,
    required this.onShareDailySummary,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.onApplyStarterTemplate,
    required this.onLoadCommercialDemo,
    required this.onCleanCommercialDemo,
    required this.onResetCommercialDemo,
    required this.onResetAllData,
    required this.onCreateProductFromFreeSale,
    required this.onCreateProductFromSuggestion,
    required this.onDismissFreeSaleSuggestion,
    required this.applyingStarterTemplate,
    required this.loadingCommercialDemo,
    required this.cleaningCommercialDemo,
    required this.resettingCommercialDemo,
    required this.resettingAllData,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenCash;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onCloseCashRegister;
  final VoidCallback onShareDailySummary;
  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onLoadCommercialDemo;
  final VoidCallback onCleanCommercialDemo;
  final VoidCallback onResetCommercialDemo;
  final VoidCallback onResetAllData;
  final Future<void> Function(Movement movement) onCreateProductFromFreeSale;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onCreateProductFromSuggestion;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onDismissFreeSaleSuggestion;
  final bool applyingStarterTemplate;
  final bool loadingCommercialDemo;
  final bool cleaningCommercialDemo;
  final bool resettingCommercialDemo;
  final bool resettingAllData;

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final recent = store.recentMovements();
        final suggestions = store.freeSaleSuggestions;
        const demoControlsEnabled = InputShortcutScope.demoControlsEnabled;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CashStatusBanner(store: store, onOpenCash: onOpenCash),
              const SizedBox(height: 12),
              _ContextualActionPanel(
                store: store,
                onNewSale: onNewSale,
                onNewExpense: onNewExpense,
                onOpenCash: onOpenCash,
                onOpenCashRegister: onOpenCashRegister,
                onCloseCashRegister: onCloseCashRegister,
              ),
              if (demoControlsEnabled &&
                  (store.hasProducts || store.hasMovements)) ...[
                const SizedBox(height: 14),
                _CommercialDemoCard(
                  hasDemoData: store.hasCommercialDemoData,
                  onCleanCommercialDemo: onCleanCommercialDemo,
                  onResetCommercialDemo: onResetCommercialDemo,
                  onResetAllData: onResetAllData,
                  cleaningCommercialDemo: cleaningCommercialDemo,
                  resettingCommercialDemo: resettingCommercialDemo,
                  resettingAllData: resettingAllData,
                ),
              ],
              if (!store.hasProducts) ...[
                const SizedBox(height: 14),
                _StarterTemplateCard(
                  onApplyStarterTemplate: onApplyStarterTemplate,
                  onAddProduct: () => showProductEditor(context, store),
                  onLoadCommercialDemo:
                      demoControlsEnabled && store.canLoadCommercialDemo
                      ? onLoadCommercialDemo
                      : null,
                  applyingStarterTemplate: applyingStarterTemplate,
                  loadingCommercialDemo: loadingCommercialDemo,
                ),
              ] else if (!store.hasMovements) ...[
                const SizedBox(height: 14),
                _GuideCard(
                  title: 'Empezá por acá',
                  steps: const [
                    'Tocá Nueva venta y escribí qué estás vendiendo.',
                    'Cargá la cantidad y el precio, y guardá.',
                    'Vas a ver la caja del día actualizada al instante.',
                  ],
                  actionLabel: 'Registrar primera venta',
                  onAction: onNewSale,
                ),
              ],
              const SizedBox(height: 18),
              const SectionHeader(
                title: 'Hoy en un vistazo',
                subtitle: 'Lo que está pasando en tu negocio ahora mismo.',
              ),
              const SizedBox(height: 12),
              _HomeKpiGrid(store: store, onOpenCash: onOpenCash),
              const SizedBox(height: 18),
              const SectionHeader(
                title: 'Accesos principales',
                subtitle: 'Lo básico para trabajar durante el día.',
              ),
              const SizedBox(height: 12),
              _MainQuickActionsPanel(
                onNewSale: onNewSale,
                onNewExpense: onNewExpense,
                onOpenProducts: onOpenProducts,
                onOpenCash: onOpenCash,
                isRegisterClosed: store.hasCashClosingToday,
              ),
              const SizedBox(height: 14),
              _SecondaryActionsPanel(
                onOpenCash: onOpenCash,
                onShareDailySummary: onShareDailySummary,
                onExportExcel: onExportExcel,
                exportingExcel: exportingExcel,
              ),
              if (store.hasProducts && store.lowStockCount > 0) ...[
                const SizedBox(height: 12),
                _LowStockBanner(
                  count: store.lowStockCount,
                  onTap: onOpenProducts,
                ),
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FreeSaleSuggestionCard(
                  suggestion: suggestions.first,
                  onCreateProduct: () =>
                      onCreateProductFromSuggestion(suggestions.first),
                  onDismiss: () =>
                      onDismissFreeSaleSuggestion(suggestions.first),
                ),
              ],
              const SizedBox(height: 18),
              const SectionHeader(
                title: 'Últimos movimientos',
                subtitle: 'Cada venta y cada gasto del día, en orden.',
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                EmptyCard(
                  icon: Icons.receipt_long_rounded,
                  title: !store.hasProducts
                      ? 'Caja Clara está lista para empezar.'
                      : !store.hasCashOpeningToday
                      ? 'Primero abrí la caja del día'
                      : 'Todavía no registraste ventas hoy',
                  message: !store.hasProducts
                      ? (demoControlsEnabled
                            ? 'Cargá productos, registrá ventas o probá una demo cuando quieras.'
                            : 'Cargá productos o usá una plantilla para empezar a vender.')
                      : !store.hasCashOpeningToday
                      ? 'Anotá el efectivo inicial y vas a poder vender, gastar y ver tu caja del día al instante.'
                      : 'Cuando registres una venta o un gasto, lo ves acá al instante.',
                  action: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: !store.hasProducts
                            ? onApplyStarterTemplate
                            : !store.hasCashOpeningToday
                            ? onOpenCashRegister
                            : onNewSale,
                        child: Text(
                          !store.hasProducts
                              ? (applyingStarterTemplate
                                    ? 'Cargando plantilla...'
                                    : 'Cargar plantilla kiosco')
                              : !store.hasCashOpeningToday
                              ? 'Abrir caja'
                              : 'Registrar primera venta',
                        ),
                      ),
                      TextButton(
                        onPressed: () => showProductEditor(context, store),
                        child: const Text('Cargar producto'),
                      ),
                      if (!store.hasProducts &&
                          demoControlsEnabled &&
                          store.canLoadCommercialDemo)
                        TextButton(
                          onPressed: loadingCommercialDemo
                              ? null
                              : onLoadCommercialDemo,
                          child: Text(
                            loadingCommercialDemo
                                ? 'Cargando demo...'
                                : 'Cargar datos de demo',
                          ),
                        ),
                    ],
                  ),
                )
              else
                BpcPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < recent.length; index++)
                        MovementsListTile(
                          movement: recent[index],
                          productName: store
                              .productById(recent[index].productId ?? '')
                              ?.name,
                          onCreateProductFromFreeSale: recent[index].isFreeSale
                              ? () => onCreateProductFromFreeSale(recent[index])
                              : null,
                          showDivider: index != recent.length - 1,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

class _CashStatusBanner extends StatelessWidget {
  const _CashStatusBanner({required this.store, required this.onOpenCash});

  final CommerceStore store;
  final VoidCallback onOpenCash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opening = store.todayOpeningCashPesos;
    final closing = store.todayClosingCashPesos;
    final variant = _cashStatusVariant(store);

    final color = switch (variant) {
      _CashStatusVariant.closed => BpcColors.accentStrong,
      _CashStatusVariant.open => BpcColors.income,
      _CashStatusVariant.dayClosed => const Color(0xFFD97706),
    };
    final icon = switch (variant) {
      _CashStatusVariant.closed => Icons.savings_rounded,
      _CashStatusVariant.open => Icons.lock_open_rounded,
      _CashStatusVariant.dayClosed => Icons.task_alt_rounded,
    };
    final title = switch (variant) {
      _CashStatusVariant.closed => 'Caja cerrada',
      _CashStatusVariant.open => 'Caja abierta',
      _CashStatusVariant.dayClosed => 'Caja cerrada',
    };
    final subtitle = switch (variant) {
      _CashStatusVariant.closed =>
        'Abrí la caja para empezar a registrar movimientos.',
      _CashStatusVariant.open =>
        'Inicio: ${formatMoney(opening ?? 0)} · esperada ahora: ${formatMoney(store.todayExpectedCashPesos ?? opening ?? 0)}.',
      _CashStatusVariant.dayClosed =>
        'Cierre contado: ${formatMoney(closing ?? 0)} · diferencia: ${_differenceLabel(store.todayClosingDifferencePesos)}.',
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenCash,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Estado de caja',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BpcColors.subtleInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BpcColors.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: BpcColors.subtleInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CashStatusVariant { closed, open, dayClosed }

_CashStatusVariant _cashStatusVariant(CommerceStore store) {
  if (!store.hasCashOpeningToday) {
    return _CashStatusVariant.closed;
  }
  if (!store.hasCashClosingToday) {
    return _CashStatusVariant.open;
  }
  return _CashStatusVariant.dayClosed;
}

String _differenceLabel(int? diff) {
  if (diff == null) return 'sin cierre';
  if (diff == 0) return 'coincide';
  if (diff < 0) return 'faltan ${formatMoney(diff.abs())}';
  return 'sobran ${formatMoney(diff)}';
}

class _ContextualActionPanel extends StatelessWidget {
  const _ContextualActionPanel({
    required this.store,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onOpenCash,
    required this.onOpenCashRegister,
    required this.onCloseCashRegister,
  });

  final CommerceStore store;
  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onOpenCash;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onCloseCashRegister;

  @override
  Widget build(BuildContext context) {
    final variant = _cashStatusVariant(store);
    final primary = switch (variant) {
      _CashStatusVariant.closed => _PrimaryActionData(
        title: 'Abrir caja',
        subtitle: 'Cargá el efectivo inicial y empezá a vender.',
        icon: Icons.savings_rounded,
        onTap: onOpenCashRegister,
      ),
      _CashStatusVariant.open => _PrimaryActionData(
        title: 'Nueva venta',
        subtitle: 'Vendé en segundos y la caja se actualiza sola.',
        icon: Icons.point_of_sale_rounded,
        onTap: onNewSale,
      ),
      _CashStatusVariant.dayClosed => _PrimaryActionData(
        title: 'Abrir caja',
        subtitle: 'Empezá un nuevo día con el saldo inicial.',
        icon: Icons.savings_rounded,
        onTap: onOpenCashRegister,
      ),
    };

    final supporting = switch (variant) {
      _CashStatusVariant.closed => <_SupportingActionData>[],
      _CashStatusVariant.open => <_SupportingActionData>[
        _SupportingActionData(
          title: 'Registrar gasto',
          icon: Icons.receipt_long_rounded,
          onTap: onNewExpense,
        ),
        _SupportingActionData(
          title: 'Cerrar caja',
          icon: Icons.logout_rounded,
          onTap: onCloseCashRegister,
        ),
      ],
      _CashStatusVariant.dayClosed => <_SupportingActionData>[
        _SupportingActionData(
          title: 'Ver cierre',
          icon: Icons.summarize_rounded,
          onTap: onOpenCash,
        ),
      ],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final primaryCard = ActionCard(
          title: primary.title,
          subtitle: primary.subtitle,
          icon: primary.icon,
          onTap: primary.onTap,
          fillColor: BpcColors.accentStrong,
          contentColor: Colors.white,
          emphasized: true,
        );
        final secondaryRow = _SupportingActionsRow(actions: supporting);

        if (supporting.isEmpty) {
          return primaryCard;
        }

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primaryCard, const SizedBox(height: 10), secondaryRow],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: primaryCard),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: secondaryRow),
          ],
        );
      },
    );
  }
}

class _PrimaryActionData {
  const _PrimaryActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _SupportingActionData {
  const _SupportingActionData({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _SupportingActionsRow extends StatelessWidget {
  const _SupportingActionsRow({required this.actions});

  final List<_SupportingActionData> actions;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.all(12),
      showShadow: false,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final action in actions)
            OutlinedButton.icon(
              onPressed: action.onTap,
              icon: Icon(action.icon, size: 18),
              label: Text(action.title),
            ),
        ],
      ),
    );
  }
}

/// Grilla de 4 KPIs principales del Home.
class _HomeKpiGrid extends StatelessWidget {
  const _HomeKpiGrid({required this.store, required this.onOpenCash});

  final CommerceStore store;
  final VoidCallback onOpenCash;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasSalesToday = store.todaySalesCount > 0;
    final hasFreeSalesToday = store.movements.any(
      (m) =>
          m.isFreeSale &&
          m.createdAt.year == now.year &&
          m.createdAt.month == now.month &&
          m.createdAt.day == now.day,
    );
    final profitIsReliable = hasSalesToday && !hasFreeSalesToday;
    final difference = store.todayClosingDifferencePesos;
    final differenceValue = difference == null
        ? 'Sin cierre'
        : difference == 0
        ? formatMoney(0)
        : difference < 0
        ? '-${formatMoney(difference.abs())}'
        : '+${formatMoney(difference)}';
    final differenceHelper = difference == null
        ? 'Al cerrar, comparamos contado vs esperado'
        : difference == 0
        ? 'La caja coincide'
        : difference < 0
        ? 'Falta efectivo al cierre'
        : 'Sobra efectivo al cierre';
    final differenceAccent = difference == null
        ? BpcColors.mutedInk
        : difference < 0
        ? BpcColors.expense
        : BpcColors.income;

    final cards = <Widget>[
      KpiCard(
        label: 'Ventas',
        value: formatMoney(store.todaySalesPesos),
        icon: Icons.trending_up_rounded,
        accent: BpcColors.accent,
        helper:
            '${store.todaySalesCount} ${store.todaySalesCount == 1 ? 'venta' : 'ventas'} registradas',
      ),
      KpiCard(
        label: 'Gastos',
        value: formatMoney(store.todayExpensesPesos),
        icon: Icons.south_east_rounded,
        accent: BpcColors.expense,
        helper: store.todayExpensesPesos == 0
            ? 'Sin gastos registrados'
            : 'Salidas de caja de hoy',
      ),
      KpiCard(
        label: 'Caja esperada',
        value: store.todayExpectedCashPesos == null
            ? 'Sin apertura'
            : formatMoney(store.todayExpectedCashPesos!),
        icon: Icons.account_balance_wallet_rounded,
        accent: BpcColors.accentStrong,
        helper: store.todayExpectedCashPesos == null
            ? 'Abrí la caja para ver el saldo'
            : 'Apertura + ventas - gastos',
        onTap: onOpenCash,
      ),
      KpiCard(
        label: 'Diferencia',
        value: differenceValue,
        icon: Icons.balance_rounded,
        accent: differenceAccent,
        helper: differenceHelper,
        onTap: onOpenCash,
      ),
      if (profitIsReliable)
        KpiCard(
          label: 'Ganancia estimada',
          value: formatMoney(store.todayEstimatedProfitPesos),
          icon: Icons.payments_rounded,
          accent: BpcColors.income,
          helper: 'Ventas con costo - gastos de hoy',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? (profitIsReliable ? 5 : 4)
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            ),
            if (!profitIsReliable) ...[
              const SizedBox(height: 10),
              _ProfitReliabilityNote(
                message: !hasSalesToday
                    ? 'Ganancia estimada: aparece cuando registres ventas con costos cargados.'
                    : 'Ganancia estimada: no la mostramos porque hay ventas libres sin costo confiable.',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfitReliabilityNote extends StatelessWidget {
  const _ProfitReliabilityNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BpcColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: BpcColors.mutedInk,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainQuickActionsPanel extends StatelessWidget {
  const _MainQuickActionsPanel({
    required this.onNewSale,
    required this.onNewExpense,
    required this.onOpenProducts,
    required this.onOpenCash,
    required this.isRegisterClosed,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenCash;
  final bool isRegisterClosed;

  static const _closedReason =
      'La caja está cerrada. Abrí una nueva caja para registrar movimientos.';

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _QuickAction(
        title: 'Nueva venta',
        subtitle: isRegisterClosed ? 'Caja cerrada' : 'Registrar una venta',
        icon: Icons.point_of_sale_rounded,
        onTap: isRegisterClosed ? null : onNewSale,
        disabledReason: isRegisterClosed ? _closedReason : null,
      ),
      _QuickAction(
        title: 'Registrar gasto',
        subtitle: isRegisterClosed ? 'Caja cerrada' : 'Anotar una salida',
        icon: Icons.receipt_long_rounded,
        onTap: isRegisterClosed ? null : onNewExpense,
        disabledReason: isRegisterClosed ? _closedReason : null,
      ),
      _QuickAction(
        title: 'Productos',
        subtitle: 'Precios, stock y códigos',
        icon: Icons.inventory_2_rounded,
        onTap: onOpenProducts,
      ),
      _QuickAction(
        title: 'Cierre / resumen',
        subtitle: 'Ver caja y cerrar el día',
        icon: Icons.account_balance_wallet_rounded,
        onTap: onOpenCash,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions) SizedBox(width: width, child: action),
          ],
        );
      },
    );
  }
}

class _SecondaryActionsPanel extends StatelessWidget {
  const _SecondaryActionsPanel({
    required this.onOpenCash,
    required this.onShareDailySummary,
    required this.onExportExcel,
    required this.exportingExcel,
  });

  final VoidCallback onOpenCash;
  final VoidCallback onShareDailySummary;
  final VoidCallback onExportExcel;
  final bool exportingExcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: BpcPanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        showShadow: false,
        color: BpcColors.surfaceStrong,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Más acciones',
              style: theme.textTheme.titleMedium?.copyWith(
                color: BpcColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Historial, reportes y respaldos del día.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SecondaryActionChip(
                  icon: Icons.history_rounded,
                  label: 'Historial',
                  onTap: onOpenCash,
                ),
                _SecondaryActionChip(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reportes',
                  onTap: onOpenCash,
                ),
                _SecondaryActionChip(
                  icon: Icons.ios_share_rounded,
                  label: 'Compartir resumen',
                  onTap: onShareDailySummary,
                ),
                _SecondaryActionChip(
                  icon: Icons.file_download_rounded,
                  label: exportingExcel ? 'Exportando...' : 'Exportar',
                  onTap: exportingExcel ? null : onExportExcel,
                  busy: exportingExcel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionChip extends StatelessWidget {
  const _SecondaryActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.disabledReason,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? disabledReason;

  bool get _disabled => onTap == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = _disabled ? BpcColors.mutedInk : BpcColors.greenDark;
    final titleColor = _disabled ? BpcColors.mutedInk : BpcColors.ink;
    final subtitleColor = _disabled ? BpcColors.mutedInk : BpcColors.subtleInk;

    Widget card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _disabled
                ? BpcColors.surface.withValues(alpha: 0.55)
                : BpcColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BpcColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _disabled ? BpcColors.mutedInk : BpcColors.subtleInk,
              ),
            ],
          ),
        ),
      ),
    );

    if (_disabled && disabledReason != null) {
      card = Tooltip(message: disabledReason!, child: card);
    }
    return card;
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.steps,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final List<String> steps;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      color: BpcColors.surfaceStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BpcColors.greenDark.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: BpcColors.greenDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: BpcColors.greenDark,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        steps[index],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: BpcColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: BpcColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BpcColors.accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BpcColors.accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: BpcColors.accentStrong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hay productos con poco stock',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1
                          ? 'Te falta 1 producto por reponer.'
                          : count > 10
                          ? 'Revisá el stock de tus productos.'
                          : 'Te faltan $count productos por reponer.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BpcColors.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: onTap, child: const Text('Ver productos')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeSaleSuggestionCard extends StatelessWidget {
  const _FreeSaleSuggestionCard({
    required this.suggestion,
    required this.onCreateProduct,
    required this.onDismiss,
  });

  final FreeSaleSuggestion suggestion;
  final VoidCallback onCreateProduct;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BpcPanel(
      color: BpcColors.surfaceStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                color: BpcColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Venta libre repetida',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: BpcColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"${suggestion.displayDescription}" se viene vendiendo seguido. Si querés, podés pasarlo al catálogo sin tocar la historia.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BpcColors.subtleInk,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SuggestionMeta(
                label: 'Se vendió',
                value:
                    '${suggestion.repeatCount} ${suggestion.repeatCount == 1 ? 'vez' : 'veces'}',
              ),
              _SuggestionMeta(
                label: 'Última venta',
                value: formatCompactDateLabel(suggestion.latestSoldAt),
              ),
              _SuggestionMeta(
                label: 'Total vendido',
                value: formatMoney(suggestion.totalRevenuePesos),
              ),
              if (suggestion.latestUnitPricePesos != null)
                _SuggestionMeta(
                  label: 'Último precio',
                  value: formatMoney(suggestion.latestUnitPricePesos!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Crear producto'),
              ),
              TextButton(onPressed: onDismiss, child: const Text('Más tarde')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionMeta extends StatelessWidget {
  const _SuggestionMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BpcColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BpcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CommercialDemoCard extends StatelessWidget {
  const _CommercialDemoCard({
    required this.hasDemoData,
    required this.onCleanCommercialDemo,
    required this.onResetCommercialDemo,
    required this.onResetAllData,
    required this.cleaningCommercialDemo,
    required this.resettingCommercialDemo,
    required this.resettingAllData,
  });

  final bool hasDemoData;
  final VoidCallback onCleanCommercialDemo;
  final VoidCallback onResetCommercialDemo;
  final VoidCallback onResetAllData;
  final bool cleaningCommercialDemo;
  final bool resettingCommercialDemo;
  final bool resettingAllData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: BpcColors.greenDark.withValues(alpha: 0.06),
      borderColor: BpcColors.greenDark.withValues(alpha: 0.14),
      elevated: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Demo comercial',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: BpcColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Volvé al ejemplo inicial para grabar ventas, gastos, caja y Excel desde cero.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BpcColors.subtleInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasDemoData)
                FilledButton.tonalIcon(
                  onPressed: cleaningCommercialDemo
                      ? null
                      : onCleanCommercialDemo,
                  icon: cleaningCommercialDemo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services_rounded),
                  label: Text(
                    cleaningCommercialDemo
                        ? 'Limpiando...'
                        : 'Limpiar datos de demo',
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: resettingCommercialDemo
                      ? null
                      : onResetCommercialDemo,
                  icon: resettingCommercialDemo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt_rounded),
                  label: Text(
                    resettingCommercialDemo
                        ? 'Reiniciando...'
                        : 'Restablecer demo',
                  ),
                ),
              TextButton.icon(
                onPressed: resettingAllData ? null : onResetAllData,
                icon: resettingAllData
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_rounded),
                label: Text(
                  resettingAllData
                      ? 'Restableciendo...'
                      : 'Restablecer Caja Clara',
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 12), actions],
            );
          }

          return Row(
            children: [
              const Icon(
                Icons.video_settings_rounded,
                color: BpcColors.greenDark,
              ),
              const SizedBox(width: 12),
              Expanded(child: copy),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _StarterTemplateCard extends StatelessWidget {
  const _StarterTemplateCard({
    required this.onApplyStarterTemplate,
    required this.onAddProduct,
    required this.onLoadCommercialDemo,
    required this.applyingStarterTemplate,
    required this.loadingCommercialDemo,
  });

  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onAddProduct;
  final VoidCallback? onLoadCommercialDemo;
  final bool applyingStarterTemplate;
  final bool loadingCommercialDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BpcPanel(
      padding: const EdgeInsets.all(18),
      color: BpcColors.surfaceStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arrancá con una base de kiosco',
            style: theme.textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Elegí cómo empezar:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BpcColors.subtleInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            onLoadCommercialDemo == null
                ? 'Cargá productos a mano o usá una base editable para empezar más rápido.'
                : 'Probá con datos de demo: carga productos, ventas, gastos y stock de ejemplo para ver la app funcionando.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BpcColors.subtleInk,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onLoadCommercialDemo != null)
                FilledButton.icon(
                  onPressed: loadingCommercialDemo
                      ? null
                      : onLoadCommercialDemo,
                  icon: loadingCommercialDemo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    loadingCommercialDemo
                        ? 'Cargando demo...'
                        : 'Probá con datos de demo',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: applyingStarterTemplate
                    ? null
                    : onApplyStarterTemplate,
                icon: applyingStarterTemplate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.storefront_rounded),
                label: Text(
                  applyingStarterTemplate
                      ? 'Cargando plantilla...'
                      : 'Cargar $argentinianKioskTemplateName',
                ),
              ),
              TextButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Cargar producto manualmente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
