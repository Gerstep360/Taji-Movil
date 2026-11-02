import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../features/auth/models/taji_user.dart';
import '../../../features/auth/state/auth_controller.dart';
import '../../../shared/widgets/taji_drawer.dart';
import 'report_models.dart';
import 'report_repository.dart';
import 'report_voice.dart';
import 'report_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes y consultas')),
      drawer: const TajiDrawer(),
      body: user?.canUseReports != true
          ? const Center(
              child: Text('No tienes acceso a reportes en este condominio.'),
            )
          : ReportsWorkspace(
              key: ValueKey(user?.activeTenant?.id),
              repository: ReportsRepository(context.read<ApiClient>()),
            ),
    );
  }
}

class ReportsWorkspace extends StatefulWidget {
  const ReportsWorkspace({required this.repository, this.voice, super.key});
  final ReportsRepository repository;
  final ReportVoice? voice;
  @override
  State<ReportsWorkspace> createState() => _ReportsWorkspaceState();
}

class _ReportsWorkspaceState extends State<ReportsWorkspace> {
  late final ReportVoice voice = widget.voice ?? NativeReportVoice();
  final text = TextEditingController(), title = TextEditingController();
  ReportCatalog? catalog;
  ReportSource? source;
  ReportPreview? result;
  ReportQuery? query;
  List<String> columns = [];
  List<ReportFilter> filters = [];
  String orderField = '', direction = 'asc', format = 'xlsx', summary = '';
  String? error, notice;
  bool loading = true, busy = false, listening = false;
  int pageSize = 25;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    title.dispose();
    unawaited(voice.stop().catchError((_) {}));
    unawaited(voice.stopSpeaking().catchError((_) {}));
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final c = await widget.repository.catalog();
      if (!mounted) return;
      setState(() {
        catalog = c;
        format = c.formats.contains('xlsx') ? 'xlsx' : c.formats.first;
        choose(c.sources.first);
      });
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void choose(ReportSource value) {
    source = value;
    columns = List.of(value.defaults);
    filters = [];
    title.clear();
    orderField = value.ordering.isNotEmpty
        ? '${value.ordering.first['field']}'
        : value.columns.first.key;
    direction = value.ordering.isNotEmpty
        ? '${value.ordering.first['direction']}'
        : 'asc';
    clearPreview();
  }

  void clearPreview() {
    result = null;
    query = null;
    summary = '';
    notice = null;
    unawaited(voice.stopSpeaking().catchError((_) {}));
  }

  void changed() {
    setState(clearPreview);
  }

  bool get valid =>
      source != null &&
      columns.isNotEmpty &&
      filters.every(
        (f) => emptyReportOperator(f.operator) || f.value.trim().isNotEmpty,
      );
  ReportQuery draft() => ReportQuery(
    source: source!.key,
    title: title.text.trim(),
    columns: List.of(columns),
    filters: filters.map((f) => f.copy()).toList(),
    ordering: [
      {'field': orderField, 'direction': direction},
    ],
    pageSize: pageSize,
  );
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> preview([int page = 1]) async {
    if (!valid || busy) return;
    final q = page == 1 ? draft() : query!.atPage(page);
    await run(() async {
      final r = await widget.repository.preview(q);
      if (!mounted) return;
      setState(() {
        result = r;
        query = q;
        summary = '';
        notice = null;
      });
    });
  }

  Future<void> ask() async {
    if (text.text.trim().isEmpty || busy) return;
    await voice.stop();
    if (!mounted) return;
    setState(() => listening = false);
    await run(() async {
      final data = await widget.repository.voice(text.text);
      if (!mounted) return;
      if (data['report_request'] is! Map) {
        throw StateError(
          'El servidor debe actualizar el contrato de consulta por voz. Puedes usar los filtros.',
        );
      }
      final q = ReportQuery.fromJson(reportMap(data['report_request']));
      final selected = catalog!.sources.firstWhere((s) => s.key == q.source);
      final r = ReportPreview.fromJson(reportMap(data['report_preview']));
      setState(() {
        choose(selected);
        columns = List.of(q.columns);
        filters = q.filters.map((f) => f.copy()).toList();
        title.text = q.title;
        orderField = '${q.ordering.first['field']}';
        direction = '${q.ordering.first['direction']}';
        pageSize = q.pageSize;
        result = r;
        query = q;
        summary = '${data['spoken_summary'] ?? ''}';
        final f = reportMap(data['understood_intent'])['detected_format'];
        if (catalog!.formats.contains(f)) format = '$f';
        notice =
            'Consulta interpretada. Revisa la fuente y los filtros antes de compartir.';
      });
    });
  }

  Future<void> dictate() async {
    if (listening) {
      await voice.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() {
      listening = true;
      error = null;
    });
    try {
      await voice.listen(
        (value) {
          if (mounted) {
            text.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
          }
        },
        () {
          if (mounted) setState(() => listening = false);
        },
        (value) {
          if (mounted) {
            setState(() {
              listening = false;
              error = value;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          listening = false;
          error = errorMessage(e);
        });
      }
    }
  }

  Future<void> read() async {
    final r = result;
    if (r == null) return;
    await run(() async {
      final value = await widget.repository.narrate(r);
      if (!mounted) return;
      setState(() => summary = value);
      await voice.speak(value);
    });
  }

  Future<void> share() async {
    final q = query;
    if (q == null || result?.canExport != true) return;
    await run(() async {
      final bytes = await widget.repository.export(q, format);
      if (!mounted) return;
      final mime = switch (format) {
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'csv' => 'text/csv',
        _ => 'text/html',
      };
      final name =
          'reporte-${q.source.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')}.$format';
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 1, 1);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
    });
  }

  String errorMessage(Object error) {
    if (error is StateError) return error.message;
    if (error is DioException) {
      if (error.response?.statusCode == 403) {
        return 'No tienes acceso a reportes en este condominio.';
      }
      dynamic data = error.response?.data;
      if (data is List<int> && data.length < 20000) {
        try {
          data = jsonDecode(utf8.decode(data));
        } catch (_) {
          data = null;
        }
      }
      final map = reportMap(data), detail = reportMap(reportMap(data)['error']);
      return '${detail['message'] ?? map['detail'] ?? 'No pudimos consultar el servidor. Tus filtros se conservan; intenta nuevamente.'}';
    }
    return 'No se pudo completar la operación. Conservamos tu configuración.';
  }

  Widget gap() => const SizedBox(height: 12);
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (catalog == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'No se pudo cargar el catálogo.'),
              gap(),
              OutlinedButton(onPressed: load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final c = catalog!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.tenant,
                style: const TextStyle(
                  color: TajiColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'De una consulta a un reporte útil',
                style: TextStyle(
                  color: TajiColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(),
              const Text(
                'Revisa la información antes de compartirla.',
                style: TextStyle(color: TajiColors.muted),
              ),
              const SizedBox(height: 20),
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  color: TajiColors.dangerSoft,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: TajiColors.danger),
                    ),
                  ),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      notice!,
                      style: const TextStyle(color: TajiColors.success),
                    ),
                  ),
                ),
              if (c.voice)
                ReportSection(
                  title: 'Pregunta con tus palabras',
                  subtitle: 'Escribe o dicta. Tú decides cuándo enviar.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: text,
                        enabled: !busy,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Consulta del reporte',
                          hintText: 'Incidencias pendientes de esta semana',
                          counterText: '',
                        ),
                      ),
                      gap(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : dictate,
                            icon: Icon(listening ? Icons.stop : Icons.mic_none),
                            label: Text(
                              listening ? 'Detener dictado' : 'Dictar',
                            ),
                          ),
                          FilledButton(
                            onPressed: busy ? null : ask,
                            child: const Text('Consultar'),
                          ),
                        ],
                      ),
                      if (listening)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Escuchando… Revisa el texto antes de consultar.',
                          ),
                        ),
                      gap(),
                      Wrap(
                        spacing: 6,
                        children: c.suggestions
                            .map(
                              (suggestion) => ActionChip(
                                label: Text(
                                  suggestion,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => text.text = suggestion,
                              ),
                            )
                            .toList(),
                      ),
                      gap(),
                      const Text(
                        'El dictado usa el servicio de voz del dispositivo, que puede procesar audio externamente. Taji recibe el texto. Puedes escribir sin activar el micrófono.',
                        style: TextStyle(fontSize: 11, color: TajiColors.muted),
                      ),
                    ],
                  ),
                ),
              ReportSection(
                title: 'Prepara tu reporte',
                subtitle: '01 / Configuración',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ReportSource>(
                      value: source,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '¿Qué quieres consultar?',
                      ),
                      items: c.sources
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (s) => setState(() => choose(s!)),
                    ),
                    gap(),
                    Text(
                      source?.description ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TajiColors.muted,
                      ),
                    ),
                    gap(),
                    TextField(
                      controller: title,
                      enabled: !busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del reporte (opcional)',
                        counterText: '',
                      ),
                      onChanged: (_) => changed(),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Columnas (${columns.length} seleccionadas)',
                        style: const TextStyle(fontSize: 14),
                      ),
                      children: [
                        Wrap(
                          spacing: 6,
                          children: source!.columns
                              .map(
                                (column) => FilterChip(
                                  label: Text(
                                    column.label,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: columns.contains(column.key),
                                  onSelected: busy
                                      ? null
                                      : (selected) => setState(() {
                                          if (selected) {
                                            columns.add(column.key);
                                          } else {
                                            columns.remove(column.key);
                                          }
                                          clearPreview();
                                        }),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtros',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: busy || filters.length >= 8
                              ? null
                              : () => setState(() {
                                  final col = source!.columns.first;
                                  filters.add(
                                    ReportFilter(col.key, col.operators.first),
                                  );
                                  clearPreview();
                                }),
                          child: const Text('+ Agregar filtro'),
                        ),
                      ],
                    ),
                    if (filters.isEmpty)
                      const Text(
                        'Sin filtros adicionales.',
                        style: TextStyle(fontSize: 12, color: TajiColors.muted),
                      ),
                    for (var i = 0; i < filters.length; i++)
                      ReportFilterEditor(
                        key: ObjectKey(filters[i]),
                        filter: filters[i],
                        source: source!,
                        index: i,
                        enabled: !busy,
                        onChanged: changed,
                        onRemove: () => setState(() {
                          filters.removeAt(i);
                          clearPreview();
                        }),
                      ),
                    gap(),
                    DropdownButtonFormField<String>(
                      value: orderField,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ordenar por',
                      ),
                      items: source!.columns
                          .map(
                            (col) => DropdownMenuItem(
                              value: col.key,
                              child: Text(col.label),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              orderField = v!;
                              clearPreview();
                            }),
                    ),
                    gap(),
                    DropdownButtonFormField<String>(
                      value: direction,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Orden'),
                      items: const [
                        DropdownMenuItem(
                          value: 'asc',
                          child: Text('Ascendente'),
                        ),
                        DropdownMenuItem(
                          value: 'desc',
                          child: Text('Descendente'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              direction = v!;
                              clearPreview();
                            }),
                    ),
                    gap(),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: pageSize,
                      decoration: const InputDecoration(
                        labelText: 'Filas por página',
                      ),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10 filas')),
                        DropdownMenuItem(value: 25, child: Text('25 filas')),
                        DropdownMenuItem(value: 50, child: Text('50 filas')),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              pageSize = v!;
                              clearPreview();
                            }),
                    ),
                    gap(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy || !valid ? null : preview,
                        icon: const Icon(Icons.search),
                        label: Text(
                          busy ? 'Procesando…' : 'Generar vista previa',
                        ),
                      ),
                    ),
                    if (columns.isEmpty)
                      const Text(
                        'Selecciona al menos una columna.',
                        style: TextStyle(fontSize: 12, color: TajiColors.muted),
                      ),
                  ],
                ),
              ),
              ReportSection(
                title: 'Vista previa',
                subtitle: '02 / Revisión y exportación',
                child: result == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 44,
                                color: TajiColors.primary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Prepara los filtros y genera una vista previa.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : resultView(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget resultView(ReportCatalog catalog) {
    final r = result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        gap(),
        Text(
          '${r.total} registros · solo del condominio activo',
          style: const TextStyle(fontSize: 12, color: TajiColors.muted),
        ),
        gap(),
        DropdownButtonFormField<String>(
          value: format,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Formato de exportación',
          ),
          items: catalog.formats
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(
                    f == 'xlsx'
                        ? 'Excel (.xlsx)'
                        : f == 'csv'
                        ? 'CSV (.csv)'
                        : 'HTML para impresión',
                  ),
                ),
              )
              .toList(),
          onChanged: busy ? null : (v) => setState(() => format = v!),
        ),
        gap(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy || !r.canExport ? null : share,
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Compartir reporte'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : read,
              icon: const Icon(Icons.volume_up_outlined, size: 18),
              label: const Text('Escuchar resumen'),
            ),
            TextButton(
              onPressed: () => voice.stopSpeaking(),
              child: const Text('Detener lectura'),
            ),
          ],
        ),
        if (!r.canExport)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Supera el límite de ${catalog.limit} filas. Aplica más filtros para exportar.',
              style: const TextStyle(color: TajiColors.danger),
            ),
          ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              summary,
              style: const TextStyle(color: TajiColors.muted, fontSize: 13),
            ),
          ),
        if (r.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No hay registros con estos criterios. Prueba con menos filtros.',
            ),
          ),
        for (var i = 0; i < r.rows.length; i++)
          ReportRecord(columns: r.columns, values: r.rows[i], index: i),
        gap(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: busy || r.page <= 1 ? null : () => preview(r.page - 1),
              child: const Text('Anterior'),
            ),
            Flexible(
              child: Text(
                'Página ${r.page} de ${r.pages}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: busy || r.page >= r.pages
                  ? null
                  : () => preview(r.page + 1),
              child: const Text('Siguiente'),
            ),
          ],
        ),
        gap(),
        const Text(
          'Se comparten todos los registros filtrados, no solo esta página. Elige únicamente destinatarios autorizados.',
          style: TextStyle(fontSize: 11, color: TajiColors.muted),
        ),
      ],
    );
  }
}
