import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';

class FaceVerificationException implements Exception {
  const FaceVerificationException(this.failure);

  final ApiFailure failure;
  String get message => failure.displayMessage;
}

class FaceVerificationRepository {
  const FaceVerificationRepository(this._api);

  final ApiClient _api;

  Future<FaceMatchResultModel> matchFace({
    required String capturedImage,
    int? targetResidentId,
    double threshold = 0.70,
  }) async {
    try {
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.security.faceMatch,
        data: {
          'captured_image': capturedImage,
          if (targetResidentId != null) 'target_resident_id': targetResidentId,
          'threshold': threshold,
        },
      );
      return FaceMatchResultModel.fromJson(json!);
    } on DioException catch (error) {
      throw FaceVerificationException(
        ApiFailure.fromDio(error, fallback: 'No se pudo realizar el análisis de coincidencia facial.'),
      );
    }
  }

  Future<FaceVerificationModel> confirmVerification({
    required String capturedImage,
    int? matchedResidentId,
    int? biometricReferenceId,
    required double similarityScore,
    double threshold = 0.70,
    required String result,
    required bool humanConfirmed,
    bool createAccessEvent = true,
    String eventType = 'ENTRY',
    String notes = '',
  }) async {
    try {
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.security.faceConfirm,
        data: {
          'captured_image': capturedImage,
          'matched_resident_id': matchedResidentId,
          'biometric_reference_id': biometricReferenceId,
          'similarity_score': similarityScore,
          'threshold': threshold,
          'result': result,
          'human_confirmed': humanConfirmed,
          'create_access_event': createAccessEvent,
          'event_type': eventType,
          'notes': notes,
        },
      );
      return FaceVerificationModel.fromJson(json!);
    } on DioException catch (error) {
      throw FaceVerificationException(
        ApiFailure.fromDio(error, fallback: 'No se pudo guardar la confirmación humana.'),
      );
    }
  }

  Future<BiometricReferenceModel> enrollBiometric({
    required int residentId,
    required String referenceImage,
  }) async {
    try {
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.security.biometricsEnroll,
        data: {
          'resident_id': residentId,
          'reference_image': referenceImage,
        },
      );
      return BiometricReferenceModel.fromJson(json!);
    } on DioException catch (error) {
      throw FaceVerificationException(
        ApiFailure.fromDio(error, fallback: 'No se pudo registrar la referencia biométrica.'),
      );
    }
  }
}
