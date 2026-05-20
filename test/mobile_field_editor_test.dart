import 'package:b_plus_commerce/app/widgets/mobile_field_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TextEditingController> pumpEditorField(
    WidgetTester tester, {
    String initialValue = '1200',
    String label = 'Monto',
    String? Function(String?)? validator,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = TextEditingController(text: initialValue);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: MobileFieldEditorFormField(
                controller: controller,
                labelText: label,
                editorContext: 'Probá movil',
                emptyDisplayText: 'Tocá para editar',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator:
                    validator ??
                    (value) {
                      final parsed = int.tryParse(value ?? '') ?? 0;
                      if (parsed <= 0) {
                        return 'Ingresá un monto válido';
                      }
                      return null;
                    },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('solo aplica cambios al confirmar', (tester) async {
    final controller = await pumpEditorField(tester);

    await tester.tap(find.text('1200'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '2400');
    await tester.pumpAndSettle();

    expect(controller.text, '1200');

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(controller.text, '2400');
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('guardar y seguir aplica y abre el siguiente campo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final firstController = TextEditingController(text: '12');
    final secondController = TextEditingController(text: '34');
    final firstEditorController = MobileFieldEditorController();
    final secondEditorController = MobileFieldEditorController();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: Column(
                children: [
                  MobileFieldEditorFormField(
                    controller: firstController,
                    editorController: firstEditorController,
                    nextEditorController: secondEditorController,
                    nextFieldLabel: 'Precio',
                    labelText: 'Cantidad',
                    editorContext: 'Probá movil',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '') ?? 0;
                      return parsed <= 0 ? 'Ingresá una cantidad' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  MobileFieldEditorFormField(
                    controller: secondController,
                    editorController: secondEditorController,
                    labelText: 'Precio',
                    editorContext: 'Probá movil',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '') ?? 0;
                      return parsed <= 0 ? 'Ingresá un precio' : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '25');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar y seguir'));
    await tester.pumpAndSettle();

    expect(firstController.text, '25');
    expect(find.widgetWithText(TextFormField, 'Precio'), findsOneWidget);
    expect(secondController.text, '34');
  });

  testWidgets('guardar y seguir inválido no cierra ni abre el siguiente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final firstController = TextEditingController(text: '12');
    final secondController = TextEditingController(text: '34');
    final firstEditorController = MobileFieldEditorController();
    final secondEditorController = MobileFieldEditorController();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: Column(
                children: [
                  MobileFieldEditorFormField(
                    controller: firstController,
                    editorController: firstEditorController,
                    nextEditorController: secondEditorController,
                    nextFieldLabel: 'Precio',
                    labelText: 'Cantidad',
                    editorContext: 'Probá movil',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '') ?? 0;
                      return parsed <= 0 ? 'Ingresá una cantidad' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  MobileFieldEditorFormField(
                    controller: secondController,
                    editorController: secondEditorController,
                    labelText: 'Precio',
                    editorContext: 'Probá movil',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '') ?? 0;
                      return parsed <= 0 ? 'Ingresá un precio' : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar y seguir'));
    await tester.pumpAndSettle();

    expect(firstController.text, '12');
    expect(find.text('Ingresá una cantidad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Cantidad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Precio'), findsNothing);
  });

  testWidgets('cancelar sin cambios cerrá sin modificar el valor', (
    tester,
  ) async {
    final controller = await pumpEditorField(tester, initialValue: '1800');

    await tester.tap(find.text('1800'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(controller.text, '1800');
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('cerrar con cambios pide confirmar antes de descartar', (
    tester,
  ) async {
    final controller = await pumpEditorField(tester, initialValue: '900');

    await tester.tap(find.text('900'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '1500');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Hay cambios sin guardar'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(find.text('Seguir editando'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(controller.text, '900');
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('si el valor es inválido se queda abierto y muestra error', (
    tester,
  ) async {
    final controller = await pumpEditorField(tester, initialValue: '100');

    await tester.tap(find.text('100'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá un monto válido'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(controller.text, '100');
  });

  testWidgets('multilinea mantiene flujo conservador sin guardar y seguir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = TextEditingController(text: 'Observacion inicial');
    final editorController = MobileFieldEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: MobileFieldEditorFormField(
                controller: controller,
                editorController: editorController,
                nextFieldLabel: 'Cantidad',
                labelText: 'Observaciones',
                editorContext: 'Probá movil',
                keyboardType: TextInputType.multiline,
                minLines: 3,
                maxLines: 5,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Observacion inicial'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar y seguir'), findsNothing);
    expect(find.textContaining('Sigue con'), findsNothing);
  });
}
