import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_text_field.dart';
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
    extends State<VisitorAuthorizationsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final VisitorAuthorizationController _controller;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _from;
  DateTime? _until;
  int? _unitId;
  int? _residentId;
  String _documentType = 'CI';

  bool get _isAdmin =>
      context.read<AuthController>().user?.role?.slug == 'administrador';

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
    _controller.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _document.dispose();
    _phone.dispose();
    _reason.dispose();
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
      // El emulador puede reportar el cambio de día con una zona horaria
      // distinta. Permitimos el día anterior para que el usuario pueda
      // corregir manualmente la fecha local.
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
      _message('Visita registrada y autorizada correctamente.');
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
          'Se cancelará la visita de ${authorization.visitorName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Autorizar visitas'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Registrar una visita',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              const Text(
                'Completa los datos y define cuándo estará autorizada.',
              ),
              if (_controller.error != null && !_controller.loading) ...[
                const SizedBox(height: 10),
                _ErrorBanner(
                  message: _controller.error!,
                  onRetry: _controller.load,
                ),
              ],
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
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de documento',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CI',
                          child: Text('Cédula de identidad'),
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
                      label: 'Teléfono',
                      hint: 'Teléfono del visitante',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _unitId,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                      ),
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.code),
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
                        initialValue: _residentId,
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
                                      : '${resident.fullName} · ${resident.documentNumber}',
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
                      label: 'Motivo',
                      hint: 'Motivo de la visita',
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
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _controller.saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: _controller.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _controller.saving
                            ? 'Registrando...'
                            : 'Registrar y autorizar',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis autorizaciones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_controller.authorizations.length}',
                    style: const TextStyle(color: TajiColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_controller.loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_controller.loading && !_controller.hasAuthorizations)
                const _EmptyState(),
              if (!_controller.loading)
                ..._controller.authorizations.map(
                  (item) => _AuthorizationCard(
                    item: item,
                    cancelling: _controller.cancellingId == item.id,
                    onCancel: () => _cancel(item),
                  ),
                ),
            ],
          ),
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
    required this.onCancel,
  });

  final VisitorAuthorization item;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final active = item.isActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.visitorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                _Status(active: active, cancelled: item.isCancelled),
              ],
            ),
            if (item.documentId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Documento: ${item.documentId}',
                style: const TextStyle(color: TajiColors.muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              '${item.unit} · ${item.reason}',
              style: const TextStyle(color: TajiColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              'Válida: ${_format(item.validFrom)} — ${_format(item.validUntil)}',
              style: const TextStyle(fontSize: 11),
            ),
            if (!item.isCancelled)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: cancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close, size: 16),
                  label: const Text('Cancelar'),
                ),
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
  Widget build(BuildContext context) => Text(
    cancelled
        ? 'Cancelada'
        : active
        ? 'Activa'
        : 'Vencida',
    style: TextStyle(
      color: cancelled || !active ? TajiColors.muted : TajiColors.success,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: TajiColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(
          Icons.event_available_outlined,
          color: TajiColors.primary,
          size: 32,
        ),
        SizedBox(height: 8),
        Text('Aún no tienes visitas autorizadas'),
      ],
    ),
  );
}

String _format(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
