import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/visit_datetime.dart';
import '../../../domain/models/access_event_models.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/access_event_repository.dart';
import '../state/access_events_controller.dart';

class AccessEventsScreen extends StatefulWidget {
  const AccessEventsScreen({super.key});

  @override
  State<AccessEventsScreen> createState() => _AccessEventsScreenState();
}

class _AccessEventsScreenState extends State<AccessEventsScreen>
    with WidgetsBindingObserver {
  late final AccessEventsController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AccessEventsController(context.read<AccessEventDataSource>());
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
    final saved = await context.push<bool>(AppRoute.newAccessEvent.path);
    if (saved == true && mounted) await controller.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Control de accesos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: controller.loading
                ? null
                : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-access-event'),
        onPressed: controller.canRegister ? register : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar acceso'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
          children: [
            Text(
              'SEGURIDAD · CU11',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Entradas, salidas y denegaciones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: TajiColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cada movimiento queda asociado a la persona, su destino y el guardia de turno.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _EventFilter(
              selected: controller.eventType,
              enabled: !controller.loading,
              onChanged: controller.filterBy,
            ),
            const SizedBox(height: 12),
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.error != null) ...[
              StatusBanner(message: controller.error!),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.loading ? null : controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
            if (!controller.loading &&
                controller.error == null &&
                controller.events.isEmpty)
              _EmptyEvents(onRegister: controller.canRegister ? register : null),
            for (final event in controller.events)
              _AccessEventCard(event: event),
            if (controller.pages > 1)
              _Pagination(
                page: controller.page,
                pages: controller.pages,
                enabled: !controller.loading,
                onPrevious: () => controller.refresh(nextPage: controller.page - 1),
                onNext: () => controller.refresh(nextPage: controller.page + 1),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EventFilter extends StatelessWidget {
  const _EventFilter({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _filter('Todos', null),
      _filter('Entrada', 'ENTRY'),
      _filter('Salida', 'EXIT'),
      _filter('Denegado', 'DENIED'),
    ],
  );

  Widget _filter(String label, String? value) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: enabled ? (_) => onChanged(value) : null,
  );
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents({required this.onRegister});

  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TajiColors.border),
    ),
    child: Column(
      children: [
        const Icon(Icons.door_front_door_outlined, size: 34, color: TajiColors.muted),
        const SizedBox(height: 10),
        Text(
          'No hay eventos para mostrar',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        const Text(
          'Registra la primera entrada, salida o denegación del turno.',
          textAlign: TextAlign.center,
        ),
        if (onRegister != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar evento'),
          ),
        ],
      ],
    ),
  );
}

class _AccessEventCard extends StatelessWidget {
  const _AccessEventCard({required this.event});

  final AccessEventItemModel event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.eventType) {
      'ENTRY' => TajiColors.success,
      'EXIT' => TajiColors.primaryStrong,
      _ => TajiColors.danger,
    };
    final softColor = switch (event.eventType) {
      'ENTRY' => TajiColors.successSoft,
      'EXIT' => TajiColors.primarySoft,
      _ => TajiColors.dangerSoft,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: softColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.eventTypeLabel,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  event.validationResultLabel,
                  style: TextStyle(
                    color: event.validationResult == 'REJECTED'
                        ? TajiColors.danger
                        : TajiColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              event.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (event.visitorDocumentNumber.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Carnet: ${event.visitorDocumentNumber}'),
            ],
            if (event.destination.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.home_outlined, size: 18, color: TajiColors.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Destino: ${event.destination}')),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${formatVisitDateTime(event.occurredAt.toLocal())} · ${event.validationMethodLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (event.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.notes, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pages,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pages;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        tooltip: 'Página anterior',
        onPressed: enabled && page > 1 ? onPrevious : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text('$page de $pages'),
      IconButton(
        tooltip: 'Página siguiente',
        onPressed: enabled && page < pages ? onNext : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

enum _PersonMode { registered, visitor }

class AccessEventFormScreen extends StatefulWidget {
  const AccessEventFormScreen({super.key, required this.source});

  final AccessEventDataSource source;

  @override
  State<AccessEventFormScreen> createState() => _AccessEventFormScreenState();
}

class _AccessEventFormScreenState extends State<AccessEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personSearch = TextEditingController();
  final _unitSearch = TextEditingController();
  final _visitorName = TextEditingController();
  final _visitorDocument = TextEditingController();
  final _notes = TextEditingController();
  Timer? _personDebounce;
  Timer? _unitDebounce;
  int _personSearchVersion = 0;
  int _unitSearchVersion = 0;
  late final AccessEventRegistrationController registration;
  _PersonMode _personMode = _PersonMode.registered;
  AccessPersonOptionModel? _person;
  AccessUnitOptionModel? _unit;
  List<AccessPersonOptionModel> _people = [];
  List<AccessUnitOptionModel> _units = [];
  bool _searchingPeople = false;
  bool _searchingUnits = false;
  bool _saving = false;
  String _eventType = 'ENTRY';
  String _validationMethod = 'MANUAL';
  String? _error;

  @override
  void initState() {
    super.initState();
    registration = AccessEventRegistrationController(widget.source);
  }

  @override
  void dispose() {
    _personDebounce?.cancel();
    _unitDebounce?.cancel();
    _personSearch.dispose();
    _unitSearch.dispose();
    _visitorName.dispose();
    _visitorDocument.dispose();
    _notes.dispose();
    registration.dispose();
    super.dispose();
  }

  void _setPersonMode(_PersonMode mode) {
    _personDebounce?.cancel();
    _personSearchVersion++;
    setState(() {
      _personMode = mode;
      _person = null;
      _people = [];
      _searchingPeople = false;
      _error = null;
    });
    _personSearch.clear();
    _visitorName.clear();
    _visitorDocument.clear();
  }

  void _searchPeople(String value) {
    _personDebounce?.cancel();
    final version = ++_personSearchVersion;
    setState(() {
      _person = null;
      _people = [];
      _error = null;
    });
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _searchingPeople = false);
      return;
    }
    _personDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || version != _personSearchVersion) return;
      setState(() => _searchingPeople = true);
      try {
        final result = await widget.source.searchPeople(query);
        if (mounted && version == _personSearchVersion) {
          setState(() => _people = result);
        }
      } on Object catch (failure) {
        if (mounted && version == _personSearchVersion) {
          setState(() => _error = _failureMessage(failure));
        }
      } finally {
        if (mounted && version == _personSearchVersion) {
          setState(() => _searchingPeople = false);
        }
      }
    });
  }

  void _searchUnits(String value) {
    _unitDebounce?.cancel();
    final version = ++_unitSearchVersion;
    setState(() {
      _unit = null;
      _units = [];
      _error = null;
    });
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchingUnits = false);
      return;
    }
    _unitDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || version != _unitSearchVersion) return;
      setState(() => _searchingUnits = true);
      try {
        final result = await widget.source.searchUnits(query);
        if (mounted && version == _unitSearchVersion) {
          setState(() => _units = result);
        }
      } on Object catch (failure) {
        if (mounted && version == _unitSearchVersion) {
          setState(() => _error = _failureMessage(failure));
        }
      } finally {
        if (mounted && version == _unitSearchVersion) {
          setState(() => _searchingUnits = false);
        }
      }
    });
  }

  String _failureMessage(Object failure) {
    if (failure is ApiFailure) {
      final fieldMessages = failure.fields.values
          .expand((messages) => messages)
          .join(' ');
      return fieldMessages.isEmpty ? failure.displayMessage : fieldMessages;
    }
    return 'No pudimos completar la búsqueda. Intenta de nuevo.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_personMode == _PersonMode.registered && _person == null) {
      setState(() => _error = 'Selecciona una persona de los resultados.');
      return;
    }
    if (_unit == null) {
      setState(() => _error = 'Selecciona la casa o unidad de destino.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await registration.create(
      isRegistered: _personMode == _PersonMode.registered,
      personId: _person?.id,
      visitorName: _visitorName.text,
      visitorDocumentNumber: _visitorDocument.text,
      unitId: _unit?.id,
      eventType: _eventType,
      validationMethod: _validationMethod,
      notes: _notes.text,
    );
    if (!mounted) return;
    if (saved) {
      setState(() => _saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      context.pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = registration.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Registrar acceso')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'PERSONA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_PersonMode>(
              key: const Key('access-person-mode'),
              segments: const [
                ButtonSegment(
                  value: _PersonMode.registered,
                  icon: Icon(Icons.person_search_rounded),
                  label: Text('Registrada'),
                ),
                ButtonSegment(
                  value: _PersonMode.visitor,
                  icon: Icon(Icons.person_add_alt_rounded),
                  label: Text('Visitante nuevo'),
                ),
              ],
              selected: {_personMode},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => _setPersonMode(selection.first),
            ),
            const SizedBox(height: 16),
            if (_personMode == _PersonMode.registered) ...[
              TextField(
                key: const Key('access-person-search'),
                controller: _personSearch,
                onChanged: _searchPeople,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar por nombre o carnet',
                  hintText: 'Escribe al menos 2 caracteres',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchingPeople
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_people.isNotEmpty) ...[
                const SizedBox(height: 8),
                _LookupPanel(
                  children: _people.take(6).map((person) {
                    final selected = _person?.id == person.id;
                    return _LookupTile(
                      key: Key('access-person-${person.id}'),
                      title: person.fullName,
                        subtitle:
                          'Carnet: ${person.documentNumber.isEmpty ? 'No registrado' : person.documentNumber}',
                      details: person.units.isEmpty
                          ? null
                          : 'Unidades: ${person.units.map((unit) => unit.code).join(', ')}',
                      selected: selected,
                      onTap: () => setState(() {
                        _person = person;
                        _error = null;
                      }),
                    );
                  }).toList(),
                ),
              ] else if (_personSearch.text.trim().length >= 2 && !_searchingPeople) ...[
                const SizedBox(height: 8),
                const Text(
                  'No encontramos resultados. Si es una persona nueva, cambia a “Visitante nuevo”.',
                ),
              ],
              if (_person != null) ...[
                const SizedBox(height: 8),
                _SelectedSummary(
                  label: 'Persona seleccionada',
                    value:
                      '${_person!.fullName} · CI ${_person!.documentNumber.isEmpty ? 'no registrado' : _person!.documentNumber}',
                  onChange: () => setState(() {
                    _person = null;
                    _error = null;
                  }),
                ),
              ],
            ] else ...[
              TextFormField(
                key: const Key('access-visitor-name'),
                controller: _visitorName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 220,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre del visitante.'
                    : null,
              ),
              TextFormField(
                key: const Key('access-visitor-document'),
                controller: _visitorDocument,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Número de carnet',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el número de carnet.'
                    : null,
              ),
              const Text(
                'Estos datos se guardan en el evento; no crean una cuenta ni un residente.',
                style: TextStyle(color: TajiColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'DESTINO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('access-unit-search'),
              controller: _unitSearch,
              onChanged: _searchUnits,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Buscar casa o unidad',
                hintText: 'Número, bloque o sector',
                prefixIcon: const Icon(Icons.home_outlined),
                suffixIcon: _searchingUnits
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_units.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LookupPanel(
                children: _units.take(6).map((unit) {
                  final selected = _unit?.id == unit.id;
                  return _LookupTile(
                    key: Key('access-unit-${unit.id}'),
                    title: unit.code,
                    subtitle: unit.type,
                    details: unit.sector.isEmpty ? null : unit.sector,
                    selected: selected,
                    onTap: () => setState(() {
                      _unit = unit;
                      _error = null;
                    }),
                  );
                }).toList(),
              ),
            ] else if (_unitSearch.text.trim().isNotEmpty && !_searchingUnits) ...[
              const SizedBox(height: 8),
              const Text('No se encontraron unidades activas.'),
            ],
            if (_unit != null) ...[
              const SizedBox(height: 8),
              _SelectedSummary(
                label: 'Destino seleccionado',
                value:
                  '${_unit!.code} · ${_unit!.type}${_unit!.sector.isEmpty ? '' : ' · ${_unit!.sector}'}',
                onChange: () => setState(() {
                  _unit = null;
                  _error = null;
                }),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'EVENTO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _eventChip('Entrada', 'ENTRY'),
                _eventChip('Salida', 'EXIT'),
                _eventChip('Denegado', 'DENIED'),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('access-validation-method'),
              value: _validationMethod,
              decoration: const InputDecoration(labelText: 'Método de validación'),
              items: const [
                DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
                DropdownMenuItem(value: 'QR', child: Text('QR')),
                DropdownMenuItem(value: 'FACE', child: Text('Facial')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _validationMethod = value ?? 'MANUAL'),
            ),
            const SizedBox(height: 8),
            Text(
              _eventType == 'DENIED'
                  ? 'El resultado de un acceso denegado siempre será Rechazado.'
                  : 'El resultado de una entrada o salida se registra como Aprobado.',
              style: const TextStyle(color: TajiColors.muted, fontSize: 12),
            ),
            if (_validationMethod != 'MANUAL') ...[
              const SizedBox(height: 4),
              Text(
                _validationMethod == 'QR'
                    ? 'El escaneo de autorizaciones se realiza desde Lector QR (CU10).'
                    : 'La verificación facial se realiza desde Verificación Facial (CU17).',
                style: const TextStyle(color: TajiColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('access-event-notes'),
              controller: _notes,
              maxLength: 300,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Anota detalles relevantes del acceso',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              StatusBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('save-access-event'),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Guardando…' : 'Registrar evento'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _eventChip(String label, String value) => ChoiceChip(
    key: Key('access-event-type-$value'),
    label: Text(label),
    selected: _eventType == value,
    onSelected: _saving ? null : (_) => setState(() => _eventType = value),
  );
}

class _LookupPanel extends StatelessWidget {
  const _LookupPanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: TajiColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );
}

class _LookupTile extends StatelessWidget {
  const _LookupTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.details,
  });

  final String title;
  final String subtitle;
  final String? details;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    selected: selected,
    selectedTileColor: TajiColors.primarySoft,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text([subtitle, if (details?.isNotEmpty == true) details!].join(' · ')),
    trailing: selected
        ? const Icon(Icons.check_circle_rounded, color: TajiColors.success)
        : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.label,
    required this.value,
    required this.onChange,
  });

  final String label;
  final String value;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
    decoration: BoxDecoration(
      color: TajiColors.successSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TajiColors.success.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded, color: TajiColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: TajiColors.muted)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        TextButton(onPressed: onChange, child: const Text('Cambiar')),
      ],
    ),
  );
}