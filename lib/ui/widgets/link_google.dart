import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/services/youtube_auth_service.dart';
import '/ui/screens/Library/library_controller.dart';

class LinkGoogle extends StatefulWidget {
  const LinkGoogle({super.key});

  @override
  State<LinkGoogle> createState() => _LinkGoogleState();
}

class _LinkGoogleState extends State<LinkGoogle> {
  bool isLoading = false;

  Future<void> connect() async {
    setState(() => isLoading = true);
    try {
      final auth = Get.find<YouTubeAuthService>();
      if (await auth.signIn()) {
        await Get.find<LibraryPlaylistsController>().refreshLib();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar sesión: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Iniciar sesión con Google'),
      content: const Text(
          'Se abrirá la pantalla oficial de Google. Harmony Music solicitará permiso de solo lectura para mostrar tus playlists y favoritos de YouTube.'),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : connect,
          icon: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Continuar con Google'),
        ),
      ],
    );
  }
}