import 'package:flutter/material.dart';

import 'commerce_components.dart';
import 'input_shortcuts.dart';

enum QuickHelpDialogResult { completed, skipped, dismissed }

Future<QuickHelpDialogResult?> showQuickHelpDialog(BuildContext context) async {
  return showDialog<QuickHelpDialogResult>(
    context: context,
    useSafeArea: true,
    barrierDismissible: false,
    builder: (context) {
      return InputShortcutScope(
        onCancel: () =>
            Navigator.of(context).pop(QuickHelpDialogResult.dismissed),
        child: const _QuickHelpDialog(),
      );
    },
  );
}

class _QuickHelpDialog extends StatefulWidget {
  const _QuickHelpDialog();

  @override
  State<_QuickHelpDialog> createState() => _QuickHelpDialogState();
}

class _QuickHelpDialogState extends State<_QuickHelpDialog> {
  static const List<_TutorialStepData> _steps = <_TutorialStepData>[
    _TutorialStepData(
      title: 'Abri caja',
      body:
          'Marca la apertura con el efectivo inicial. Si arrancas en cero, tambien sirve.',
      icon: Icons.point_of_sale_rounded,
      section: 'Caja',
    ),
    _TutorialStepData(
      title: 'Agrega un producto',
      body:
          'Carga nombre, precio y stock. Si quieres ir rapido, usa el catalogo base.',
      icon: Icons.inventory_2_rounded,
      section: 'Productos',
    ),
    _TutorialStepData(
      title: 'Hace una venta',
      body:
          'Busca el producto, elige como te pagan y registra el cobro. Si falta, usa venta libre.',
      icon: Icons.shopping_cart_checkout_rounded,
      section: 'Ventas',
    ),
    _TutorialStepData(
      title: 'Revisa el resumen',
      body:
          'En Caja ves ventas, gastos y el estado del dia para cerrar con control.',
      icon: Icons.account_balance_wallet_rounded,
      section: 'Resumen',
    ),
    _TutorialStepData(
      title: 'Listo para usar',
      body:
          'Con eso ya puedes trabajar. Si te olvidas algo, abri Ayuda y lo repasas en un minuto.',
      icon: Icons.check_circle_rounded,
      section: 'Listo',
    ),
  ];

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final step = _steps[_currentStep];
    final isLastStep = _currentStep == _steps.length - 1;
    final progress = (_currentStep + 1) / _steps.length;

    return BpcDialogFrame(
      maxWidth: 620,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BpcDialogHeader(
            icon: Icons.auto_stories_rounded,
            title: 'Tutorial rapido',
            subtitle:
                'Cinco pasos cortos para empezar a usar Caja Clara sin leer de mas.',
            badgeLabel: '${_currentStep + 1}/${_steps.length}',
            onClose: () =>
                Navigator.of(context).pop(QuickHelpDialogResult.dismissed),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final header = _StepIconHeader(step: step);
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      step.section,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 16), copy],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(width: 18),
                  Expanded(child: copy),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: () => setState(() => _currentStep -= 1),
                  child: const Text('Atras'),
                )
              else
                const SizedBox(width: 64),
              const Spacer(),
              if (!isLastStep)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(QuickHelpDialogResult.skipped),
                  child: const Text('Saltear'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (isLastStep) {
                    Navigator.of(context).pop(QuickHelpDialogResult.completed);
                    return;
                  }
                  setState(() => _currentStep += 1);
                },
                child: Text(isLastStep ? 'Listo' : 'Siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIconHeader extends StatelessWidget {
  const _StepIconHeader({required this.step});

  final _TutorialStepData step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(step.icon, color: scheme.primary, size: 34),
    );
  }
}

class _TutorialStepData {
  const _TutorialStepData({
    required this.title,
    required this.body,
    required this.icon,
    required this.section,
  });

  final String title;
  final String body;
  final IconData icon;
  final String section;
}
