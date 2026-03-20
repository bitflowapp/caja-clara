import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/excel_export_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildWorkbookBytes creates expected sheets and headers', () {
    final store = CommerceStore.seededForTest();
    final service = ExcelExportService();
    final bytes = service.buildWorkbookBytes(
      store,
      exportAt: DateTime(2026, 3, 20, 10, 30),
    );

    expect(bytes, isNotEmpty);

    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys, containsAll(<String>[
      'Resumen',
      'Productos',
      'Ventas',
      'Gastos',
      'Movimientos',
    ]));

    expect(
      workbook.tables['Resumen']!.rows.first.first!.value.toString(),
      'Campo',
    );
    expect(
      workbook.tables['Productos']!.rows.first[2]!.value.toString(),
      'Barcode',
    );
    expect(
      workbook.tables['Ventas']!.rows.first[3]!.value.toString(),
      'Medio de pago',
    );
    expect(
      workbook.tables['Gastos']!.rows.first[2]!.value.toString(),
      'Categoria',
    );
    expect(
      workbook.tables['Movimientos']!.rows.first[3]!.value.toString(),
      'Importe',
    );
  });
}
