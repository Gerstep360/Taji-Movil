import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/camera_permission.dart';
import '../../../domain/models/security_models.dart';
import '../data/face_verification_repository.dart';
import '../state/face_verification_controller.dart';

class FaceVerificationScreen extends StatelessWidget {
  const FaceVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final repository = FaceVerificationRepository(api);

    return ChangeNotifierProvider(
      create: (_) => FaceVerificationController(repository),
      child: const _FaceVerificationView(),
    );
  }
}

class _FaceVerificationView extends StatefulWidget {
  const _FaceVerificationView();

  @override
  State<_FaceVerificationView> createState() => _FaceVerificationViewState();
}

class _FaceVerificationViewState extends State<_FaceVerificationView> {
  String _eventType = 'ENTRY';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  final _picker = ImagePicker();

  Future<void> _pickImage(FaceVerificationController controller, ImageSource source) async {
    if (source == ImageSource.camera) {
      final granted = await CameraPermissionHelper.ensureCameraPermission(context);
      if (!granted) return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        controller.setCapturedImage(base64Image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar imagen: $e')),
        );
      }
    }
  }

  void _showCaptureOptions(FaceVerificationController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Captura Biométrica Facial',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: TajiColors.primary),
                title: const Text('Tomar foto con la cámara'),
                subtitle: const Text('Usa la cámara del dispositivo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(controller, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: TajiColors.primary),
                title: const Text('Seleccionar de la galería'),
                subtitle: const Text('Elegir foto existente'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(controller, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined, color: Colors.indigo),
                title: const Text('Cargar imagen de prueba (Demo)'),
                subtitle: const Text('Para pruebas sin cámara física'),
                onTap: () {
                  Navigator.pop(ctx);
                  _generateDemoPhoto(controller);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Generar foto sintética o de demostración biométrica si no se selecciona cámara física
  void _generateDemoPhoto(FaceVerificationController controller) {
    // Imagen PNG / JPEG sintética ligera de demo
    const sampleB64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    controller.setCapturedImage(sampleB64);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FaceVerificationController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación Facial (CU17)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.clearPhoto,
            tooltip: 'Reiniciar captura',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: TajiColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TajiColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.face, color: TajiColors.primary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RF-17: Verificación Facial',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: TajiColors.primary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Captura la foto del residente y valida la coincidencia antes de dar acceso.',
                            style: TextStyle(fontSize: 12, color: TajiColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Viewport de Captura Fotográfica
              GestureDetector(
                onTap: () => _showCaptureOptions(controller),
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (controller.capturedImage != null)
                          Image.memory(
                            base64Decode(
                              controller.capturedImage!.contains(',')
                                  ? controller.capturedImage!.split(',')[1]
                                  : controller.capturedImage!,
                            ),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.person, size: 96, color: Colors.white24),
                            ),
                          )
                        else
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 56, color: Colors.white38),
                              SizedBox(height: 12),
                              Text(
                                'Toca aquí para capturar o elegir foto',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cámara frontal / trasera o galería',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),

                        // Marcos de Escaneo Facial Overlay
                        Container(
                          width: 170,
                          height: 210,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(80),
                            border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones de Acción de Captura
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCaptureOptions(controller),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capturar Foto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (controller.capturedImage != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: controller.clearPhoto,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Botón de Análisis Facial
              if (controller.capturedImage != null && controller.matchResult == null)
                FilledButton.icon(
                  onPressed: controller.isAnalyzing ? null : () => controller.runFaceMatch(),
                  icon: controller.isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.psychology),
                  label: Text(
                    controller.isAnalyzing ? 'Analizando Coincidencia...' : 'Analizar Coincidencia Facial',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

              // Muestra Mensaje de Error si ocurre
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
              ],

              // RESULTADO DEL ANÁLISIS Y CONFIRMACIÓN HUMANA
              if (controller.matchResult != null) ...[
                const SizedBox(height: 20),
                _MatchResultWidget(
                  result: controller.matchResult!,
                  eventType: _eventType,
                  notesController: _notesController,
                  isSubmitting: controller.isSubmitting,
                  onEventTypeChanged: (val) => setState(() => _eventType = val),
                  onConfirm: (confirmed) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await controller.confirmVerification(
                      humanConfirmed: confirmed,
                      eventType: _eventType,
                      notes: _notesController.text,
                    );
                    if (ok && mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(controller.statusMessage ?? 'Procesado'),
                          backgroundColor: confirmed ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ],

              if (controller.statusMessage != null && controller.matchResult == null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    controller.statusMessage!,
                    style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchResultWidget extends StatelessWidget {
  const _MatchResultWidget({
    required this.result,
    required this.eventType,
    required this.notesController,
    required this.isSubmitting,
    required this.onEventTypeChanged,
    required this.onConfirm,
  });

  final FaceMatchResultModel result;
  final String eventType;
  final TextEditingController notesController;
  final bool isSubmitting;
  final ValueChanged<String> onEventTypeChanged;
  final ValueChanged<bool> onConfirm;

  @override
  Widget build(BuildContext context) {
    final isMatch = result.result == 'MATCH';
    final isReview = result.result == 'REVIEW';
    final candidate = result.matchedResident;
    final scorePct = (result.similarityScore * 100).round();

    Color badgeColor = Colors.red;
    String badgeText = '❌ SIN COINCIDENCIA';
    if (isMatch) {
      badgeColor = Colors.green;
      badgeText = '✅ COINCIDENCIA DETECTADA';
    } else if (isReview) {
      badgeColor = Colors.orange;
      badgeText = '⚠️ REVISIÓN RECOMENDADA';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Resultado
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${(result.threshold * 100).round()}% Umbral',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gauge / Medidor Porcentaje
          Row(
            children: [
              Text(
                '$scorePct%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: TajiColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Similitud Biométrica', style: TextStyle(fontSize: 12, color: TajiColors.muted)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: result.similarityScore,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: badgeColor,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Detalles de Residente Candidato
          if (candidate != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.person, color: TajiColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${candidate.documentType}: ${candidate.documentNumber}',
                          style: const TextStyle(fontSize: 12, color: TajiColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SECCIÓN DE CONFIRMACIÓN HUMANA (RF-17)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF92400E), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Exige Confirmación Humana (RF-17)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'El guardia debe confirmar manualmente la coincidencia física.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                ),

                const SizedBox(height: 12),

                // Selector Tipo de Evento
                Row(
                  children: [
                    const Text('Acceso:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Entrada'),
                      selected: eventType == 'ENTRY',
                      onSelected: (_) => onEventTypeChanged('ENTRY'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Salida'),
                      selected: eventType == 'EXIT',
                      onSelected: (_) => onEventTypeChanged('EXIT'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observación o Nota (Opcional)',
                    hintText: 'Ej. Documento verificado manualmente...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                const SizedBox(height: 16),

                // Botones de Confirmación
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: isSubmitting ? null : () => onConfirm(true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('✅ CONFIRMAR IDENTIDAD Y DAR ACCESO'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: isSubmitting ? null : () => onConfirm(false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('❌ RECHAZAR / SIN COINCIDENCIA'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
