import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import 'incident_ai.dart';

class IncidentAIPanel extends StatefulWidget {
  const IncidentAIPanel({required this.code, super.key});
  final String code;
  @override
  State<IncidentAIPanel> createState() => _IncidentAIPanelState();
}

class _IncidentAIPanelState extends State<IncidentAIPanel> {
  IncidentAIResult? result;
  String? error;
  bool loading = true;
  Timer? timer;
  int polls = 0;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(IncidentAIPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      timer?.cancel();
      polls = 0;
      result = null;
      unawaited(load());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    timer?.cancel();
    final code = widget.code;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final response = await context
          .read<ApiClient>()
          .get<Map<String, dynamic>>(ApiEndpoints.incidentAIFor(code));
      if (response == null || response['analyses'] is! List) {
        throw StateError('Respuesta inválida');
      }
      final rows = response['analyses'] as List;
      final next = rows.isEmpty
          ? null
          : IncidentAIResult.fromJson(
              Map<String, dynamic>.from(rows.first as Map),
            );
      if (!mounted || widget.code != code) return;
      setState(() {
        result = next;
      });
      if (next?.pending == true && polls++ < 30) {
        timer = Timer(const Duration(seconds: 2), load);
      }
    } catch (_) {
      if (mounted && widget.code == code) {
        setState(() {
          error =
              'No pudimos consultar el análisis. Puedes continuar con el seguimiento.';
        });
      }
    } finally {
      if (mounted && widget.code == code) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String contextLabel(String value) => switch (value) {
    'present' => 'Presente',
    'negated' => 'Negado en el reporte',
    'distant' => 'Fuera del peligro',
    'past' => 'Hecho pasado',
    'drill' => 'Simulacro',
    _ => 'Por verificar',
  };
  @override
  Widget build(BuildContext context) {
    final analysis = result;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        border: Border.all(color: const Color(0xFFD4E3FA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Análisis de la incidencia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar análisis',
                onPressed: loading
                    ? null
                    : () {
                        polls = 0;
                        load();
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (!loading && analysis == null && error == null)
            const Text(
              'Todavía no hay un análisis. El equipo puede clasificar esta incidencia manualmente.',
            ),
          if (analysis != null) ...[
            if (analysis.pending)
              const Text(
                'El análisis está en proceso. Puedes seguir usando la app.',
              ),
            if (analysis.status == 'FAILED' && !analysis.reviewed)
              const Text(
                'El análisis automático no está disponible. El equipo realizará una revisión manual.',
              ),
            if (analysis.status == 'SUCCEEDED' || analysis.reviewed) ...[
              Text(
                analysis.reviewed
                    ? 'Clasificación revisada por el equipo'
                    : 'Propuesta IA · pendiente de revisión',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(analysis.category ?? 'Por clasificar')),
                  Chip(
                    label: Text(
                      'Prioridad: ${analysis.priority ?? 'Por revisar'}',
                    ),
                  ),
                ],
              ),
              if (analysis.confidence != null)
                Text(
                  'Confianza del modelo: ${(analysis.confidence! * 100).round()}%',
                ),
              if (analysis.summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(analysis.summary),
                ),
              Text(
                'Peligros y contexto',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (analysis.risks.isEmpty)
                const Text(
                  'Sin peligros específicos identificados; esto no garantiza ausencia de riesgo.',
                ),
              for (final risk in analysis.risks)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${risk.name} · ${contextLabel(risk.context)}\n«${risk.evidence}»',
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Acciones sugeridas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final action in analysis.recommendations)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('• $action'),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
