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
                ),
              ],
              const SizedBox(height: 14),
              _PrimaryActions(
                onNewSale: onNewSale,
                onNewExpense: onNewExpense,
                onScanProduct: onScanProduct,
              ),
              const SizedBox(height: 12),
              _SecondaryActions(
                lowStockCount: store.lowStockCount,
                onAddProduct: () => showProductEditor(context, store),
                onOpenLowStock: onOpenProducts,
                onExportExcel: onExportExcel,
                exportingExcel: exportingExcel,
                hasProducts: store.hasProducts,
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
              const SectionHeader(
                title: 'Ultimos movimientos',
                subtitle: 'Todo lo que movio caja y stock, en una sola lista.',
              ),
              const SizedBox(height: 10),
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
                        onPressed: () => showProductEditor(context, store),
                        child: const Text('Agregar producto'),
                      ),
                    ],
                  ),
                )
              else
                BpcPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
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

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: Colors.white.withValues(alpha: 0.82),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BpcColors.greenDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const CajaClaraSymbol(size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja Clara',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoy',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatShortDate(now),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderMetric(
            label: 'Ventas del dia',
            value: formatMoney(store.todaySalesPesos),
          ),
          _HeaderMetric(
            label: 'Caja actual',
            value: formatMoney(store.cashBalancePesos),
          ),
          _HeaderMetric(label: 'Productos', value: '${store.products.length}'),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
            ),
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
    return Column(
      children: [
        ActionCard(
          title: 'Nueva venta',
          subtitle: 'Registra una venta y actualiza caja al instante',
          icon: Icons.shopping_bag_rounded,
          onTap: onNewSale,
          fillColor: Theme.of(context).colorScheme.primary,
          contentColor: Theme.of(context).colorScheme.onPrimary,
          emphasized: true,
        ),
        const SizedBox(height: 12),
        BpcPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white.withValues(alpha: 0.76),
          child: Column(
            children: [
              _InlineActionRow(
                title: 'Registrar gasto',
                subtitle: 'Anota una salida y deja la caja al dia',
                icon: Icons.receipt_long_rounded,
                onTap: onNewExpense,
              ),
              const Divider(height: 1),
              _InlineActionRow(
                title: 'Escanear producto',
                subtitle: 'Camara, scanner o ingreso manual',
                icon: Icons.qr_code_scanner_rounded,
                onTap: onScanProduct,
              ),
            ],
          ),
        ),
      ],
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
    return BpcPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white.withValues(alpha: 0.74),
      child: Column(
        children: [
          _InlineActionRow(
            title: 'Agregar producto',
            subtitle: hasProducts
                ? 'Carga nombre, stock, precio y codigo de barras'
                : 'Empieza a cargar tu catalogo manualmente',
            icon: Icons.add_box_rounded,
            onTap: onAddProduct,
          ),
          const Divider(height: 1),
          _InlineActionRow(
            title: 'Ver stock bajo',
            subtitle: !hasProducts
                ? 'Todavia no hay productos cargados'
                : lowStockCount == 0
                ? 'Sin alertas'
                : '$lowStockCount productos a reponer',
            icon: Icons.warning_amber_rounded,
            onTap: onOpenLowStock,
          ),
          const Divider(height: 1),
          _InlineActionRow(
            title: 'Exportar Excel',
            subtitle: exportingExcel
                ? 'Preparando archivo'
                : hasProducts
                ? 'Lleva ventas, gastos, productos y movimientos'
                : 'Disponible cuando empieces a cargar datos',
            icon: Icons.file_download_rounded,
            onTap: onExportExcel,
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
  });

  final VoidCallback onApplyStarterTemplate;
  final VoidCallback onLoadDemoData;
  final VoidCallback onAddProduct;
  final bool applyingStarterTemplate;
  final bool loadingDemoData;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lista para demo o primer uso',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Puedes mostrar valor en segundos con una demo comercial ya armada o empezar desde una plantilla kiosco editable. Todo queda local en este dispositivo.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _OnboardingStepChip(
                step: '1',
                title: 'Carga datos',
                subtitle: 'Demo comercial o plantilla kiosco',
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

class _InlineActionRow extends StatelessWidget {
  const _InlineActionRow({
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
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
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: BpcColors.mutedInk),
          ],
        ),
      ),
    );
  }
}
