import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';
import '../utils/user_facing_errors.dart';
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
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _LicenseManagementDialog(lockedFeature: lockedFeature),
        ),
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
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            licenseService.statusHeadline,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            licenseService.statusDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Windows principal',
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
                  title: 'ID de instalacion',
                  value: licenseService.installationId,
                  actionLabel: 'Copiar ID',
                  onAction: () => _copyValue(
                    context,
                    licenseService.installationId,
                    label: 'ID de instalacion',
                  ),
                ),
                if (licenseService.hasSalesEmail)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InfoBlock(
                      title: 'Mail comercial',
                      value: LicenseService.salesEmail.trim(),
                      actionLabel: 'Copiar mail',
                      onAction: () => _copyValue(
                        context,
                        LicenseService.salesEmail.trim(),
                        label: 'mail comercial',
                      ),
                    ),
                  ),
                if (licenseService.hasSalesWhatsApp)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InfoBlock(
                      title: 'WhatsApp comercial',
                      value: LicenseService.salesWhatsApp.trim(),
                      actionLabel: 'Copiar WhatsApp',
                      onAction: () => _copyValue(
                        context,
                        LicenseService.salesWhatsApp.trim(),
                        label: 'WhatsApp comercial',
                      ),
                    ),
                  ),
                if (!licenseService.isActivated) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Codigo de activacion',
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
                      labelText: 'Pega tu codigo',
                      hintText: 'CCW-XXXX-XXXX',
                    ),
                    onSubmitted: (_) => _activate(context, licenseService),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Comparte el ID de instalacion con tu contacto comercial y pega aqui el codigo que te envien. Tus datos no se borran si la prueba vence.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  _InfoBlock(
                    title: 'Licencia aplicada',
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
                        ? 'Seguir en modo lectura'
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
                            ? 'Licencia activa'
                            : _activating
                            ? 'Activando'
                            : 'Activar Windows',
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
            'Licencia activada. Caja Clara Windows ya opera normal.',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
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
