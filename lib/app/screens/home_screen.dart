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
  });

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
              _HeaderStrip(now: now, store: store),
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
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final primary = _PrimaryActions(
                    onNewSale: onNewSale,
                    onNewExpense: onNewExpense,
                    onScanProduct: onScanProduct,
                  );
                  final secondary = _SecondaryActions(
                    lowStockCount: store.lowStockCount,
                    onAddProduct: () => showProductEditor(context, store),
                    onOpenLowStock: onOpenProducts,
                    onExportExcel: onExportExcel,
                    exportingExcel: exportingExcel,
                    hasProducts: store.hasProducts,
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        primary,
                        const SizedBox(height: 12),
                        secondary,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: primary),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: secondary),
                    ],
                  );
                },
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
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

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.now, required this.store});

  final DateTime now;
  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusChips = [
      _HomeStatusChip(
        label: store.hasCashOpeningToday ? 'Caja abierta' : 'Sin apertura',
        color: store.hasCashOpeningToday
            ? BpcColors.income
            : Theme.of(context).colorScheme.error,
        icon: store.hasCashOpeningToday
            ? Icons.verified_outlined
            : Icons.login_rounded,
      ),
      _HomeStatusChip(
        label: store.lowStockCount == 0
            ? 'Stock estable'
            : '${store.lowStockCount} alertas',
        color: store.lowStockCount == 0
            ? BpcColors.greenSoft
            : BpcColors.sandMuted,
        icon: store.lowStockCount == 0
            ? Icons.inventory_2_outlined
            : Icons.warning_amber_rounded,
      ),
      _HomeStatusChip(
        label: store.productsWithBarcodeCount == 0
            ? 'Barcode pendiente'
            : '${store.productsWithBarcodeCount} con barcode',
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
        helper: '${store.todayMovementCount} movimientos hoy',
      ),
      _WorkspaceMetric(
        label: 'Caja actual',
        value: formatMoney(store.cashBalancePesos),
        helper: store.hasCashOpeningToday
            ? 'Control en curso'
            : 'Conviene registrar apertura',
      ),
      _WorkspaceMetric(
        label: 'Productos',
        value: '${store.products.length}',
        helper: '${store.sellableProductsCount} listos para vender',
      ),
    ];

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      color: Colors.white.withValues(alpha: 0.82),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final brandCard = Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: BpcColors.greenDeep,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const CajaClaraSymbol(size: 30),
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
                          'Panel de trabajo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  formatShortDate(now),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ventas, caja, stock y barcode en un mismo espacio operativo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: statusChips),
              ],
            ),
          );

          final metricWrap = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map((metric) => _WorkspaceMetricCard(metric: metric))
                .toList(growable: false),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [brandCard, const SizedBox(height: 14), metricWrap],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: brandCard),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: metricWrap),
            ],
          );
        },
      ),
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
  const _WorkspaceMetricCard({required this.metric});

  final _WorkspaceMetric metric;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: BpcColors.surfaceStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BpcColors.line),
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
            const SizedBox(height: 8),
            Text(
              metric.value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: BpcColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metric.helper,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BpcColors.subtleInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSupportCard extends StatelessWidget {
  const _ActionSupportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: BpcPanel(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          color: Colors.white.withValues(alpha: 0.78),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BpcColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BpcColors.surfaceStrong,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: BpcColors.line),
              ),
              child: Text(
                recent.isEmpty ? 'Sin actividad' : '${recent.length} recientes',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: BpcColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(
              title: store.hasProducts
                  ? 'Todavia no registraste movimientos'
                  : 'Arranca cargando tu negocio',
              message: store.hasProducts
                  ? 'Empieza con una venta o un gasto. Todo queda guardado en este dispositivo.'
                  : 'Puedes cargar la plantilla kiosco para empezar en minutos o crear tus primeros productos a mano.',
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

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onNewSale,
    required this.onNewExpense,
    required this.onScanProduct,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onScanProduct;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final primary = ActionCard(
          title: 'Nueva venta',
          subtitle: 'Registra una venta y actualiza caja al instante',
          icon: Icons.shopping_bag_rounded,
          onTap: onNewSale,
          fillColor: Theme.of(context).colorScheme.primary,
          contentColor: Theme.of(context).colorScheme.onPrimary,
          emphasized: true,
        );
        final support = Column(
          children: [
            _ActionSupportCard(
              title: 'Registrar gasto',
              subtitle: 'Anota una salida y deja la caja al dia',
              icon: Icons.receipt_long_rounded,
              onTap: onNewExpense,
            ),
            const SizedBox(height: 12),
            _ActionSupportCard(
              title: 'Escanear producto',
              subtitle: 'Camara, scanner o ingreso manual',
              icon: Icons.qr_code_scanner_rounded,
              onTap: onScanProduct,
            ),
          ],
        );

        if (!wide) {
          return Column(
            children: [primary, const SizedBox(height: 12), support],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: primary),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: support),
          ],
        );
      },
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.lowStockCount,
    required this.onAddProduct,
    required this.onOpenLowStock,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.hasProducts,
  });

  final int lowStockCount;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenLowStock;
  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final bool hasProducts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final spacing = 12.0;
        final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
        final cardWidth = (constraints.maxWidth - totalGap) / columns;
        final cards = [
          _ActionSupportCard(
            title: 'Agregar producto',
            subtitle: hasProducts
                ? 'Carga nombre, stock, precio y codigo de barras'
                : 'Empieza a cargar tu catalogo manualmente',
            icon: Icons.add_box_rounded,
            onTap: onAddProduct,
          ),
          _ActionSupportCard(
            title: 'Ver stock bajo',
            subtitle: !hasProducts
                ? 'Todavia no hay productos cargados'
                : lowStockCount == 0
                ? 'Sin alertas de reposicion'
                : '$lowStockCount productos a reponer',
            icon: Icons.warning_amber_rounded,
            onTap: onOpenLowStock,
          ),
          _ActionSupportCard(
            title: 'Exportar Excel',
            subtitle: exportingExcel
                ? 'Preparando archivo'
                : hasProducts
                ? 'Lleva ventas, gastos, productos y movimientos'
                : 'Disponible cuando empieces a cargar datos',
            icon: Icons.file_download_rounded,
            onTap: onExportExcel,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : cardWidth,
                  child: card,
                ),
              )
              .toList(growable: false),
        );
      },
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
        ? 'Lista para demo o primer uso'
        : 'Falta resolver el catalogo base';
    final message = canLoadDemoData
        ? 'Puedes mostrar valor en segundos con una demo comercial ya armada o empezar desde una plantilla kiosco editable. Todo queda local en este dispositivo.'
        : hasMovements
        ? 'Ya hay movimientos guardados en este dispositivo, asi que la demo comercial no corresponde sobre este estado. Conviene sumar catalogo real con una plantilla o alta manual.'
        : 'Conviene sumar catalogo real con una plantilla editable o alta manual para empezar a vender sin estados ambiguos.';
    final firstStepSubtitle = canLoadDemoData
        ? 'Demo comercial o plantilla kiosco'
        : 'Plantilla kiosco o alta manual';
    return BpcPanel(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OnboardingStepChip(
                step: '1',
                title: 'Carga datos',
                subtitle: firstStepSubtitle,
              ),
              _OnboardingStepChip(
                step: '2',
                title: 'Registra una venta',
                subtitle: 'Caja y stock se actualizan al instante',
              ),
              _OnboardingStepChip(
                step: '3',
                title: 'Muestra control',
                subtitle: 'Caja, backup y export en el mismo flujo',
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
                    loadingDemoData
                        ? 'Cargando demo...'
                        : 'Cargar demo comercial',
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
                label: const Text('Agregar producto manualmente'),
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
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BpcColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: BpcColors.greenDeep,
                borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }
}

class _CatalogReadinessCard extends StatelessWidget {
  const _CatalogReadinessCard({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      color: Colors.white.withValues(alpha: 0.76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catalogo listo para demo y operacion',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estas senales ayudan a mostrar control rapido: productos vendibles, cobertura de barcode y capital inmovilizado en stock.',
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
                label: 'Listos para vender',
                value: '${store.sellableProductsCount}',
              ),
              _SuggestionMeta(
                label: 'Con barcode',
                value:
                    '${store.productsWithBarcodeCount}/${store.products.length}',
              ),
              _SuggestionMeta(
                label: 'Stock valorizado',
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
