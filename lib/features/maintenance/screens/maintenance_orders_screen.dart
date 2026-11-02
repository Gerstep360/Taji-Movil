import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_drawer.dart';
import '../../auth/models/taji_user.dart';
import '../../auth/state/auth_controller.dart';
import '../data/maintenance_order_repository.dart';
import '../state/maintenance_orders_controller.dart';

class MaintenanceOrdersScreen extends StatefulWidget {
  const MaintenanceOrdersScreen({super.key});

  @override
  State<MaintenanceOrdersScreen> createState() =>
      _MaintenanceOrdersScreenState();
}

class _MaintenanceOrdersScreenState extends State<MaintenanceOrdersScreen> {
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MaintenanceOrdersController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MaintenanceOrdersController>();
    final user = context.watch<AuthController>().user;
    final orders = controller.orders.where((order) {
      if (_statusFilter == 'ALL') return true;
      return order.status == _statusFilter;
    }).toList(growable: false);

    return Scaffold(
      drawer: const TajiDrawer(),
      appBar: AppBar(
        title: const Text('Órdenes de trabajo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: controller.loading || controller.busy
                ? null
                : controller.refresh,
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
                selected: _statusFilter,
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                _FeedbackBanner(
                  message: controller.error!,
                  isError: true,
                  onClose: () => setState(() => controller.error = null),
                ),
              ],
              if (controller.success != null) ...[
                const SizedBox(height: 12),
                _FeedbackBanner(
                  message: controller.success!,
                  onClose: () => setState(() => controller.success = null),
                ),
              ],
              if (controller.loading && controller.orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (orders.isEmpty)
                _EmptyState(
                  hasOrders: controller.orders.isNotEmpty,
                  canManage: user?.canManageMaintenance ?? false,
                )
              else ...[
                const SizedBox(height: 12),
                for (final order in orders)
                  _WorkOrderCard(
                    order: order,
                    busy: controller.busy,
                    canUpdate: user?.canUpdateMaintenanceOrders ?? false,
                    canAttach: user?.canAttachWorkEvidence ?? false,
                    onStatus: (status, notes) => controller.changeStatus(
                      order,
                      status: status,
                      notes: notes,
                    ),
                    onEvidence: (file, caption) =>
                        controller.uploadEvidence(
                          order,
                          file: file,
                          caption: caption,
                        ),
                  ),
              ],
              if (controller.loading && controller.orders.isNotEmpty)
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
          label: 'Pendientes',
          value: 'PENDING',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Asignadas',
          value: 'ASSIGNED',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'En progreso',
          value: 'IN_PROGRESS',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Pausadas',
          value: 'PAUSED',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Completadas',
          value: 'COMPLETED',
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

class _WorkOrderCard extends StatefulWidget {
  const _WorkOrderCard({
    required this.order,
    required this.busy,
    required this.canUpdate,
    required this.canAttach,
    required this.onStatus,
    required this.onEvidence,
  });

  final MaintenanceWorkOrder order;
  final bool busy;
  final bool canUpdate;
  final bool canAttach;
  final Future<bool> Function(String, String) onStatus;
  final Future<bool> Function(XFile, String) onEvidence;

  @override
  State<_WorkOrderCard> createState() => _WorkOrderCardState();
}

class _WorkOrderCardState extends State<_WorkOrderCard> {
  final _picker = ImagePicker();
  final _notes = TextEditingController();
  final _caption = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.publicCode,
                style: const TextStyle(
                  color: TajiColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StatusBadge(status: order.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.title,
                style: const TextStyle(
                  color: TajiColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.assetCode} · ${order.assetName}',
                style: const TextStyle(
                  color: TajiColors.primaryStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 18),
          _InfoLine(label: 'Tipo', value: _workTypeLabel(order.workType)),
          _InfoLine(
            label: 'Responsable',
            value: order.assigneeName.isNotEmpty
                ? order.assigneeName
                : order.supplierName.isNotEmpty
                ? order.supplierName
                : 'Sin asignar',
          ),
          _InfoLine(
            label: 'Programada',
            value: order.scheduledFor == null
                ? 'Sin fecha'
                : _dateLabel(order.scheduledFor!),
          ),
          if (order.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  order.description,
                  style: const TextStyle(
                    color: TajiColors.muted,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (widget.canUpdate && _availableStatuses(order.status).isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Nota de seguimiento (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final next in _availableStatuses(order.status))
                  FilledButton.tonal(
                    onPressed: widget.busy ? null : () => _changeStatus(next),
                    child: Text(_actionLabel(next)),
                  ),
              ],
            ),
          ],
          if (widget.canAttach && !_isClosed(order.status)) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Evidencias (${order.evidence.length})',
                style: const TextStyle(
                  color: TajiColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (order.evidence.isNotEmpty)
              for (final evidence in order.evidence)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.attach_file_rounded,
                    color: TajiColors.primary,
                  ),
                  title: Text(
                    evidence.caption.isEmpty
                        ? evidence.fileType
                        : evidence.caption,
                  ),
                  subtitle: Text(
                    evidence.createdAt == null
                        ? evidence.fileType
                        : '${evidence.fileType} · ${_dateLabel(evidence.createdAt!)}',
                  ),
                ),
            TextField(
              controller: _caption,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Descripción de la foto',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : _captureEvidence,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tomar foto de evidencia'),
            ),
          ] else if (order.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final evidence in order.evidence)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(evidence.caption.isEmpty ? evidence.fileType : evidence.caption),
                subtitle: Text(evidence.fileType),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeStatus(String status) async {
    final changed = await widget.onStatus(status, _notes.text);
    if (changed && mounted) _notes.clear();
  }

  Future<void> _captureEvidence() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file == null || !mounted) return;
      final added = await widget.onEvidence(file, _caption.text);
      if (added && mounted) _caption.clear();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo acceder a la cámara.')),
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(color: TajiColors.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: TajiColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
      'PENDING' => ('Pendiente', const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      'ASSIGNED' => ('Asignada', const Color(0xFF1E40AF), const Color(0xFFDBEAFE)),
      'IN_PROGRESS' => ('En progreso', const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
      'PAUSED' => ('Pausada', const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      'COMPLETED' => ('Completada', const Color(0xFF166534), const Color(0xFFDCFCE7)),
      _ => ('Cancelada', const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasOrders, required this.canManage});
  final bool hasOrders;
  final bool canManage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 70),
    child: Column(
      children: [
        const Icon(
          Icons.handyman_outlined,
          size: 44,
          color: TajiColors.primary,
        ),
        const SizedBox(height: 14),
        Text(
          hasOrders ? 'No hay órdenes con este filtro' : 'No tienes órdenes asignadas',
          style: const TextStyle(
            color: TajiColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          canManage
              ? 'Las órdenes creadas desde la Web también aparecen aquí.'
              : 'Cuando te asignen una orden, podrás dar seguimiento desde esta pantalla.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: TajiColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.onClose,
    this.isError = false,
  });
  final String message;
  final VoidCallback onClose;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF166534);
    final background = isError
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF0FDF4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: foreground,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 12),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close, color: foreground, size: 16),
          ),
        ],
      ),
    );
  }
}

bool _isClosed(String status) =>
    status == 'COMPLETED' || status == 'CANCELLED';

List<String> _availableStatuses(String current) => switch (current) {
  'ASSIGNED' => const ['IN_PROGRESS'],
  'IN_PROGRESS' => const ['PAUSED', 'COMPLETED'],
  'PAUSED' => const ['IN_PROGRESS'],
  _ => const [],
};

String _statusAction(String status) => switch (status) {
  'IN_PROGRESS' => 'Iniciar trabajo',
  'PAUSED' => 'Pausar trabajo',
  'COMPLETED' => 'Completar orden',
  _ => status,
};

String _actionLabel(String status) => _statusAction(status);

String _workTypeLabel(String type) => switch (type) {
  'PREVENTIVE' => 'Preventivo',
  'CORRECTIVE' => 'Correctivo',
  'INSPECTION' => 'Inspección',
  _ => type,
};

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
