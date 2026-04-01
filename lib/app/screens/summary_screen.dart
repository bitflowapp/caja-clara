import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../theme/bpc_colors.dart';
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
              _SummaryWorkspaceDeck(
                store: store,
                onExportExcel: onExportExcel,
                exportingExcel: exportingExcel,
                onExportBackup: onExportBackup,
                exportingBackup: exportingBackup,
                onRestoreBackup: onRestoreBackup,
                restoringBackup: restoringBackup,
                onUndoLastMovement: onUndoLastMovement,
                undoingMovement: undoingMovement,
                onRegisterCashOpening: onRegisterCashOpening,
                onRegisterCashClosing: onRegisterCashClosing,
                savingCashEvent: savingCashEvent,
              ),
              const SizedBox(height: 16),
              _SummaryMetricsDeck(store: store),
              const SizedBox(height: 18),
              _OwnerSignalsDeck(store: store),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                _FreeSaleSuggestionBanner(
                  suggestion: suggestions.first,
                  onCreateProduct: () =>
                      onCreateProductFromSuggestion(suggestions.first),
                  onDismiss: () =>
                      onDismissFreeSaleSuggestion(suggestions.first),
                ),
              ],
              const SizedBox(height: 18),
              _SummaryMovementsPanel(
                store: store,
                recent: recent,
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

class _SummaryWorkspaceDeck extends StatelessWidget {
  const _SummaryWorkspaceDeck({
    required this.store,
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
  });

  final CommerceStore store;
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

  @override
  Widget build(BuildContext context) {
    final primaryCommand = _SummaryCommand(
      title: exportingExcel ? 'Exportando Excel' : 'Exportar Excel',
      subtitle: 'Llevar ventas, productos y movimientos',
      icon: Icons.file_download_rounded,
      onTap: exportingExcel ? null : onExportExcel,
      emphasized: true,
      loading: exportingExcel,
    );
    final backupActions = [
      _SummaryCommand(
        title: exportingBackup ? 'Guardando respaldo' : 'Guardar respaldo',
        subtitle: 'Guardar una copia completa de la app',
        icon: Icons.save_alt_rounded,
        onTap: exportingBackup ? null : onExportBackup,
        loading: exportingBackup,
      ),
      _SummaryCommand(
        title: restoringBackup ? 'Restaurando respaldo' : 'Restaurar respaldo',
        subtitle: 'Recuperar una copia anterior',
        icon: Icons.restore_page_rounded,
        onTap: restoringBackup ? null : onRestoreBackup,
        loading: restoringBackup,
      ),
    ];
    final cashActions = [
      _SummaryCommand(
        title: undoingMovement ? 'Deshaciendo' : 'Deshacer ultimo',
        subtitle: store.canUndoLastMovement
            ? 'Volver atras el ultimo movimiento guardado'
            : 'No hay movimientos reversibles',
        icon: Icons.undo_rounded,
        onTap: undoingMovement || !store.canUndoLastMovement
            ? null
            : onUndoLastMovement,
        loading: undoingMovement,
      ),
      _SummaryCommand(
        title: store.hasCashOpeningToday ? 'Editar apertura' : 'Abrir caja',
        subtitle: 'Registrar el efectivo inicial del dia',
        icon: Icons.login_rounded,
        onTap: savingCashEvent ? null : onRegisterCashOpening,
      ),
      _SummaryCommand(
        title: store.hasCashClosingToday ? 'Editar cierre' : 'Cerrar caja',
        subtitle: 'Comparar lo contado con lo esperado',
        icon: Icons.logout_rounded,
        onTap: savingCashEvent ? null : onRegisterCashClosing,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final commandHub = _SummaryCommandHub(
          primaryCommand: primaryCommand,
          backupActions: backupActions,
          cashActions: cashActions,
        );
        final snapshot = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Caja del dia',
              subtitle: 'Apertura, cierre y respaldo en el mismo lugar',
              trailing: _SectionCountLabel(
                label: store.todayMovementCount == 0
                    ? 'Sin actividad'
                    : '${store.todayMovementCount} movimientos hoy',
              ),
            ),
            const SizedBox(height: 12),
            _OperationalSnapshotBanner(store: store),
            const SizedBox(height: 12),
            const _DataConfidenceNote(),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [snapshot, const SizedBox(height: 16), commandHub],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: snapshot),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: commandHub),
          ],
        );
      },
    );
  }
}

class _SummaryCommandHub extends StatelessWidget {
  const _SummaryCommandHub({
    required this.primaryCommand,
    required this.backupActions,
    required this.cashActions,
  });

  final _SummaryCommand primaryCommand;
  final List<_SummaryCommand> backupActions;
  final List<_SummaryCommand> cashActions;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      color: Colors.white.withValues(alpha: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Acciones de caja',
            subtitle:
                'Exporta, respalda y corrige desde una sola zona de trabajo.',
          ),
          const SizedBox(height: 16),
          _SummaryCommandRow(command: primaryCommand),
          const SizedBox(height: 18),
          _SummaryCommandGroup(title: 'Resguardo', commands: backupActions),
          const SizedBox(height: 20),
          _SummaryCommandGroup(title: 'Operativa', commands: cashActions),
        ],
      ),
    );
  }
}

class _SummaryCommand {
  const _SummaryCommand({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool emphasized;
}

class _SummaryCommandGroup extends StatelessWidget {
  const _SummaryCommandGroup({required this.title, required this.commands});

  final String title;
  final List<_SummaryCommand> commands;

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
        for (var index = 0; index < commands.length; index++)
          _SummaryCommandRow(command: commands[index], showDivider: index != 0),
      ],
    );
  }
}

class _SummaryCommandRow extends StatelessWidget {
  const _SummaryCommandRow({required this.command, this.showDivider = false});

  final _SummaryCommand command;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = command.onTap != null;
    final iconColor = command.emphasized ? Colors.white : primary;
    final titleColor = command.emphasized
        ? Colors.white
        : enabled
        ? BpcColors.ink
        : BpcColors.subtleInk;
    final subtitleColor = command.emphasized
        ? Colors.white.withValues(alpha: 0.82)
        : BpcColors.subtleInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: command.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            0,
            command.emphasized ? 16 : 12,
            0,
            command.emphasized ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: command.emphasized ? primary : Colors.transparent,
            borderRadius: command.emphasized
                ? BorderRadius.circular(20)
                : BorderRadius.circular(16),
            border: showDivider
                ? Border(top: BorderSide(color: BpcColors.line))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: command.emphasized
                      ? Colors.white.withValues(alpha: 0.14)
                      : primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: command.loading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(command.icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      command.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: titleColor.withValues(alpha: enabled ? 1 : 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricsDeck extends StatelessWidget {
  const _SummaryMetricsDeck({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final cashState = _MetricGroupPanel(
          title: 'Estado de caja',
          subtitle: 'Lo justo para abrir, cobrar y cerrar con control.',
          metrics: [
            MetricCard(
              label: 'Caja total',
              value: formatMoney(store.cashBalancePesos),
              helper: 'Saldo total registrado',
              framed: false,
            ),
            MetricCard(
              label: 'Apertura',
              value: store.todayOpeningCashPesos == null
                  ? 'Sin abrir'
                  : formatMoney(store.todayOpeningCashPesos!),
              helper: 'Efectivo inicial del dia',
              framed: false,
            ),
            MetricCard(
              label: 'Caja esperada',
              value: store.todayExpectedCashPesos == null
                  ? 'Sin apertura'
                  : formatMoney(store.todayExpectedCashPesos!),
              helper: 'Apertura + ventas - gastos',
              framed: false,
            ),
            MetricCard(
              label: 'Cierre contado',
              value: store.todayClosingCashPesos == null
                  ? 'Sin cierre'
                  : formatMoney(store.todayClosingCashPesos!),
              helper: store.todayClosingDifferencePesos == null
                  ? 'Monto contado al cierre'
                  : 'Diferencia: ${formatMoney(store.todayClosingDifferencePesos!)}',
              framed: false,
            ),
          ],
        );
        final operations = _MetricGroupPanel(
          title: 'Actividad del dia',
          subtitle: 'Ventas, gastos y una foto clara del movimiento.',
          metrics: [
            MetricCard(
              label: 'Ventas del dia',
              value: formatMoney(store.todaySalesPesos),
              helper: 'Ingresos de hoy',
              accentColor: BpcColors.greenSoft.withValues(alpha: 0.18),
              framed: false,
            ),
            MetricCard(
              label: 'Gastos del dia',
              value: formatMoney(store.todayExpensesPesos),
              helper: 'Egresos de hoy',
              accentColor: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.42),
              framed: false,
            ),
            MetricCard(
              label: 'Movimientos hoy',
              value: '${store.todayMovementCount}',
              helper: 'Ventas, gastos y ajustes',
              framed: false,
            ),
            MetricCard(
              label: 'Ganancia estimada',
              value: formatMoney(store.todayEstimatedProfitPesos),
              helper: 'Ventas menos costo estimado',
              framed: false,
            ),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Resumen de caja',
                subtitle:
                    'Una vista clara del dia con formula, caja esperada y movimiento real.',
              ),
              const SizedBox(height: 12),
              _CashFormulaCard(store: store),
              const SizedBox(height: 18),
              cashState,
              const SizedBox(height: 18),
              operations,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Resumen de caja',
              subtitle:
                  'Una vista clara del dia con formula, caja esperada y movimiento real.',
            ),
            const SizedBox(height: 12),
            _CashFormulaCard(store: store),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cashState),
                const SizedBox(width: 28),
                Expanded(child: operations),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricGroupPanel extends StatelessWidget {
  const _MetricGroupPanel({
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: BpcColors.line)),
      ),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              final spacing = 18.0;
              final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
              final itemWidth = (constraints.maxWidth - totalGap) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: columns == 1 ? constraints.maxWidth : itemWidth,
                        child: metric,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OwnerSignalsDeck extends StatelessWidget {
  const _OwnerSignalsDeck({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final daily = store.dailyMovementSummary();
    final topSelling = store.topSellingProductsToday();
    final urgentRestock = store.urgentRestockProducts();
    final lowRotation = store.lowRotationProducts();
    final focusItems = _buildOwnerFocusItems(
      store,
      daily: daily,
      topSelling: topSelling,
      urgentRestock: urgentRestock,
      lowRotation: lowRotation,
    );
    final shareSummary = _buildDailyShareSummary(
      focusItems: focusItems,
      daily: daily,
      topSelling: topSelling,
      urgentRestock: urgentRestock,
      lowRotation: lowRotation,
    );

    Future<void> copySummary() async {
      await Clipboard.setData(ClipboardData(text: shareSummary));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resumen listo para compartir'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final movementSection = _OwnerSignalSection(
      title: 'Movimientos de hoy',
      subtitle: 'Que paso hoy y con que ritmo se movio la caja.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 420 ? 3 : 1;
              final spacing = 14.0;
              final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
              final itemWidth = (constraints.maxWidth - totalGap) / columns;
              final metrics = <Widget>[
                MetricCard(
                  label: 'Movimientos',
                  value: '${daily.movementCount}',
                  helper: 'Todo lo registrado hoy',
                  framed: false,
                ),
                MetricCard(
                  label: 'Ventas',
                  value: '${daily.salesCount}',
                  helper: formatMoney(daily.salesPesos),
                  framed: false,
                ),
                MetricCard(
                  label: 'Gastos',
                  value: '${daily.expenseCount}',
                  helper: formatMoney(daily.expensesPesos),
                  framed: false,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: columns == 1 ? constraints.maxWidth : itemWidth,
                        child: metric,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          if (daily.recentMovements.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < daily.recentMovements.length; index++)
              _MovementDigestRow(
                movement: daily.recentMovements[index],
                showDivider: index != 0,
              ),
          ],
        ],
      ),
    );

    final topSellingSection = _OwnerSignalSection(
      title: 'Mas vendidos',
      subtitle: 'Lo que mas salio hoy para reponer con criterio.',
      child: topSelling.isEmpty
          ? const _SignalNote(
              text: 'Todavia no hay ventas de productos cargadas hoy.',
            )
          : Column(
              children: [
                for (var index = 0; index < topSelling.length; index++)
                  _ProductSignalRow(
                    title: topSelling[index].product.name,
                    trailing: '${topSelling[index].unitsSold} u.',
                    detail: formatMoney(topSelling[index].revenuePesos),
                    showDivider: index != 0,
                  ),
              ],
            ),
    );

    final urgentRestockSection = _OwnerSignalSection(
      title: 'Reponer pronto',
      subtitle: 'Stock bajo, priorizado por lo que ya se esta moviendo.',
      child: urgentRestock.isEmpty
          ? const _SignalNote(
              text: 'Sin urgencias claras de reposicion por ahora.',
            )
          : Column(
              children: [
                for (var index = 0; index < urgentRestock.length; index++)
                  _ProductSignalRow(
                    title: urgentRestock[index].product.name,
                    trailing:
                        'Stock ${urgentRestock[index].product.stockUnits}',
                    detail: _restockDetail(urgentRestock[index]),
                    showDivider: index != 0,
                  ),
              ],
            ),
    );

    final lowRotationSection = _OwnerSignalSection(
      title: 'Poca salida',
      subtitle: 'Lo que conviene revisar antes de volver a reponer.',
      child: !lowRotation.hasEnoughHistory
          ? _SignalNote(
              text:
                  lowRotation.message ??
                  'Todavia no hay suficiente historial para sugerir productos de baja salida.',
            )
          : lowRotation.products.isEmpty
          ? _SignalNote(
              text:
                  lowRotation.message ??
                  'Sin alertas claras de baja salida por ahora.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < lowRotation.products.length;
                  index++
                )
                  _ProductSignalRow(
                    title: lowRotation.products[index].product.name,
                    trailing: lowRotation.products[index].statusLabel,
                    detail: _lowRotationDetail(lowRotation.products[index]),
                    showDivider: index != 0,
                  ),
              ],
            ),
    );

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      color: Colors.white.withValues(alpha: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Senales para decidir',
            subtitle:
                'Lo que conviene mirar antes de comprar, reponer o cerrar el dia.',
            trailing: TextButton.icon(
              onPressed: copySummary,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar para compartir'),
            ),
          ),
          const SizedBox(height: 14),
          if (focusItems.isNotEmpty) ...[
            _OwnerFocusPanel(items: focusItems),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    movementSection,
                    const SizedBox(height: 18),
                    topSellingSection,
                    const SizedBox(height: 18),
                    urgentRestockSection,
                    const SizedBox(height: 18),
                    lowRotationSection,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        movementSection,
                        const SizedBox(height: 18),
                        topSellingSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        urgentRestockSection,
                        const SizedBox(height: 18),
                        lowRotationSection,
                      ],
                    ),
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

class _OwnerSignalSection extends StatelessWidget {
  const _OwnerSignalSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: BpcColors.line)),
      ),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OwnerFocusPanel extends StatelessWidget {
  const _OwnerFocusPanel({required this.items});

  final List<_OwnerFocusItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Que mirar hoy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BpcColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tres senales simples para decidir sin perder tiempo.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: BpcColors.subtleInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final spacing = 12.0;
            final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
            final itemWidth = (constraints.maxWidth - totalGap) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: columns == 1 ? constraints.maxWidth : itemWidth,
                      child: _OwnerFocusCard(item: item),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _OwnerFocusCard extends StatelessWidget {
  const _OwnerFocusCard({required this.item});

  final _OwnerFocusItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BpcColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
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

class _OwnerFocusItem {
  const _OwnerFocusItem({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}

class _SignalNote extends StatelessWidget {
  const _SignalNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: BpcColors.subtleInk,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MovementDigestRow extends StatelessWidget {
  const _MovementDigestRow({required this.movement, this.showDivider = false});

  final Movement movement;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: BpcColors.line))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((movement.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    movement.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BpcColors.subtleInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoney(movement.cashImpactPesos),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: movement.isIncome
                  ? BpcColors.income
                  : BpcColors.expenseSoft,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSignalRow extends StatelessWidget {
  const _ProductSignalRow({
    required this.title,
    required this.trailing,
    required this.detail,
    this.showDivider = false,
  });

  final String title;
  final String trailing;
  final String detail;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: BpcColors.line))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _restockDetail(UrgentRestockProduct product) {
  final stockText =
      'Minimo ${product.product.minStockUnits} / faltan ${product.stockGapUnits}';
  if (!product.hasRecentSales) {
    return 'Stock bajo / $stockText';
  }
  final soldLabel = product.latestSoldAt == null
      ? 'Venta reciente'
      : product.latestSoldAt!.year == DateTime.now().year &&
            product.latestSoldAt!.month == DateTime.now().month &&
            product.latestSoldAt!.day == DateTime.now().day
      ? 'Se vendio hoy'
      : 'Ultima venta ${formatCompactDateLabel(product.latestSoldAt!)}';
  return '$soldLabel / ${product.recentUnitsSold} u. recientes / $stockText';
}

String _lowRotationDetail(LowRotationProduct product) {
  if (product.latestSoldAt == null) {
    return 'Revisar antes de reponer';
  }
  return 'Ultima venta ${formatCompactDateLabel(product.latestSoldAt!)} / Revisar antes de reponer';
}

List<_OwnerFocusItem> _buildOwnerFocusItems(
  CommerceStore store, {
  required DailyMovementSummary daily,
  required List<TopSellingProduct> topSelling,
  required List<UrgentRestockProduct> urgentRestock,
  required LowRotationInsight lowRotation,
}) {
  final items = <_OwnerFocusItem>[];
  final suggestions = store.freeSaleSuggestions;

  if (!store.hasCashOpeningToday) {
    items.add(
      const _OwnerFocusItem(
        title: 'Abrir caja',
        detail:
            'Todavia no marcaste el efectivo inicial de hoy y despues cuesta comparar el cierre.',
        icon: Icons.login_rounded,
      ),
    );
  }

  if (daily.salesCount == 0 && store.hasProducts) {
    items.add(
      const _OwnerFocusItem(
        title: 'Primera venta pendiente',
        detail:
            'En cuanto registres una venta ya se actualizan caja, comprobante y resumen.',
        icon: Icons.shopping_bag_rounded,
      ),
    );
  }

  if (topSelling.isNotEmpty) {
    final item = topSelling.first;
    items.add(
      _OwnerFocusItem(
        title: 'Mas vendido hoy',
        detail: '${item.product.name} lleva ${item.unitsSold} u. vendidas.',
        icon: Icons.trending_up_rounded,
      ),
    );
  }

  if (urgentRestock.isNotEmpty) {
    final item = urgentRestock.first;
    items.add(
      _OwnerFocusItem(
        title: 'Reponer pronto',
        detail:
            '${item.product.name} quedo en ${item.product.stockUnits} u. y ya aparece con alerta.',
        icon: Icons.inventory_2_rounded,
      ),
    );
  }

  if (suggestions.isNotEmpty) {
    final suggestion = suggestions.first;
    items.add(
      _OwnerFocusItem(
        title: 'Venta libre repetida',
        detail:
            '"${suggestion.displayDescription}" se repitio ${suggestion.repeatCount} veces y puede pasar al catalogo.',
        icon: Icons.add_box_rounded,
      ),
    );
  }

  if (lowRotation.hasEnoughHistory && lowRotation.products.isNotEmpty) {
    final item = lowRotation.products.first;
    items.add(
      _OwnerFocusItem(
        title: 'Poca salida',
        detail:
            '${item.product.name} conviene revisarlo antes de volver a reponer.',
        icon: Icons.visibility_rounded,
      ),
    );
  }

  if (items.isEmpty && daily.movementCount > 0) {
    items.add(
      _OwnerFocusItem(
        title: 'Dia en marcha',
        detail:
            '${daily.movementCount} movimientos guardados con ventas y gastos listos para revisar.',
        icon: Icons.insights_rounded,
      ),
    );
  }

  return items.take(3).toList(growable: false);
}

String _buildDailyShareSummary({
  required List<_OwnerFocusItem> focusItems,
  required DailyMovementSummary daily,
  required List<TopSellingProduct> topSelling,
  required List<UrgentRestockProduct> urgentRestock,
  required LowRotationInsight lowRotation,
}) {
  final lines = <String>['Resumen de hoy'];

  if (focusItems.isNotEmpty) {
    lines.add('Que mirar hoy:');
    for (final item in focusItems) {
      lines.add('- ${item.title}: ${item.detail}');
    }
  }

  lines.addAll([
    'Movimientos: ${daily.movementCount}',
    'Ventas: ${formatMoney(daily.salesPesos)} en ${daily.salesCount} ventas',
    'Gastos: ${formatMoney(daily.expensesPesos)} en ${daily.expenseCount} gastos',
    'Mas vendidos:',
  ]);

  if (topSelling.isEmpty) {
    lines.add('- Sin ventas destacadas hoy');
  } else {
    for (final item in topSelling) {
      lines.add('- ${item.product.name}: ${item.unitsSold} u.');
    }
  }

  lines.add('Reponer pronto:');
  if (urgentRestock.isEmpty) {
    lines.add('- Sin alertas urgentes');
  } else {
    for (final item in urgentRestock) {
      lines.add('- ${item.product.name}: stock ${item.product.stockUnits}');
    }
  }

  lines.add('Poca salida:');
  if (!lowRotation.hasEnoughHistory) {
    lines.add('- ${lowRotation.message}');
  } else if (lowRotation.products.isEmpty) {
    lines.add('- ${lowRotation.message ?? 'Sin alertas claras por ahora'}');
  } else {
    for (final item in lowRotation.products) {
      lines.add('- ${item.product.name}: ${item.statusLabel}');
    }
  }

  return lines.join('\n');
}

class _SummaryMovementsPanel extends StatelessWidget {
  const _SummaryMovementsPanel({
    required this.store,
    required this.recent,
    required this.onCreateProductFromFreeSale,
  });

  final CommerceStore store;
  final List<Movement> recent;
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
            title: 'Movimientos recientes',
            subtitle: 'Todo lo que movio la caja y el stock',
            trailing: _SectionCountLabel(
              label: recent.isEmpty
                  ? 'Sin movimientos'
                  : '${recent.length} movimientos',
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const EmptyCard(
              title: 'Sin movimientos',
              message:
                  'Cuando registres ventas, gastos o ajustes, se van a ver aqui.',
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

class _SectionCountLabel extends StatelessWidget {
  const _SectionCountLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: BpcColors.mutedInk,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _OperationalSnapshotBanner extends StatelessWidget {
  const _OperationalSnapshotBanner({required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opening = store.todayOpeningCashPesos;
    final closing = store.todayClosingCashPesos;
    final expected = store.todayExpectedCashPesos;
    final difference = store.todayClosingDifferencePesos;
    final isBalanced = closing != null && difference == 0;

    late final IconData icon;
    late final Color accent;
    late final Color surface;
    late final String title;
    late final String message;

    if (opening == null) {
      icon = Icons.login_rounded;
      accent = scheme.primary;
      surface = scheme.surfaceContainerLow;
      title = 'Falta apertura de caja';
      message =
          'Registra el efectivo inicial para arrancar el dia con una referencia clara.';
    } else if (closing == null) {
      icon = Icons.timelapse_rounded;
      accent = scheme.primary;
      surface = scheme.surfaceContainerLow;
      title = 'Caja abierta';
      message = expected == null
          ? 'La apertura ya quedo registrada. Cuando cierres, podras comparar lo contado con lo esperado.'
          : 'La apertura ya quedo registrada. Si cerraras ahora, deberia darte ${formatMoney(expected)}.';
    } else if (difference == 0) {
      icon = Icons.verified_rounded;
      accent = Colors.white;
      surface = const Color(0xFF184D41);
      title = 'Caja cerrada, todo en orden';
      message =
          'La caja contada coincide con la esperada. Puedes cerrar el dia con tranquilidad.';
    } else {
      icon = Icons.warning_amber_rounded;
      accent = scheme.error;
      surface = scheme.errorContainer.withValues(alpha: 0.72);
      title = 'Diferencia a revisar';
      message =
          'La caja contada no coincide con la esperada. Revisa movimientos o vuelve a contar antes de dar el dia por cerrado.';
    }

    final onAccent = isBalanced ? Colors.white : null;
    return BpcPanel(
      color: surface,
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (onAccent == Colors.white ? Colors.white : accent)
                      .withValues(
                        alpha: onAccent == Colors.white ? 0.16 : 0.14,
                      ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onAccent?.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (opening != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormulaChip(
                  label: 'Apertura',
                  value: formatMoney(opening),
                  emphasized: isBalanced,
                  framed: true,
                ),
                if (expected != null)
                  _FormulaChip(
                    label: 'Esperada',
                    value: formatMoney(expected),
                    emphasized: isBalanced,
                    framed: true,
                  ),
                if (closing != null)
                  _FormulaChip(
                    label: 'Contada',
                    value: formatMoney(closing),
                    emphasized: isBalanced,
                    framed: true,
                  ),
                if (difference != null)
                  _FormulaChip(
                    label: 'Diferencia',
                    value: formatMoney(difference),
                    emphasized: difference == 0,
                    framed: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DataConfidenceNote extends StatelessWidget {
  const _DataConfidenceNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.shield_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Excel te sirve para revisar o compartir. El respaldo guarda todo para volver atras o mover la app sin perder datos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formula de la caja del dia',
              style: theme.textTheme.labelLarge?.copyWith(
                color: outline,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una apertura para ver la cuenta del dia: apertura + ventas - gastos = caja esperada.',
              style: theme.textTheme.bodyMedium?.copyWith(color: outline),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuenta visual de caja',
            style: theme.textTheme.labelLarge?.copyWith(
              color: outline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Apertura + ventas - gastos = caja esperada',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FormulaChip(label: 'Apertura', value: formatMoney(opening)),
              const Text('+', style: TextStyle(fontWeight: FontWeight.w800)),
              _FormulaChip(
                label: 'Ventas',
                value: formatMoney(store.todaySalesPesos),
              ),
              const Text('-', style: TextStyle(fontWeight: FontWeight.w800)),
              _FormulaChip(
                label: 'Gastos',
                value: formatMoney(store.todayExpensesPesos),
              ),
              const Text('=', style: TextStyle(fontWeight: FontWeight.w800)),
              _FormulaChip(
                label: 'Caja esperada',
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
    this.framed = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!framed) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 92),
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
      showShadow: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sugerencia de catalogo',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '"${suggestion.displayDescription}" se vendio varias veces como venta libre. Puedes crear un producto sin tocar esas ventas pasadas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _SuggestionMetaChip(
                    label: 'Se vendio',
                    value:
                        '${suggestion.repeatCount} ${suggestion.repeatCount == 1 ? 'vez' : 'veces'}',
                  ),
                  _SuggestionMetaChip(
                    label: 'Ultima venta',
                    value: formatCompactDateLabel(suggestion.latestSoldAt),
                  ),
                  _SuggestionMetaChip(
                    label: 'Total vendido',
                    value: formatMoney(suggestion.totalRevenuePesos),
                  ),
                  if (suggestion.latestUnitPricePesos != null)
                    _SuggestionMetaChip(
                      label: 'Ultimo precio',
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
                    child: const Text('Mas tarde'),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 108, maxWidth: 160),
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
