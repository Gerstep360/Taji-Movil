import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/visit_datetime.dart';
import '../../../domain/models/security_models.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/security_shift_repository.dart';
import '../data/shift_log_repository.dart';
import '../state/shift_log_controller.dart';

class ShiftLogsScreen extends StatefulWidget {
  const ShiftLogsScreen({super.key});
  @override
  State<ShiftLogsScreen> createState() => _ShiftLogsScreenState();
}

class _ShiftLogsScreenState extends State<ShiftLogsScreen>
    with WidgetsBindingObserver {
  late final ShiftLogController controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = ShiftLogController(
      context.read<ShiftLogDataSource>(),
      context.read<SecurityShiftDataSource>(),
    );
    unawaited(controller.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> register() async {
    controller.clearFormError();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _LogForm(controller: controller)),
    );
    if (saved == true && mounted) await controller.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Novedades de turno'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: controller.loading || controller.saving
                ? null
                : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Mi turno'),
                    selected: !controller.showHistory,
                    onSelected: controller.loading
                        ? null
                        : (_) => controller.setHistory(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Mi historial'),
                    selected: controller.showHistory,
                    onSelected: controller.loading
                        ? null
                        : (_) => controller.setHistory(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.error != null) ...[
              StatusBanner(message: controller.error!),
              const SizedBox(height: 12),
            ],
            if (controller.success != null) ...[
              StatusBanner(message: controller.success!, success: true),
              const SizedBox(height: 12),
            ],
            if (!controller.showHistory) ...[
              Text(
                controller.current == null
                    ? 'No tienes turno asignado.'
                    : 'Turno #${controller.current!.id} · ${controller.current!.statusLabel}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (controller.current?.condominiumName.isNotEmpty == true)
                Text(controller.current!.condominiumName),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('new-shift-log'),
                onPressed: controller.canRegister ? register : null,
                icon: const Icon(Icons.add),
                label: const Text('Registrar novedad'),
              ),
              if (!controller.loading && controller.current?.status != 'OPEN')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Debes iniciar tu turno para registrar novedades, incidentes o alertas.',
                  ),
                ),
              if (controller.current?.status == 'OPEN')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'La fecha, la hora y el guardia se registran automáticamente.',
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (!controller.loading && controller.entries.isEmpty)
              const Text('No hay registros para mostrar.'),
            for (final entry in controller.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(entry.typeLabel)),
                          Chip(
                            label: Text(entry.severityLabel),
                            backgroundColor:
                                ['HIGH', 'CRITICAL'].contains(entry.severity)
                                ? const Color(0xFFFEE2E2)
                                : null,
                          ),
                        ],
                      ),
                      Text('Turno #${entry.shiftId} · ${entry.guardName}'),
                      if (entry.condominiumName.isNotEmpty)
                        Text(entry.condominiumName),
                      const SizedBox(height: 8),
                      Text(entry.description),
                      const SizedBox(height: 12),
                      Text(
                        formatVisitDateTime(entry.occurredAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if (controller.pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: controller.loading || controller.page <= 1
                        ? null
                        : () =>
                              controller.refresh(nextPage: controller.page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${controller.page} / ${controller.pages}'),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed:
                        controller.loading ||
                            controller.page >= controller.pages
                        ? null
                        : () =>
                              controller.refresh(nextPage: controller.page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'Los registros se conservan sin edición ni eliminación. Las alertas se muestran al administrador; no envían notificaciones externas.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _LogForm extends StatefulWidget {
  const _LogForm({required this.controller});
  final ShiftLogController controller;
  @override
  State<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<_LogForm> {
  int? expectedShift;
  String guardName = '';
  @override
  void initState() {
    super.initState();
    expectedShift = widget.controller.current?.id;
    guardName = widget.controller.current?.guardName ?? '';
  }

  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final scroll = ScrollController();
  String type = 'NOTE';
  String severity = 'INFO';
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return PopScope(
        canPop: !controller.saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Nuevo registro')),
          body: Form(
            key: form,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Turno #$expectedShift · $guardName'),
                const SizedBox(height: 8),
                const Text(
                  'Se guardará en tu turno en curso y quedará visible para el administrador.',
                ),
                const SizedBox(height: 16),
                if (controller.formError != null) ...[
                  StatusBanner(message: controller.formError!),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  key: const Key('log-type'),
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: ShiftLogEntryModel.types.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: controller.saving
                      ? null
                      : (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('log-severity'),
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: ShiftLogEntryModel.severities.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: controller.saving
                      ? null
                      : (value) => setState(() => severity = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('log-title'),
                  controller: title,
                  enabled: !controller.saving,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Escribe un título.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('log-description'),
                  controller: description,
                  enabled: !controller.saving,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Descripción *',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Describe lo ocurrido.'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('save-shift-log'),
                  onPressed: controller.saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final saved = await controller.create(
                            type: type,
                            severity: severity,
                            title: title.text,
                            description: description.text,
                            expectedShift: expectedShift,
                          );
                          if (saved && context.mounted) {
                            Navigator.of(context).pop(true);
                          } else if (context.mounted && scroll.hasClients) {
                            await scroll.animateTo(
                              0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: Text(
                    controller.saving ? 'Guardando…' : 'Guardar registro',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
