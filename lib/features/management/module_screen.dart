import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/taji_theme.dart';
import '../../shared/widgets/taji_drawer.dart';
import '../auth/models/taji_user.dart';
import '../auth/state/auth_controller.dart';
import 'module_catalog.dart';
import 'module_repository.dart';

bool canReadModule(TajiUser? user, MobileModule module) =>
    user != null &&
    (user.isSuperuser ||
        (module.key != 'audit' && module.endpoint.startsWith('/community/')) ||
        (module.key == 'audit' && user.hasPermission('view_audit_log')) ||
        user.hasPermission(module.permission ?? 'manage_settings'));
bool canWriteModule(TajiUser? user, MobileModule module) =>
    !module.readOnly &&
    user != null &&
    (user.isSuperuser ||
        user.hasPermission(module.permission ?? 'manage_settings'));

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({required this.module, super.key});
  final MobileModule module;
  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  late final ModuleRepository repository = ModuleRepository(
    context.read<ApiClient>(),
  );
  final search = TextEditingController();
  List<ResourceRow> items = [];
  int page = 1, pages = 1, revision = 0;
  bool loading = true;
  String? error, notice;
  MobileModule get module => widget.module;
  TajiUser? get user => context.read<AuthController>().user;
  bool get manager => canWriteModule(user, module);
  bool get reserving =>
      module.key == 'reservations' &&
      (user?.hasPermission('reserve_areas') ?? false);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    revision++;
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final version = ++revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await repository.list(
        module,
        page: page,
        search: search.text.trim(),
      );
      if (!mounted || version != revision) return;
      setState(() {
        items = result.items;
        pages = result.pages;
      });
    } catch (e) {
      if (mounted && version == revision) {
        setState(() => error = moduleError(e));
      }
    } finally {
      if (mounted && version == revision) setState(() => loading = false);
    }
  }

  Future<void> edit([ResourceRow? row]) async {
    if (module.key == 'roles') {
      if (row == null) return;
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) =>
            _RoleEditor(repository: repository, module: module, row: row),
      );
      if (changed == true && mounted) {
        notice = 'Permisos actualizados.';
        await load();
      }
      return;
    }
    final fields = module.fields
        .where(
          (field) => manager || !['resident', 'status'].contains(field.key),
        )
        .toList();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ResourceEditor(
        repository: repository,
        module: module,
        fields: fields,
        original: row,
      ),
    );
    if (changed == true && mounted) {
      notice = row == null
          ? 'Registro creado correctamente.'
          : 'Cambios guardados.';
      await load();
    }
  }

  void detail(ResourceRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rowTitle(row),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar detalle',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final field in module.fields)
              if (row[field.key] != null && '${row[field.key]}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: const TextStyle(
                          color: TajiColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(displayValue(field, row[field.key], row)),
                    ],
                  ),
                ),
            if (module.readOnly || module.key == 'roles')
              for (final entry in row.entries.where(
                (e) => ![
                  'id',
                  'permissions',
                  'before_data',
                  'after_data',
                ].contains(e.key),
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    fieldLabels[entry.key] ?? entry.key.replaceAll('_', ' '),
                  ),
                  subtitle: SelectableText('${entry.value ?? ''}'),
                ),
            if (module.key == 'reservations' &&
                ['PENDING', 'APPROVED'].contains(row['status']))
              OutlinedButton.icon(
                icon: const Icon(Icons.event_busy),
                label: const Text('Cancelar reserva'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('¿Cancelar esta reserva?'),
                      content: const Text(
                        'El horario quedará libre. Se conservará el historial.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Volver'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Cancelar reserva'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  try {
                    await repository.save(module, {
                      'status': 'CANCELLED',
                    }, original: row);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await load();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(moduleError(e))));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const TajiDrawer(),
    appBar: AppBar(
      title: Text(module.title),
      actions: [
        IconButton(
          tooltip: 'Actualizar lista',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: (manager || reserving) && module.canCreate
        ? FloatingActionButton.extended(
            backgroundColor: TajiColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: loading ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          )
        : null,
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              module.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(module.description),
            const SizedBox(height: 20),
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Buscar en ${module.title.toLowerCase()}',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  onPressed: loading
                      ? null
                      : () {
                          page = 1;
                          load();
                        },
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) {
                page = 1;
                load();
              },
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error!,
                      style: const TextStyle(color: TajiColors.danger),
                    ),
                    TextButton(
                      onPressed: load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  notice!,
                  style: const TextStyle(color: TajiColors.success),
                ),
              ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!loading && error == null && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text('No hay registros para esta búsqueda.'),
              ),
            const SizedBox(height: 12),
            for (final row in items)
              Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: TajiColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  onTap: () => detail(row),
                  title: Text(
                    rowTitle(row),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    rowSubtitle(row),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: manager
                      ? IconButton(
                          tooltip: 'Editar registro',
                          onPressed: () => edit(row),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: TajiColors.primary,
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                ),
              ),
            if (pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: loading || page <= 1
                        ? null
                        : () {
                            page--;
                            load();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$page de $pages'),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: loading || page >= pages
                        ? null
                        : () {
                            page++;
                            load();
                          },
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

class _ResourceEditor extends StatefulWidget {
  const _ResourceEditor({
    required this.repository,
    required this.module,
    required this.fields,
    this.original,
  });
  final ModuleRepository repository;
  final MobileModule module;
  final List<ModuleField> fields;
  final ResourceRow? original;
  @override
  State<_ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<_ResourceEditor> {
  final form = GlobalKey<FormState>();
  final values = <String, dynamic>{},
      controllers = <String, TextEditingController>{};
  final references = <String, List<ResourceRow>>{};
  String? error;
  bool loading = true, saving = false;
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final value = widget.original?[field.key] ?? field.initial;
      values[field.key] = value;
      controllers[field.key] = TextEditingController(
        text: value == null ? '' : '$value',
      );
    }
    loadReferences();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadReferences() async {
    try {
      for (final field in widget.fields.where((f) => f.reference != null)) {
        final options = await widget.repository.options(field.reference!);
        if (!mounted) return;
        references[field.key] = options;
      }
    } catch (e) {
      if (mounted) error = moduleError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickDate(ModuleField field) async {
    final current =
        DateTime.tryParse('${values[field.key] ?? ''}')?.toLocal() ??
        DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    var chosen = date;
    if (field.kind == FieldKind.dateTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null || !mounted) return;
      chosen = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    setState(() {
      values[field.key] = field.kind == FieldKind.date
          ? chosen.toIso8601String().split('T').first
          : chosen.toUtc().toIso8601String();
      controllers[field.key]!.text = field.kind == FieldKind.date
          ? '${chosen.day}/${chosen.month}/${chosen.year}'
          : '${chosen.day}/${chosen.month}/${chosen.year} ${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final payload = <String, dynamic>{};
    for (final field in widget.fields) {
      final value = values[field.key];
      if (value == null || value == '') {
        if (widget.original != null ||
            field.kind == FieldKind.text ||
            field.kind == FieldKind.multiline) {
          payload[field.key] =
              [
                FieldKind.reference,
                FieldKind.date,
                FieldKind.dateTime,
                FieldKind.number,
              ].contains(field.kind)
              ? null
              : '';
        }
        continue;
      }
      payload[field.key] = field.kind == FieldKind.number
          ? num.parse('$value')
          : value;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.save(
        widget.module,
        payload,
        original: widget.original,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = moduleError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.original == null
                          ? 'Nuevo registro'
                          : 'Editar registro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar formulario',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.module.title),
              const SizedBox(height: 20),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: TajiColors.danger),
                  ),
                ),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else
                for (final field in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: editor(field),
                  ),
              FilledButton.icon(
                onPressed: loading || saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(saving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget editor(ModuleField field) {
    final label = field.label + (field.required ? ' *' : '');
    if (field.kind == FieldKind.toggle) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: values[field.key] == true,
        onChanged: saving ? null : (v) => setState(() => values[field.key] = v),
      );
    }
    if (field.kind == FieldKind.choice || field.kind == FieldKind.reference) {
      final options = field.kind == FieldKind.reference
          ? {
              for (final row in references[field.key] ?? <ResourceRow>[])
                '${row['id']}': rowTitle(row),
            }
          : field.choices;
      final selected = values[field.key]?.toString();
      return DropdownButtonFormField<String>(
        value: options.containsKey(selected) ? selected : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (!field.required)
            const DropdownMenuItem(value: '', child: Text('Sin seleccionar')),
          for (final entry in options.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        validator: (v) => field.required && (v == null || v.isEmpty)
            ? 'Selecciona una opción.'
            : null,
        onChanged: saving
            ? null
            : (v) => values[field.key] = field.kind == FieldKind.reference
                  ? int.tryParse(v ?? '')
                  : v,
      );
    }
    final date =
        field.kind == FieldKind.date || field.kind == FieldKind.dateTime;
    return TextFormField(
      controller: controllers[field.key],
      readOnly: date || saving,
      minLines: field.kind == FieldKind.multiline ? 3 : 1,
      maxLines: field.kind == FieldKind.multiline ? 6 : 1,
      keyboardType: field.kind == FieldKind.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.key.contains('email')
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: date
            ? IconButton(
                tooltip: 'Elegir fecha',
                onPressed: saving ? null : () => pickDate(field),
                icon: const Icon(Icons.calendar_today_outlined),
              )
            : null,
      ),
      onTap: date && !saving ? () => pickDate(field) : null,
      onChanged: (v) => values[field.key] = v,
      validator: (v) {
        if (field.required && (v == null || v.trim().isEmpty)) {
          return 'Completa este campo.';
        }
        if (field.kind == FieldKind.number &&
            v != null &&
            v.isNotEmpty &&
            num.tryParse(v) == null) {
          return 'Escribe un número válido.';
        }
        return null;
      },
    );
  }
}

class _RoleEditor extends StatefulWidget {
  const _RoleEditor({
    required this.repository,
    required this.module,
    required this.row,
  });
  final ModuleRepository repository;
  final MobileModule module;
  final ResourceRow row;
  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  late final selected = (widget.row['permissions'] as List? ?? [])
      .map((v) => v is Map ? '${v['code']}' : '$v')
      .toSet();
  List<ResourceRow> permissions = [];
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      permissions = await widget.repository.permissions();
    } catch (e) {
      error = moduleError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Permisos de ${widget.row['name']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar permisos',
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error!,
              style: const TextStyle(color: TajiColors.danger),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    for (final permission in permissions)
                      CheckboxListTile(
                        title: Text('${permission['name']}'),
                        subtitle: Text('${permission['description'] ?? ''}'),
                        value: selected.contains(permission['code']),
                        onChanged: saving
                            ? null
                            : (checked) => setState(() {
                                if (checked == true) {
                                  selected.add('${permission['code']}');
                                } else {
                                  selected.remove(permission['code']);
                                }
                              }),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: loading || saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await widget.repository.save(widget.module, {
                        'permissions': selected.toList(),
                      }, original: widget.row);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) setState(() => error = moduleError(e));
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Guardando…' : 'Guardar permisos'),
          ),
        ),
      ],
    ),
  );
}

String moduleError(Object e) => e is ApiFailure
    ? e.displayMessage
    : e is DioException
    ? ApiFailure.fromDio(
        e,
        fallback: 'No pudimos completar la operación. Tus datos se conservan.',
      ).displayMessage
    : e is StateError
    ? e.message
    : 'No pudimos completar la operación. Inténtalo nuevamente.';
String rowTitle(ResourceRow row) =>
    '${row['full_name'] ?? row['name'] ?? row['title'] ?? row['common_area_name'] ?? row['resident_name'] ?? row['description'] ?? row['code'] ?? row['action_code'] ?? 'Registro ${row['id'] ?? ''}'}';
String rowSubtitle(ResourceRow row) => [
  row['employee_code'] ?? row['code'] ?? row['unit_code'],
  row['status_display'] ?? statusLabels[row['status']] ?? row['status'],
  row['sector_name'] ??
      row['assembly_title'] ??
      row['purpose'] ??
      row['phone'] ??
      row['created_at'],
].where((v) => v != null && '$v'.isNotEmpty).join(' · ');
String displayValue(ModuleField field, dynamic value, ResourceRow row) =>
    field.choices['$value'] ??
    (field.kind == FieldKind.reference
        ? '${row['${field.key}_name'] ?? row['${field.key}_title'] ?? row['${field.key}_code'] ?? value}'
        : value is bool
        ? (value ? 'Sí' : 'No')
        : '$value');
const fieldLabels = {
  'name': 'Nombre',
  'description': 'Descripción',
  'slug': 'Rol',
  'is_active': 'Activo',
  'action_code': 'Acción',
  'resource_type': 'Recurso',
  'resource_id': 'Identificador',
  'created_at': 'Fecha',
  'actor_email': 'Usuario',
  'category': 'Categoría',
};
const statusLabels = {
  'ACTIVE': 'Activo',
  'INACTIVE': 'Inactivo',
  'PENDING': 'Pendiente',
  'APPROVED': 'Aprobada',
  'REJECTED': 'Rechazada',
  'CANCELLED': 'Cancelada',
  'COMPLETED': 'Completado',
  'PUBLISHED': 'Publicado',
  'DRAFT': 'Borrador',
  'ARCHIVED': 'Archivado',
  'AVAILABLE': 'Disponible',
  'SCHEDULED': 'Programada',
  'IN_PROGRESS': 'En progreso',
  'FINISHED': 'Finalizada',
  'OVERDUE': 'Vencido',
};
