import 'package:flutter/material.dart';

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
    final actions = [
      _SummaryCommand(
        title: exportingExcel ? 'Exportando Excel' : 'Exportar Excel',
        subtitle: 'Compartir resumen, productos y movimientos',
        icon: Icons.file_download_rounded,
        onTap: exportingExcel ? null : onExportExcel,
        emphasized: true,
        loading: exportingExcel,
      ),
      _SummaryCommand(
        title: exportingBackup ? 'Exportando backup' : 'Exportar backup',
        subtitle: 'Guardar el estado completo local',
        icon: Icons.save_alt_rounded,
        onTap: exportingBackup ? null : onExportBackup,
        loading: exportingBackup,
      ),
      _SummaryCommand(
        title: restoringBackup ? 'Restaurando' : 'Restaurar backup',
        subtitle: 'Recuperar un estado anterior',
        icon: Icons.restore_page_rounded,
        onTap: restoringBackup ? null : onRestoreBackup,
        loading: restoringBackup,
      ),
      _SummaryCommand(
        title: undoingMovement ? 'Deshaciendo' : 'Deshacer ultimo',
        subtitle: store.canUndoLastMovement
            ? 'Revertir el ultimo movimiento guardado'
            : 'No hay movimientos reversibles',
        icon: Icons.undo_rounded,
        onTap: undoingMovement || !store.canUndoLastMovement
            ? null
            : onUndoLastMovement,
        loading: undoingMovement,
      ),
      _SummaryCommand(
        title: store.hasCashOpeningToday ? 'Editar apertura' : 'Apertura',
        subtitle: 'Registrar caja inicial del dia',
        icon: Icons.login_rounded,
        onTap: savingCashEvent ? null : onRegisterCashOpening,
      ),
      _SummaryCommand(
        title: store.hasCashClosingToday ? 'Editar cierre' : 'Cierre',
        subtitle: 'Comparar caja contada con la esperada',
        icon: Icons.logout_rounded,
        onTap: savingCashEvent ? null : onRegisterCashClosing,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final commandGrid = _SummaryCommandGrid(commands: actions);
        final snapshot = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Caja / Resumen',
              subtitle: 'Control diario, exportacion y respaldo local',
              trailing: _SectionCountChip(
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
            children: [snapshot, const SizedBox(height: 14), commandGrid],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: snapshot),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: commandGrid),
          ],
        );
      },
    );
  }
}

class _SummaryCommandGrid extends StatelessWidget {
  const _SummaryCommandGrid({required this.commands});

  final List<_SummaryCommand> commands;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final spacing = 12.0;
        final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
        final cardWidth = (constraints.maxWidth - totalGap) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: commands
              .map(
                (command) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : cardWidth,
                  child: _SummaryCommandCard(command: command),
                ),
              )
              .toList(growable: false),
        );
      },
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

class _SummaryCommandCard extends StatelessWidget {
  const _SummaryCommandCard({required this.command});

  final _SummaryCommand command;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = command.onTap != null;
    final fillColor = command.emphasized
        ? primary
        : Colors.white.withValues(alpha: enabled ? 0.82 : 0.7);
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
        child: BpcPanel(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          color: fillColor,
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
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: Colors.white.withValues(alpha: 0.8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1080;
          final cashState = _MetricGroupPanel(
            title: 'Estado de caja',
            subtitle: 'Lo importante para abrir, operar y cerrar con control.',
            metrics: [
              MetricCard(
                label: 'Caja acumulada',
                value: formatMoney(store.cashBalancePesos),
                helper: 'Saldo total registrado',
              ),
              MetricCard(
                label: 'Saldo inicial',
                value: store.todayOpeningCashPesos == null
                    ? 'Sin abrir'
                    : formatMoney(store.todayOpeningCashPesos!),
                helper: 'Apertura del dia',
              ),
              MetricCard(
                label: 'Caja del dia',
                value: store.todayExpectedCashPesos == null
                    ? 'Sin apertura'
                    : formatMoney(store.todayExpectedCashPesos!),
                helper: 'Saldo inicial + ventas - gastos',
              ),
              MetricCard(
                label: 'Cierre registrado',
                value: store.todayClosingCashPesos == null
                    ? 'Sin cierre'
                    : formatMoney(store.todayClosingCashPesos!),
                helper: store.todayClosingDifferencePesos == null
                    ? 'Caja contada al cierre'
                    : 'Diferencia: ${formatMoney(store.todayClosingDifferencePesos!)}',
              ),
            ],
          );
          final operations = _MetricGroupPanel(
            title: 'Actividad del dia',
            subtitle: 'Ingresos, egresos y senales operativas del turno.',
            metrics: [
              MetricCard(
                label: 'Ventas del dia',
                value: formatMoney(store.todaySalesPesos),
                helper: 'Ingresos de hoy',
                accentColor: BpcColors.greenSoft.withValues(alpha: 0.18),
              ),
              MetricCard(
                label: 'Gastos del dia',
                value: formatMoney(store.todayExpensesPesos),
                helper: 'Egresos de hoy',
                accentColor: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.42),
              ),
              MetricCard(
                label: 'Movimientos hoy',
                value: '${store.todayMovementCount}',
                helper: 'Ventas, gastos y ajustes',
              ),
              MetricCard(
                label: 'Margen estimado hoy',
                value: formatMoney(store.todayEstimatedProfitPesos),
                helper: 'Ventas menos costo estimado',
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
                      'Una vista operativa del dia con formula, caja esperada y actividad real.',
                ),
                const SizedBox(height: 12),
                _CashFormulaCard(store: store),
                const SizedBox(height: 14),
                cashState,
                const SizedBox(height: 12),
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
                    'Una vista operativa del dia con formula, caja esperada y actividad real.',
              ),
              const SizedBox(height: 12),
              _CashFormulaCard(store: store),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cashState),
                  const SizedBox(width: 12),
                  Expanded(child: operations),
                ],
              ),
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BpcColors.line),
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
              final spacing = 10.0;
              final totalGap = columns > 1 ? spacing * (columns - 1) : 0.0;
              final itemWidth = (constraints.maxWidth - totalGap) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
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
            subtitle: 'Todo lo que impacta en caja y stock',
            trailing: _SectionCountChip(
              label: recent.isEmpty
                  ? 'Sin movimientos'
                  : '${recent.length} items',
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const EmptyCard(
              title: 'Sin movimientos',
              message:
                  'Cuando registres ventas, gastos o ajustes, se veran aqui.',
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

class _SectionCountChip extends StatelessWidget {
  const _SectionCountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BpcColors.line),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: BpcColors.ink,
          fontWeight: FontWeight.w900,
        ),
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
          'Registra la caja inicial para controlar el dia y detectar diferencias antes del cierre.';
    } else if (closing == null) {
      icon = Icons.timelapse_rounded;
      accent = scheme.primary;
      surface = scheme.surfaceContainerLow;
      title = 'Caja abierta y bajo seguimiento';
      message = expected == null
          ? 'Ya registraste la apertura. Cuando cierres, podras comparar contra el esperado.'
          : 'Ya registraste la apertura. Si cerraras ahora, la caja esperada seria ${formatMoney(expected)}.';
    } else if (difference == 0) {
      icon = Icons.verified_rounded;
      accent = Colors.white;
      surface = const Color(0xFF184D41);
      title = 'Cierre cuadrado';
      message =
          'La caja contada coincide con la caja esperada. Es una buena senal para demo y operacion real.';
    } else {
      icon = Icons.warning_amber_rounded;
      accent = scheme.error;
      surface = scheme.errorContainer.withValues(alpha: 0.72);
      title = 'Diferencia a revisar';
      message =
          'La caja esperada y la caja contada no coinciden. Revisa movimientos o el conteo antes de cerrar el dia.';
    }

    final onAccent = isBalanced ? Colors.white : null;
    return BpcPanel(
      color: surface,
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
                ),
                if (expected != null)
                  _FormulaChip(
                    label: 'Esperada',
                    value: formatMoney(expected),
                    emphasized: isBalanced,
                  ),
                if (closing != null)
                  _FormulaChip(
                    label: 'Contada',
                    value: formatMoney(closing),
                    emphasized: isBalanced,
                  ),
                if (difference != null)
                  _FormulaChip(
                    label: 'Diferencia',
                    value: formatMoney(difference),
                    emphasized: difference == 0,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BpcColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Excel sirve para compartir o revisar fuera de la app. El backup guarda el estado completo para moverlo o restaurarlo sin depender de internet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formula del dia',
              style: theme.textTheme.labelLarge?.copyWith(
                color: outline,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una apertura para ver la formula del dia: saldo inicial + ventas - gastos = caja del dia.',
              style: theme.textTheme.bodyMedium?.copyWith(color: outline),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formula visual de caja',
            style: theme.textTheme.labelLarge?.copyWith(
              color: outline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saldo inicial + ventas - gastos = caja del dia',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BpcColors.subtleInk,
              fontWeight: FontWeight.w600,
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
                label: 'Caja del dia',
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
                spacing: 8,
                runSpacing: 8,
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
