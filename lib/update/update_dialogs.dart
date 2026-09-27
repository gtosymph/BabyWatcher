import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import 'release_info.dart';
import 'update_service.dart';

/// Vérifie la dernière release et propose la mise à jour.
/// [silent] : ne montre rien si l'app est à jour ou si la vérification échoue.
Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
  if (!UpdateService.isSupported) return;
  final service = UpdateService();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final release = await service.findUpdate();
    if (!context.mounted) return;
    if (release == null) {
      if (!silent) messenger.showSnackBar(const SnackBar(content: Text('L\'app est à jour.')));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Version ${release.version} disponible'),
        content: SingleChildScrollView(
          child: Text(release.notes.isEmpty ? 'Une nouvelle version est prête.' : release.notes),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mettre à jour')),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _InstallDialog(service: service, release: release),
      );
    }
  } catch (e) {
    if (!silent) {
      messenger.showSnackBar(SnackBar(content: Text('Vérification impossible : $e')));
    }
  }
}

class _InstallDialog extends StatefulWidget {
  final UpdateService service;
  final ReleaseInfo release;
  const _InstallDialog({required this.service, required this.release});

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog> {
  OtaEvent? _event;

  @override
  void initState() {
    super.initState();
    widget.service.install(widget.release).listen(
          (e) => setState(() => _event = e),
          onError: (Object e) => setState(() => _event = OtaEvent(OtaStatus.INTERNAL_ERROR, '$e')),
        );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final status = event?.status;
    final progress = status == OtaStatus.DOWNLOADING ? double.tryParse(event?.value ?? '') : null;
    final done = status != null && status != OtaStatus.DOWNLOADING;
    final text = switch (status) {
      null => 'Préparation…',
      OtaStatus.DOWNLOADING => 'Téléchargement… ${progress?.round() ?? 0} %',
      OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE =>
        'Android va demander de confirmer l\'installation.',
      OtaStatus.CHECKSUM_ERROR => 'Le fichier téléchargé est corrompu. Réessaie plus tard.',
      OtaStatus.PERMISSION_NOT_GRANTED_ERROR =>
        'Autorise « Installer des applis inconnues » pour BabyWatcher, puis réessaie.',
      _ => 'Erreur : ${event?.value ?? status.name}',
    };
    return AlertDialog(
      title: Text('Mise à jour ${widget.release.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!done) LinearProgressIndicator(value: progress == null ? null : progress / 100),
          const SizedBox(height: 16),
          Text(text),
        ],
      ),
      actions: [
        if (done)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}
