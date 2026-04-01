import 'package:b_plus_commerce/app/screens/summary_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSummaryScreen(
    WidgetTester tester,
    CommerceStore store,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SummaryScreen(
              onExportExcel: () {},
              exportingExcel: false,
              onExportBackup: () {},
              exportingBackup: false,
              onRestoreBackup: () {},
              restoringBackup: false,
              onUndoLastMovement: () {},
              undoingMovement: false,
              onRegisterCashOpening: () {},
              onRegisterCashClosing: () {},
              savingCashEvent: false,
              onCreateProductFromFreeSale: (_) async {},
              onCreateProductFromSuggestion: (_) async {},
              onDismissFreeSaleSuggestion: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('summary shows owner signals with honest low-rotation copy', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();

    await pumpSummaryScreen(tester, store);

    expect(find.text('Senales para decidir'), findsOneWidget);
    expect(find.text('Que mirar hoy'), findsOneWidget);
    expect(find.text('Movimientos de hoy'), findsOneWidget);
    expect(find.text('Mas vendidos'), findsWidgets);
    expect(find.text('Reponer pronto'), findsWidgets);
    expect(find.text('Poca salida'), findsOneWidget);
    expect(
      find.text(
        'Todavia no hay suficiente historial para sugerir productos de baja salida.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('summary copies a short daily report', (tester) async {
    final store = CommerceStore.seededForTest();
    String copiedText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String? ?? '';
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpSummaryScreen(tester, store);

    await tester.ensureVisible(find.text('Copiar para compartir'));
    await tester.tap(find.text('Copiar para compartir'));
    await tester.pump();

    expect(copiedText, contains('Resumen de hoy'));
    expect(copiedText, contains('Que mirar hoy:'));
    expect(copiedText, contains('Ventas:'));
    expect(copiedText, contains('Mas vendidos:'));
    expect(copiedText, contains('Reponer pronto:'));
    expect(copiedText, contains('Poca salida:'));
  });
}
