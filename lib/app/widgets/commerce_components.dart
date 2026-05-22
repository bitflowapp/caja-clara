import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../models/product.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';

/// Tarjeta base de la app: superficie blanca, borde fino y sombra suave.
class BpcPanel extends StatelessWidget {
  const BpcPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? BpcColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? BpcColors.line),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: BpcColors.shadow,
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Encabezado de sección con título fuerte y bajada opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: BpcColors.subtleInk,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Tarjeta KPI con icono, etiqueta, valor grande y ayuda corta.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.helper,
    this.accent = BpcColors.greenDark,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helper;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 136),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: BpcColors.mutedInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: BpcColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Text(
                helper!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BpcColors.subtleInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: BpcColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BpcColors.line),
            boxShadow: const [
              BoxShadow(
                color: BpcColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Métrica compacta usada en la pantalla de Caja.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.accentColor,
    this.tight = false,
  });

  final String label;
  final String value;
  final String? helper;
  final Color? accentColor;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(tight ? 14 : 16),
      decoration: BoxDecoration(
        color: accentColor ?? BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BpcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: BpcColors.ink,
              fontSize: 24,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 5),
            Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BpcColors.subtleInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de acción. `emphasized` la convierte en el CTA dominante.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.fillColor,
    this.contentColor,
    this.emphasized = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? fillColor;
  final Color? contentColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = contentColor ?? scheme.onSurface;
    final radius = emphasized ? 22.0 : 18.0;
    final iconSurface = emphasized
        ? Colors.white.withValues(alpha: 0.16)
        : BpcColors.greenDark.withValues(alpha: 0.08);
    return Material(
      color: fillColor ?? BpcColors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: emphasized ? 112 : 84),
          padding: EdgeInsets.all(emphasized ? 20 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: emphasized
                  ? Colors.white.withValues(alpha: 0.12)
                  : BpcColors.line,
            ),
            boxShadow: emphasized
                ? const [
                    BoxShadow(
                      color: Color(0x333B82F6),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: emphasized ? 58 : 50,
                height: emphasized ? 58 : 50,
                decoration: BoxDecoration(
                  color: iconSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: emphasized ? Colors.white : BpcColors.greenDark,
                  size: emphasized ? 28 : 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontSize: emphasized ? 22 : 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: emphasized
                              ? Colors.white.withValues(alpha: 0.82)
                              : BpcColors.subtleInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (emphasized) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un movimiento (venta, gasto o ajuste) en una lista.
class MovementsListTile extends StatelessWidget {
  const MovementsListTile({
    super.key,
    required this.movement,
    this.productName,
    this.onCreateProductFromFreeSale,
    this.showDivider = true,
  });

  final Movement movement;
  final String? productName;
  final VoidCallback? onCreateProductFromFreeSale;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = movement.isNeutral
        ? BpcColors.mutedInk
        : (movement.isIncome ? BpcColors.income : BpcColors.expense);
    final label = movement.isNeutral
        ? formatMoney(0)
        : movement.isIncome
        ? '+${formatMoney(movement.amountPesos)}'
        : '-${formatMoney(movement.amountPesos)}';
    final subtitle = movement.kind == MovementKind.sale
        ? '${movement.subtitle ?? productName ?? movement.title} · ${movement.quantityUnits ?? 0} u. · ${movement.paymentMethod ?? 'Caja'}'
        : movement.kind == MovementKind.expense
        ? '${movement.originLabel} · ${movement.category ?? 'Gasto'}'
        : movement.subtitle ?? movement.originLabel;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: BpcColors.line))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              movement.isNeutral
                  ? Icons.sync_alt_rounded
                  : movement.isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (movement.isFreeSale &&
                    onCreateProductFromFreeSale != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onCreateProductFromFreeSale,
                    icon: const Icon(Icons.add_box_rounded, size: 18),
                    label: const Text('Crear producto desde esta venta'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatMovementDate(movement.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BpcColors.subtleInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado vacío con icono, mensaje humano y acción opcional.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: BpcColors.greenDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: BpcColors.greenDark, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Distintivo de stock: "Stock bajo" o "Stock ok".
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;
    final color = low ? BpcColors.expense : BpcColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            low ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            low ? 'Stock bajo' : 'Stock ok',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
