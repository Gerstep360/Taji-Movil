import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_text_field.dart';
import '../../auth/models/taji_user.dart';
import '../../auth/state/auth_controller.dart';
import '../data/visitor_authorization_repository.dart';
import '../models/visitor_authorization.dart';
import '../state/visitor_authorization_controller.dart';

class VisitorAuthorizationsScreen extends StatefulWidget {
  const VisitorAuthorizationsScreen({super.key});

  @override
  State<VisitorAuthorizationsScreen> createState() =>
      _VisitorAuthorizationsScreenState();
}

class _VisitorAuthorizationsScreenState
    extends State<VisitorAuthorizationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  late final VisitorAuthorizationController _controller;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  final _searchQuery = TextEditingController();
  DateTime? _from;
  DateTime? _until;
  int? _unitId;
  int? _residentId;
  String _documentType = 'CI';

  bool get _isAdmin =>
      context.read<AuthController>().user?.isAdmin ?? false;

  bool get _canIssueQr =>
      context.read<AuthController>().user?.canIssueVisitQr ?? true;

  List<ResidentUnit> get _units {
    final residentUnits =
        context
            .read<AuthController>()
            .user
            ?.residentUnits
            .map(ResidentUnit.fromJson)
            .toList() ??
        const <ResidentUnit>[];
    return residentUnits.isNotEmpty ? residentUnits : _controller.units;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller = VisitorAuthorizationController(
      context.read<VisitorAuthorizationRepository>(),
    );
    final units = _units;
    if (units.isNotEmpty) {
      _unitId = units.first.id;
    } else {
      _loadAvailableUnits();
    }
    _controller.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _document.dispose();
    _phone.dispose();
    _reason.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUnits() async {
    await Future.wait([
      _controller.loadUnits(),
      if (_isAdmin) _controller.loadResidents(),
    ]);
    if (!mounted || _units.isEmpty) return;
    setState(() {
      _unitId = _unitId ?? _units.first.id;
      if (_isAdmin && _controller.residents.isNotEmpty) {
        _residentId = _residentId ?? _controller.residents.first.id;
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_from ?? now.add(const Duration(hours: 1)))
        : (_until ?? now.add(const Duration(hours: 3)));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate:
          initial.isBefore(
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 1)),
          )
          ? DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 1))
          : initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => isStart ? _from = result : _until = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _until == null) {
      return _message('Selecciona el periodo de validez.');
    }
    if (_unitId == null) return _message('Selecciona la unidad de destino.');
    if (_isAdmin && _residentId == null) {
      return _message('Selecciona el residente que autoriza la visita.');
    }
    try {
      final success = await _controller.add(
        VisitorAuthorizationInput(
          visitorFirstName: _firstName.text,
          visitorLastName: _lastName.text,
          documentType: _documentType,
          documentId: _document.text,
          phone: _phone.text,
          unitId: _unitId!,
          authorizedByResidentId: _isAdmin ? _residentId : null,
          reason: _reason.text,
          validFrom: _from!,
          validUntil: _until!,
        ),
      );
      if (!success) {
        return _message(_controller.error ?? 'No pudimos registrar la visita.');
      }
      _clearForm();
      _message('Visita registrada. Pase QR generado exitosamente.');
      _tabController.animateTo(0);
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    }
  }

  void _clearForm() {
    _firstName.clear();
    _lastName.clear();
    _document.clear();
    _phone.clear();
    _reason.clear();
    setState(() {
      _from = null;
      _until = null;
    });
    _formKey.currentState!.reset();
  }

  Future<void> _cancel(VisitorAuthorization authorization) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar autorización?'),
        content: Text(
          'Se cancelará la visita de ${authorization.visitorName} y su código QR quedará invalidado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: TajiColors.danger),
            child: const Text('Cancelar autorización'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await _controller.cancel(authorization.id);
    _message(
      success
          ? 'Autorización cancelada.'
          : _controller.error ?? 'No pudimos cancelar la autorización.',
    );
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _openQr(VisitorAuthorization item) =>
      context.push(AppRoute.visitQrFor(item.id), extra: item);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pases QR y Visitas (CU09)'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      bottom: TabBar(
        controller: _tabController,
        labelColor: TajiColors.primaryStrong,
        unselectedLabelColor: TajiColors.muted,
        indicatorColor: TajiColors.primary,
        indicatorWeight: 3,
        tabs: [
          Tab(
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            text: 'Pases QR (${_controller.authorizations.length})',
          ),
          const Tab(
            icon: Icon(Icons.person_add_alt_1_rounded, size: 20),
            text: 'Nueva Visita',
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => TabBarView(
          controller: _tabController,
          children: [
            // TAB 0: PASES QR ACTIVOS Y LISTA
            RefreshIndicator(
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pases QR de Acceso',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: TajiColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Toca "Ver Pase QR" para mostrarlo al guardia o compartirlo.',
                            style: TextStyle(color: TajiColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_controller.error != null && !_controller.loading) ...[
                    _ErrorBanner(
                      message: _controller.error!,
                      onRetry: _controller.load,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_controller.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_controller.hasAuthorizations)
                    _EmptyState(onCreate: () => _tabController.animateTo(1))
                  else
                    ..._controller.authorizations.map(
                      (item) => _AuthorizationCard(
                        item: item,
                        cancelling: _controller.cancellingId == item.id,
                        canIssueQr: _canIssueQr,
                        onCancel: () => _cancel(item),
                        onViewQr: () => _openQr(item),
                      ),
                    ),
                ],
              ),
            ),

            // TAB 1: FORMULARIO DE REGISTRO
            RefreshIndicator(
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    'Registrar una Visita',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: TajiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Completa los datos del visitante y su ventana de acceso.',
                    style: TextStyle(color: TajiColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TajiTextField(
                          controller: _firstName,
                          label: 'Nombre',
                          hint: 'Nombre del visitante',
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TajiTextField(
                          controller: _lastName,
                          label: 'Apellido',
                          hint: 'Apellido del visitante',
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _documentType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de documento',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'CI',
                              child: Text('Cédula de identidad (CI)'),
                            ),
                            DropdownMenuItem(
                              value: 'PASSPORT',
                              child: Text('Pasaporte'),
                            ),
                            DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                          ],
                          onChanged: (value) =>
                              setState(() => _documentType = value ?? 'CI'),
                        ),
                        const SizedBox(height: 12),
                        TajiTextField(
                          controller: _document,
                          label: 'Número de documento',
                          hint: 'Ej. 12345678',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TajiTextField(
                          controller: _phone,
                          label: 'Teléfono de contacto',
                          hint: 'Ej. 70012345',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _unitId,
                          decoration: const InputDecoration(
                            labelText: 'Unidad de destino',
                            prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                          ),
                          items: _units
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit.id,
                                  child: Text('Unidad ${unit.code}'),
                                ),
                              )
                              .toList(),
                          onChanged: _units.isEmpty
                              ? null
                              : (value) => setState(() => _unitId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona una unidad' : null,
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _residentId,
                            decoration: const InputDecoration(
                              labelText: 'Residente autorizante',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            ),
                            items: _controller.residents
                                .map(
                                  (resident) => DropdownMenuItem(
                                    value: resident.id,
                                    child: Text(
                                      resident.documentNumber.isEmpty
                                          ? resident.fullName
                                          : '${resident.fullName} (${resident.documentNumber})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _controller.residents.isEmpty
                                ? null
                                : (value) => setState(() => _residentId = value),
                            validator: (value) => value == null
                                ? 'Selecciona el residente autorizante'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TajiTextField(
                          controller: _reason,
                          label: 'Motivo de la visita',
                          hint: 'Ej. Reunión familiar, entrega...',
                          icon: Icons.notes_outlined,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Desde',
                                value: _from,
                                onTap: () => _pickDate(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateField(
                                label: 'Hasta',
                                value: _until,
                                onTap: () => _pickDate(false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _controller.saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: TajiColors.primary,
                          ),
                          icon: _controller.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _controller.saving
                                ? 'Registrando...'
                                : 'Registrar y Emitir Pase QR',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: TajiColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: TajiColors.danger, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule, size: 19),
      ),
      child: Text(
        value == null ? 'Seleccionar' : _format(value!),
        style: TextStyle(
          fontSize: 12,
          color: value == null ? TajiColors.muted : TajiColors.ink,
        ),
      ),
    ),
  );
}

class _AuthorizationCard extends StatelessWidget {
  const _AuthorizationCard({
    required this.item,
    required this.cancelling,
    required this.canIssueQr,
    required this.onCancel,
    required this.onViewQr,
  });

  final VisitorAuthorization item;
  final bool cancelling;
  final bool canIssueQr;
  final VoidCallback onCancel;
  final VoidCallback onViewQr;

  @override
  Widget build(BuildContext context) {
    final active = item.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF93C5FD) : TajiColors.border,
          width: active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: active ? const Color(0x140F6FFF) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: active ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.person_rounded,
                    color: active ? const Color(0xFF0F6FFF) : TajiColors.muted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.visitorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: TajiColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Unidad ${item.unit}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: TajiColors.ink,
                              ),
                            ),
                          ),
                          if (item.documentId.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${item.documentId}',
                              style: const TextStyle(color: TajiColors.muted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _Status(active: active, cancelled: item.isCancelled),
              ],
            ),
            const SizedBox(height: 12),
            if (item.reason.isNotEmpty) ...[
              Text(
                'Motivo: ${item.reason}',
                style: const TextStyle(color: TajiColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: TajiColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_format(item.validFrom)} — ${_format(item.validUntil)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TajiColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewQr,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6FFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    label: const Text(
                      'Ver Pase QR',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                if (!item.isCancelled) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: cancelling ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TajiColors.danger,
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: cancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TajiColors.danger),
                          )
                        : const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.active, required this.cancelled});
  final bool active;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final text = cancelled ? 'Cancelada' : active ? 'Activa' : 'Vencida';
    final bgColor = cancelled
        ? const Color(0xFFFFE4E6)
        : active
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF1F5F9);
    final textColor = cancelled
        ? const Color(0xFFBE123C)
        : active
            ? const Color(0xFF15803D)
            : const Color(0xFF64748B);
    final borderColor = cancelled
        ? const Color(0xFFFDA4AF)
        : active
            ? const Color(0xFF86EFAC)
            : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: TajiColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: Color(0xFF0F6FFF),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No tienes pases QR activos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: TajiColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Registra una autorización para emitir el código QR de acceso seguro.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: TajiColors.muted),
        ),
        if (onCreate != null) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F6FFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Registrar Nueva Visita', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    ),
  );
}

String _format(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
