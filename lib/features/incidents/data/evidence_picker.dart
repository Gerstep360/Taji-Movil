import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/camera_permission.dart';
import '../models/incident_report.dart';

/// Fallo al obtener una evidencia, con un mensaje listo para mostrar.
class EvidencePickerException implements Exception {
  const EvidencePickerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Fuente de evidencias del formulario. Se abstrae para que las pruebas
/// simulen cámara y galería sin canales de plataforma.
abstract class EvidencePicker {
  /// Pide permiso de cámara; si se niega, ofrece abrir los ajustes.
  Future<bool> ensureCameraPermission(BuildContext context);

  /// Devuelve `null` si el usuario cancela.
  Future<EvidenceFile?> takePhoto();

  /// Fotos de la galería, como máximo [limit].
  Future<List<EvidenceFile>> pickFromGallery({required int limit});
}

/// Implementación con `image_picker`. Solo fotos: elegir PDF requeriría una
/// dependencia nueva (file_picker), así que en móvil los PDF quedan para web.
class ImagePickerEvidencePicker implements EvidencePicker {
  ImagePickerEvidencePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // Reducen el peso de fotos de cámara modernas para no superar 5 MB.
  static const _maxSide = 1920.0;
  static const _quality = 85;

  @override
  Future<bool> ensureCameraPermission(BuildContext context) =>
      CameraPermissionHelper.ensureCameraPermission(context);

  @override
  Future<EvidenceFile?> takePhoto() => _guard(() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    return file == null ? null : _read(file);
  });

  @override
  Future<List<EvidenceFile>> pickFromGallery({required int limit}) =>
      _guard(() async {
        if (limit <= 0) return const <EvidenceFile>[];
        // `pickMultiImage` exige un límite de al menos 2.
        final files = limit == 1
            ? [
                ?await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: _maxSide,
                  maxHeight: _maxSide,
                  imageQuality: _quality,
                ),
              ]
            : await _picker.pickMultiImage(
                maxWidth: _maxSide,
                maxHeight: _maxSide,
                imageQuality: _quality,
                limit: limit,
              );
        return Future.wait(files.take(limit).map(_read));
      });

  static Future<EvidenceFile> _read(XFile file) async => EvidenceFile(
    name: file.name,
    bytes: await file.readAsBytes(),
    mimeType: file.mimeType,
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      throw EvidencePickerException(switch (error.code) {
        'camera_access_denied' =>
          'Taji no tiene permiso para usar la cámara. Actívalo en los ajustes del teléfono.',
        'photo_access_denied' =>
          'Taji no tiene permiso para ver tus fotos. Actívalo en los ajustes del teléfono.',
        'no_available_camera' => 'Este dispositivo no tiene una cámara disponible.',
        _ => 'No pudimos obtener la foto. Inténtalo nuevamente.',
      });
    }
  }
}
