import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import 'caja_clara_brand.dart';

class SaleReceiptData {
  const SaleReceiptData({
    required this.issuedAt,
    required this.itemLabel,
    required this.quantityUnits,
    required this.totalPesos,
    required this.paymentMethodLabel,
    required this.saleKindLabel,
    this.unitPricePesos,
    this.stockAfterUnits,
    this.categoryLabel,
    this.referenceLabel,
  });

  final DateTime issuedAt;
  final String itemLabel;
  final int quantityUnits;
  final int totalPesos;
  final String paymentMethodLabel;
  final String saleKindLabel;
  final int? unitPricePesos;
  final int? stockAfterUnits;
  final String? categoryLabel;
  final String? referenceLabel;
}

Future<void> showSaleReceiptDialog(
  BuildContext context, {
  required SaleReceiptData receipt,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprobante listo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Una vista clara para revisar, copiar o mostrar al cliente en el momento.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SaleReceiptCard(receipt: receipt, compact: true),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      final copyButton = OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: buildSaleReceiptPlainText(receipt),
                            ),
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Comprobante copiado.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar comprobante'),
                      );
                      final closeButton = FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Listo'),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            closeButton,
                            const SizedBox(height: 10),
                            copyButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          copyButton,
                          const Spacer(),
                          closeButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String buildSaleReceiptPlainText(SaleReceiptData receipt) {
  final lines = <String>[
    'Caja Clara',
    'Comprobante de venta',
    formatDateTimeShort(receipt.issuedAt),
    'Detalle: ${receipt.itemLabel}',
    if ((receipt.categoryLabel ?? '').trim().isNotEmpty)
      'Categoria: ${receipt.categoryLabel!.trim()}',
    'Cantidad: ${receipt.quantityUnits}',
    if (receipt.unitPricePesos != null)
      'Precio unitario: ${formatMoney(receipt.unitPricePesos!)}',
    'Medio de pago: ${receipt.paymentMethodLabel}',
    if (receipt.stockAfterUnits != null)
      'Stock restante: ${receipt.stockAfterUnits}',
    if ((receipt.referenceLabel ?? '').trim().isNotEmpty)
      'Operacion: ${receipt.referenceLabel!.trim()}',
    'Total: ${formatMoney(receipt.totalPesos)}',
  ];
  return lines.join('\n');
}

class SaleReceiptCard extends StatelessWidget {
  const SaleReceiptCard({
    super.key,
    required this.receipt,
    this.compact = false,
  });

  final SaleReceiptData receipt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 18 : 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BpcColors.line),
        boxShadow: const [
          BoxShadow(
            color: BpcColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BpcColors.greenDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CajaClaraSymbol(size: 28),
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
                      'Comprobante de venta',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BpcColors.subtleInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ReceiptTag(
                label: formatDateTimeShort(receipt.issuedAt),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReceiptTag(
                label: receipt.saleKindLabel,
                icon: Icons.receipt_long_rounded,
              ),
              _ReceiptTag(
                label: receipt.paymentMethodLabel,
                icon: Icons.payments_rounded,
              ),
              if ((receipt.categoryLabel ?? '').trim().isNotEmpty)
                _ReceiptTag(
                  label: receipt.categoryLabel!.trim(),
                  icon: Icons.category_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: BpcColors.surfaceStrong,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BpcColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalle',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  receipt.itemLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                _ReceiptLine(
                  label: 'Cantidad',
                  value: '${receipt.quantityUnits}',
                ),
                if (receipt.unitPricePesos != null)
                  _ReceiptLine(
                    label: 'Precio unitario',
                    value: formatMoney(receipt.unitPricePesos!),
                  ),
                if (receipt.stockAfterUnits != null)
                  _ReceiptLine(
                    label: 'Stock que queda',
                    value: '${receipt.stockAfterUnits}',
                  ),
                if ((receipt.referenceLabel ?? '').trim().isNotEmpty)
                  _ReceiptLine(
                    label: 'Operacion',
                    value: receipt.referenceLabel!.trim(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: BpcColors.greenDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total cobrado',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(receipt.totalPesos),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comprobante simple y claro para revisar o compartir al momento.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptTag extends StatelessWidget {
  const _ReceiptTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: BpcColors.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BpcColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BpcColors.greenDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BpcColors.subtleInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
