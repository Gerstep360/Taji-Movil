import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/router/app_routes.dart';
import '../state/asset_controller.dart';

class AssetQRScannerScreen extends StatefulWidget {
  const AssetQRScannerScreen({Key? key}) : super(key: key);

  @override
  State<AssetQRScannerScreen> createState() => _AssetQRScannerScreenState();
}

class _AssetQRScannerScreenState extends State<AssetQRScannerScreen> {
  late MobileScannerController _cameraController;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final qrPayload = barcodes.first.rawValue;
    if (qrPayload == null || qrPayload.isEmpty) return;

    final regex = RegExp(r'^TAJI-ASSET\.[0-9a-fA-F]+$');
    if (!regex.hasMatch(qrPayload)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR inválido')),
      );
      return;
    }

    await _cameraController.stop();
    if (!mounted) return;
    final controller = context.read<AssetController>();
    await controller.scanQr(qrPayload);

    if (!mounted) return;
    if (controller.asset != null) {
      context.push(AppRoute.assetDetailFor(controller.asset!.id));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error ?? 'Error')),
      );
      await _cameraController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Activo')),
      body: MobileScanner(
        controller: _cameraController,
        onDetect: _handleQRCode,
        errorBuilder: (context, error) => Center(
          child: Text('Error de cámara: ${error.errorCode}'),
        ),
      ),
    );
  }
}
