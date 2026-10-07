import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionHelper {
  CameraPermissionHelper._();

  /// Solicita el permiso de cámara en tiempo de ejecución.
  /// Si está denegado, ofrece abrir los ajustes del dispositivo para no bloquear al usuario.
  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;

    final result = await Permission.camera.request();
    if (result.isGranted || result.isLimited) return true;

    if (context.mounted) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: Color(0xFF0F6FFF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permiso de Cámara',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Taji requiere acceso a la cámara para escanear pases QR de portería y realizar la verificación biométrica facial.\n\n'
            '¿Deseas abrir los ajustes del sistema para habilitarlo?',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F6FFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await openAppSettings();
      }
    }
    return false;
  }
}
