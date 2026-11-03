import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../models/asset_models.dart';
import '../repositories/asset_repository.dart';

class AssetController extends ChangeNotifier {
  AssetController(this._repository);

  final AssetRepository _repository;
  Asset? _asset;
  AssetHistory? _history;
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;

  Asset? get asset => _asset;
  AssetHistory? get history => _history;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;

  Future<void> scanQr(String qrPayload) async {
    _isScanning = true;
    _error = null;
    notifyListeners();
    try {
      _asset = await _repository.scanQr(qrPayload);
    } on ApiFailure catch (failure) {
      _error = failure.displayMessage;
    } catch (e) {
      _error = 'Error al escanear QR: ${e.toString()}';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> fetchAssetHistory(int assetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _history = await _repository.getAssetHistory(assetId);
    } on ApiFailure catch (failure) {
      _error = failure.displayMessage;
    } catch (e) {
      _error = 'Error al cargar historial: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _asset = null;
    _history = null;
    _isLoading = false;
    _isScanning = false;
    _error = null;
    notifyListeners();
  }
}
