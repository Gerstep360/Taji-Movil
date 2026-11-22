// CU27 · T121 (consulta de áreas y disponibilidad) y T122 (solicitud/cancelación).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_drawer.dart';
import '../data/reservation_repository.dart';
import '../state/reservations_controller.dart';

// ---------------------------------------------------------------- formato
const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String _two(int v) => v.toString().padLeft(2, '0');
String hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String range(DateTime a, DateTime b) => '${hm(a)} – ${hm(b)}';
String shortDay(DateTime d) => '${_weekdays[d.weekday - 1].substring(0, 3)} ${d.day} ${_months[d.month - 1]}';
String longDay(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';

String durationText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

String scheduleSummary(ReservableArea area) {
  if (area.schedules.isEmpty) return 'Abierta todo el día';
  final byDay = <int, List<String>>{};
  for (final s in area.schedules) {
    byDay.putIfAbsent(s.weekday, () => []).add('${s.opensAt}–${s.closesAt}');
  }
  final days = byDay.keys.toList()..sort();
  return days.map((d) => '${_weekdays[d].substring(0, 3)} ${byDay[d]!.join(', ')}').join(' · ');
}

({Color fg, Color bg}) statusColors(String status) => switch (status) {
  'APPROVED' => (fg: TajiColors.primaryStrong, bg: TajiColors.primarySoft),
  'PENDING' => (fg: TajiColors.warning, bg: TajiColors.warningSoft),
  'COMPLETED' => (fg: TajiColors.success, bg: TajiColors.successSoft),
  _ => (fg: TajiColors.muted, bg: const Color(0xFFF1F5F9)),
};

// ---------------------------------------------------------------- pantalla
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReservationsController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final activeCount = controller.upcoming.where((r) => r.isActive).length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const TajiDrawer(),
        appBar: AppBar(
          title: const Text('Áreas comunes'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: controller.busy ? null : controller.initialize,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.event_available_outlined), text: 'Reservar'),
              Tab(
                icon: const Icon(Icons.bookmark_border_rounded),
                text: activeCount > 0 ? 'Mis reservas ($activeCount)' : 'Mis reservas',
              ),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_BookTab(), _MineTab()]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- pestaña reservar
class _BookTab extends StatelessWidget {
  const _BookTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReservationsController>();
    final area = c.selectedArea;
    return RefreshIndicator(
      onRefresh: c.loadAreas,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _Messages(controller: c),
          if (c.loadingAreas && c.areas.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
          else if (c.areas.isEmpty)
            const _EmptyState(
              icon: Icons.park_outlined,
              title: 'No hay áreas comunes disponibles',
              text: 'Cuando la administración registre áreas comunes podrás reservarlas aquí.',
            )
          else ...[
            const _StepTitle(number: 1, text: 'Elige el área'),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.areas.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _AreaCard(
                  area: c.areas[i],
                  selected: c.areas[i].id == area?.id,
                  onTap: () => c.selectArea(c.areas[i]),
                ),
              ),
            ),
            if (area != null) _AreaDetails(area: area),
            const SizedBox(height: 18),
            const _StepTitle(number: 2, text: 'Elige el día'),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.dayOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = c.dayOptions[i];
                  return _DayChip(
                    day: day,
                    index: i,
                    selected: day == c.selectedDay,
                    onTap: () => c.selectDay(day),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _StepTitle(number: 3, text: 'Horarios libres · ${longDay(c.selectedDay)}'),
            _Availability(controller: c),
          ],
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: TajiColors.primary,
          child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TajiColors.ink)),
        ),
      ],
    ),
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.selected, required this.onTap});
  final ReservableArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? TajiColors.primary : TajiColors.border;
    return Material(
      color: selected ? TajiColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                area.bookable ? Icons.meeting_room_outlined : Icons.do_not_disturb_on_outlined,
                color: area.bookable ? TajiColors.primary : TajiColors.muted,
              ),
              const SizedBox(height: 6),
              Text(
                area.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: area.bookable ? TajiColors.ink : TajiColors.muted,
                ),
              ),
              const Spacer(),
              Text(
                area.bookable ? (area.requiresApproval ? 'Requiere aprobación' : 'Confirmación inmediata') : area.statusLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  color: !area.bookable ? TajiColors.danger : (area.requiresApproval ? TajiColors.warning : TajiColors.success),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaDetails extends StatelessWidget {
  const _AreaDetails({required this.area});
  final ReservableArea area;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (area.description.isNotEmpty)
          Text(area.description, style: const TextStyle(color: TajiColors.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _InfoLine(icon: Icons.schedule_rounded, text: scheduleSummary(area)),
            if (area.capacity != null) _InfoLine(icon: Icons.groups_outlined, text: 'Hasta ${area.capacity} personas'),
            if (area.sectorName.isNotEmpty) _InfoLine(icon: Icons.place_outlined, text: area.sectorName),
          ],
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: TajiColors.muted),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 12, color: TajiColors.muted))),
    ],
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.index, required this.selected, required this.onTap});
  final DateTime day;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = index == 0 ? 'Hoy' : (index == 1 ? 'Mañana' : _weekdays[day.weekday - 1].substring(0, 3));
    return Material(
      color: selected ? TajiColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? TajiColors.primary : TajiColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(top, style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : TajiColors.muted)),
              Text(
                '${day.day}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: selected ? Colors.white : TajiColors.ink),
              ),
              Text(_months[day.month - 1], style: TextStyle(fontSize: 10.5, color: selected ? Colors.white70 : TajiColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.controller});
  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final a = controller.availability;
    if (controller.loadingAvailability && a == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (a == null) {
      return const _Notice(icon: Icons.info_outline, text: 'Selecciona un área para ver su disponibilidad.');
    }
    final slots = a.bookable ? a.free.where((r) => startOptions(r, a.minDuration).isNotEmpty).toList() : const <TimeRange>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!a.bookable || slots.isEmpty)
          _Notice(
            icon: Icons.event_busy_outlined,
            text: a.reason.isNotEmpty ? a.reason : 'No quedan horarios libres este día.',
            warning: true,
          ),
        for (final slot in slots)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFA7F3D0)),
            ),
            color: TajiColors.successSoft,
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline, color: TajiColors.success),
              title: Text(range(slot.start, slot.end), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${durationText(slot.duration)} libres'),
              trailing: FilledButton(
                onPressed: controller.busy ? null : () => _openBookingSheet(context, slot, a),
                child: const Text('Reservar'),
              ),
              onTap: controller.busy ? null : () => _openBookingSheet(context, slot, a),
            ),
          ),
        if (a.occupied.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Ocupado', style: TextStyle(fontWeight: FontWeight.w700, color: TajiColors.muted)),
          const SizedBox(height: 6),
          for (final item in a.occupied)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: item.mine ? TajiColors.primarySoft : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isBlock ? Icons.block_outlined : (item.mine ? Icons.person_outline : Icons.lock_clock_outlined),
                    size: 16,
                    color: TajiColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(range(item.range.start, item.range.end), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.isBlock ? 'Bloqueado · ${item.label}' : '${item.label}${item.status == 'PENDING' ? ' (pendiente)' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: TajiColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _openBookingSheet(BuildContext context, TimeRange slot, AreaAvailability availability) async {
    final controller = context.read<ReservationsController>();
    final area = controller.selectedArea;
    if (area == null) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: _BookingSheet(area: area, slot: slot, availability: availability),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.success ?? 'Reserva registrada.')));
    }
  }
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.area, required this.slot, required this.availability});
  final ReservableArea area;
  final TimeRange slot;
  final AreaAvailability availability;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late final List<DateTime> _starts = startOptions(widget.slot, widget.availability.minDuration);
  late DateTime _start = _starts.first;
  late Duration _duration = _defaultDuration();
  final _purpose = TextEditingController();
  String? _error;

  List<Duration> get _durations =>
      durationOptions(widget.slot, _start, widget.availability.minDuration, widget.availability.maxDuration);

  Duration _defaultDuration() {
    final options = durationOptions(widget.slot, _start, widget.availability.minDuration, widget.availability.maxDuration);
    const preferred = Duration(hours: 1);
    return options.contains(preferred) ? preferred : options.last;
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = context.read<ReservationsController>();
    setState(() => _error = null);
    final created = await controller.create(start: _start, end: _start.add(_duration), purpose: _purpose.text);
    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = controller.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<ReservationsController>().busy;
    final end = _start.add(_duration);
    final needsApproval = widget.availability.requiresApproval;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.area.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(longDay(widget.slot.start), style: const TextStyle(color: TajiColors.muted)),
            const SizedBox(height: 16),
            const Text('Hora de inicio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _starts)
                  ChoiceChip(
                    label: Text(hm(option)),
                    selected: option == _start,
                    onSelected: busy
                        ? null
                        : (_) => setState(() {
                            _start = option;
                            final options = _durations;
                            if (!options.contains(_duration)) _duration = options.isEmpty ? widget.availability.minDuration : options.last;
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Duración', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _durations)
                  ChoiceChip(
                    label: Text(durationText(option)),
                    selected: option == _duration,
                    onSelected: busy ? null : (_) => setState(() => _duration = option),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purpose,
              maxLength: 240,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej.: Cumpleaños familiar',
                border: OutlineInputBorder(),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: needsApproval ? TajiColors.warningSoft : TajiColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${shortDay(_start)} · ${range(_start, end)} (${durationText(_duration)})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    needsApproval
                        ? 'Esta área requiere aprobación. Tu solicitud quedará pendiente hasta que la administración la revise.'
                        : 'La reserva se confirma al instante.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: TajiColors.danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _submit,
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(needsApproval ? 'Enviar solicitud' : 'Confirmar reserva'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------ pestaña mis reservas
class _MineTab extends StatefulWidget {
  const _MineTab();

  @override
  State<_MineTab> createState() => _MineTabState();
}

class _MineTabState extends State<_MineTab> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReservationsController>();
    final items = _upcoming ? c.upcoming : c.past;
    return RefreshIndicator(
      onRefresh: c.loadMine,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _Messages(controller: c),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Próximas'), icon: Icon(Icons.upcoming_outlined)),
              ButtonSegment(value: false, label: Text('Historial'), icon: Icon(Icons.history_rounded)),
            ],
            selected: {_upcoming},
            onSelectionChanged: (value) => setState(() => _upcoming = value.first),
          ),
          const SizedBox(height: 14),
          if (c.loadingMine && items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            _EmptyState(
              icon: _upcoming ? Icons.event_available_outlined : Icons.history_rounded,
              title: _upcoming ? 'No tienes reservas próximas' : 'Aún no hay historial',
              text: _upcoming
                  ? 'Ve a la pestaña “Reservar” para elegir un área y un horario.'
                  : 'Aquí verás tus reservas finalizadas, canceladas o rechazadas.',
            )
          else
            for (final item in items) _ReservationCard(reservation: item, busy: c.busy),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.busy});
  final Reservation reservation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final colors = statusColors(r.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TajiColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.areaName, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(r.statusLabel, style: TextStyle(color: colors.fg, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoLine(icon: Icons.calendar_today_outlined, text: longDay(r.start)),
            const SizedBox(height: 2),
            _InfoLine(icon: Icons.schedule_rounded, text: '${range(r.start, r.end)} · ${durationText(r.end.difference(r.start))}'),
            if (r.purpose.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('“${r.purpose}”', style: const TextStyle(color: TajiColors.muted, fontSize: 13)),
            ],
            if (r.status == 'PENDING') ...[
              const SizedBox(height: 8),
              const _Notice(icon: Icons.hourglass_top_rounded, text: 'Esperando aprobación de la administración.', warning: true),
            ],
            if (r.status == 'REJECTED' && r.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Notice(icon: Icons.info_outline, text: 'Motivo del rechazo: ${r.rejectionReason}'),
            ],
            if (r.status == 'CANCELLED' && r.cancellationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Notice(icon: Icons.info_outline, text: 'Motivo de la cancelación: ${r.cancellationReason}'),
            ],
            if (r.canCancel) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: TajiColors.danger),
                  onPressed: busy ? null : () => _confirmCancel(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar reserva'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final controller = context.read<ReservationsController>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(reservation: reservation),
    );
    if (reason == null) return; // el usuario volvió sin cancelar
    final ok = await controller.cancel(reservation, reason: reason);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
    }
  }
}

/// Devuelve el motivo (puede ser vacío) si se confirma, o `null` si se vuelve.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.reservation});
  final Reservation reservation;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    return AlertDialog(
      title: const Text('¿Cancelar la reserva?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.areaName} · ${shortDay(r.start)} · ${range(r.start, r.end)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 240,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TajiColors.danger),
          onPressed: () => Navigator.pop(context, _reason.text),
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- comunes
class _Messages extends StatelessWidget {
  const _Messages({required this.controller});
  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final message = controller.error;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: TajiColors.dangerSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TajiColors.danger.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: TajiColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: TajiColors.danger, fontSize: 12.5))),
            IconButton(
              tooltip: 'Cerrar',
              visualDensity: VisualDensity.compact,
              onPressed: controller.clearMessages,
              icon: const Icon(Icons.close, size: 18, color: TajiColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.warning = false});
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warning ? TajiColors.warningSoft : TajiColors.canvas,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: warning ? TajiColors.warning : TajiColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 44, color: TajiColors.muted),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: TajiColors.muted)),
      ],
    ),
  );
}
