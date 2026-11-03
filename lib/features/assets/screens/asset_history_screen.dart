import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/asset_controller.dart';
import '../models/asset_models.dart';

class AssetHistoryScreen extends StatelessWidget {
  const AssetHistoryScreen({required this.assetId, Key? key}) : super(key: key);

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetController>(
      builder: (context, controller, _) {
        final history = controller.history;

        if (controller.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Historial del Activo')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Historial del Activo')),
            body: Center(child: Text('Error: ${controller.error}')),
          );
        }

        if (history == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Historial del Activo')),
            body: const Center(child: Text('No hay historial disponible')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Historial del Activo'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Incidentes'),
                  Tab(text: 'Órdenes'),
                  Tab(text: 'Mantenimiento'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildIncidentsList(history.incidents),
                _buildWorkOrdersList(history.workOrders),
                _buildMaintenancePlansList(history.maintenancePlans),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncidentsList(List<Incident> incidents) {
    if (incidents.isEmpty) {
      return const Center(child: Text('Sin incidentes'));
    }
    return ListView.builder(
      itemCount: incidents.length,
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: Text(incident.title),
          subtitle: Text('${incident.publicCode} • ${incident.status}'),
          trailing: Text(_formatDateTime(incident.createdAt)),
        );
      },
    );
  }

  Widget _buildWorkOrdersList(List<WorkOrder> workOrders) {
    if (workOrders.isEmpty) {
      return const Center(child: Text('Sin órdenes de trabajo'));
    }
    return ListView.builder(
      itemCount: workOrders.length,
      itemBuilder: (context, index) {
        final order = workOrders[index];
        return ListTile(
          leading: const Icon(Icons.build, color: Colors.blue),
          title: Text(order.title),
          subtitle: Text('${order.publicCode} • ${order.workType}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.status,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                _formatDateTime(order.createdAt),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaintenancePlansList(List<MaintenancePlan> plans) {
    if (plans.isEmpty) {
      return const Center(child: Text('Sin planes de mantenimiento'));
    }
    return ListView.builder(
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return ListTile(
          leading: Icon(
            Icons.schedule,
            color: plan.isActive ? Colors.green : Colors.grey,
          ),
          title: Text(plan.name),
          subtitle: Text('Cada ${plan.frequencyDays} días'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDateTime(plan.nextDueAt),
                style: const TextStyle(fontSize: 12),
              ),
              if (plan.lastCompletedAt != null)
                Text(
                  'Última: ${_formatDateTime(plan.lastCompletedAt!)}',
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
