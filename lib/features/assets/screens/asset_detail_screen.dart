import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/router/app_routes.dart';
import '../state/asset_controller.dart';

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({required this.assetId, Key? key}) : super(key: key);

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetController>(
      builder: (context, controller, _) {
        final asset = controller.asset;

        if (asset == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Activo')),
            body: const Center(child: Text('No hay datos')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle de Activo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  context.push('/detalle-activo/$assetId/historial');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Código', asset.code),
                        _buildDetailRow('Nombre', asset.name),
                        _buildDetailRow('Tipo', asset.assetTypeName),
                        if (asset.sectorName != null)
                          _buildDetailRow('Sector', asset.sectorName!),
                        _buildDetailRow('Estado', asset.status),
                        _buildDetailRow(
                          'Creado',
                          _formatDateTime(asset.createdAt),
                        ),
                        if (asset.description != null)
                          _buildDetailRow('Descripción', asset.description!),
                        if (asset.brand != null)
                          _buildDetailRow('Marca', asset.brand!),
                        if (asset.model != null)
                          _buildDetailRow('Modelo', asset.model!),
                        if (asset.serialNumber != null)
                          _buildDetailRow('Serie', asset.serialNumber!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('Ver Historial'),
                        onPressed: () {
                          controller.fetchAssetHistory(assetId);
                          context.push(AppRoute.assetDetailFor(assetId) + '/historial');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear Otro'),
                        onPressed: () {
                          controller.reset();
                          context.go(AppRoute.assetQrScanner.path);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value),
          const Divider(),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
