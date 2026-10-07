import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../data/visit_consultation_repository.dart';
import '../state/visit_consultation_controller.dart';

class VisitConsultationScreen extends StatefulWidget {
  const VisitConsultationScreen({super.key});
  @override
  State<VisitConsultationScreen> createState() => _VisitConsultationScreenState();
}

class _VisitConsultationScreenState extends State<VisitConsultationScreen> {
  late final VisitConsultationController controller;
  @override
  void initState() {
    super.initState();
    controller = VisitConsultationController(VisitConsultationRepository(context.read<ApiClient>()));
    controller.load();
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  String date(DateTime? value) {
    if (value == null) return 'No registrada';
    final local = value.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year} ${pad(local.hour)}:${pad(local.minute)}';
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Visitas'), actions: [
        IconButton(onPressed: controller.loading ? null : () => controller.load(), icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: controller.section == 'expected'
            ? FilledButton(onPressed: () => controller.load(selectedSection: 'expected'), child: const Text('Esperadas'))
            : OutlinedButton(onPressed: () => controller.load(selectedSection: 'expected'), child: const Text('Esperadas'))),
          const SizedBox(width: 8),
          Expanded(child: controller.section == 'inside'
            ? FilledButton(onPressed: () => controller.load(selectedSection: 'inside'), child: const Text('Dentro'))
            : OutlinedButton(onPressed: () => controller.load(selectedSection: 'inside'), child: const Text('Dentro'))),
        ])),
        if (controller.loading) const LinearProgressIndicator(),
        if (controller.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(controller.error!, semanticsLabel: controller.error)),
        Expanded(child: RefreshIndicator(onRefresh: () => controller.load(), child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), children: [
            if (controller.items.isEmpty && !controller.loading && controller.error == null)
              const Padding(padding: EdgeInsets.all(24), child: Text('No hay visitas para esta consulta.')),
            for (final item in controller.items) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name.isEmpty ? 'Sin nombre registrado' : item.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Documento: ${item.document.isEmpty ? 'No registrado' : item.document}'),
                Text('Unidad: ${item.unit.isEmpty ? 'No registrada' : item.unit}'),
                if (controller.section == 'expected') ...[
                  Text('Desde: ${date(item.from)}'), Text('Hasta: ${date(item.until)}'), Text('Estado: ${item.status}'),
                ] else Text('Entrada: ${date(item.enteredAt)}'),
              ],
            ))),
          ],
        ))),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Wrap(
          spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center, children: [
            TextButton(onPressed: controller.loading || controller.page <= 1 ? null : () => controller.load(selectedPage: controller.page - 1), child: const Text('Anterior')),
            Text('Página ${controller.page} de ${controller.pages < 1 ? 1 : controller.pages}'),
            TextButton(onPressed: controller.loading || controller.page >= controller.pages ? null : () => controller.load(selectedPage: controller.page + 1), child: const Text('Siguiente')),
          ],
        ))),
      ]),
    ),
  );
}
