import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';
import '../utils/user_facing_errors.dart';
import 'commerce_components.dart';
import 'license_scope.dart';

Future<bool> ensureLicenseAccess(
  BuildContext context,
  LockedFeature feature,
) async {
  final licenseService = LicenseScope.of(context);
  if (licenseService.canUse(feature)) {
    return true;
  }

  await showLicenseManagementDialog(context, lockedFeature: feature);
  return false;
}

Future<void> showLicenseManagementDialog(
  BuildContext context, {
  LockedFeature? lockedFeature,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return BpcDialogFrame(
        maxWidth: 760,
        child: _LicenseManagementDialog(lockedFeature: lockedFeature),
      );
    },
  );
}

class _LicenseManagementDialog extends StatefulWidget {
  const _LicenseManagementDialog({this.lockedFeature});

  final LockedFeature? lockedFeature;

  @override
  State<_LicenseManagementDialog> createState() =>
      _LicenseManagementDialogState();
}

class _LicenseManagementDialogState extends State<_LicenseManagementDialog> {
  late final TextEditingController _codeController;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final licenseService = LicenseScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: licenseService,
      builder: (context, _) {
        final statusColor = switch (licenseService.status) {
          LicenseStatus.active => const Color(0xFF184D41),
          LicenseStatus.trialActive => scheme.primary,
          LicenseStatus.trialExpired => scheme.error,
        };
        return Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BpcDialogHeader(
                  icon: licenseService.isActivated
                      ? Icons.verified_rounded
                      : Icons.lock_open_rounded,
                  title: licenseService.statusHeadline,
                  subtitle: licenseService.statusDescription,
                  badgeLabel: licenseService.isActivated
                      ? 'Activacion'
                      : licenseService.isTrialExpired
                      ? 'Prueba vencida'
                      : 'Prueba activa',
                  badgeColor: statusColor,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                BpcPanel(
                  color: scheme.surfaceContainerLow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tus datos quedan guardados',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        licenseService.positioningMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.lockedFeature != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          licenseService.blockingMessage(widget.lockedFeature!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _InfoBlock(
                  title: 'ID de esta PC',
                  value: licenseService.installationId,
                  actionLabel: 'Copiar ID',
                  onAction: () => _copyValue(
                    context,
                    licenseService.installationId,
                    label: 'ID de esta PC',
                  ),
                ),
                if (licenseService.hasSalesEmail)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InfoBlock(
                      title: 'Mail de soporte',
                      value: LicenseService.salesEmail.trim(),
                      actionLabel: 'Copiar mail',
                      onAction: () => _copyValue(
                        context,
                        LicenseService.salesEmail.trim(),
                        label: 'mail de soporte',
                      ),
                    ),
                  ),
                if (licenseService.hasSalesWhatsApp)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InfoBlock(
                      title: 'WhatsApp de soporte',
                      value: LicenseService.salesWhatsApp.trim(),
                      actionLabel: 'Copiar WhatsApp',
                      onAction: () => _copyValue(
                        context,
                        LicenseService.salesWhatsApp.trim(),
                        label: 'WhatsApp de soporte',
                      ),
                    ),
                  ),
                if (!licenseService.isActivated) ...[
                  const SizedBox(height: 18),
                  BpcPanel(
                    color: scheme.surfaceContainerLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activar Caja Clara',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Pega el codigo',
                            hintText: 'CCW-XXXX-XXXX',
                            helperText:
                                'Lo recibes desde soporte despues de compartir el ID de esta PC.',
                          ),
                          onSubmitted: (_) => _activate(context, licenseService),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Aunque la prueba termine, tus datos no se borran y siguen disponibles.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  _InfoBlock(
                    title: 'Activacion cargada',
                    value: licenseService.activationCode ?? 'Activa',
                    actionLabel: 'Copiar codigo',
                    onAction: () => _copyValue(
                      context,
                      licenseService.activationCode ?? 'Activa',
                      label: 'codigo de activacion',
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final closeLabel = licenseService.isTrialExpired
                        ? 'Seguir viendo datos'
                        : 'Cerrar';
                    final closeButton = TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(closeLabel),
                    );
                    final activateButton = FilledButton.icon(
                      onPressed: licenseService.isActivated || _activating
                          ? null
                          : () => _activate(context, licenseService),
                      icon: _activating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        licenseService.isActivated
                            ? 'Caja Clara activada'
                            : _activating
                            ? 'Activando'
                            : 'Activar Caja Clara',
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          activateButton,
                          const SizedBox(height: 10),
                          closeButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Spacer(),
                        closeButton,
                        const SizedBox(width: 12),
                        activateButton,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _activate(
    BuildContext context,
    LicenseService licenseService,
  ) async {
    if (_activating || licenseService.isActivated) {
      return;
    }

    setState(() => _activating = true);
    try {
      await licenseService.activate(_codeController.text);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caja Clara quedo activada. Ya puedes seguir trabajando normal.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _activating = false);
      }
    }
  }

  Future<void> _copyValue(
    BuildContext context,
    String value, {
    required String label,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Se copio $label.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BpcPanel(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectionArea(
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.copy_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
