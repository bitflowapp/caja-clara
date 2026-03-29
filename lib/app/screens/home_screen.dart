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
    required this.onRegisterCashOpening,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onScanProduct,
    required this.onOpenProducts,
    required this.onExportExcel,
    required this.onApplyStarterTemplate,
    required this.onLoadDemoData,
    required this.onCreateProductFromFreeSale,
    required this.onCreateProductFromSuggestion,
    required this.onDismissFreeSaleSuggestion,
    required this.exportingExcel,
    required this.applyingStarterTemplate,
    required this.loadingDemoData,
    required this.hasCashOpeningToday,
    required this.savingCashEvent,
  });

  final VoidCallback onRegisterCashOpening;
  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onScanProduct;
  final VoidCallback onOpenProducts;
  final VoidCallback onExportExcel;
  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onLoadDemoData;
  final Future<void> Function(Movement movement) onCreateProductFromFreeSale;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onCreateProductFromSuggestion;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onDismissFreeSaleSuggestion;
  final bool exportingExcel;
  final bool applyingStarterTemplate;
  final bool loadingDemoData;
  final bool hasCashOpeningToday;
  final bool savingCashEvent;

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
              _ActionWorkspace(
                onRegisterCashOpening: onRegisterCashOpening,
                onNewSale: onNewSale,
                onNewExpense: onNewExpense,
                onScanProduct: onScanProduct,
                lowStockCount: store.lowStockCount,
                onAddProduct: () => showProductEditor(context, store),
                onOpenLowStock: onOpenProducts,
                onExportExcel: onExportExcel,
                exportingExcel: exportingExcel,
                hasProducts: store.hasProducts,
                hasCashOpeningToday: hasCashOpeningToday,
                savingCashEvent: savingCashEvent,
              ),
              if (!store.hasProducts) ...[
                const SizedBox(height: 14),
                _StarterTemplateCard(
                  onApplyStarterTemplate: onApplyStarterTemplate,
                  onLoadDemoData: onLoadDemoData,
                  onAddProduct: () => showProductEditor(context, store),
                  applyingStarterTemplate: applyingStarterTemplate,
                  loadingDemoData: loadingDemoData,
                  canLoadDemoData: store.isEmptyState,
                  hasMovements: store.hasMovements,
                ),
              ],
              const SizedBox(height: 16),
              _HeaderStrip(now: now, store: store),
              if (store.hasProducts) ...[
                const SizedBox(height: 16),
                _CatalogReadinessCard(store: store),
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
              const SizedBox(height: 16),
              _HomeMovementsPanel(
                store: store,
                recent: recent,
                applyingStarterTemplate: applyingStarterTemplate,
                onNewSale: onNewSale,
                onApplyStarterTemplate: onApplyStarterTemplate,
                onAddProduct: () => showProductEditor(context, store),
                onCreateProductFromFreeSale: onCreateProductFromFreeSale,
              ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
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
    return BpcPanel(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venta libre repetida',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"${suggestion.displayDescription}" se viene vendiendo seguido. Si quieres, puedes pasarlo al catalogo sin tocar la historia.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SuggestionMeta(
                label: 'Se vendio',
                value:
                    '${suggestion.repeatCount} ${suggestion.repeatCount == 1 ? 'vez' : 'veces'}',
              ),
              _SuggestionMeta(
                label: 'Ultima venta',
                value: formatCompactDateLabel(suggestion.latestSoldAt),
              ),
              _SuggestionMeta(
                label: 'Total vendido',
                value: formatMoney(suggestion.totalRevenuePesos),
              ),
              if (suggestion.latestUnitPricePesos != null)
                _SuggestionMeta(
                  label: 'Ultimo precio',
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
              TextButton(onPressed: onDismiss, child: const Text('Mas tarde')),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 168),
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

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.now, required this.store});

  final DateTime now;
  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusChips = [
      _HomeStatusChip(
        label: store.hasCashOpeningToday ? 'Caja abierta' : 'Abrir caja',
        color: store.hasCashOpeningToday
            ? BpcColors.income
            : Theme.of(context).colorScheme.error,
        icon: store.hasCashOpeningToday
            ? Icons.verified_outlined
            : Icons.login_rounded,
      ),
      _HomeStatusChip(
        label: store.lowStockCount == 0
            ? 'Stock al dia'
            : '${store.lowStockCount} con alerta',
        color: store.lowStockCount == 0
            ? BpcColors.greenSoft
            : BpcColors.sandMuted,
        icon: store.lowStockCount == 0
            ? Icons.inventory_2_outlined
            : Icons.warning_amber_rounded,
      ),
      _HomeStatusChip(
        label: store.productsWithBarcodeCount == 0
            ? 'Sin codigos'
            : '${store.productsWithBarcodeCount} con codigo',
        color: store.productsWithBarcodeCount == 0
            ? BpcColors.sandMuted
            : BpcColors.greenSoft,
        icon: Icons.qr_code_2_rounded,
      ),
    ];
    final metrics = [
      _WorkspaceMetric(
        label: 'Ventas del dia',
        value: formatMoney(store.todaySalesPesos),
        helper: '${store.todayMovementCount} movimientos del dia',
      ),
      _WorkspaceMetric(
        label: 'Caja actual',
        value: formatMoney(store.cashBalancePesos),
        helper: store.hasCashOpeningToday
            ? 'Caja en marcha'
            : 'Conviene abrir caja',
      ),
      _WorkspaceMetric(
        label: 'Productos',
        value: '${store.products.length}',
        helper: '${store.sellableProductsCount} listos para vender',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final brandCard = Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: BpcColors.greenDeep,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: BpcColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const CajaClaraSmallMark(size: 34),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caja Clara',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mostrador al dia',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                formatShortDate(now),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ventas, caja, stock y codigos en un solo lugar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: statusChips),
            ],
          ),
        );

        final metricsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoy en un vistazo',
              style: theme.textTheme.labelLarge?.copyWith(
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < metrics.length; index++)
              _WorkspaceMetricCard(
                metric: metrics[index],
                showDivider: index != 0,
              ),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [brandCard, const SizedBox(height: 18), metricsColumn],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: brandCard),
            const SizedBox(width: 28),
            Expanded(flex: 4, child: metricsColumn),
          ],
        );
      },
    );
  }
}

class _HomeStatusChip extends StatelessWidget {
  const _HomeStatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMetric {
  const _WorkspaceMetric({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;
}

class _WorkspaceMetricCard extends StatelessWidget {
  const _WorkspaceMetricCard({required this.metric, this.showDivider = true});

  final _WorkspaceMetric metric;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: BpcColors.line))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionWorkspace extends StatelessWidget {
  const _ActionWorkspace({
    required this.onRegisterCashOpening,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onScanProduct,
    required this.lowStockCount,
    required this.onAddProduct,
    required this.onOpenLowStock,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.hasProducts,
    required this.hasCashOpeningToday,
    required this.savingCashEvent,
  });

  final VoidCallback onRegisterCashOpening;
  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onScanProduct;
  final int lowStockCount;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenLowStock;
  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final bool hasProducts;
  final bool hasCashOpeningToday;
  final bool savingCashEvent;

  @override
  Widget build(BuildContext context) {
    final primaryOpenCash = ActionCard(
      title: savingCashEvent
          ? 'Guardando apertura'
          : hasCashOpeningToday
          ? 'Editar apertura'
          : 'Abrir caja',
      subtitle: hasCashOpeningToday
          ? 'La caja ya esta abierta. Ajusta el efectivo inicial si hace falta.'
          : 'Marca el efectivo inicial del dia antes de empezar a cobrar.',
      icon: hasCashOpeningToday ? Icons.edit_note_rounded : Icons.login_rounded,
      onTap: onRegisterCashOpening,
    );
    final primaryNewSale = ActionCard(
      title: 'Nueva venta',
      subtitle: hasProducts
          ? 'Elige producto, marca el cobro y registra en tres pasos.'
          : 'Puedes vender en cuanto cargues el primer producto o usar venta libre.',
      icon: Icons.shopping_bag_rounded,
      onTap: onNewSale,
      fillColor: Theme.of(context).colorScheme.primary,
      contentColor: Theme.of(context).colorScheme.onPrimary,
      emphasized: true,
    );
    final primaryAddProduct = ActionCard(
      title: 'Agregar producto',
      subtitle: hasProducts
          ? 'Carga nombre, precio y stock en lo basico. El resto es opcional.'
          : 'Empieza el catalogo con nombre, precio y stock.',
      icon: Icons.add_box_rounded,
      onTap: onAddProduct,
    );
    final secondaryActions = [
      _ActionShortcut(
        title: 'Registrar gasto',
        subtitle: 'Anota una salida y deja la caja del dia clara',
        icon: Icons.receipt_long_rounded,
        onTap: onNewExpense,
      ),
      _ActionShortcut(
        title: 'Escanear producto',
        subtitle: 'Camara, lector o codigo manual',
        icon: Icons.qr_code_scanner_rounded,
        onTap: onScanProduct,
      ),
      _ActionShortcut(
        title: 'Ver stock bajo',
        subtitle: !hasProducts
            ? 'Todavia no hay productos cargados'
            : lowStockCount == 0
            ? 'Sin alertas de reposicion'
            : '$lowStockCount productos a reponer',
        icon: Icons.warning_amber_rounded,
        onTap: onOpenLowStock,
      ),
      _ActionShortcut(
        title: 'Exportar Excel',
        subtitle: exportingExcel
            ? 'Preparando archivo'
            : hasProducts
            ? 'Lleva ventas, gastos y productos a un archivo'
            : 'Disponible cuando empieces a cargar datos',
        icon: Icons.file_download_rounded,
        onTap: onExportExcel,
      ),
    ];

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      color: Colors.white.withValues(alpha: 0.8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final shortcuts = _ActionShortcutGroup(
            title: 'Tambien puedes',
            actions: secondaryActions,
          );

          final primaryActions = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: primaryNewSale),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: primaryOpenCash),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: primaryAddProduct),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primaryNewSale,
                    const SizedBox(height: 12),
                    primaryOpenCash,
                    const SizedBox(height: 12),
                    primaryAddProduct,
                  ],
                );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Empieza por aca',
                  subtitle:
                      'Primero caja, venta y catalogo. Lo demas queda a mano mas abajo.',
                ),
                const SizedBox(height: 16),
                primaryActions,
                const SizedBox(height: 18),
                shortcuts,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Empieza por aca',
                subtitle:
                    'Primero caja, venta y catalogo. Despues revisa stock, gastos y salida.',
              ),
              const SizedBox(height: 16),
              primaryActions,
              const SizedBox(height: 18),
              shortcuts,
            ],
          );
        },
      ),
    );
  }
}

class _ActionShortcut {
  const _ActionShortcut({
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

class _ActionShortcutGroup extends StatelessWidget {
  const _ActionShortcutGroup({required this.title, required this.actions});

  final String title;
  final List<_ActionShortcut> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: BpcColors.mutedInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < actions.length; index++)
          _ActionShortcutRow(action: actions[index], showDivider: index != 0),
      ],
    );
  }
}

class _ActionShortcutRow extends StatelessWidget {
  const _ActionShortcutRow({required this.action, this.showDivider = true});

  final _ActionShortcut action;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(top: BorderSide(color: BpcColors.line))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  action.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BpcColors.subtleInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: BpcColors.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMovementsPanel extends StatelessWidget {
  const _HomeMovementsPanel({
    required this.store,
    required this.recent,
    required this.applyingStarterTemplate,
    required this.onNewSale,
    required this.onApplyStarterTemplate,
    required this.onAddProduct,
    required this.onCreateProductFromFreeSale,
  });

  final CommerceStore store;
  final List<Movement> recent;
  final bool applyingStarterTemplate;
  final VoidCallback onNewSale;
  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onAddProduct;
  final Future<void> Function(Movement movement) onCreateProductFromFreeSale;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.white.withValues(alpha: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Ultimos movimientos',
            subtitle: 'Todo lo que movio caja y stock, en una sola lista.',
            trailing: Text(
              recent.isEmpty ? 'Sin actividad' : '${recent.length} recientes',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BpcColors.mutedInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(
              title: store.hasProducts
                  ? 'Todavia no registraste movimientos'
                  : 'Arranca con lo basico',
              message: store.hasProducts
                  ? 'Empieza con una venta o un gasto. Todo queda guardado en esta PC.'
                  : 'Puedes cargar una base simple o agregar tus primeros productos a mano.',
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
                          ? 'Nueva venta'
                          : applyingStarterTemplate
                          ? 'Cargando plantilla...'
                          : 'Cargar plantilla kiosco',
                    ),
                  ),
                  TextButton(
                    onPressed: onAddProduct,
                    child: const Text('Agregar producto'),
                  ),
                ],
              ),
              framed: false,
            )
          else
            Column(
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
        ],
      ),
    );
  }
}

class _StarterTemplateCard extends StatelessWidget {
  const _StarterTemplateCard({
    required this.onApplyStarterTemplate,
    required this.onLoadDemoData,
    required this.onAddProduct,
    required this.applyingStarterTemplate,
    required this.loadingDemoData,
    required this.canLoadDemoData,
    required this.hasMovements,
  });

  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onLoadDemoData;
  final VoidCallback onAddProduct;
  final bool applyingStarterTemplate;
  final bool loadingDemoData;
  final bool canLoadDemoData;
  final bool hasMovements;

  @override
  Widget build(BuildContext context) {
    final title = canLoadDemoData
        ? 'Primeros pasos'
        : 'Falta completar tu catalogo base';
    final message = canLoadDemoData
        ? 'Puedes arrancar con una base simple del kiosco o abrir un ejemplo corto para recorrer la app sin tocar tus datos.'
        : hasMovements
        ? 'Ya hay movimientos guardados en esta PC, asi que conviene sumar catalogo real sin tocar ese historial.'
        : 'Conviene sumar catalogo real con una plantilla simple o alta manual para empezar a vender sin vueltas.';
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerLow.withValues(alpha: 0.82),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: message),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _OnboardingStepChip(
                step: '1',
                title: 'Abri caja',
                subtitle: 'Marca el efectivo inicial del dia',
              ),
              _OnboardingStepChip(
                step: '2',
                title: 'Agrega un producto',
                subtitle: 'Nombre, precio y stock basico',
              ),
              _OnboardingStepChip(
                step: '3',
                title: 'Hace una venta',
                subtitle: 'Elige medio de pago y guarda',
              ),
              _OnboardingStepChip(
                step: '4',
                title: 'Listo',
                subtitle: 'Caja y movimientos al dia',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canLoadDemoData)
                FilledButton.icon(
                  onPressed: loadingDemoData || applyingStarterTemplate
                      ? null
                      : onLoadDemoData,
                  icon: loadingDemoData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_rounded),
                  label: Text(
                    loadingDemoData ? 'Cargando ejemplo...' : 'Ver ejemplo',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: applyingStarterTemplate || loadingDemoData
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
                label: const Text('Agregar producto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepChip extends StatelessWidget {
  const _OnboardingStepChip({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 230),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: BpcColors.greenDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogReadinessCard extends StatelessWidget {
  const _CatalogReadinessCard({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: BpcColors.line),
          bottom: BorderSide(color: BpcColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Catalogo listo para vender',
            subtitle:
                'Estas senales te muestran rapido si hay precio, stock y codigos para trabajar sin sorpresas.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _SuggestionMeta(
                label: 'Listos para vender',
                value: '${store.sellableProductsCount}',
              ),
              _SuggestionMeta(
                label: 'Con codigo',
                value:
                    '${store.productsWithBarcodeCount}/${store.products.length}',
              ),
              _SuggestionMeta(
                label: 'Stock invertido',
                value: formatMoney(store.estimatedInventoryCostPesos),
              ),
              _SuggestionMeta(
                label: 'Alertas de stock',
                value: '${store.lowStockCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
