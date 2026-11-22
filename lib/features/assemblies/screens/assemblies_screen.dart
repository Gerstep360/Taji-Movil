import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../data/assemblies_repository.dart';
import '../models/assembly_models.dart';
import '../state/assemblies_controller.dart';
import '../widgets/assembly_format.dart';
import 'assembly_detail_screen.dart';

const _statusFilters = <(String, String)>[
  ('', 'Todas'),
  ('SCHEDULED', 'Programadas'),
  ('IN_PROGRESS', 'En curso'),
  ('FINISHED', 'Finalizadas'),
  ('CANCELLED', 'Canceladas'),
];

class AssembliesScreen extends StatefulWidget {
  const AssembliesScreen({super.key, this.repository});

  /// Permite inyectar un repositorio en pruebas; en la app se arma con el
  /// `ApiClient` compartido.
  final AssembliesRepository? repository;

  @override
  State<AssembliesScreen> createState() => _AssembliesScreenState();
}

class _AssembliesScreenState extends State<AssembliesScreen> {
  late final AssembliesRepository repository;
  late final AssembliesController controller;

  @override
  void initState() {
    super.initState();
    repository =
        widget.repository ?? AssembliesRepository(context.read<ApiClient>());
    controller = AssembliesController(repository)..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _open(AssemblyItem assembly) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AssemblyDetailScreen(assembly: assembly, repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Asambleas y acuerdos'),
        actions: [
          IconButton(
            onPressed: controller.loading ? null : () => controller.load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.canFilter)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final (value, label) in _statusFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: controller.status == value,
                        onSelected: (_) =>
                            controller.load(selectedStatus: value),
                      ),
                    ),
                ],
              ),
            ),
          if (controller.loading) const LinearProgressIndicator(),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(controller.error!, semanticsLabel: controller.error),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (controller.items.isEmpty &&
                      !controller.loading &&
                      controller.error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay asambleas para mostrar.'),
                    ),
                  for (final assembly in controller.items)
                    Card(
                      child: ListTile(
                        onTap: () => _open(assembly),
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          assembly.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatAssemblyDate(assembly.scheduledAt)),
                              if (assembly.location.isNotEmpty)
                                Text(assembly.location),
                              if (assembly.hasFullAccess)
                                Text(
                                  '${assembly.openAgreementsCount} acuerdos '
                                  'abiertos de ${assembly.agreementsCount}',
                                ),
                              const SizedBox(height: 8),
                              StatusChip(
                                status: assembly.status,
                                label: assembly.statusDisplay,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: controller.loading || controller.page <= 1
                        ? null
                        : () => controller.load(
                            selectedPage: controller.page - 1,
                          ),
                    child: const Text('Anterior'),
                  ),
                  Text(
                    'Página ${controller.page} de '
                    '${controller.pages < 1 ? 1 : controller.pages}',
                  ),
                  TextButton(
                    onPressed:
                        controller.loading || controller.page >= controller.pages
                        ? null
                        : () => controller.load(
                            selectedPage: controller.page + 1,
                          ),
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
