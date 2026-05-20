import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.onExportBackup,
    required this.exportingBackup,
    required this.onRestoreBackup,
    required this.restoringBackup,
    required this.onUndoLastMovement,
    required this.undoingMovement,
    required this.onRegisterCashOpening,
    required this.onRegisterCashClosing,
    required this.savingCashEvent,
    required this.onCreateProductFromFreeSale,
    required this.onCreateProductFromSuggestion,
    required this.onDismissFreeSaleSuggestion,
  });

  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final VoidCallback onExportBackup;
  final bool exportingBackup;
  final VoidCallback onRestoreBackup;
  final bool restoringBackup;
  final VoidCallback onUndoLastMovement;
  final bool undoingMovement;
  final VoidCallback onRegisterCashOpening;
  final VoidCallback onRegisterCashClosing;
  final bool savingCashEvent;
  final Future<void> Function(Movement movement) onCreateProductFromFreeSale;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onCreateProductFromSuggestion;
  final Future<void> Function(FreeSaleSuggestion suggestion)
  onDismissFreeSaleSuggestion;

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final recent = store.recentMovements(10);
        final suggestions = store.freeSaleSuggestions;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Caja del día',
                subtitle: 'Entradas, salidas, saldo y movimientos de hoy',
              ),
              const SizedBox(height: 12),
              BpcPanel(
                padding: const EdgeInsets.all(16),
                color: Colors.white.withValues(alpha: 0.78),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu caja, clara',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final width = wide
                            ? (constraints.maxWidth - 20) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Entró hoy',
                                value: formatMoney(store.todaySalesPesos),
                                helper: 'Ventas registradas',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Salió hoy',
                                value: formatMoney(store.todayExpensesPesos),
                                helper: 'Gastos registrados',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Queda en caja',
                                value: formatMoney(store.cashBalancePesos),
                                helper: 'Lo que tenés ahora',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Movimientos hoy',
                                value: '${store.todayMovementCount}',
                                helper: 'Ventas, gastos y ajustes',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Apertura',
                                value: store.todayOpeningCashPesos == null
                                    ? 'Sin abrir'
                                    : formatMoney(store.todayOpeningCashPesos!),
                                helper: 'Plata inicial del día',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: MetricCard(
                                label: 'Cierre',
                                value: store.todayClosingCashPesos == null
                                    ? 'Sin cierre'
                                    : formatMoney(store.todayClosingCashPesos!),
                                helper:
                                    store.todayClosingDifferencePesos == null
                                    ? 'Caja contada al cierre'
                                    : 'Diferencia: ${formatMoney(store.todayClosingDifferencePesos!)}',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (store.todayOpeningCashPesos != null) ...[
                      const SizedBox(height: 12),
                      _CashFormulaCard(store: store),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: savingCashEvent ? null : onRegisterCashOpening,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      store.hasCashOpeningToday
                          ? 'Editar apertura'
                          : 'Apertura de caja',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: savingCashEvent ? null : onRegisterCashClosing,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      store.hasCashClosingToday
                          ? 'Editar cierre'
                          : 'Cierre de caja',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: exportingExcel ? null : onExportExcel,
                    icon: exportingExcel
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_rounded),
                    label: Text(
                      exportingExcel ? 'Exportando Excel' : 'Exportar Excel',
                    ),
                  ),
                  _CashMoreActionsMenu(
                    store: store,
                    exportingBackup: exportingBackup,
                    restoringBackup: restoringBackup,
                    undoingMovement: undoingMovement,
                    onExportBackup: onExportBackup,
                    onRestoreBackup: onRestoreBackup,
                    onUndoLastMovement: onUndoLastMovement,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (suggestions.isNotEmpty) ...[
                _FreeSaleSuggestionBanner(
                  suggestion: suggestions.first,
                  onCreateProduct: () =>
                      onCreateProductFromSuggestion(suggestions.first),
                  onDismiss: () =>
                      onDismissFreeSaleSuggestion(suggestions.first),
                ),
                const SizedBox(height: 18),
              ],
              const SectionHeader(
                title: 'Movimientos recientes',
                subtitle: 'Lo último que entró y salió de tu caja',
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                const EmptyCard(
                  title: 'Todavía no hay movimientos',
                  message:
                      'Cuando registres una venta o un gasto, lo ves acá al instante.',
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

enum _CashMoreAction { undo, exportBackup, restoreBackup }

class _CashMoreActionsMenu extends StatelessWidget {
  const _CashMoreActionsMenu({
    required this.store,
    required this.exportingBackup,
    required this.restoringBackup,
    required this.undoingMovement,
    required this.onExportBackup,
    required this.onRestoreBackup,
    required this.onUndoLastMovement,
  });

  final CommerceStore store;
  final bool exportingBackup;
  final bool restoringBackup;
  final bool undoingMovement;
  final VoidCallback onExportBackup;
  final VoidCallback onRestoreBackup;
  final VoidCallback onUndoLastMovement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_CashMoreAction>(
      tooltip: 'Más acciones',
      onSelected: (action) {
        switch (action) {
          case _CashMoreAction.undo:
            onUndoLastMovement();
            break;
          case _CashMoreAction.exportBackup:
            onExportBackup();
            break;
          case _CashMoreAction.restoreBackup:
            onRestoreBackup();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CashMoreAction.undo,
          enabled: !undoingMovement && store.canUndoLastMovement,
          child: _CashMenuRow(
            icon: Icons.undo_rounded,
            label: undoingMovement ? 'Deshaciendo' : 'Deshacer último',
          ),
        ),
        PopupMenuItem(
          value: _CashMoreAction.exportBackup,
          enabled: !exportingBackup,
          child: _CashMenuRow(
            icon: Icons.save_alt_rounded,
            label: exportingBackup ? 'Exportando backup' : 'Exportar backup',
          ),
        ),
        PopupMenuItem(
          value: _CashMoreAction.restoreBackup,
          enabled: !restoringBackup,
          child: _CashMenuRow(
            icon: Icons.restore_page_rounded,
            label: restoringBackup ? 'Restaurando' : 'Restaurar backup',
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Más acciones',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashMenuRow extends StatelessWidget {
  const _CashMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(label)],
    );
  }
}

class _CashFormulaCard extends StatelessWidget {
  const _CashFormulaCard({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final opening = store.todayOpeningCashPesos;
    if (opening == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Registrá la apertura del día y vas a ver: saldo inicial + ventas - gastos = caja del día.',
          style: theme.textTheme.bodyMedium?.copyWith(color: outline),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo inicial + ventas - gastos = caja del día',
            style: theme.textTheme.labelLarge?.copyWith(
              color: outline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FormulaChip(label: 'Saldo inicial', value: formatMoney(opening)),
              const Text('+'),
              _FormulaChip(
                label: 'Ventas',
                value: formatMoney(store.todaySalesPesos),
              ),
              const Text('-'),
              _FormulaChip(
                label: 'Gastos',
                value: formatMoney(store.todayExpensesPesos),
              ),
              const Text('='),
              _FormulaChip(
                label: 'Caja del día',
                value: formatMoney(store.todayExpectedCashPesos ?? 0),
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaChip extends StatelessWidget {
  const _FormulaChip({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasized
              ? theme.colorScheme.primary.withValues(alpha: 0.26)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: emphasized ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeSaleSuggestionBanner extends StatelessWidget {
  const _FreeSaleSuggestionBanner({
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sugerencia de catálogo',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '"${suggestion.displayDescription}" se vendió varias veces como venta libre. Podés crear un producto sin tocar esas ventas pasadas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SuggestionMetaChip(
                    label: 'Se vendió',
                    value:
                        '${suggestion.repeatCount} ${suggestion.repeatCount == 1 ? 'vez' : 'veces'}',
                  ),
                  _SuggestionMetaChip(
                    label: 'Última venta',
                    value: formatCompactDateLabel(suggestion.latestSoldAt),
                  ),
                  _SuggestionMetaChip(
                    label: 'Total vendido',
                    value: formatMoney(suggestion.totalRevenuePesos),
                  ),
                  if (suggestion.latestUnitPricePesos != null)
                    _SuggestionMetaChip(
                      label: 'Último precio',
                      value: formatMoney(suggestion.latestUnitPricePesos!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onCreateProduct,
                    icon: const Icon(Icons.add_box_rounded),
                    label: const Text('Crear producto'),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Más tarde'),
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                content,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _SuggestionMetaChip extends StatelessWidget {
  const _SuggestionMetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.outline,
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
