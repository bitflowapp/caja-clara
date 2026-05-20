import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../services/starter_templates.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../widgets/caja_clara_brand.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/product_form_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onOpenProducts,
    required this.onOpenCash,
    required this.onOpenCashRegister,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.onApplyStarterTemplate,
    required this.onLoadCommercialDemo,
    required this.onCreateProductFromFreeSale,
    required this.onCreateProductFromSuggestion,
    required this.onDismissFreeSaleSuggestion,
    required this.applyingStarterTemplate,
    required this.loadingCommercialDemo,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenCash;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onLoadCommercialDemo;
  final Future<void> Function(Movement movement) onCreateProductFromFreeSale;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onCreateProductFromSuggestion;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onDismissFreeSaleSuggestion;
  final bool applyingStarterTemplate;
  final bool loadingCommercialDemo;

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final recent = store.recentMovements();
        final suggestions = store.freeSaleSuggestions;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeGreeting(now: now),
              const SizedBox(height: 14),
              _CashStatusBanner(
                store: store,
                onOpenCashRegister: onOpenCashRegister,
              ),
              if (!store.hasProducts) ...[
                const SizedBox(height: 14),
                _StarterTemplateCard(
                  onApplyStarterTemplate: onApplyStarterTemplate,
                  onAddProduct: () => showProductEditor(context, store),
                  onLoadCommercialDemo: store.canLoadCommercialDemo
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
              _PrimaryActions(onNewSale: onNewSale),
              const SizedBox(height: 12),
              _QuickActionsPanel(
                onAddProduct: () => showProductEditor(context, store),
                onOpenCash: onOpenCash,
                onNewExpense: onNewExpense,
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
                  title: store.hasProducts
                      ? 'Todavía no registraste ventas hoy'
                      : 'Todavía no cargaste productos',
                  message: store.hasProducts
                      ? 'Cuando registres una venta o un gasto, lo ves acá al instante.'
                      : 'Cargá uno para empezar a vender.',
                  action: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: store.hasProducts
                            ? onNewSale
                            : onApplyStarterTemplate,
                        child: Text(
                          store.hasProducts
                              ? 'Registrar primera venta'
                              : applyingStarterTemplate
                              ? 'Cargando plantilla...'
                              : 'Cargar plantilla kiosco',
                        ),
                      ),
                      TextButton(
                        onPressed: () => showProductEditor(context, store),
                        child: Text(
                          store.hasProducts
                              ? 'Cargar producto'
                              : 'Cargar primer producto',
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

/// Saludo del día con la marca, compacto y cálido.
class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.now});

  final DateTime now;

  String get _greeting {
    final hour = now.hour;
    if (hour < 13) {
      return 'Buen día';
    }
    if (hour < 20) {
      return 'Buenas tardes';
    }
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: BpcColors.greenDeep,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const CajaClaraSymbol(size: 34),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_greeting · ${formatShortDate(now)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BpcColors.subtleInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Caja Clara',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner de estado de caja: guía a abrir la caja antes de vender.
class _CashStatusBanner extends StatelessWidget {
  const _CashStatusBanner({
    required this.store,
    required this.onOpenCashRegister,
  });

  final CommerceStore store;
  final VoidCallback onOpenCashRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = store.hasCashOpeningToday;
    final color = open ? BpcColors.income : BpcColors.warning;
    final opening = store.todayOpeningCashPesos;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              open ? Icons.lock_open_rounded : Icons.savings_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  open ? 'Caja abierta' : 'Todavía no abriste la caja',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  open
                      ? 'Apertura del día: ${formatMoney(opening ?? 0)}.'
                      : 'Primero abrí la caja para empezar a vender.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          open
              ? OutlinedButton(
                  onPressed: onOpenCashRegister,
                  child: const Text('Editar'),
                )
              : FilledButton.icon(
                  onPressed: onOpenCashRegister,
                  icon: const Icon(Icons.savings_rounded, size: 18),
                  label: const Text('Abrir caja'),
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
    final lowStock = store.lowStockCount;
    final cards = <Widget>[
      KpiCard(
        label: 'Ventas de hoy',
        value: formatMoney(store.todaySalesPesos),
        icon: Icons.trending_up_rounded,
        accent: BpcColors.income,
        helper:
            '${store.todaySalesCount} ${store.todaySalesCount == 1 ? 'venta' : 'ventas'} registradas',
      ),
      KpiCard(
        label: 'Caja actual',
        value: formatMoney(store.cashBalancePesos),
        icon: Icons.account_balance_wallet_rounded,
        accent: BpcColors.greenDark,
        helper: 'Lo que tenés ahora',
        onTap: onOpenCash,
      ),
      KpiCard(
        label: 'Stock bajo',
        value: '$lowStock',
        icon: Icons.inventory_2_rounded,
        accent: lowStock == 0 ? BpcColors.mutedInk : BpcColors.warning,
        helper: lowStock == 0
            ? 'Sin productos a reponer'
            : lowStock == 1
            ? '1 producto a reponer'
            : '$lowStock productos a reponer',
      ),
      KpiCard(
        label: 'Gastos del día',
        value: formatMoney(store.todayExpensesPesos),
        icon: Icons.south_east_rounded,
        accent: BpcColors.expense,
        helper: store.todayExpensesPesos == 0
            ? 'Sin gastos registrados'
            : 'Salidas de caja de hoy',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.onNewSale});

  final VoidCallback onNewSale;

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: 'Nueva venta',
      subtitle: 'Vendé en segundos y se actualiza la caja.',
      icon: Icons.shopping_bag_rounded,
      onTap: onNewSale,
      fillColor: BpcColors.greenDark,
      contentColor: Colors.white,
      emphasized: true,
    );
  }
}

/// Accesos rápidos del Home en grilla de tarjetas.
class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.onAddProduct,
    required this.onOpenCash,
    required this.onNewExpense,
    required this.onExportExcel,
    required this.exportingExcel,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onOpenCash;
  final VoidCallback onNewExpense;
  final VoidCallback onExportExcel;
  final bool exportingExcel;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _QuickAction(
        title: 'Cargar producto',
        subtitle: 'Nombre, precio, stock y código',
        icon: Icons.add_box_rounded,
        onTap: onAddProduct,
      ),
      _QuickAction(
        title: 'Registrar gasto',
        subtitle: 'Anotá una salida de la caja',
        icon: Icons.receipt_long_rounded,
        onTap: onNewExpense,
      ),
      _QuickAction(
        title: 'Ver caja del día',
        subtitle: 'Cuánto entró, salió y queda',
        icon: Icons.account_balance_wallet_rounded,
        onTap: onOpenCash,
      ),
      _QuickAction(
        title: 'Exportar Excel',
        subtitle: 'Guardá un respaldo del día',
        icon: Icons.file_download_rounded,
        onTap: exportingExcel ? null : onExportExcel,
        busy: exportingExcel,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(width: width, child: action),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: BpcColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BpcColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BpcColors.greenDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, color: BpcColors.greenDark, size: 22),
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
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BpcColors.subtleInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
            color: BpcColors.warningSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: BpcColors.warning.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: BpcColors.warning,
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
              TextButton(
                onPressed: onTap,
                child: const Text('Ver productos'),
              ),
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
            'Probá con datos de demo: carga productos, ventas, gastos y stock de ejemplo para ver la app funcionando.',
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
