import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/asset_models.dart';

class AssetRepository {
  AssetRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Asset> scanQr(String qrPayload) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.assets.scan,
      data: {'qr_payload': qrPayload},
    );
    if (data == null) throw Exception('No data returned from server');
    return Asset.fromJson(data);
  }

  Future<AssetHistory> getAssetHistory(int assetId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.assets.history(assetId),
    );
    if (data == null) throw Exception('No data returned from server');
    return AssetHistory.fromJson(data);
  }
}
