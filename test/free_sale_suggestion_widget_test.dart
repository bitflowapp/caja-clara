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
      for (var i = 0; i < 3; i++) {
        await store.recordFreeSale(
          description: 'Cable USB rapido',
          quantityUnits: 1,
          unitPricePesos: 3900,
          paymentMethod: 'Transferencia',
        );
      }

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

      await tester.ensureVisible(find.text('Crear producto').first);
      await tester.tap(find.text('Crear producto').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Agregar producto'), findsWidgets);
      expect(find.text('Cable USB rapido'), findsWidgets);
      expect(
        find.text('Vista previa: Cable USB rapido / \$3.900'),
        findsOneWidget,
      );
    },
  );
}
