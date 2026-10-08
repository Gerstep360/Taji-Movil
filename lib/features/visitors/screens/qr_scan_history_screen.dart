import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/visit_datetime.dart';
import '../data/qr_scan_history_repository.dart';
import '../models/qr_scan_history.dart';
import '../state/qr_scan_history_controller.dart';

/// Bitácora de escaneos de portería (CU10 / RF-10).
///
/// Complementa al panel "Escaneos de esta sesión" del lector, que solo conserva
/// los últimos intentos en memoria. Aquí el registro viene del servidor, así que
/// sobrevive al cierre de la aplicación e incluye los QR desconocidos, que son
/// los intentos que el guardia necesita poder revisar.
///
/// El origen de datos se resuelve por `Provider`, igual que el resto de
/// pantallas de visitantes, para que las pruebas puedan inyectar un doble.
class QrScanHistoryScreen extends StatefulWidget {
  const QrScanHistoryScreen({super.key});

  @override
  State<QrScanHistoryScreen> createState() => _QrScanHistoryScreenState();
}

class _QrScanHistoryScreenState extends State<QrScanHistoryScreen> {
  late final QrScanHistoryController controller;

  @override
  void initState() {
    super.initState();
    controller = QrScanHistoryController(context.read<QrScanHistoryDataSource>());
    controller.load();
    controller.loadGuards();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await controller.loadGuards();
    await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final summary = controller.summary;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Bitácora de escaneos'),
              actions: [
                IconButton(
                  onPressed: controller.loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            body: Column(
              children: [
                if (controller.loading) const LinearProgressIndicator(),
                _Filters(controller: controller),
                _Summary(summary: summary, days: controller.filters.days),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      controller.error!,
                      semanticsLabel: controller.error,
                      style: const TextStyle(color: TajiColors.danger),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (controller.entries.isEmpty &&
                            !controller.loading &&
                            controller.error == null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              controller.hasActiveFilters
                                  ? 'No hay escaneos que coincidan con los filtros aplicados.'
                                  : 'Todavía no se ha escaneado ningún código QR.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final entry in controller.entries)
                          _ScanCard(entry: entry),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: controller.loading || !controller.hasPrevious
                              ? null
                              : () => controller.goToPage(controller.page.page - 1),
                          child: const Text('Anterior'),
                        ),
                        Text(
                          'Página ${controller.page.page} de '
                          '${controller.page.totalPages < 1 ? 1 : controller.page.totalPages}',
                        ),
                        TextButton(
                          onPressed: controller.loading || !controller.hasNext
                              ? null
                              : () => controller.goToPage(controller.page.page + 1),
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

/// Filtros de resultado, guardia y periodo.
class _Filters extends StatefulWidget {
  const _Filters({required this.controller});

  final QrScanHistoryController controller;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  // Los valores iniciales se toman del controlador en `initState`: un
  // inicializador de campo no puede leer `widget`.
  QrScanResult? _result;
  int? _guardId;
  int _days = 7;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _result = widget.controller.filters.result;
    _guardId = widget.controller.filters.guardStaffId;
    _days = widget.controller.filters.days;
    _search = TextEditingController(text: widget.controller.filters.search ?? '');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() => widget.controller.applyFilters(
        result: _result,
        guardStaffId: _guardId,
        days: _days,
        search: _search.text,
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<QrScanResult?>(
                    value: _result,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Resultado',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      for (final value in QrScanResult.values)
                        DropdownMenuItem(value: value, child: Text(value.label)),
                    ],
                    onChanged: (value) => setState(() => _result = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _days,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Periodo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Hoy')),
                      DropdownMenuItem(value: 7, child: Text('7 días')),
                      DropdownMenuItem(value: 30, child: Text('30 días')),
                      DropdownMenuItem(value: 90, child: Text('90 días')),
                      DropdownMenuItem(value: 365, child: Text('1 año')),
                    ],
                    onChanged: (value) => setState(() => _days = value ?? 7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Visitante, documento o motivo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('Filtrar')),
              ],
            ),
            if (widget.controller.guards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<int?>(
                  value: _guardId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Guardia',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los guardias')),
                    for (final guard in widget.controller.guards)
                      DropdownMenuItem(value: guard.id, child: Text(guard.fullName)),
                  ],
                  onChanged: (value) => setState(() => _guardId = value),
                ),
              ),
            if (widget.controller.hasActiveFilters)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _result = null;
                      _guardId = null;
                      _days = 7;
                      _search.clear();
                    });
                    widget.controller.clearFilters();
                  },
                  child: const Text('Limpiar filtros'),
                ),
              ),
          ],
        ),
      );
}

/// Totales de la ventana consultada.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.days});

  final QrScanSummary summary;
  final int days;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat(label: 'Escaneos', value: '${summary.total}', tone: TajiColors.ink),
            _Stat(
              label: 'Autorizados',
              value: '${summary.approved}',
              tone: TajiColors.success,
              hint: '${summary.successRate.toStringAsFixed(1)}% del total',
            ),
            _Stat(
              label: 'Fallidos',
              value: '${summary.failed}',
              tone: TajiColors.danger,
              hint: 'no autorizaron el ingreso',
            ),
            _Stat(
              label: 'QR no registrados',
              value: '${summary.notFound}',
              tone: TajiColors.warning,
              hint: 'códigos ajenos',
            ),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone, this.hint});

  final String label;
  final String value;
  final Color tone;
  final String? hint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: tone, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: TajiColors.muted),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tone),
            ),
            if (hint != null)
              Text(hint!, style: const TextStyle(fontSize: 9, color: TajiColors.muted)),
          ],
        ),
      );
}

/// Una fila de la bitácora.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.entry});

  final QrScanEntry entry;

  Color get _tone => switch (entry.result) {
        QrScanResult.valid => TajiColors.success,
        QrScanResult.rejected => TajiColors.danger,
        QrScanResult.notFound => TajiColors.warning,
      };

  IconData get _icon => switch (entry.result) {
        QrScanResult.valid => Icons.check_circle,
        QrScanResult.rejected => Icons.cancel,
        QrScanResult.notFound => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final visitor = entry.visitorName.isEmpty ? null : entry.visitorName;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _tone, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visitor ?? 'Sin identificar',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    entry.reasonLabel,
                    style: TextStyle(color: _tone, fontWeight: FontWeight.w600),
                  ),
                  if (entry.message.isNotEmpty)
                    Text(
                      entry.message,
                      style: const TextStyle(fontSize: 11, color: TajiColors.muted),
                    ),
                  Text(
                    [
                      if (entry.visitorDocumentNumber.isNotEmpty)
                        'CI ${entry.visitorDocumentNumber}',
                      if (entry.unitCode.isNotEmpty) 'Unidad ${entry.unitCode}',
                      if (entry.guardName.isNotEmpty) entry.guardName,
                      formatVisitDateTime(entry.occurredAt),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: TajiColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
