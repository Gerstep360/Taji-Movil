import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_failure.dart';
import '../../shared/widgets/taji_drawer.dart';

class IncidentStep {
  IncidentStep.fromJson(Map<String, dynamic> json)
    : label = json['to_status_display'] as String? ?? '',
      comment = json['comment'] as String? ?? '',
      at = DateTime.tryParse(json['changed_at'] as String? ?? ''),
      author =
          (json['changed_by'] as Map?)?['full_name'] as String? ?? 'Sistema';
  final String label, comment, author;
  final DateTime? at;
}

class TrackedIncident {
  TrackedIncident.fromJson(Map<String, dynamic> json)
    : code = json['public_code'] as String,
      title = json['title'] as String? ?? '',
      description = json['description'] as String? ?? '',
      status = json['status_display'] as String? ?? '',
      assignee =
          (json['current_assignee'] as Map?)?['full_name'] as String? ??
          'Por asignar',
      overdue = json['is_overdue'] == true,
      due = DateTime.tryParse(json['due_at'] as String? ?? ''),
      history = ((json['status_history'] as List?) ?? [])
          .map(
            (item) =>
                IncidentStep.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
  final String code, title, description, status, assignee;
  final bool overdue;
  final DateTime? due;
  final List<IncidentStep> history;
}

class IncidentTrackingRepository {
  IncidentTrackingRepository(this.api);
  final ApiClient api;
  static const root = ApiEndpoints.incidents;
  Future<({List<TrackedIncident> items, int pages})> list(
    String filter,
    int page,
  ) async {
    final json = await api.get<Map<String, dynamic>>(
      root,
      query: {'page': page, if (filter.isNotEmpty) 'sla_status': filter},
    );
    if (json == null ||
        json['results'] is! List ||
        json['pagination'] is! Map) {
      throw StateError('Respuesta de seguimiento inválida');
    }
    return (
      items: (json['results'] as List)
          .map(
            (e) =>
                TrackedIncident.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      pages: ((json['pagination'] as Map)['total_pages'] as int?) ?? 1,
    );
  }

  Future<TrackedIncident> detail(String code) async {
    final json = await api.get<Map<String, dynamic>>(
      '$root${Uri.encodeComponent(code)}/',
    );
    if (json == null) throw StateError('Respuesta vacía');
    return TrackedIncident.fromJson(json);
  }
}

class IncidentTrackingScreen extends StatefulWidget {
  const IncidentTrackingScreen({super.key});
  @override
  State<IncidentTrackingScreen> createState() => _IncidentTrackingScreenState();
}

class _IncidentTrackingScreenState extends State<IncidentTrackingScreen> {
  late IncidentTrackingRepository repository;
  List<TrackedIncident> items = [];
  TrackedIncident? detail;
  bool loading = false, initialized = false;
  String? error;
  String filter = '';
  int page = 1, pages = 1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      repository = IncidentTrackingRepository(context.read<ApiClient>());
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await repository.list(filter, page);
      if (!mounted) return;
      setState(() {
        items = response.items;
        pages = response.pages < 1 ? 1 : response.pages;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = failure is DioException
              ? ApiFailure.fromDio(
                  failure,
                  fallback: 'No pudimos cargar las incidencias.',
                ).displayMessage
              : 'No pudimos cargar las incidencias. Revisa tu conexión.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> open(TrackedIncident item) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await repository.detail(item.code);
      if (mounted) {
        setState(() {
          detail = response;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = failure is DioException
              ? ApiFailure.fromDio(
                  failure,
                  fallback: 'No se pudo abrir la incidencia.',
                ).displayMessage
              : 'No se pudo abrir la incidencia. Intenta nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String date(DateTime? value) {
    if (value == null) return 'Por definir';
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final item = detail;
    return Scaffold(
      drawer: const TajiDrawer(),
      appBar: AppBar(
        title: Text(item?.code ?? 'Seguimiento de incidencias'),
        leading: item == null
            ? null
            : IconButton(
                tooltip: 'Volver al listado',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  detail = null;
                }),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: loading
                    ? null
                    : () => item == null ? load() : open(item),
                child: const Text('Reintentar'),
              ),
            ],
            if (item == null) ...[
              Text(
                'Cada incidencia, con su historia',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Consulta el estado, la persona responsable y los avances de atención.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: filter,
                decoration: const InputDecoration(labelText: 'Mostrar'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todas')),
                  DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                  DropdownMenuItem(value: 'overdue', child: Text('Vencidas')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resueltas')),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        filter = value ?? '';
                        page = 1;
                        load();
                      },
              ),
              const SizedBox(height: 16),
              if (items.isEmpty && !loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay incidencias en esta consulta.'),
                ),
              for (final entry in items)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(entry.title.isEmpty ? entry.code : entry.title),
                    subtitle: Text(
                      '${entry.code}\n${entry.status}${entry.overdue ? ' · Vencida' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: loading ? null : () => open(entry),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: loading || page <= 1
                        ? null
                        : () {
                            page--;
                            load();
                          },
                    child: const Text('Anterior'),
                  ),
                  Text('$page / $pages'),
                  TextButton(
                    onPressed: loading || page >= pages
                        ? null
                        : () {
                            page++;
                            load();
                          },
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text(item.status)),
              ),
              Text(item.description),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Responsable'),
                subtitle: Text(item.assignee),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  item.overdue ? 'Fecha objetivo vencida' : 'Fecha objetivo',
                ),
                subtitle: Text(date(item.due)),
              ),
              const Divider(height: 36),
              Text(
                'Línea de tiempo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (item.history.isEmpty) const Text('Sin cambios registrados.'),
              for (final step in item.history)
                ListTile(
                  contentPadding: const EdgeInsets.only(bottom: 16),
                  leading: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(step.label),
                  subtitle: Text(
                    '${date(step.at)}\n${step.comment}\n${step.author}',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: loading ? null : () => open(item),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar seguimiento'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
