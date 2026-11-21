import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_drawer.dart';
import '../state/community_areas_controller.dart';

/// CU26 / T121: consulta de áreas comunes y su disponibilidad.
///
/// Lista de tarjetas con nombre, capacidad, estado, horarios de atención y
/// bloqueos por mantenimiento vigentes o programados. Es de solo lectura:
/// la administración de las áreas vive en el módulo de gestión.
class CommunityAreasScreen extends StatefulWidget {
  const CommunityAreasScreen({super.key});

  @override
  State<CommunityAreasScreen> createState() => _CommunityAreasScreenState();
}

class _CommunityAreasScreenState extends State<CommunityAreasScreen> {
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityAreasController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CommunityAreasController>();
    final entries = controller.entries
        .where((entry) => switch (_filter) {
          'AVAILABLE' => _isEffectivelyAvailable(entry),
          'MAINTENANCE' =>
            entry.area.status == 'MAINTENANCE' ||
                entry.area.status == 'UNAVAILABLE',
          'BLOCKED' => entry.activeBlock != null,
          _ => true,
        })
        .toList(growable: false);

    return Scaffold(
      drawer: const TajiDrawer(),
      appBar: AppBar(
        title: const Text('Áreas comunes y disponibilidad'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: controller.loading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _FilterBar(
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(
                  message: controller.error!,
                  onRetry: controller.refresh,
                ),
              ],
              if (controller.loading && controller.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (entries.isEmpty)
                _EmptyState(
                  hasEntries: controller.entries.isNotEmpty,
                  filtered: _filter != 'ALL',
                )
              else ...[
                const SizedBox(height: 12),
                for (final entry in entries)
                  _AreaCard(
                    key: ValueKey('area-${entry.area.id}'),
                    entry: entry,
                  ),
              ],
              if (controller.loading && controller.entries.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isEffectivelyAvailable(AreaAvailability entry) =>
      entry.area.status == 'AVAILABLE' && entry.activeBlock == null;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _FilterChip(
          label: 'Todas',
          value: 'ALL',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Disponibles',
          value: 'AVAILABLE',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'En mantenimiento',
          value: 'MAINTENANCE',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Bloqueadas',
          value: 'BLOCKED',
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onChanged(value),
      selectedColor: TajiColors.primarySoft,
      labelStyle: TextStyle(
        color: selected == value ? TajiColors.primaryStrong : TajiColors.ink,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected == value
            ? TajiColors.primary.withValues(alpha: .28)
            : const Color(0xFFE2E8F0),
      ),
    ),
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({super.key, required this.entry});
  final AreaAvailability entry;

  @override
  Widget build(BuildContext context) {
    final area = entry.area;
    final activeBlock = entry.activeBlock;
    final upcomingBlock = entry.upcomingBlock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: activeBlock != null
              ? const Color(0xFFF3C0C0)
              : const Color(0xFFE2E8F0),
          width: activeBlock != null ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: TajiColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.park_outlined,
                    color: TajiColors.primaryStrong,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.name.isEmpty ? 'Área común #${area.id}' : area.name,
                        style: const TextStyle(
                          color: TajiColors.ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_outlined,
                            size: 14,
                            color: TajiColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            area.capacity == null
                                ? 'Capacidad no definida'
                                : 'Capacidad: ${area.capacity} '
                                      '${area.capacity == 1 ? 'persona' : 'personas'}',
                            style: const TextStyle(
                              color: TajiColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: area.status),
              ],
            ),
            if (area.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                area.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TajiColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
            if (area.requiresApproval) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 13,
                      color: TajiColors.muted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Las reservas requieren aprobación',
                      style: TextStyle(
                        color: TajiColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 22),
            const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: TajiColors.muted),
                SizedBox(width: 6),
                Text(
                  'Horarios de atención',
                  style: TextStyle(
                    color: TajiColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _SchedulesSection(entry: entry),
            if (activeBlock != null) ...[
              const SizedBox(height: 10),
              _ActiveBlockBanner(
                blockReason: activeBlock.reason,
                from: activeBlock.blockedFrom,
                until: activeBlock.blockedUntil,
              ),
            ] else if (upcomingBlock != null) ...[
              const SizedBox(height: 10),
              _UpcomingBlockBanner(
                blockReason: upcomingBlock.reason,
                from: upcomingBlock.blockedFrom,
                until: upcomingBlock.blockedUntil,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchedulesSection extends StatelessWidget {
  const _SchedulesSection({required this.entry});
  final AreaAvailability entry;

  @override
  Widget build(BuildContext context) {
    if (entry.detailsUnavailable) {
      return _DetailNote(
        icon: Icons.warning_amber_rounded,
        text: 'No se pudieron cargar los horarios y bloqueos de esta área. '
            'Intenta actualizar.',
        color: TajiColors.warning,
        background: TajiColors.warningSoft,
      );
    }
    final schedules = entry.activeSchedules;
    if (schedules.isEmpty) {
      return const _DetailNote(
        icon: Icons.event_busy_outlined,
        text: 'Sin horarios de atención publicados.',
        color: TajiColors.muted,
        background: Color(0xFFF1F5F9),
      );
    }
    return Column(
      children: [
        for (final schedule in schedules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _weekdayName(schedule.weekday),
                    style: const TextStyle(
                      color: TajiColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${schedule.opensAt} - ${schedule.closesAt}',
                  style: const TextStyle(
                    color: TajiColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActiveBlockBanner extends StatelessWidget {
  const _ActiveBlockBanner({
    required this.blockReason,
    required this.from,
    required this.until,
  });

  final String blockReason;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: TajiColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF1B6BD)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.block_rounded, color: TajiColors.danger, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bloqueo activo — no disponible',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                blockReason.isEmpty ? 'El área está bloqueada.' : blockReason,
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Desde ${_dateTimeLabel(from)} hasta ${_dateTimeLabel(until)}',
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _UpcomingBlockBanner extends StatelessWidget {
  const _UpcomingBlockBanner({
    required this.blockReason,
    required this.from,
    required this.until,
  });

  final String blockReason;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: TajiColors.warningSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEAD08A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.engineering_outlined,
          color: TajiColors.warning,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bloqueo programado',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                blockReason.isEmpty
                    ? 'El área estará bloqueada por mantenimiento.'
                    : blockReason,
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Del ${_dateTimeLabel(from)} al ${_dateTimeLabel(until)}',
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailNote extends StatelessWidget {
  const _DetailNote({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'AVAILABLE' => (
        'Disponible',
        const Color(0xFF166534),
        const Color(0xFFDCFCE7),
      ),
      'UNAVAILABLE' => (
        'No disponible',
        const Color(0xFF991B1B),
        const Color(0xFFFEE2E2),
      ),
      'MAINTENANCE' => (
        'En mantenimiento',
        const Color(0xFF92400E),
        const Color(0xFFFEF3C7),
      ),
      'INACTIVE' => (
        'Inactiva',
        const Color(0xFF475569),
        const Color(0xFFF1F5F9),
      ),
      _ => (status.isEmpty ? 'Sin estado' : status, TajiColors.muted, const Color(0xFFF1F5F9)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasEntries, required this.filtered});
  final bool hasEntries;
  final bool filtered;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 70),
    child: Column(
      children: [
        const Icon(
          Icons.park_outlined,
          size: 44,
          color: TajiColors.primary,
        ),
        const SizedBox(height: 14),
        Text(
          filtered
              ? 'Ningún área coincide con este filtro'
              : 'No hay áreas comunes registradas',
          style: const TextStyle(
            color: TajiColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasEntries
              ? 'Prueba con otro filtro o actualiza la consulta.'
              : 'Cuando la administración publique áreas comunes, aparecerán aquí '
                    'con sus horarios y disponibilidad.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: TajiColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFB91C1C).withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB91C1C),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Reintentar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

String _weekdayName(int weekday) {
  // El backend guarda el weekday estilo Python/Django: 0 = lunes … 6 = domingo.
  // Tolera 7 como domingo por si llegara el formato ISO.
  const names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  if (weekday == 7) return 'Domingo';
  if (weekday >= 0 && weekday < names.length) return names[weekday];
  return 'Día ${weekday + 1}';
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
