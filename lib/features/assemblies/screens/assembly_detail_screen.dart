import 'package:flutter/material.dart';

import '../data/assemblies_repository.dart';
import '../models/assembly_models.dart';
import '../state/assemblies_controller.dart';
import '../widgets/assembly_format.dart';

class AssemblyDetailScreen extends StatefulWidget {
  const AssemblyDetailScreen({
    super.key,
    required this.assembly,
    required this.repository,
  });
  final AssemblyItem assembly;
  final AssembliesRepository repository;

  @override
  State<AssemblyDetailScreen> createState() => _AssemblyDetailScreenState();
}

class _AssemblyDetailScreenState extends State<AssemblyDetailScreen> {
  late final AssemblyDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = AssemblyDetailController(widget.repository, widget.assembly)
      ..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assembly = widget.assembly;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Asamblea')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(assembly.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                status: assembly.status,
                label: assembly.statusDisplay,
              ),
            ),
            const SizedBox(height: 16),
            _Line(label: 'Fecha y hora', value: formatAssemblyDate(assembly.scheduledAt)),
            _Line(label: 'Lugar', value: assembly.location.isEmpty ? '—' : assembly.location),
            if (assembly.description.isNotEmpty)
              _Line(label: 'Descripción', value: assembly.description),
            if (assembly.hasFullAccess) ...[
              const SizedBox(height: 16),
              Text('Acta', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                (assembly.minutesText ?? '').isEmpty
                    ? 'Aún no hay acta registrada.'
                    : assembly.minutesText!,
              ),
              const SizedBox(height: 24),
              Text(
                'Acuerdos (${controller.agreements.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (controller.loading) const LinearProgressIndicator(),
              if (controller.error != null)
                Text(controller.error!, semanticsLabel: controller.error),
              if (!controller.loading &&
                  controller.error == null &&
                  controller.agreements.isEmpty)
                const Text('Esta asamblea no tiene acuerdos registrados.'),
              for (final agreement in controller.agreements)
                _AgreementCard(agreement: agreement),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _AgreementCard extends StatelessWidget {
  const _AgreementCard({required this.agreement});
  final AgreementItem agreement;

  @override
  Widget build(BuildContext context) => Card(
    shape: agreement.isOverdue
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade300),
          )
        : null,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  agreement.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusChip(
                status: agreement.status,
                label: agreement.statusDisplay,
              ),
            ],
          ),
          if (agreement.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(agreement.description),
          ],
          const SizedBox(height: 8),
          Text(
            'Responsable: ${agreement.responsibleName.isEmpty ? 'Sin asignar' : agreement.responsibleName}',
          ),
          Text(
            'Plazo: ${formatAssemblyDate(agreement.dueAt, fallback: 'Sin plazo')}',
          ),
          Text('Presupuesto: ${formatMoney(agreement.estimatedBudget)}'),
          Text('Costo real: ${formatMoney(agreement.actualCost)}'),
          if (agreement.attachmentsCount > 0)
            Text('Evidencias: ${agreement.attachmentsCount}'),
        ],
      ),
    ),
  );
}
