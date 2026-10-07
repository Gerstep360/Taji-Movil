import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';

import '../../../core/utils/visit_datetime.dart';
import '../../../domain/models/security_models.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/security_shift_repository.dart';
import '../state/security_shift_controller.dart';

class SecurityShiftsScreen extends StatefulWidget {
  const SecurityShiftsScreen({super.key});

  @override
  State<SecurityShiftsScreen> createState() => _SecurityShiftsScreenState();
}

class _SecurityShiftsScreenState extends State<SecurityShiftsScreen>
    with WidgetsBindingObserver {
  late final SecurityShiftController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SecurityShiftController(
      context.read<SecurityShiftDataSource>(),
    );
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm(bool starting) async {
    _controller.clearActionError();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ShiftActionDialog(controller: _controller, starting: starting),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Mis turnos'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _controller.loading || _controller.busy
                  ? null
                  : _controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mi turno', icon: Icon(Icons.schedule)),
              Tab(text: 'Próximos', icon: Icon(Icons.event)),
              Tab(text: 'Historial', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_controller.loading) const LinearProgressIndicator(),
            if (_controller.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatusBanner(message: _controller.error!),
              ),
            if (_controller.success != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatusBanner(
                  message: _controller.success!,
                  success: true,
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _currentTab(),
                  _listTab(
                    _controller.upcoming,
                    'No tienes próximos turnos programados.',
                  ),
                  _listTab(
                    _controller.history,
                    'No tienes turnos en el historial.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _scrollable(List<Widget> children) => RefreshIndicator(
    onRefresh: _controller.refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    ),
  );

  Widget _currentTab() {
    final shift = _controller.currentShift;
    if (shift == null) {
      return _scrollable([
        if (!_controller.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              _controller.currentMessage.isEmpty
                  ? 'No tienes un turno asignado para hoy.'
                  : _controller.currentMessage,
              textAlign: TextAlign.center,
            ),
          ),
      ]);
    }
    final blockReason = shift.startBlockReason(_controller.now);
    return _scrollable([
      Text('Mi turno actual', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      _shiftCard(shift),
      TextButton.icon(
        onPressed: () => context.push(AppRoute.shiftLogs.path),
        icon: const Icon(Icons.edit_note),
        label: const Text('Novedades, incidentes y alertas'),
      ),
      const SizedBox(height: 16),
      if (shift.status == 'SCHEDULED') ...[
        FilledButton.icon(
          key: const Key('start-shift'),
          onPressed: _controller.canStart ? () => _confirm(true) : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Iniciar turno'),
        ),
        if (blockReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(blockReason),
          if (_controller.now.isBefore(shift.startAllowedAt))
            Text('Habilitado desde ${_date(shift.startAllowedAt)}.'),
        ],
      ],
      if (shift.status == 'OPEN')
        FilledButton.icon(
          key: const Key('close-shift'),
          onPressed: _controller.canClose ? () => _confirm(false) : null,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Cerrar turno'),
        ),
    ]);
  }

  Widget _listTab(List<SecurityShiftModel> shifts, String emptyMessage) =>
      _scrollable([
        if (shifts.isEmpty && !_controller.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(emptyMessage, textAlign: TextAlign.center),
          ),
        for (final shift in shifts) ...[
          _shiftCard(shift),
          const SizedBox(height: 12),
        ],
      ]);

  Widget _shiftCard(SecurityShiftModel shift) {
    final notice = shift.timingNotice(_controller.now);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turno #${shift.id} · ${shift.statusLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (shift.guardName.isNotEmpty) Text(shift.guardName),
            if (shift.condominiumName.isNotEmpty) Text(shift.condominiumName),
            const Divider(height: 24),
            _field('Inicio programado', _date(shift.scheduledStart)),
            _field('Fin programado', _date(shift.scheduledEnd)),
            _field(
              'Apertura real',
              shift.openedAt == null ? 'Pendiente' : _date(shift.openedAt!),
            ),
            _field(
              'Cierre real',
              shift.closedAt == null ? 'Pendiente' : _date(shift.closedAt!),
            ),
            if (notice.isNotEmpty) ...[
              const SizedBox(height: 8),
              StatusBanner(message: notice, info: shift.status == 'CLOSED'),
            ],
            if (shift.observation.isNotEmpty)
              _field('Observación administrativa', shift.observation),
            if (shift.openingNotes.isNotEmpty)
              _field('Notas de apertura', shift.openingNotes),
            if (shift.closingNotes.isNotEmpty)
              _field('Motivo / notas de cierre', shift.closingNotes),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value),
      ],
    ),
  );

  String _date(DateTime value) => formatVisitDateTime(value.toLocal());
}

class _ShiftActionDialog extends StatefulWidget {
  const _ShiftActionDialog({required this.controller, required this.starting});
  final SecurityShiftController controller;
  final bool starting;

  @override
  State<_ShiftActionDialog> createState() => _ShiftActionDialogState();
}

class _ShiftActionDialogState extends State<_ShiftActionDialog> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final requiredReason = !widget.starting && controller.closeReasonRequired;
      return PopScope(
        canPop: !controller.busy,
        child: AlertDialog(
          title: Text(widget.starting ? 'Iniciar turno' : 'Cerrar turno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.starting
                      ? 'Se registrará tu hora real de apertura.'
                      : requiredReason
                      ? 'El cierre es anticipado o posterior al horario. El motivo quedará registrado para el administrador.'
                      : 'Se registrará tu hora real de cierre.',
                ),
                const SizedBox(height: 16),
                if (controller.actionError != null) ...[
                  StatusBanner(message: controller.actionError!),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const Key('shift-action-notes'),
                  controller: _notes,
                  enabled: !controller.busy,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: requiredReason
                        ? 'Motivo del cierre (obligatorio)'
                        : 'Notas (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: controller.busy
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-shift-action'),
              onPressed:
                  controller.busy ||
                      (widget.starting && !controller.canStart) ||
                      (!widget.starting && !controller.canClose) ||
                      (requiredReason && _notes.text.trim().isEmpty)
                  ? null
                  : () async {
                      final saved = widget.starting
                          ? await controller.start(notes: _notes.text)
                          : await controller.close(notes: _notes.text);
                      if (saved && context.mounted) Navigator.of(context).pop();
                    },
              child: Text(controller.busy ? 'Guardando…' : 'Confirmar'),
            ),
          ],
        ),
      );
    },
  );
}
