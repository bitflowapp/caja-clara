import 'package:flutter/material.dart';

import 'input_shortcuts.dart';

Future<void> showQuickHelpDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(),
        child: AlertDialog(
          insetPadding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          scrollable: true,
          title: const Text('Como usar Caja Clara'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpBlock(
                title: 'Que es',
                text:
                    'Caja Clara ayuda a registrar ventas, gastos, productos y caja desde una sola app local.',
              ),
              _HelpBlock(
                title: 'Empezar',
                text:
                    'Primero carga tus productos. Luego registra ventas o gastos y revisa la caja en Resumen.',
              ),
              _HelpBlock(
                title: 'Barcode',
                text:
                    'Puedes leer con camara, scanner o ingreso manual. Si el codigo no existe, lo das de alta desde ahi.',
              ),
              _HelpBlock(
                title: 'Windows',
                text:
                    'La version Windows es la principal para operar todos los dias. La web sirve como demo o adicional, no como reemplazo de la app local.',
              ),
              _HelpBlock(
                title: 'Licencia',
                text:
                    'La app incluye una prueba de 30 dias. Si vence, tus datos siguen visibles y exportables, pero las acciones operativas se bloquean hasta activar.',
              ),
              _HelpBlock(
                title: 'Primera prueba en Windows',
                text:
                    'Para una prueba rapida: revisa que el estado de licencia sea visible, crea o revisa al menos un producto, registra una venta o gasto de prueba y confirma que Caja responda sin cerrarse.',
              ),
              _HelpChecklist(
                title: 'Checklist de validacion manual',
                items: [
                  'Abrir Caja Clara desde la carpeta portable completa, no desde un .exe suelto.',
                  'Confirmar que Inicio cargue sin errores y que el estado de prueba o licencia sea visible.',
                  'Probar Agregar producto o abrir Productos para verificar que el catalogo responde.',
                  'Probar Nueva venta o Registrar gasto y revisar que aparezca feedback en pantalla.',
                  'Si usas scanner tipo teclado, enfocar el campo de barcode, escanear y confirmar que Enter resuelve el flujo.',
                ],
              ),
              _HelpBlock(
                title: 'Entrega Windows',
                text:
                    'La forma recomendada de entrega es la carpeta portable o el .zip extraido. El MSIX queda como opcion adicional y puede requerir confiar un certificado de desarrollo en la PC destino.',
              ),
              _HelpBlock(
                title: 'Exportar',
                text:
                    'Desde Caja puedes exportar Excel o guardar un backup para llevarte la informacion.',
              ),
              _HelpBlock(
                title: 'Si algo falla',
                text:
                    'Revisa el mensaje en pantalla. La app guarda localmente, asi que conviene exportar o hacer backup con regularidad.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    },
  );
}

class _HelpBlock extends StatelessWidget {
  const _HelpBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HelpChecklist extends StatelessWidget {
  const _HelpChecklist({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: bodyStyle),
                  Expanded(child: Text(item, style: bodyStyle)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
