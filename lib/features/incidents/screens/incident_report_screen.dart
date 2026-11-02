import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/taji_button.dart';
import '../data/evidence_picker.dart';
import '../data/incident_repository.dart';
import '../models/incident_report.dart';
import '../state/incident_report_controller.dart';

/// CU18 / T114-T115: reporte de una incidencia en lenguaje natural con fotos
/// de la cámara o de la galería como evidencia.
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({
    super.key,
    required this.source,
    required this.picker,
  });

  final IncidentDataSource source;
  final EvidencePicker picker;

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  late final IncidentReportController controller;
  final _description = TextEditingController();
  final _title = TextEditingController();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    controller = IncidentReportController(widget.source)..loadOptions();
  }

  @override
  void dispose() {
    _description.dispose();
    _title.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_picking || controller.remainingEvidenceSlots == 0) return;
    setState(() => _picking = true);
    try {
      if (!await widget.picker.ensureCameraPermission(context)) return;
      final file = await widget.picker.takePhoto();
      if (file != null) controller.addEvidences([file]);
    } on EvidencePickerException catch (failure) {
      controller.reportEvidenceError(failure.message);
    } on Object {
      controller.reportEvidenceError(
        'No pudimos abrir la cámara. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final limit = controller.remainingEvidenceSlots;
    if (_picking || limit == 0) return;
    setState(() => _picking = true);
    try {
      final files = await widget.picker.pickFromGallery(limit: limit);
      if (files.isNotEmpty) controller.addEvidences(files);
    } on EvidencePickerException catch (failure) {
      controller.reportEvidenceError(failure.message);
    } on Object {
      controller.reportEvidenceError(
        'No pudimos abrir la galería. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await controller.submit(
      description: _description.text,
      title: _title.text,
    );
  }

  void _startNew() {
    _description.clear();
    _title.clear();
    controller.startNew();
  }

  void _leave() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(AppRoute.home.path);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop: !controller.submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nueva incidencia')),
        body: SafeArea(child: _body()),
      ),
    ),
  );

  Widget _body() {
    final created = controller.created;
    if (created != null) {
      return _ReportedView(
        incident: created,
        onNew: _startNew,
        onLeave: _leave,
      );
    }
    final options = controller.options;
    if (options == null) {
      if (controller.loadingOptions || controller.optionsError == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _OptionsErrorView(
        message: controller.optionsError!,
        onRetry: controller.loadOptions,
      );
    }
    return _form(options);
  }

  Widget _form(IncidentOptions options) {
    final busy = controller.submitting;
    final errors = controller.fieldErrors;
    final category = controller.selectedCategory;
    final rules = controller.rules;
    final canAdd = !busy && !_picking && controller.remainingEvidenceSlots > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const Text(
          'Cuéntanos qué ocurrió y dónde. La administración revisará tu reporte '
          'y le asignará la prioridad.',
          style: TextStyle(color: TajiColors.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('¿QUÉ PASÓ? *'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('incident-description'),
          controller: _description,
          enabled: !busy,
          minLines: 4,
          maxLines: 8,
          maxLength: IncidentReportController.maxDescription,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => controller.clearFieldError('description'),
          decoration: InputDecoration(
            hintText: 'Describe con tus palabras qué pasó',
            errorText: errors['description'],
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: const Key('incident-title'),
          controller: _title,
          enabled: !busy,
          maxLength: IncidentReportController.maxTitle,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => controller.clearFieldError('title'),
          decoration: InputDecoration(
            labelText: 'Título corto (opcional)',
            hintText: 'Ej.: Fuga de agua en el pasillo',
            errorText: errors['title'],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: const Key('incident-category'),
          initialValue: controller.categoryId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Categoría *',
            errorText: errors['category'],
          ),
          items: [
            for (final option in options.categories)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy ? null : controller.selectCategory,
        ),
        if (category != null) ...[
          const SizedBox(height: 6),
          if (category.description.isNotEmpty)
            Text(
              category.description,
              style: const TextStyle(color: TajiColors.muted, fontSize: 12.5),
            ),
          if (category.defaultPriorityName.isNotEmpty)
            Text(
              'Prioridad habitual: ${category.defaultPriorityName}',
              style: const TextStyle(color: TajiColors.muted, fontSize: 12.5),
            ),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: const Key('incident-sector'),
          initialValue: controller.sectorId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Ubicación *',
            errorText: errors['sector'],
          ),
          items: [
            for (final option in options.sectors)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy ? null : controller.selectSector,
        ),
        const SizedBox(height: 14),
        // La clave por sector reinicia el control cuando cambia la ubicación.
        KeyedSubtree(
          key: ValueKey('unit-for-${controller.sectorId}'),
          child: DropdownButtonFormField<int?>(
            key: const Key('incident-unit'),
            initialValue: controller.unitId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Unidad (opcional)',
              helperText: controller.sectorId == null
                  ? 'Primero elige la ubicación.'
                  : null,
              errorText: errors['unit'],
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sin unidad específica'),
              ),
              for (final unit in controller.availableUnits)
                DropdownMenuItem<int?>(value: unit.id, child: Text(unit.code)),
            ],
            onChanged: busy || controller.sectorId == null
                ? null
                : controller.selectUnit,
          ),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey('asset-for-${controller.sectorId}'),
          child: DropdownButtonFormField<int?>(
            key: const Key('incident-asset'),
            initialValue: controller.assetId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Equipo o bien afectado (opcional)',
              errorText: errors['asset'],
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Ninguno'),
              ),
              for (final asset in controller.availableAssets)
                DropdownMenuItem<int?>(
                  value: asset.id,
                  child: Text(asset.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: busy || controller.sectorId == null
                ? null
                : controller.selectAsset,
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('EVIDENCIAS (OPCIONAL)'),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${controller.evidences.length} de ${rules.maxFiles} archivos',
              style: const TextStyle(
                color: TajiColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '· fotos hasta ${rules.maxSizeLabel} cada una',
                style: const TextStyle(color: TajiColors.muted, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('incident-take-photo'),
                onPressed: canAdd ? _takePhoto : null,
                icon: const Icon(Icons.photo_camera_outlined, size: 19),
                label: const Text('Tomar foto'),
                style: _evidenceButtonStyle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('incident-pick-gallery'),
                onPressed: canAdd ? _pickFromGallery : null,
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const Text('Galería'),
                style: _evidenceButtonStyle,
              ),
            ),
          ],
        ),
        if (controller.evidences.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < controller.evidences.length; index++)
                _EvidenceThumbnail(
                  key: Key('incident-evidence-$index'),
                  index: index,
                  file: controller.evidences[index],
                  onRemove: busy ? null : () => controller.removeEvidence(index),
                ),
            ],
          ),
        ],
        if (controller.evidenceError != null ||
            errors['evidences'] != null) ...[
          const SizedBox(height: 10),
          StatusBanner(
            message: controller.evidenceError ?? errors['evidences']!,
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 18),
          StatusBanner(message: controller.error!),
        ],
        const SizedBox(height: 22),
        TajiButton(
          key: const Key('incident-submit'),
          label: 'Registrar incidencia',
          icon: Icons.send_rounded,
          loading: busy,
          onPressed: busy || _picking ? null : _submit,
        ),
      ],
    );
  }

  static final _evidenceButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    foregroundColor: TajiColors.primaryStrong,
    side: const BorderSide(color: TajiColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: TajiColors.muted,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    super.key,
    required this.index,
    required this.file,
    required this.onRemove,
  });

  final int index;
  final EvidenceFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    height: 92,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: TajiColors.primarySoft,
              child: file.isImage
                  ? Image.memory(
                      file.bytes,
                      fit: BoxFit.cover,
                      semanticLabel: file.name,
                      errorBuilder: (_, _, _) => const _FileIcon(),
                    )
                  : const _FileIcon(),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              key: Key('incident-evidence-remove-$index'),
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Tooltip(
                message: 'Quitar ${file.name}',
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FileIcon extends StatelessWidget {
  const _FileIcon();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.insert_drive_file_outlined,
      color: TajiColors.primaryStrong,
    ),
  );
}

class _OptionsErrorView extends StatelessWidget {
  const _OptionsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBanner(message: message),
          const SizedBox(height: 16),
          TajiButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            secondary: true,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _ReportedView extends StatelessWidget {
  const _ReportedView({
    required this.incident,
    required this.onNew,
    required this.onLeave,
  });

  final ReportedIncident incident;
  final VoidCallback onNew;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final location = [
      incident.sectorName,
      if (incident.unitCode?.isNotEmpty ?? false) incident.unitCode!,
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: TajiColors.success,
          size: 56,
        ),
        const SizedBox(height: 12),
        Text(
          'Incidencia registrada',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'Guarda este código para dar seguimiento a tu reporte.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TajiColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CÓDIGO DE SEGUIMIENTO',
                style: TextStyle(
                  color: TajiColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      incident.publicCode,
                      style: const TextStyle(
                        color: TajiColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TajiColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      incident.statusDisplay.isEmpty
                          ? incident.status
                          : incident.statusDisplay,
                      style: const TextStyle(
                        color: TajiColors.primaryStrong,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _Detail('Categoría', incident.categoryName),
              _Detail('Prioridad asignada', incident.priorityName),
              _Detail('Ubicación', location),
              if (incident.assetName?.isNotEmpty ?? false)
                _Detail('Equipo', incident.assetName!),
              _Detail('Evidencias', '${incident.evidenceCount}'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TajiButton(
          label: 'Registrar otra incidencia',
          onPressed: onNew,
        ),
        const SizedBox(height: 10),
        TajiButton(label: 'Volver', secondary: true, onPressed: onLeave),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(color: TajiColors.ink, fontSize: 13.5),
      ),
    );
  }
}
