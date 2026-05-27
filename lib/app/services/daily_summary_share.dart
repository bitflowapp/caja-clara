import '../models/movement.dart';
import '../services/commerce_store.dart';
import '../utils/formatters.dart';

class DailyTopProduct {
  const DailyTopProduct({required this.name, required this.units});

  final String name;
  final int units;
}

class DailySummaryReport {
  const DailySummaryReport({
    required this.text,
    required this.salesPesos,
    required this.expensesPesos,
    required this.salesCount,
    required this.hasOpening,
    required this.hasClosing,
    required this.differencePesos,
    required this.topProducts,
  });

  final String text;
  final int salesPesos;
  final int expensesPesos;
  final int salesCount;
  final bool hasOpening;
  final bool hasClosing;
  final int? differencePesos;
  final List<DailyTopProduct> topProducts;
}

DailySummaryReport buildDailySummary(
  CommerceStore store, {
  DateTime? now,
  int topProductsLimit = 3,
}) {
  final reference = now ?? DateTime.now();
  final dateLabel = formatShortDate(reference);

  final todayMovements = store.movements
      .where(
        (m) =>
            m.createdAt.year == reference.year &&
            m.createdAt.month == reference.month &&
            m.createdAt.day == reference.day,
      )
      .toList(growable: false);

  final aggregates = <String, int>{};
  for (final movement in todayMovements) {
    if (movement.kind != MovementKind.sale) continue;
    final units = movement.quantityUnits ?? 0;
    if (units <= 0) continue;
    final productName = movement.productId == null
        ? (movement.subtitle ?? movement.title)
        : (store.productById(movement.productId!)?.name ??
              movement.subtitle ??
              movement.title);
    final key = productName.trim();
    if (key.isEmpty) continue;
    aggregates.update(key, (prev) => prev + units, ifAbsent: () => units);
  }

  final topProducts =
      (aggregates.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(topProductsLimit)
          .map((e) => DailyTopProduct(name: e.key, units: e.value))
          .toList(growable: false);

  final salesPesos = store.todaySalesPesos;
  final expensesPesos = store.todayExpensesPesos;
  final salesCount = store.todaySalesCount;
  final hasOpening = store.hasCashOpeningToday;
  final opening = store.todayOpeningCashPesos;
  final expected = store.todayExpectedCashPesos;
  final hasClosing = store.hasCashClosingToday;
  final closing = store.todayClosingCashPesos;
  final difference = store.todayClosingDifferencePesos;

  final buffer = StringBuffer();
  buffer.writeln('Caja Clara — Resumen del $dateLabel');
  buffer.writeln();
  buffer.writeln(
    'Ventas: ${formatMoney(salesPesos)} '
    '(${salesCount == 1 ? '1 venta' : '$salesCount ventas'})',
  );
  buffer.writeln('Gastos: ${formatMoney(expensesPesos)}');

  if (hasOpening && opening != null && expected != null) {
    buffer.writeln();
    buffer.writeln('Apertura: ${formatMoney(opening)}');
    buffer.writeln('Caja esperada: ${formatMoney(expected)}');
    if (hasClosing && closing != null) {
      buffer.writeln('Cierre contado: ${formatMoney(closing)}');
      if (difference != null) {
        if (difference == 0) {
          buffer.writeln('Diferencia: coincide exacto');
        } else if (difference > 0) {
          buffer.writeln('Diferencia: sobran ${formatMoney(difference)}');
        } else {
          buffer.writeln(
            'Diferencia: faltan ${formatMoney(difference.abs())}',
          );
        }
      }
    }
  } else {
    buffer.writeln();
    buffer.writeln('Apertura: sin registrar');
  }

  if (topProducts.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Más vendidos hoy:');
    for (final product in topProducts) {
      buffer.writeln(
        '- ${product.name} · ${product.units} ${product.units == 1 ? 'u.' : 'u.'}',
      );
    }
  }

  return DailySummaryReport(
    text: buffer.toString().trimRight(),
    salesPesos: salesPesos,
    expensesPesos: expensesPesos,
    salesCount: salesCount,
    hasOpening: hasOpening,
    hasClosing: hasClosing,
    differencePesos: difference,
    topProducts: topProducts,
  );
}
