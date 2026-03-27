import 'package:flutter/material.dart';

import 'commerce_components.dart';
import 'input_shortcuts.dart';

Future<void> showQuickHelpDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return InputShortcutScope(
        onCancel: () => Navigator.of(context).pop(),
        child: BpcDialogFrame(
          maxWidth: 760,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BpcDialogHeader(
                  icon: Icons.help_center_rounded,
                  title: 'Ayuda rapida',
                  subtitle:
                      'Lo justo para arrancar, cobrar y resolver dudas comunes sin perder tiempo.',
                  badgeLabel: 'Windows',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                const BpcPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HelpBlock(
                        title: 'Para que sirve',
                        text:
                            'Caja Clara te ayuda a llevar ventas, gastos, productos y caja desde una sola app local.',
                      ),
                      _HelpBlock(
                        title: 'Primeros pasos',
                        text:
                            'Empieza asi: 1. Abre caja. 2. Agrega un producto. 3. Registra una venta. 4. Revisa la caja del dia.',
                      ),
                      _HelpBlock(
                        title: 'Cobros',
                        text:
                            'Los medios de pago ya vienen pensados para el dia a dia: Efectivo, Transferencia, Mercado Pago, Debito, Credito y Cuenta corriente.',
                      ),
                      _HelpBlock(
                        title: 'Codigos',
                        text:
                            'Puedes usar camara, lector o ingreso manual. Si un codigo no existe, lo das de alta en el momento sin perder la venta.',
                      ),
                      _HelpBlock(
                        title: 'Activacion',
                        text:
                            'La app incluye una prueba de 30 dias. Si se termina, tus datos siguen visibles y exportables. Desde Activar Caja Clara puedes copiar el ID de esta PC y seguir el contacto de soporte.',
                      ),
                      _HelpBlock(
                        title: 'Tus datos',
                        text:
                            'Todo queda guardado localmente. Puedes sacar Excel o guardar un respaldo para quedarte tranquilo.',
                      ),
                      _HelpChecklist(
                        title: 'Checklist rapida',
                        items: [
                          'Instala desde "Instalar Caja Clara.cmd" o abre la carpeta completa si prefieres usarla portable.',
                          'Confirma que Inicio cargue bien y que el estado de prueba o activacion quede visible.',
                          'Prueba Agregar producto o abre Productos para ver que el catalogo responda.',
                          'Registra una venta o un gasto de prueba y revisa el mensaje en pantalla.',
                          'Si usas lector tipo teclado, enfoca el campo de codigo, escanea y confirma que Enter resuelve el flujo.',
                        ],
                      ),
                      _HelpBlock(
                        title: 'Windows',
                        text:
                            'La experiencia recomendada en Windows es instalarla desde el paquete portable. El MSIX sigue siendo opcional y puede pedir certificado confiable.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
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
                  Text('- ', style: bodyStyle),
                  Expanded(child: Text(item, style: bodyStyle)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
