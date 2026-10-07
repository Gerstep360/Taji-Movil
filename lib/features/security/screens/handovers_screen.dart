import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/visit_datetime.dart';
import '../../../domain/models/security_models.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/handover_repository.dart';
import '../data/security_shift_repository.dart';
import '../state/handover_controller.dart';

String _date(DateTime value) => formatVisitDateTime(value.toLocal());

class HandoversScreen extends StatefulWidget {
  const HandoversScreen({super.key});
  @override
  State<HandoversScreen> createState() => _HandoversScreenState();
}

class _HandoversScreenState extends State<HandoversScreen>
    with WidgetsBindingObserver {
  late final HandoverController controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = HandoverController(
      context.read<HandoverDataSource>(),
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

  Future<void> deliver() async {
    if (!await controller.prepare() || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _DeliveryForm(controller: controller)),
    );
  }

  Future<void> detail(int id) async {
    if (!await controller.loadDetail(id) || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ReceiptDetail(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Entrega y recepción'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed:
                controller.loading || controller.busy || controller.preparing
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
            if (controller.loading || controller.preparing)
              const LinearProgressIndicator(),
            if (controller.error != null) ...[
              StatusBanner(message: controller.error!),
              const SizedBox(height: 12),
            ],
            if (controller.success != null) ...[
              StatusBanner(message: controller.success!, success: true),
              const SizedBox(height: 12),
            ],
            Text(
              controller.current == null
                  ? 'No tienes turno asignado.'
                  : 'Mi turno #${controller.current!.id} · ${controller.current!.statusLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('prepare-handover'),
              onPressed: controller.canDeliver ? deliver : null,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Preparar entrega'),
            ),
            const SizedBox(height: 12),
            if (controller.outgoingHandover != null)
              Text(
                'Tu entrega #${controller.outgoingHandover!.id}: ${controller.outgoingHandover!.statusLabel}.',
              ),
            const Text(
              'Entregar no cierra tu turno y recibir no lo inicia. Estas acciones siguen siendo manuales en Mis turnos.',
            ),
            const SizedBox(height: 24),
            Text(
              'Mis entregas y recepciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!controller.loading && controller.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Todavía no tienes entregas ni recepciones.'),
              ),
            for (final entry in controller.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entrega #${entry.id} · ${entry.statusLabel}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.outgoingDetail?.guardName ?? 'Guardia saliente'} → ${entry.incomingDetail?.guardName ?? 'Sin destinatario'}',
                      ),
                      Text(
                        'Turnos #${entry.outgoingShiftId} → #${entry.incomingShiftId ?? '—'}',
                      ),
                      Text('Entregada: ${_date(entry.deliveredAt)}'),
                      Text(
                        entry.receivedAt == null
                            ? 'Recepción pendiente'
                            : 'Recibida: ${_date(entry.receivedAt!)}',
                      ),
                      TextButton(
                        onPressed: controller.loading || controller.busy
                            ? null
                            : () => detail(entry.id),
                        child: const Text('Ver resumen y novedades'),
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
          ],
        ),
      ),
    ),
  );
}

class _DeliveryForm extends StatefulWidget {
  const _DeliveryForm({required this.controller});
  final HandoverController controller;
  @override
  State<_DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends State<_DeliveryForm> {
  final form = GlobalKey<FormState>();
  final summary = TextEditingController();
  final scroll = ScrollController();
  int? incoming;
  late final int outgoing;
  bool reviewed = false;
  @override
  void initState() {
    super.initState();
    outgoing = widget.controller.preparedShift!;
    if (widget.controller.candidates.length == 1) {
      incoming = widget.controller.candidates.single.id;
    }
  }

  @override
  void dispose() {
    summary.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Entregar turno')),
          body: Form(
            key: form,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Turno saliente #$outgoing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'El relevo debe iniciar hasta 15 minutos antes o después de tu cierre planificado, en el mismo condominio.',
                ),
                const SizedBox(height: 16),
                if (controller.formError != null) ...[
                  StatusBanner(message: controller.formError!),
                  const SizedBox(height: 12),
                ],
                if (controller.candidates.isEmpty)
                  const StatusBanner(
                    message:
                        'No hay relevos válidos. Solicita al administrador que programe el turno correspondiente.',
                  ),
                if (controller.candidates.isNotEmpty)
                  DropdownButtonFormField<int>(
                    key: const Key('relay-shift'),
                    initialValue: incoming,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Turno de relevo *',
                    ),
                    items: controller.candidates
                        .map(
                          (shift) => DropdownMenuItem(
                            value: shift.id,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '${shift.guardName} · Turno #${shift.id}\n${_date(shift.scheduledStart)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: controller.busy
                        ? null
                        : (value) => setState(() => incoming = value),
                    validator: (value) => value == null
                        ? 'Selecciona el guardia y turno destinatarios.'
                        : null,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('handover-summary'),
                  controller: summary,
                  enabled: !controller.busy,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Resumen y pendientes *',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Escribe el resumen de tu turno.'
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Novedades del turno',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'La entrega incluirá los registros existentes al enviarla. Si registras algo después, seguirá en CU14 pero no en esta entrega.',
                ),
                for (final entry in controller.records) _LogCard(entry: entry),
                if (controller.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hay novedades registradas. Puedes entregar con tu resumen.',
                    ),
                  ),
                CheckboxListTile(
                  key: const Key('delivery-reviewed'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Revisé las novedades y el turno destinatario.',
                  ),
                  value: reviewed,
                  onChanged: controller.busy
                      ? null
                      : (value) => setState(() => reviewed = value ?? false),
                ),
                FilledButton(
                  key: const Key('deliver-handover'),
                  onPressed:
                      controller.busy ||
                          !reviewed ||
                          controller.candidates.isEmpty
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final saved = await controller.deliver(
                            incoming!,
                            summary.text,
                            outgoing: outgoing,
                          );
                          if (!context.mounted) return;
                          if (saved) {
                            Navigator.of(context).pop();
                          } else {
                            await scroll.animateTo(
                              0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: Text(
                    controller.busy ? 'Guardando…' : 'Confirmar entrega',
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

class _ReceiptDetail extends StatefulWidget {
  const _ReceiptDetail({required this.controller});
  final HandoverController controller;
  @override
  State<_ReceiptDetail> createState() => _ReceiptDetailState();
}

class _ReceiptDetailState extends State<_ReceiptDetail> {
  bool reviewed = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final entry = controller.selected!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(title: Text('Entrega #${entry.id}')),
          body: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                entry.statusLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${entry.outgoingDetail?.guardName ?? 'Guardia saliente'} → ${entry.incomingDetail?.guardName ?? 'Sin destinatario'}',
              ),
              Text(
                'Turnos #${entry.outgoingShiftId} → #${entry.incomingShiftId ?? '—'}',
              ),
              Text('Entregada: ${_date(entry.deliveredAt)}'),
              if (entry.receivedAt != null)
                Text('Recibida: ${_date(entry.receivedAt!)}'),
              const SizedBox(height: 16),
              if (controller.formError != null) ...[
                StatusBanner(message: controller.formError!),
                const SizedBox(height: 12),
              ],
              if (controller.success != null) ...[
                StatusBanner(message: controller.success!, success: true),
                const SizedBox(height: 12),
              ],
              Text(
                'Resumen y pendientes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(entry.summary),
              const SizedBox(height: 24),
              Text(
                'Novedades incluidas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final log in entry.logEntries) _LogCard(entry: log),
              if (entry.logEntries.isEmpty)
                const Text('No había novedades registradas al entregar.'),
              if (entry.status == 'PENDING') ...[
                const SizedBox(height: 16),
                const Text(
                  'Solo el guardia destinatario puede confirmar, después de iniciar su turno.',
                ),
                CheckboxListTile(
                  key: const Key('receipt-reviewed'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Revisé el resumen y las novedades de esta entrega.',
                  ),
                  value: reviewed,
                  onChanged: !controller.canReceive(entry)
                      ? null
                      : (value) => setState(() => reviewed = value ?? false),
                ),
                FilledButton(
                  key: const Key('receive-handover'),
                  onPressed: !controller.canReceive(entry) || !reviewed
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirmar recepción'),
                              content: const Text(
                                'Se registrarán tu identidad y la hora de recepción. Esta acción no inicia ni cierra turnos.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  key: const Key('confirm-receipt'),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Confirmar'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            await controller.receive(entry, reviewed: reviewed);
                            if (context.mounted && scroll.hasClients) {
                              await scroll.animateTo(
                                0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            }
                          }
                        },
                  child: Text(
                    controller.busy ? 'Guardando…' : 'Confirmar recepción',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});
  final ShiftLogEntryModel entry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
          Text('${entry.typeLabel} · ${entry.severityLabel}'),
          Text(entry.description),
          const SizedBox(height: 8),
          Text(
            _date(entry.occurredAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
