import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/movement.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../utils/payment_methods.dart';
import 'commerce_store.dart';
import 'excel_file_saver.dart';

class ExcelExportResult {
  const ExcelExportResult({
    required this.disposition,
    required this.fileName,
    this.path,
  });

  final ExcelSaveDisposition disposition;
  final String fileName;
  final String? path;

  bool get saved => disposition == ExcelSaveDisposition.saved;
  bool get downloaded => disposition == ExcelSaveDisposition.downloaded;
  bool get cancelled => disposition == ExcelSaveDisposition.cancelled;
}

class ExcelExportService {
  ExcelExportService({ExcelFileSaver? fileSaver})
      : _fileSaver = fileSaver ?? createExcelFileSaver();

  final ExcelFileSaver _fileSaver;

  Future<ExcelExportResult> export(
    CommerceStore store, {
    DateTime? now,
  }) async {
    final exportAt = now ?? DateTime.now();
    final fileName = buildSuggestedFileName(exportAt);
    final workbook = buildWorkbookBytes(store, exportAt: exportAt);
    final saveResult = await _fileSaver.save(
      bytes: workbook,
      suggestedName: fileName,
    );

    return ExcelExportResult(
      disposition: saveResult.disposition,
      fileName: fileName,
      path: saveResult.path,
    );
  }

  @visibleForTesting
  Uint8List buildWorkbookBytes(
    CommerceStore store, {
    required DateTime exportAt,
  }) {
    final excel = Excel.createExcel();
    final summarySheet = excel['Resumen'];
    final productsSheet = excel['Productos'];
    final salesSheet = excel['Ventas'];
    final expensesSheet = excel['Gastos'];
    final movementsSheet = excel['Movimientos'];

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    _fillSummary(summarySheet, store, exportAt);
    _fillProducts(productsSheet, store.products);
    _fillSales(salesSheet, store);
    _fillExpenses(expensesSheet, store);
    _fillMovements(movementsSheet, store);

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  @visibleForTesting
  String buildSuggestedFileName(DateTime exportAt) {
    final suffix = DateFormat('dd-MM-yyyy_HH-mm').format(exportAt);
    return 'caja_clara_$suffix.xlsx';
  }

  void _fillSummary(Sheet sheet, CommerceStore store, DateTime exportAt) {
    _writeHeaderRow(sheet, 0, const <String>['Campo', 'Valor']);
    _writeRow(sheet, 1, <CellValue>[
      TextCellValue('Fecha de exportacion'),
      TextCellValue(_formatDateTime(exportAt)),
    ]);
    _writeRow(sheet, 2, <CellValue>[
      TextCellValue('Ventas del dia'),
      IntCellValue(store.todaySalesPesos),
    ]);
    _writeRow(sheet, 3, <CellValue>[
      TextCellValue('Gastos del dia'),
      IntCellValue(store.todayExpensesPesos),
    ]);
    _writeRow(sheet, 4, <CellValue>[
      TextCellValue('Caja actual'),
      IntCellValue(store.cashBalancePesos),
    ]);
    _writeRow(sheet, 5, <CellValue>[
      TextCellValue('Ganancia estimada simple'),
      IntCellValue(store.todayEstimatedProfitPesos),
    ]);
  }

  void _fillProducts(Sheet sheet, List<Product> products) {
    _writeHeaderRow(sheet, 0, const <String>[
      'ID',
      'Nombre',
      'Barcode',
      'Stock',
      'Stock minimo',
      'Costo',
      'Precio',
      'Categoria',
    ]);

    for (var i = 0; i < products.length; i++) {
      final product = products[i];
      _writeRow(sheet, i + 1, <CellValue>[
        TextCellValue(product.id),
        TextCellValue(product.name),
        TextCellValue(product.barcode ?? ''),
        IntCellValue(product.stockUnits),
        IntCellValue(product.minStockUnits),
        IntCellValue(product.costPesos),
        IntCellValue(product.pricePesos),
        TextCellValue(product.category ?? ''),
      ]);
    }
  }

  void _fillSales(Sheet sheet, CommerceStore store) {
    final sales = store.movements
        .where((movement) => movement.kind == MovementKind.sale)
        .toList(growable: false);

    _writeHeaderRow(sheet, 0, const <String>[
      'Fecha/hora',
      'Producto',
      'Cantidad',
      'Medio de pago',
      'Total',
    ]);

    for (var i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final productName = _saleLabel(store, sale);
      _writeRow(sheet, i + 1, <CellValue>[
        TextCellValue(_formatDateTime(sale.createdAt)),
        TextCellValue(productName),
        IntCellValue(sale.quantityUnits ?? 0),
        TextCellValue(displayPaymentMethodLabel(sale.paymentMethod, fallback: '')),
        IntCellValue(sale.amountPesos),
      ]);
    }
  }

  void _fillExpenses(Sheet sheet, CommerceStore store) {
    final expenses = store.movements
        .where((movement) => movement.kind == MovementKind.expense)
        .toList(growable: false);

    _writeHeaderRow(sheet, 0, const <String>[
      'Fecha/hora',
      'Concepto',
      'Categoria',
      'Monto',
    ]);

    for (var i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      _writeRow(sheet, i + 1, <CellValue>[
        TextCellValue(_formatDateTime(expense.createdAt)),
        TextCellValue(expense.title),
        TextCellValue(expense.category ?? expense.subtitle ?? ''),
        IntCellValue(expense.amountPesos),
      ]);
    }
  }

  void _fillMovements(Sheet sheet, CommerceStore store) {
    _writeHeaderRow(sheet, 0, const <String>[
      'Fecha/hora',
      'Tipo',
      'Detalle',
      'Importe',
    ]);

    for (var i = 0; i < store.movements.length; i++) {
      final movement = store.movements[i];
      _writeRow(sheet, i + 1, <CellValue>[
        TextCellValue(_formatDateTime(movement.createdAt)),
        TextCellValue(movement.originLabel),
        TextCellValue(_movementDetail(store, movement)),
        IntCellValue(movement.cashImpactPesos),
      ]);
    }
  }

  void _writeHeaderRow(Sheet sheet, int rowIndex, List<String> headers) {
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          rowIndex: rowIndex,
          columnIndex: columnIndex,
        ),
      );
      cell.value = TextCellValue(headers[columnIndex]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Left,
      );
    }
  }

  void _writeRow(Sheet sheet, int rowIndex, List<CellValue> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              rowIndex: rowIndex,
              columnIndex: columnIndex,
            ),
          )
          .value = values[columnIndex];
    }
  }

  String _movementDetail(CommerceStore store, Movement movement) {
    if (movement.kind == MovementKind.sale) {
      final productName = _saleLabel(store, movement);
      final paymentMethod = displayPaymentMethodLabel(movement.paymentMethod);
      return '$productName / $paymentMethod';
    }

    if (movement.kind == MovementKind.adjustment) {
      return movement.subtitle ?? movement.title;
    }

    final category = movement.category ?? movement.subtitle ?? 'General';
    return '${movement.title} / $category';
  }

  String _saleLabel(CommerceStore store, Movement movement) {
    return store.productById(movement.productId ?? '')?.name ??
        movement.subtitle ??
        movement.title;
  }

  String _formatDateTime(DateTime value) {
    return formatDateTimeShort(value);
  }
}
