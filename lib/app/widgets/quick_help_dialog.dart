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
          title: const Text('Cómo usar Caja Clara'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpBlock(
                title: 'Para que sirve',
                text:
                    'Para ordenar tu negocio sin Excel: ventas, gastos, caja, productos y stock en una sola app.',
              ),
              _HelpBlock(
                title: 'Cómo empezar',
                text:
                    'Cargá tus productos (o usá la plantilla kiosco). Después registrá ventas y gastos en segundos.',
              ),
              _HelpBlock(
                title: 'Vender rápido',
                text:
                    'Escribís qué vendés, la cantidad y el precio, y guardás. La caja del día se actualiza sola.',
              ),
              _HelpBlock(
                title: 'Código de barras',
                text:
                    'Usá la cámara, un lector o cargalo a mano. Si el código no existe, lo das de alta desde ahí.',
              ),
              _HelpBlock(
                title: 'Llevarte los datos',
                text:
                    'Desde Caja podés exportar a Excel o guardar un backup para tener tu información siempre a mano.',
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
