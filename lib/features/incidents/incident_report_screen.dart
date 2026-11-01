import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_routes.dart';
import 'incident_report.dart';

class IncidentReportScreen extends StatelessWidget {
  const IncidentReportScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => IncidentReportController(
      IncidentReportRepository(context.read<ApiClient>()),
    )..load(),
    child: const IncidentReportView(),
  );
}

class IncidentReportView extends StatefulWidget {
  const IncidentReportView({super.key});
  @override
  State<IncidentReportView> createState() => _IncidentReportViewState();
}

class _IncidentReportViewState extends State<IncidentReportView> {
  final formKey = GlobalKey<FormState>();
  bool choosingPhotos = false;
  Future<void> pickPhotos(IncidentReportController controller) async {
    if (choosingPhotos) return;
    setState(() => choosingPhotos = true);
    try {
      final selected = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (mounted) await controller.addPhotos(selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir las fotos. Revisa los permisos de la app.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => choosingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentReportController>();
    final options = controller.options;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar incidencia'),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoute.home.path),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.code != null) ...[
                    const SizedBox(height: 35),
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF13835F),
                      size: 60,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reporte recibido',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Guarda este código para consultar cómo avanza la atención.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      controller.code!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0F6FFF),
                      ),
                    ),
                    const SizedBox(height: 25),
                    FilledButton(
                      onPressed: () => context.go(
                        '${AppRoute.incidents.path}?codigo=${Uri.encodeComponent(controller.code!)}',
                      ),
                      child: const Text('Ver mi incidencia'),
                    ),
                  ] else ...[
                    Text(
                      'Cuéntanos qué pasó',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Describe el problema y dónde sucede. El equipo revisará tu reporte y podrás seguir cada avance.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'El texto y las fotos compatibles se enviarán a NVIDIA para proponer una clasificación. No incluyas contraseñas ni datos personales.',
                    ),
                    const SizedBox(height: 12),
                    if (controller.loading) const LinearProgressIndicator(),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            controller.error!,
                            style: const TextStyle(color: Color(0xFFA72B40)),
                          ),
                        ),
                      ),
                    if (options == null && !controller.loading)
                      OutlinedButton(
                        onPressed: controller.load,
                        child: const Text('Volver a intentar'),
                      ),
                    if (options != null &&
                        (options.categories.isEmpty || options.sectors.isEmpty))
                      const Text(
                        'Falta configurar el condominio. La administración debe agregar categorías y ubicaciones para recibir reportes.',
                      ),
                    if (options != null &&
                        options.categories.isNotEmpty &&
                        options.sectors.isNotEmpty)
                      AbsorbPointer(
                        absorbing: controller.saving,
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Título (opcional)',
                                  hintText: 'Ej. Filtración en el pasillo',
                                ),
                                maxLength: 160,
                                onChanged: (value) => controller.title = value,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Descripción *',
                                  hintText: 'Qué viste, dónde y desde cuándo',
                                  alignLabelWithHint: true,
                                ),
                                minLines: 4,
                                maxLines: 7,
                                maxLength: 5000,
                                onChanged: (value) =>
                                    controller.description = value,
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                    ? null
                                    : 'Describe lo que ocurrió.',
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: controller.category,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Categoría *',
                                ),
                                items: options.categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    controller.category = value,
                                validator: (value) => value == null
                                    ? 'Selecciona una categoría.'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                value: controller.sector,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ubicación *',
                                ),
                                items: options.sectors
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          '${s.name} · ${s.code}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: controller.selectSector,
                                validator: (value) => value == null
                                    ? 'Selecciona la ubicación.'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              if (controller.sector != null) ...[
                                DropdownButtonFormField<int>(
                                  key: ValueKey('unit-${controller.sector}'),
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Unidad (opcional)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text(
                                        'Área común / no corresponde',
                                      ),
                                    ),
                                    ...controller.units.map(
                                      (u) => DropdownMenuItem(
                                        value: u.id,
                                        child: Text(u.code),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => controller.unit = value,
                                ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<int>(
                                  key: ValueKey('asset-${controller.sector}'),
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Equipo o activo (opcional)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Sin equipo asociado'),
                                    ),
                                    ...controller.assets.map(
                                      (a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          a.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      controller.asset = value,
                                ),
                                const SizedBox(height: 22),
                              ],
                              Text(
                                'Fotos de evidencia',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Opcionales · hasta ${options.maxFiles} fotos de ${(options.maxBytes / 1048576).round()} MB. No te acerques al peligro para tomar una foto.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    choosingPhotos ||
                                        controller.files.length >=
                                            options.maxFiles
                                    ? null
                                    : () => pickPhotos(controller),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: Text(
                                  choosingPhotos
                                      ? 'Abriendo fotos…'
                                      : 'Agregar fotos',
                                ),
                              ),
                              for (var i = 0; i < controller.files.length; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.image_outlined),
                                  title: Text(
                                    controller.files[i].name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip:
                                        'Quitar ${controller.files[i].name}',
                                    onPressed: () => controller.removePhoto(i),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              const Text(
                                'El código, estado y prioridad inicial se asignan automáticamente.',
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: controller.saving || choosingPhotos
                                    ? null
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          controller.submit();
                                        }
                                      },
                                child: Text(
                                  controller.saving
                                      ? 'Enviando reporte…'
                                      : 'Enviar reporte',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Si hay peligro inmediato, no esperes una respuesta de la app. Aléjate del riesgo y contacta a seguridad o a los servicios de emergencia locales.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
