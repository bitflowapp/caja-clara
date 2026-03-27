import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:b_plus_commerce/app/widgets/responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'repeated free sales show suggestion and reuse product editor flow',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.recordFreeSale(
        description: 'Cable USB rapido',
        quantityUnits: 1,
        unitPricePesos: 4200,
        paymentMethod: 'Transferencia',
        createdAt: DateTime(2026, 3, 23, 19, 15),
      );
      await store.recordFreeSale(
        description: 'Cable USB rapido',
        quantityUnits: 1,
        unitPricePesos: 3900,
        paymentMethod: 'Transferencia',
        createdAt: DateTime(2026, 3, 21, 11, 0),
      );
      await store.recordFreeSale(
        description: 'Cable USB rapido',
        quantityUnits: 2,
        unitPricePesos: 4000,
        paymentMethod: 'Transferencia',
        createdAt: DateTime(2026, 3, 22, 17, 0),
      );

      await tester.pumpWidget(
        CommerceScope(
          store: store,
          child: const MaterialApp(home: ResponsiveShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Venta libre repetida'), findsOneWidget);
      expect(find.textContaining('Cable USB rapido'), findsWidgets);
      expect(find.text('Se vendio'), findsOneWidget);
      expect(find.text('3 veces'), findsOneWidget);
      expect(find.text('Total vendido'), findsOneWidget);
      expect(find.text('\$ 16.100'), findsWidgets);
      expect(find.text('Ultimo precio'), findsOneWidget);
      expect(find.text('\$ 4.200'), findsWidgets);

      await tester.ensureVisible(find.text('Crear producto').first);
      await tester.tap(find.text('Crear producto').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Agregar producto'), findsWidgets);
      expect(find.text('Cable USB rapido'), findsWidgets);
      expect(find.text('Vista rapida'), findsOneWidget);
      expect(find.text('Cable USB rapido / \$ 4.200'), findsOneWidget);
    },
  );
}
